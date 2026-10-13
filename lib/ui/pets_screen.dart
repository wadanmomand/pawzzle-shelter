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

class PetsScreen extends ConsumerWidget {
  const PetsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(gameProvider);
    final content = data.content!;
    final missions = data.missions!;
    final pets = content.pets.values.toList()
      ..sort((a, b) => a.rarity.index.compareTo(b.rarity.index));

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Row(
            children: [
              const Text('My Pets',
                  style:
                      TextStyle(fontWeight: FontWeight.w900, fontSize: 20)),
              const Spacer(),
              Text('${missions.rescued.length}/30 rescued',
                  style: const TextStyle(
                      color: AppColors.textSoft,
                      fontWeight: FontWeight.w700)),
            ],
          ),
        ),
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.all(12),
            gridDelegate:
                const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              childAspectRatio: 0.82,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
            ),
            itemCount: pets.length,
            itemBuilder: (_, i) => _petCard(context, ref, data, pets[i]),
          ),
        ),
      ],
    );
  }

  Widget _petCard(
      BuildContext context, WidgetRef ref, GameData data, PetDef def) {
    final missions = data.missions!;
    final rescued = missions.rescued.contains(def.id);
    final mission = missions.active[def.id];
    final color = rarityColor(def.rarity);

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
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color, width: rescued ? 2 : 1),
          boxShadow: const [
            BoxShadow(
                color: AppColors.cardShadow,
                blurRadius: 6,
                offset: Offset(0, 2))
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(6),
                child: Opacity(
                  opacity: rescued || mission != null ? 1.0 : 0.35,
                  child: Image.asset(
                    'assets/pets/${def.id}.webp',
                    fit: BoxFit.contain,
                    errorBuilder: (_, _, _) => const Icon(
                        Icons.pets_rounded,
                        size: 40,
                        color: AppColors.textSoft),
                  ),
                ),
              ),
            ),
            Text(def.name,
                style: const TextStyle(
                    fontWeight: FontWeight.w800, fontSize: 12)),
            Padding(
              padding: const EdgeInsets.only(bottom: 6, top: 2),
              child: mission != null
                  ? _missionMini(mission)
                  : Text(
                      rescued
                          ? rarityLabel(def.rarity)
                          : 'Tap to rescue',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: rescued ? color : AppColors.textSoft,
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
