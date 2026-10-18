/// Rescue missions: active timers + available rescues.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shelter/ads/ad_service.dart';
import 'package:shelter/core/economy.dart';
import 'package:shelter/core/format.dart';
import 'package:shelter/core/missions.dart';
import 'package:shelter/state/game.dart';
import 'package:shelter/ui/anim.dart';
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
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      children: [
        // Title card
        Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
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
          child: const Text(
            'Rescue Missions',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 24,
              color: AppColors.textDark,
              letterSpacing: 0.3,
            ),
          ),
        ),
        const SizedBox(height: 8),
        _statsRow(data),
        const SizedBox(height: 4),
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
              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
        ),
        for (final p in available) _availableCard(context, notifier, data, p),
      ],
    );
  }

  Widget _statsRow(GameData data) {
    final shelter = data.shelter!;
    return Row(
      children: [
        Expanded(
            child: _statBox('assets/zones/gold-coin.png',
                formatCompact(shelter.coins), 'Coins')),
        const SizedBox(width: 8),
        Expanded(
            child: _statBox('assets/zones/treat-bone.png',
                formatCompact(shelter.treats), 'Treats')),
        const SizedBox(width: 8),
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 10),
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
                const Icon(Icons.favorite_rounded,
                    color: AppColors.primaryDark, size: 26),
                Text('${data.missions!.rescued.length}/30',
                    style: const TextStyle(
                        fontWeight: FontWeight.w900, fontSize: 17)),
                const Text('Pets Rescued',
                    style: TextStyle(
                        fontSize: 11,
                        color: AppColors.textSoft,
                        fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _statBox(String asset, String value, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
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
          Image.asset(asset, width: 28, height: 28, fit: BoxFit.contain),
          Text(value,
              style: const TextStyle(
                  fontWeight: FontWeight.w900, fontSize: 17)),
          Text(label,
              style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.textSoft,
                  fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  String _difficulty(Rarity r) => switch (r) {
        Rarity.common => 'Easy',
        Rarity.rare => 'Medium',
        Rarity.epic => 'Hard',
      };

  String _location(GameData data, String petId) {
    final ids = data.content!.pets.keys.toList();
    final idx = ids.indexOf(petId);
    final zones = data.content!.zones;
    return zones[idx % zones.length].name;
  }

  Widget _missionCard(BuildContext context, GameNotifier notifier,
      GameData data, MissionState m, DateTime now) {
    final pet = data.content!.pets[m.petId]!;
    final ready = m.isReady(now);
    final progress = m.progress(now);
    final cost = instantFinishCost(pet.rarity);
    final canAfford = data.shelter!.treats >= cost;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
            color: ready ? AppColors.teal : rarityColor(pet.rarity),
            width: ready ? 2.5 : 1.5),
        boxShadow: const [
          BoxShadow(
              color: AppColors.cardShadow,
              blurRadius: 10,
              offset: Offset(0, 3))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: BoxDecoration(
              color: ready ? AppColors.teal : AppColors.teal.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Text(
              ready ? 'COMPLETE' : 'ACTIVE',
              style: TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 12,
                letterSpacing: 0.5,
                color: ready ? Colors.white : AppColors.teal,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Image.asset('assets/pets/${pet.id}.webp',
                    width: 76, height: 76, fit: BoxFit.cover),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Rescue ${pet.name}',
                        style: const TextStyle(
                            fontWeight: FontWeight.w900, fontSize: 18)),
                    const SizedBox(height: 2),
                    Text(
                      '${_location(data, pet.id)} • ${_difficulty(pet.rarity)}',
                      style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSoft,
                          fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: progress,
                        minHeight: 10,
                        backgroundColor: const Color(0xFFF3E5DC),
                        valueColor: AlwaysStoppedAnimation<Color>(
                            ready ? AppColors.teal : AppColors.primary),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      ready
                          ? 'Ready to Claim!'
                          : 'Time remaining: ${formatDuration(m.remaining(now))}',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: ready ? AppColors.teal : AppColors.textDark,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerRight,
            child: ready
                ? _actionButton(
                    label: 'Claim',
                    gold: true,
                    onTap: () => notifier.claimMission(m.petId),
                  )
                : canAfford
                    ? _actionButton(
                        label:
                            'Finish now • ${formatCompact(cost)} treats',
                        gold: false,
                        onTap: () => notifier.instantFinish(m.petId),
                      )
                    : _actionButton(
                        label: 'Watch ad to finish',
                        gold: false,
                        onTap: () => _instantFinishWithAd(
                            context, notifier, m.petId),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _actionButton(
      {required String label,
      required bool gold,
      required VoidCallback onTap}) {
    return BounceButton(
      onTap: onTap,
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          gradient: gold
              ? const LinearGradient(
                  colors: [Color(0xFFFFD54F), Color(0xFFFFB300)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                )
              : const LinearGradient(
                  colors: [Color(0xFFFF8A65), Color(0xFFF46B45)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
          borderRadius: BorderRadius.circular(24),
          boxShadow: const [
            BoxShadow(
                color: AppColors.cardShadow,
                blurRadius: 6,
                offset: Offset(0, 3))
          ],
        ),
        child: Text(
          label,
          style: const TextStyle(
            fontWeight: FontWeight.w900,
            fontSize: 14,
            color: Colors.white,
          ),
        ),
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
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(
              color: AppColors.cardShadow, blurRadius: 10, offset: Offset(0, 3))
        ],
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Opacity(
              opacity: 0.55,
              child: Image.asset('assets/pets/${pet.id}.webp',
                  width: 56, height: 56, fit: BoxFit.cover),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Rescue ${pet.name}',
                    style: const TextStyle(
                        fontWeight: FontWeight.w900, fontSize: 16)),
                const SizedBox(height: 2),
                Text(
                  '${_location(data, pet.id)} • ${_difficulty(pet.rarity)} • ${formatDuration(duration)}',
                  style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSoft,
                      fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Opacity(
            opacity: slotsLeft > 0 ? 1 : 0.4,
            child: _actionButton(
              label: 'Start Rescue',
              gold: false,
              onTap: slotsLeft > 0
                  ? () => notifier.startMission(pet.id)
                  : () {},
            ),
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
