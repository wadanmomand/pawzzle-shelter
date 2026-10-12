/// Rescue missions: timed missions that add pets to the collection.
///
/// Pure Dart — the UI/Riverpod layer drives time via [tick]; the engine
/// stays untouched. Durations come from rarity; the tutorial mission
/// (puppy_milo) is short on purpose.
library;

import 'package:shelter/core/economy.dart';

/// Mission length per rarity.
Duration missionDuration(Rarity rarity) => switch (rarity) {
      Rarity.common => const Duration(hours: 2),
      Rarity.rare => const Duration(hours: 4),
      Rarity.epic => const Duration(hours: 8),
    };

/// Treats to finish a mission instantly.
double instantFinishCost(Rarity rarity) => switch (rarity) {
      Rarity.common => 2,
      Rarity.rare => 4,
      Rarity.epic => 8,
    };

class MissionState {
  final String petId;
  final DateTime startedAt;
  final Duration duration;

  const MissionState({
    required this.petId,
    required this.startedAt,
    required this.duration,
  });

  double progress(DateTime now) {
    final elapsed = now.difference(startedAt);
    if (elapsed <= Duration.zero) return 0.0;
    return (elapsed.inMilliseconds / duration.inMilliseconds).clamp(0.0, 1.0);
  }

  bool isReady(DateTime now) => progress(now) >= 1.0;

  Duration remaining(DateTime now) {
    final left = startedAt.add(duration).difference(now);
    return left.isNegative ? Duration.zero : left;
  }
}

/// Tracks active rescue missions and the rescued collection.
class MissionBoard {
  static const int maxConcurrent = 3;

  MissionBoard();

  final Map<String, MissionState> active = {};
  final Set<String> rescued = {};

  int get activeCount => active.length;

  bool canStart(String petId) =>
      !rescued.contains(petId) &&
      !active.containsKey(petId) &&
      activeCount < maxConcurrent;

  /// Starts a rescue mission. Returns false when not allowed.
  bool start(String petId, Rarity rarity, DateTime now, {Duration? duration}) {
    if (!canStart(petId)) return false;
    active[petId] =
        MissionState(petId: petId, startedAt: now, duration: duration ?? missionDuration(rarity));
    return true;
  }

  /// Claims a finished mission, adding the pet to the collection.
  bool claim(String petId, DateTime now) {
    final m = active[petId];
    if (m == null || !m.isReady(now)) return false;
    active.remove(petId);
    rescued.add(petId);
    return true;
  }

  /// Removes a mission instantly (the caller charges treats via the economy).
  bool finishNow(String petId) {
    final m = active[petId];
    if (m == null) return false;
    active.remove(petId);
    rescued.add(petId);
    return true;
  }

  /// Cancels a mission (pet goes back to the available pool).
  bool cancel(String petId) => active.remove(petId) != null;

  Map<String, dynamic> toJson() => {
        'active': [
          for (final m in active.values)
            {
              'petId': m.petId,
              'startedAt': m.startedAt.toIso8601String(),
              'durationMs': m.duration.inMilliseconds,
            }
        ],
        'rescued': rescued.toList(),
      };

  factory MissionBoard.fromJson(Map<String, dynamic> j) {
    final b = MissionBoard();
    for (final m in (j['active'] as List? ?? [])) {
      final mm = m as Map<String, dynamic>;
      b.active[mm['petId'] as String] = MissionState(
        petId: mm['petId'] as String,
        startedAt: DateTime.parse(mm['startedAt'] as String),
        duration: Duration(milliseconds: (mm['durationMs'] as num).toInt()),
      );
    }
    b.rescued.addAll((j['rescued'] as List? ?? []).cast<String>());
    return b;
  }
}
