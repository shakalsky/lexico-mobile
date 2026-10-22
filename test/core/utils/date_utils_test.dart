import 'package:flutter_test/flutter_test.dart';
import 'package:lexico/core/utils/date_utils.dart';

void main() {
  final now = DateTime(2026, 8, 21, 9, 30);

  group('streakFromDays', () {
    test('is zero without any sessions', () {
      expect(streakFromDays(const [], now), 0);
    });

    test('counts consecutive days ending today', () {
      final days = [
        DateTime(2026, 8, 21, 8),
        DateTime(2026, 8, 20, 22),
        DateTime(2026, 8, 19, 7),
      ];
      expect(streakFromDays(days, now), 3);
    });

    test('still counts when the last session was yesterday', () {
      final days = [DateTime(2026, 8, 20, 22), DateTime(2026, 8, 19, 7)];
      expect(streakFromDays(days, now), 2);
    });

    test('lapses when the last session is older than yesterday', () {
      final days = [DateTime(2026, 8, 18), DateTime(2026, 8, 17)];
      expect(streakFromDays(days, now), 0);
    });

    test('collapses several sessions on the same day', () {
      final days = [
        DateTime(2026, 8, 21, 8),
        DateTime(2026, 8, 21, 12),
        DateTime(2026, 8, 20, 9),
      ];
      expect(streakFromDays(days, now), 2);
    });

    test('stops at the first gap', () {
      final days = [
        DateTime(2026, 8, 21),
        DateTime(2026, 8, 20),
        DateTime(2026, 8, 17),
      ];
      expect(streakFromDays(days, now), 2);
    });
  });
}
