/// Shelter home: currencies, zone chips, room list, floating TAP button.
library;

import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shelter/ads/ad_service.dart';
import 'package:shelter/core/economy.dart';
import 'package:shelter/core/format.dart';
import 'package:shelter/state/game.dart';
import 'package:shelter/ui/anim.dart';
import 'package:shelter/ui/nav.dart';
import 'package:shelter/ui/theme.dart';
import 'package:shelter/ui/widgets.dart';

class _Floater {
  final int id;
  final String text;
  final double dx; // -1..1 horizontal offset factor
  _Floater(this.id, this.text, this.dx);
}

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen>
    with SingleTickerProviderStateMixin {
  final List<_Floater> _floaters = [];
  int _floaterId = 0;
  late final AnimationController _tapCtrl;
  final _rand = Random();

  @override
  void initState() {
    super.initState();
    _tapCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
      lowerBound: 0.92,
      upperBound: 1.0,
    )..value = 1.0;
  }

  @override
  void dispose() {
    _tapCtrl.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails _) {
    _tapCtrl.reverse();
    final gained =
        ref.read(gameProvider.notifier).tap();
    setState(() {
      _floaters.add(_Floater(
        _floaterId++,
        '+${formatCompact(gained)}',
        _rand.nextDouble() * 1.6 - 0.8,
      ));
    });
    final id = _floaterId - 1;
    Timer(const Duration(milliseconds: 800), () {
      if (!mounted) return;
      setState(() => _floaters.removeWhere((f) => f.id == id));
    });
    Timer(const Duration(milliseconds: 120), () {
      if (mounted) _tapCtrl.forward();
    });
  }

  @override
  Widget build(BuildContext context) {
    final data = ref.watch(gameProvider);
    final shelter = data.shelter!;
    final content = data.content!;
    final zone = data.selectedZone;
    final rooms = content.roomsInZone(zone)
      ..sort((a, b) => a.baseCost.compareTo(b.baseCost));

    return Column(
      children: [
        _topBar(shelter),
        _currencyRow(shelter),
        _zoneChips(data),
        if (ShelterEconomy.canPrestige(shelter)) _prestigeBanner(shelter),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'ROOMS — ${rooms.where((r) => shelter.rooms[r.id]!.isBuilt).length}/${rooms.length} unlocked',
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 15,
                    color: AppColors.textDark,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              Text(
                '${formatCompact(ShelterEconomy.totalIncomePerSec(shelter))}/s',
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 12,
                  color: AppColors.teal,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: Stack(
            children: [
              ListView.builder(
                padding: const EdgeInsets.only(bottom: 170),
            itemCount: rooms.length,
            itemBuilder: (_, i) {
              final def = rooms[i];
              final rs = shelter.rooms[def.id]!;
              return RoomCard(
                room: rs,
                incomePerSec: ShelterEconomy.roomIncome(shelter, def.id),
                coins: shelter.coins,
                onUpgrade: () =>
                    ref.read(gameProvider.notifier).buyRoom(def.id),
              );
            },
          ),
              Positioned(
                bottom: 12,
                right: 12,
                child: _floatingTap(data),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _topBar(ShelterState shelter) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 6),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: const [
          BoxShadow(
              color: AppColors.cardShadow,
              blurRadius: 10,
              offset: Offset(0, 3))
        ],
      ),
      child: Row(
        children: [
          const Icon(Icons.auto_awesome_rounded,
              color: AppColors.gold, size: 22),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              'Pawzzle Shelter',
              style: TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 23,
                color: AppColors.teal,
                letterSpacing: 0.3,
              ),
            ),
          ),
          CurrencyPill(
            icon: Icons.pets_rounded,
            text: formatCompact(shelter.goldenPaws),
            iconColor: AppColors.teal,
          ),
          const SizedBox(width: 8),
          BounceButton(
            onTap: () => openSettings(context),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: const BoxDecoration(
                color: AppColors.teal,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.settings_rounded,
                  color: Colors.white, size: 20),
            ),
          ),
        ],
      ),
    );
  }

  Widget _currencyRow(ShelterState shelter) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 2, 12, 6),
      child: Row(
        children: [
          Expanded(
            child: CurrencyPill(
              asset: 'assets/zones/gold-coin.png',
              text: formatCompact(shelter.coins),
              iconColor: AppColors.gold,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: GestureDetector(
              onTap: _freeTreats,
              child: CurrencyPill(
                asset: 'assets/zones/treat-bone.png',
                text: '${formatCompact(shelter.treats)} +',
                iconColor: AppColors.primaryDark,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _freeTreats() async {
    final earned = await AdService.instance.showRewarded();
    if (!mounted) return;
    if (earned) {
      ref.read(gameProvider.notifier).grantTreats(5);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('+5 treats!')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No ad ready — try again later')),
      );
    }
  }

  Widget _zoneChips(GameData data) {
    final content = data.content!;
    final shelter = data.shelter!;
    return SizedBox(
      height: 56,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        itemCount: content.zones.length,
        itemBuilder: (_, i) {
          final z = content.zones[i];
          final unlocked = shelter.unlockedZones.contains(i);
          final selected = data.selectedZone == i;
          final nextLocked =
              !unlocked && (i == 0 || shelter.unlockedZones.contains(i - 1));
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: BounceButton(
              onTap: () {
                if (unlocked) {
                  ref.read(gameProvider.notifier).selectZone(i);
                } else if (nextLocked) {
                  _confirmUnlock(z.index, z.name, z.coinCost, z.requiredPets);
                }
              },
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                decoration: BoxDecoration(
                  color: selected
                      ? AppColors.teal
                      : unlocked
                          ? AppColors.surface
                          : const Color(0xFFF3E5DC),
                  borderRadius: BorderRadius.circular(22),
                  border: !selected && unlocked
                      ? Border.all(color: AppColors.teal, width: 1.5)
                      : null,
                  boxShadow: const [
                    BoxShadow(
                        color: AppColors.cardShadow,
                        blurRadius: 6,
                        offset: Offset(0, 2))
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (!unlocked)
                      const Icon(Icons.lock_rounded,
                          size: 14, color: AppColors.textSoft),
                    Text(
                      unlocked
                          ? z.name
                          : '${z.name} • ${formatCompact(z.coinCost)}',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                        color: selected
                            ? Colors.white
                            : unlocked
                                ? AppColors.teal
                                : AppColors.textSoft,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  void _confirmUnlock(int index, String name, double cost, int petsNeeded) {
    final notifier = ref.read(gameProvider.notifier);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Unlock $name?',
            style: const TextStyle(fontWeight: FontWeight.w900)),
        content: Text(
          'Cost: ${formatCompact(cost)} coins\nNeeds $petsNeeded rescued pets.',
          style: const TextStyle(color: AppColors.textSoft),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Later',
                style: TextStyle(color: AppColors.textSoft)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryDark,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30)),
            ),
            onPressed: () {
              Navigator.pop(ctx);
              if (notifier.unlockZone(index)) {
                ConfettiBurst.show(context);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text('Not enough coins or pets yet!')),
                );
              }
            },
            child: const Text('Unlock'),
          ),
        ],
      ),
    );
  }

  Widget _prestigeBanner(ShelterState shelter) {
    final gain = ShelterEconomy.prestigeGain(shelter);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: BounceButton(
        onTap: () => _confirmPrestige(gain),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFFFD54F), Color(0xFFFFB300)],
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.rocket_launch_rounded,
                  color: AppColors.textDark),
              const SizedBox(width: 8),
              Text(
                'Naya Season! +$gain Golden Paws',
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  color: AppColors.textDark,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _confirmPrestige(int gain) {
    final notifier = ref.read(gameProvider.notifier);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Start a Naya Season?',
            style: TextStyle(fontWeight: FontWeight.w900)),
        content: Text(
          'Gain $gain Golden Paws (+${gain * 2}% income forever).\n'
          'Rooms and coins reset — your pets stay!',
          style: const TextStyle(color: AppColors.textSoft),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Keep going',
                style: TextStyle(color: AppColors.textSoft)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryDark,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30)),
            ),
            onPressed: () {
              Navigator.pop(ctx);
              notifier.doPrestige();
              ConfettiBurst.show(context);
            },
            child: const Text('Prestige!'),
          ),
        ],
      ),
    );
  }

  /// Floating TAP cluster pinned to the bottom-right of the room list.
  /// The old fixed TAP section ate ~200px of vertical space and hid rooms
  /// behind it; floating it gives the room list the full screen height.
  /// The list's bottom padding (170) keeps the last card scrollable above
  /// this cluster.
  Widget _floatingTap(GameData data) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        _autoTapperChip(data),
        const SizedBox(height: 8),
        Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Image.asset(
              'assets/pets/puppy_milo.webp',
              width: 52,
              height: 52,
              fit: BoxFit.contain,
              errorBuilder: (_, _, _) => const SizedBox(width: 52),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 120,
              height: 110,
              child: Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.bottomCenter,
                children: [
                  // floating +N texts rise above the button
                  for (final f in _floaters)
                    _FloaterWidget(
                        key: ValueKey(f.id), text: f.text, dx: f.dx),
                  GestureDetector(
                    onTapDown: _onTapDown,
                    child: ScaleTransition(
                      scale: _tapCtrl,
                      child: Container(
                        width: 72,
                        height: 72,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            colors: [
                              AppColors.primary,
                              AppColors.primaryDark
                            ],
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.cardShadow,
                              blurRadius: 12,
                              offset: Offset(0, 6),
                            )
                          ],
                        ),
                        child: const Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.pets_rounded,
                                size: 24, color: Colors.white),
                            Text(
                              'TAP',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w900,
                                fontSize: 14,
                                letterSpacing: 1,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _autoTapperChip(GameData data) {
    final active = data.autoTapperActive;
    return BounceButton(
      onTap: active ? null : _startAutoTapper,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: active ? AppColors.teal : AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          boxShadow: const [
            BoxShadow(
                color: AppColors.cardShadow,
                blurRadius: 6,
                offset: Offset(0, 2))
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.bolt_rounded,
              size: 15,
              color: active ? Colors.white : AppColors.primaryDark,
            ),
            const SizedBox(width: 4),
            Text(
              active
                  ? 'Auto-tapper ${formatDuration(data.autoTapperUntil!.difference(DateTime.now()))}'
                  : 'Auto-tapper 4h (watch ad)',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 12,
                color: active ? Colors.white : AppColors.textDark,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _startAutoTapper() async {
    final earned = await AdService.instance.showRewarded();
    if (!mounted) return;
    if (earned) {
      ref.read(gameProvider.notifier).startAutoTapper();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Auto-tapper on for 4 hours!')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No ad ready — try again later')),
      );
    }
  }
}

class _FloaterWidget extends StatefulWidget {
  final String text;
  final double dx;
  const _FloaterWidget({super.key, required this.text, required this.dx});

  @override
  State<_FloaterWidget> createState() => _FloaterWidgetState();
}

class _FloaterWidgetState extends State<_FloaterWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  late final Animation<double> _y;
  late final Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 800))
      ..forward();
    _y = Tween(begin: 0.0, end: -70.0).animate(
        CurvedAnimation(parent: _c, curve: Curves.easeOut));
    _opacity = Tween(begin: 1.0, end: 0.0).animate(
        CurvedAnimation(parent: _c, curve: const Interval(0.4, 1.0)));
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (_, _) => Transform.translate(
        offset: Offset(widget.dx * 60, _y.value),
        child: Opacity(
          opacity: _opacity.value,
          child: Text(
            widget.text,
            style: const TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 18,
              color: AppColors.teal,
            ),
          ),
        ),
      ),
    );
  }
}
