import 'package:flutter_test/flutter_test.dart';
import 'package:shelter/core/format.dart';

void main() {
  group('formatCompact', () {
    test('small numbers', () {
      expect(formatCompact(0), equals('0'));
      expect(formatCompact(999), equals('999'));
      expect(formatCompact(999.5), equals('999.5'));
    });

    test('thousands', () {
      expect(formatCompact(1000), equals('1K'));
      expect(formatCompact(1500), equals('1.5K'));
      expect(formatCompact(1550), equals('1.55K'));
      expect(formatCompact(15000), equals('15K'));
      expect(formatCompact(150000), equals('150K'));
    });

    test('millions and up', () {
      expect(formatCompact(2500000), equals('2.5M'));
      expect(formatCompact(1000000000), equals('1B'));
      expect(formatCompact(3.42e12), equals('3.42T'));
      expect(formatCompact(1e15), equals('1Q'));
    });
  });

  group('formatDuration', () {
    test('seconds, minutes, hours', () {
      expect(formatDuration(const Duration(seconds: 45)), equals('45s'));
      expect(formatDuration(const Duration(seconds: 90)), equals('1m 30s'));
      expect(formatDuration(const Duration(seconds: 3661)), equals('1h 1m'));
      expect(formatDuration(Duration.zero), equals('0s'));
    });
  });
}
