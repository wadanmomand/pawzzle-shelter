/// Rescue missions: active timers + available rescues.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shelter/ads/ad_service.dart';
import 'package:shelter/core/economy.dart';
import 'package:shelter/core/format.dart';
import 'package:shelter/core/missions.dart';
import 'package:shelter/state/game.dart';
import 'package:shelter/ui/theme.dart';

class MissionsScreen extends ConsumerWidget {
  const MissionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(gameProvider);
    final content = data.content!;
    final missions = data.missions!;
    final now = DateTime.now();
    final notifier = ref.read(gameProvider.notifier);

    final active = missions.active.values.toList();
    final available = content.pets.values
        .where((p) =>
            !missions.rescued.contains(p.id) &&
            !missions.active.containsKey(p.id))
        .toList()
      ..sort((a, b) => a.rarity.index.compareTo(b.rarity.index));

    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(4, 4, 4, 8),
          child: Text('Rescue Missions',
              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 20)),
        ),
        if (active.isEmpty)
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'No active missions. Start one below to rescue a pet!',
              style: TextStyle(color: AppColors.textSoft),
              textAlign: TextAlign.center,
            ),
          ),
        for (final m in active) _missionCard(context, notifier, data, m, now),
        const SizedBox(height: 12),
        const Padding(
          padding: EdgeInsets.fromLTRB(4, 4, 4, 8),
          child: Text('Available rescues',
              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
        ),
        for (final p in available) _availableCard(context, notifier, data, p),
      ],
    );
  }

  Widget _missionCard(BuildContext context, GameNotifier notifier,
      GameData data, MissionState m, DateTime now) {
    final pet = data.content!.pets[m.petId]!;
    final ready = m.isReady(now);
    final progress = m.progress(now);
    final cost = instantFinishCost(pet.rarity);
    final canAfford = data.shelter!.treats >= cost;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: rarityColor(pet.rarity), width: 1.5),
        boxShadow: const [
          BoxShadow(
              color: AppColors.cardShadow, blurRadius: 6, offset: Offset(0, 2))
        ],
      ),
      child: Row(
        children: [
          SizedBox(
            width: 56,
            height: 56,
            child: Image.asset('assets/pets/${pet.id}.webp',
                fit: BoxFit.contain),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Rescue ${pet.name}',
                    style: const TextStyle(
                        fontWeight: FontWeight.w800, fontSize: 15)),
                const SizedBox(height: 4),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 8,
                    backgroundColor: const Color(0xFFF3E5DC),
                    valueColor: AlwaysStoppedAnimation<Color>(
                        ready ? AppColors.teal : AppColors.primary),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  ready ? 'Ready to claim!' : formatDuration(m.remaining(now)),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color:
                        ready ? AppColors.teal : AppColors.textSoft,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (ready)
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.teal,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30)),
              ),
              onPressed: () => notifier.claimMission(m.petId),
              child: const Text('Claim'),
            )
          else if (canAfford)
            OutlinedButton(
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primaryDark,
                side:
                    const BorderSide(color: AppColors.primaryDark),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30)),
              ),
              onPressed: () => notifier.instantFinish(m.petId),
              child: Text('${formatCompact(cost)} treats'),
            )
          else
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.teal,
                side: const BorderSide(color: AppColors.teal),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30)),
              ),
              onPressed: () => _instantFinishWithAd(context, notifier, m.petId),
              icon: const Icon(Icons.play_circle_outline_rounded, size: 16),
              label: const Text('Watch ad'),
            ),
        ],
      ),
    );
  }

  Widget _availableCard(BuildContext context, GameNotifier notifier,
      GameData data, PetDef pet) {
    final slotsLeft =
        MissionBoard.maxConcurrent - data.missions!.activeCount;
    final duration = (pet.id == kTutorialPetId &&
            data.missions!.rescued.isEmpty)
        ? kTutorialMission
        : missionDuration(pet.rarity);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
              color: AppColors.cardShadow, blurRadius: 6, offset: Offset(0, 2))
        ],
      ),
      child: Row(
        children: [
          SizedBox(
            width: 48,
            height: 48,
            child: Opacity(
              opacity: 0.45,
              child: Image.asset('assets/pets/${pet.id}.webp',
                  fit: BoxFit.contain),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(pet.name,
                    style: const TextStyle(
                        fontWeight: FontWeight.w800, fontSize: 14)),
                Text(
                  '${rarityLabel(pet.rarity)} • ${formatDuration(duration)}',
                  style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textSoft,
                      fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30)),
            ),
            onPressed: slotsLeft > 0
                ? () => notifier.startMission(pet.id)
                : null,
            child: const Text('Rescue'),
          ),
        ],
      ),
    );
  }

  Future<void> _instantFinishWithAd(
      BuildContext context, GameNotifier notifier, String petId) async {
    final earned = await AdService.instance.showRewarded();
    if (!context.mounted) return;
    if (earned) {
      notifier.instantFinishFree(petId);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No ad ready — try again later')),
      );
    }
  }
}
