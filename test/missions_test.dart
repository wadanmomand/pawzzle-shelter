import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shelter/core/economy.dart';
import 'package:shelter/core/missions.dart';

void main() {
  final t0 = DateTime(2026, 1, 1, 12);

  group('mission durations', () {
    test('duration by rarity', () {
      expect(missionDuration(Rarity.common), equals(const Duration(hours: 2)));
      expect(missionDuration(Rarity.rare), equals(const Duration(hours: 4)));
      expect(missionDuration(Rarity.epic), equals(const Duration(hours: 8)));
    });

    test('instant finish cost by rarity', () {
      expect(instantFinishCost(Rarity.common), equals(2));
      expect(instantFinishCost(Rarity.rare), equals(4));
      expect(instantFinishCost(Rarity.epic), equals(8));
    });

    test('progress and remaining', () {
      final m = MissionState(
          petId: 'x', startedAt: t0, duration: const Duration(hours: 2));
      expect(m.progress(t0), equals(0.0));
      expect(m.progress(t0.add(const Duration(hours: 1))), equals(0.5));
      expect(m.isReady(t0.add(const Duration(hours: 2))), isTrue);
      expect(m.isReady(t0.add(const Duration(hours: 3))), isTrue);
      expect(m.remaining(t0.add(const Duration(minutes: 30))),
          equals(const Duration(hours: 1, minutes: 30)));
      expect(
          m.remaining(t0.add(const Duration(hours: 5))), equals(Duration.zero));
    });
  });

  group('mission board', () {
    test('start and claim a mission', () {
      final b = MissionBoard();
      expect(b.start('puppy_milo', Rarity.common, t0), isTrue);
      expect(b.activeCount, equals(1));
      expect(
          b.claim('puppy_milo', t0.add(const Duration(hours: 1))), isFalse);
      expect(
          b.claim('puppy_milo', t0.add(const Duration(hours: 2))), isTrue);
      expect(b.rescued, contains('puppy_milo'));
      expect(b.activeCount, equals(0));
    });

    test('cannot start the same pet twice or a rescued pet', () {
      final b = MissionBoard();
      expect(b.start('puppy_milo', Rarity.common, t0), isTrue);
      expect(b.start('puppy_milo', Rarity.common, t0), isFalse);
      b.claim('puppy_milo', t0.add(const Duration(hours: 3)));
      expect(b.start('puppy_milo', Rarity.common, t0), isFalse);
    });

    test('max 3 concurrent missions', () {
      final b = MissionBoard();
      expect(b.start('a', Rarity.common, t0), isTrue);
      expect(b.start('b', Rarity.common, t0), isTrue);
      expect(b.start('c', Rarity.common, t0), isTrue);
      expect(b.start('d', Rarity.common, t0), isFalse);
      expect(b.cancel('a'), isTrue);
      expect(b.start('d', Rarity.common, t0), isTrue);
    });

    test('finishNow skips the timer', () {
      final b = MissionBoard();
      b.start('kitten_luna', Rarity.rare, t0);
      expect(b.finishNow('kitten_luna'), isTrue);
      expect(b.rescued, contains('kitten_luna'));
      expect(b.finishNow('nope'), isFalse);
    });

    test('cancel returns pet to the pool', () {
      final b = MissionBoard();
      b.start('a', Rarity.common, t0);
      expect(b.cancel('a'), isTrue);
      expect(b.activeCount, equals(0));
      expect(b.start('a', Rarity.common, t0), isTrue);
    });

    test('custom duration override (tutorial)', () {
      final b = MissionBoard();
      b.start('puppy_milo', Rarity.common, t0,
          duration: const Duration(seconds: 60));
      expect(b.claim('puppy_milo', t0.add(const Duration(seconds: 61))),
          isTrue);
    });

    test('toJson/fromJson roundtrip through real JSON', () {
      final b = MissionBoard();
      b.start('a', Rarity.common, t0);
      b.rescued.add('old_pet');
      final raw = jsonDecode(jsonEncode(b.toJson())) as Map<String, dynamic>;
      final loaded = MissionBoard.fromJson(raw);
      expect(loaded.active.containsKey('a'), isTrue);
      expect(loaded.rescued, contains('old_pet'));
      expect(
          loaded.active['a']!.startedAt.isAtSameMomentAs(t0), isTrue);
    });
  });
}
