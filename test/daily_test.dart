import 'package:flutter_test/flutter_test.dart';
import 'package:shelter/core/daily.dart';

void main() {
  group('daily rewards', () {
    test('first claim starts streak at 1', () {
      final s = DailyState();
      final now = DateTime(2026, 10, 12, 10);
      expect(dailyClaimable(s, now), isTrue);
      final r = claimDaily(s, now)!;
      expect(r.day, equals(1));
      expect(r.kind, equals('coins'));
      expect(r.amount, equals(500));
      expect(s.streak, equals(1));
      expect(s.lastClaim, equals('2026-10-12'));
    });

    test('cannot claim twice the same day', () {
      final s = DailyState();
      final now = DateTime(2026, 10, 12, 10);
      claimDaily(s, now);
      expect(dailyClaimable(s, now.add(const Duration(hours: 5))), isFalse);
      expect(claimDaily(s, now.add(const Duration(hours: 5))), isNull);
    });

    test('consecutive days grow the streak', () {
      final s = DailyState();
      var day = DateTime(2026, 10, 12);
      for (var expected = 1; expected <= 3; expected++) {
        final r = claimDaily(s, day)!;
        expect(r.day, equals(expected));
        expect(s.streak, equals(expected));
        day = day.add(const Duration(days: 1));
      }
    });

    test('missing a day resets the streak', () {
      final s = DailyState();
      claimDaily(s, DateTime(2026, 10, 10));
      claimDaily(s, DateTime(2026, 10, 11));
      final r = claimDaily(s, DateTime(2026, 10, 13))!; // skipped 12th
      expect(r.day, equals(1));
      expect(s.streak, equals(1));
    });

    test('streak wraps after day 7', () {
      final s = DailyState(lastClaim: '2026-10-18', streak: 7);
      final r = claimDaily(s, DateTime(2026, 10, 19))!;
      expect(r.day, equals(1));
      expect(s.streak, equals(1));
    });

    test('previewDaily matches what claim would give', () {
      final s = DailyState();
      final now = DateTime(2026, 10, 12);
      expect(previewDaily(s, now).day, equals(1));
      claimDaily(s, now);
      final tomorrow = now.add(const Duration(days: 1));
      expect(previewDaily(s, tomorrow).day, equals(2));
      expect(previewDaily(s, tomorrow).kind, equals('treats'));
    });

    test('dateKey format', () {
      expect(dateKey(DateTime(2026, 1, 5)), equals('2026-01-05'));
    });
  });
}
