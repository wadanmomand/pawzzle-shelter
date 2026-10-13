/// Shelter home: currencies, zone chips, room list, big TAP button.
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
        _zoneChips(data),
        if (ShelterEconomy.canPrestige(shelter)) _prestigeBanner(shelter),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.only(bottom: 8),
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
        ),
        _tapArea(data),
      ],
    );
  }

  Widget _topBar(ShelterState shelter) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      child: Row(
        children: [
          CurrencyPill(
            icon: Icons.monetization_on_rounded,
            text: formatCompact(shelter.coins),
            iconColor: AppColors.gold,
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: _freeTreats,
            child: CurrencyPill(
              icon: Icons.cookie_rounded,
              text: '${formatCompact(shelter.treats)} +',
              iconColor: AppColors.primaryDark,
            ),
          ),
          const SizedBox(width: 8),
          CurrencyPill(
            icon: Icons.pets_rounded,
            text: formatCompact(shelter.goldenPaws),
            iconColor: AppColors.teal,
          ),
          const Spacer(),
          Text(
            '${formatCompact(ShelterEconomy.totalIncomePerSec(shelter))}/s',
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 13,
              color: AppColors.teal,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.settings_rounded,
                color: AppColors.textSoft),
            onPressed: () => openSettings(context),
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
      height: 46,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: selected
                      ? AppColors.primaryDark
                      : unlocked
                          ? AppColors.surface
                          : const Color(0xFFF3E5DC),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: selected
                      ? const [
                          BoxShadow(
                              color: AppColors.cardShadow,
                              blurRadius: 6,
                              offset: Offset(0, 2))
                        ]
                      : null,
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
                        fontSize: 12,
                        color: selected ? Colors.white : AppColors.textDark,
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

  Widget _tapArea(GameData data) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: 150,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // floating +N texts
              for (final f in _floaters)
                _FloaterWidget(key: ValueKey(f.id), text: f.text, dx: f.dx),
              GestureDetector(
                onTapDown: _onTapDown,
                child: ScaleTransition(
                  scale: _tapCtrl,
                  child: Container(
                    width: 108,
                    height: 108,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [AppColors.primary, AppColors.primaryDark],
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
                            size: 40, color: Colors.white),
                        Text(
                          'TAP',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: 14,
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
        _autoTapperChip(data),
        const SizedBox(height: 6),
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
