/// Pets album: 30 pets, rescue / assign / feed.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shelter/core/economy.dart';
import 'package:shelter/core/format.dart';
import 'package:shelter/core/missions.dart';
import 'package:shelter/state/game.dart';
import 'package:shelter/ui/anim.dart';
import 'package:shelter/ui/theme.dart';
import 'package:shelter/ui/widgets.dart';

class PetsScreen extends ConsumerWidget {
  const PetsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(gameProvider);
    final content = data.content!;
    final missions = data.missions!;
    final shelter = data.shelter!;
    final pets = content.pets.values.toList()
      ..sort((a, b) => a.rarity.index.compareTo(b.rarity.index));
    final rescuedCount = missions.rescued.length;

    return Column(
      children: [
        // Album header card
        Container(
          margin: const EdgeInsets.fromLTRB(12, 8, 12, 4),
          padding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
              const Expanded(
                child: Text(
                  'PETS ALBUM',
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 24,
                    color: Color(0xFFE8A93D),
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              CurrencyPill(
                asset: 'assets/zones/gold-coin.png',
                text: formatCompact(shelter.coins),
                iconColor: AppColors.gold,
              ),
            ],
          ),
        ),
        // Collection progress
        Container(
          margin: const EdgeInsets.fromLTRB(12, 4, 12, 4),
          padding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            boxShadow: const [
              BoxShadow(
                  color: AppColors.cardShadow,
                  blurRadius: 8,
                  offset: Offset(0, 2))
            ],
          ),
          child: Column(
            children: [
              Text(
                'Your rescued friends • $rescuedCount/30 collected',
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                  color: AppColors.textDark,
                ),
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: rescuedCount / 30,
                  minHeight: 10,
                  backgroundColor: const Color(0xFFF3E5DC),
                  valueColor: const AlwaysStoppedAnimation<Color>(
                      AppColors.primary),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.all(12),
            gridDelegate:
                const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 0.78,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
            ),
            itemCount: pets.length,
            itemBuilder: (_, i) => _petCard(context, ref, data, pets[i]),
          ),
        ),
      ],
    );
  }

  int _rarityStars(Rarity r) => switch (r) {
        Rarity.common => 1,
        Rarity.rare => 2,
        Rarity.epic => 3,
      };

  Widget _petCard(
      BuildContext context, WidgetRef ref, GameData data, PetDef def) {
    final missions = data.missions!;
    final rescued = missions.rescued.contains(def.id);
    final mission = missions.active[def.id];
    final color = rarityColor(def.rarity);
    final petState = data.shelter!.pets[def.id];
    final happiness = petState?.happiness ?? 0.0;

    return BounceButton(
      onTap: () {
        if (rescued) {
          _petSheet(context, ref, data, def);
        } else if (mission == null) {
          if (!ref.read(gameProvider.notifier).startMission(def.id)) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                  content: Text('Mission slots full (3 max)!')),
            );
          }
        }
      },
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color, width: rescued ? 2.5 : 1),
          boxShadow: const [
            BoxShadow(
                color: AppColors.cardShadow,
                blurRadius: 10,
                offset: Offset(0, 3))
          ],
        ),
        child: Column(
          children: [
            Expanded(
              flex: 5,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10, 10, 10, 4),
                child: Opacity(
                  opacity: rescued || mission != null ? 1.0 : 0.35,
                  child: Image.asset(
                    'assets/pets/${def.id}.webp',
                    fit: BoxFit.contain,
                    errorBuilder: (_, _, _) => const Icon(
                        Icons.pets_rounded,
                        size: 48,
                        color: AppColors.textSoft),
                  ),
                ),
              ),
            ),
            Expanded(
              flex: 4,
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(def.name,
                        style: const TextStyle(
                            fontWeight: FontWeight.w900, fontSize: 16)),
                    const SizedBox(height: 4),
                    if (rescued) ...[
                      Row(
                        children: [
                          const Icon(Icons.favorite_rounded,
                              color: AppColors.primaryDark, size: 16),
                          const SizedBox(width: 4),
                          Expanded(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(5),
                              child: LinearProgressIndicator(
                                value: happiness / 100,
                                minHeight: 9,
                                backgroundColor:
                                    const Color(0xFFF3E5DC),
                                valueColor:
                                    const AlwaysStoppedAnimation<Color>(
                                        AppColors.primary),
                              ),
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text('${happiness.round()}%',
                              style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 10,
                                  color: AppColors.textSoft)),
                        ],
                      ),
                      const SizedBox(height: 3),
                    ] else if (mission != null)
                      _missionMini(mission)
                    else
                      const Text('Tap to rescue',
                          style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textSoft)),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        for (int s = 0;
                            s < _rarityStars(def.rarity);
                            s++)
                          const Icon(Icons.star_rounded,
                              size: 14, color: AppColors.gold),
                        const SizedBox(width: 4),
                        Text(
                          rarityLabel(def.rarity).toUpperCase(),
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            color: color,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _missionMini(MissionState m) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: LinearProgressIndicator(
          value: m.progress(DateTime.now()),
          minHeight: 5,
          backgroundColor: const Color(0xFFF3E5DC),
          valueColor:
              const AlwaysStoppedAnimation<Color>(AppColors.primary),
        ),
      ),
    );
  }

  void _petSheet(
      BuildContext context, WidgetRef ref, GameData data, PetDef def) {
    final notifier = ref.read(gameProvider.notifier);
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        // re-read fresh state inside the sheet
        final d = ref.read(gameProvider);
        final pet = d.shelter!.pets[def.id]!;
        final shelter = d.shelter!;
        final builtRooms = shelter.rooms.values
            .where((r) => r.isBuilt)
            .toList();
        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                height: 120,
                child: Image.asset('assets/pets/${def.id}.webp',
                    fit: BoxFit.contain),
              ),
              const SizedBox(height: 8),
              Text(def.name,
                  style: const TextStyle(
                      fontWeight: FontWeight.w900, fontSize: 20)),
              Text(
                '${rarityLabel(def.rarity)}  •  x${def.rarity.roomMultiplier} room income',
                style: TextStyle(
                    color: rarityColor(def.rarity),
                    fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Icon(Icons.favorite_rounded,
                      color: AppColors.primaryDark, size: 18),
                  const SizedBox(width: 6),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: pet.happiness / 100,
                        minHeight: 10,
                        backgroundColor: const Color(0xFFF3E5DC),
                        valueColor:
                            const AlwaysStoppedAnimation<Color>(
                                AppColors.primary),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text('${pet.happiness.round()}%',
                      style: const TextStyle(
                          fontWeight: FontWeight.w800, fontSize: 12)),
                ],
              ),
              const SizedBox(height: 8),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.teal,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30)),
                ),
                onPressed: shelter.treats >= 1
                    ? () {
                        notifier.feedPet(def.id);
                        Navigator.pop(ctx);
                      }
                    : null,
                icon: const Icon(Icons.cookie_rounded, size: 18),
                label: Text(
                    'Feed (1 treat) — you have ${formatCompact(shelter.treats)}'),
              ),
              const SizedBox(height: 12),
              const Align(
                alignment: Alignment.centerLeft,
                child: Text('Assign to room:',
                    style: TextStyle(fontWeight: FontWeight.w800)),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                children: [
                  ChoiceChip(
                    label: const Text('Rest'),
                    selected: pet.assignedRoomId == null,
                    onSelected: (_) {
                      notifier.assignPet(def.id, null);
                      Navigator.pop(ctx);
                    },
                  ),
                  for (final r in builtRooms)
                    ChoiceChip(
                      label: Text(r.def.name),
                      selected: pet.assignedRoomId == r.def.id,
                      onSelected: (_) {
                        notifier.assignPet(def.id, r.def.id);
                        Navigator.pop(ctx);
                      },
                    ),
                ],
              ),
              const SizedBox(height: 12),
            ],
          ),
        );
      },
    );
  }
}
