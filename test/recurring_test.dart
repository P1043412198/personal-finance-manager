import 'package:flutter_test/flutter_test.dart';

import 'package:personal_finance/models/recurring.dart';
import 'package:personal_finance/models/transaction.dart';
import 'package:personal_finance/utils/recurring_calc.dart';

RecurringRule _rule({
  RecurFreq freq = RecurFreq.monthly,
  int? dayOfMonth,
  int? dayOfWeek,
  int? monthOfYear,
  DateTime? start,
  DateTime? end,
}) =>
    RecurringRule(
      id: 'r',
      name: 'Test',
      type: TxType.expense,
      amount: 10,
      freq: freq,
      dayOfMonth: dayOfMonth,
      dayOfWeek: dayOfWeek,
      monthOfYear: monthOfYear,
      startDate: start ?? DateTime(2024, 1, 1),
      endDate: end,
    );

void main() {
  group('lastDayOfMonth', () {
    test('handles leap years', () {
      expect(lastDayOfMonth(2024, 2), 29);
      expect(lastDayOfMonth(2023, 2), 28);
    });
    test('handles 30/31 day months', () {
      expect(lastDayOfMonth(2025, 4), 30);
      expect(lastDayOfMonth(2025, 7), 31);
    });
  });

  group('nextDue monthly', () {
    test('next is later this month', () {
      final r = _rule(dayOfMonth: 20, start: DateTime(2024, 1, 1));
      final n = nextDue(r, DateTime(2025, 6, 5));
      expect(n, DateTime(2025, 6, 20));
    });

    test('next rolls into next month when day passed', () {
      final r = _rule(dayOfMonth: 5, start: DateTime(2024, 1, 1));
      final n = nextDue(r, DateTime(2025, 6, 10));
      expect(n, DateTime(2025, 7, 5));
    });

    test('day 31 clamps in February', () {
      final r = _rule(dayOfMonth: 31, start: DateTime(2024, 1, 1));
      final n = nextDue(r, DateTime(2025, 1, 31));
      // 31 doesn't exist in Feb, must clamp to last day (28).
      expect(n, DateTime(2025, 2, 28));
    });
  });

  group('nextDue weekly', () {
    test('jumps to next matching weekday', () {
      // 2025-06-04 is a Wednesday (weekday=3).
      final r = _rule(
        freq: RecurFreq.weekly,
        dayOfWeek: 5, // Friday
        start: DateTime(2024, 1, 1),
      );
      final n = nextDue(r, DateTime(2025, 6, 4));
      expect(n, DateTime(2025, 6, 6));
    });
  });

  group('dueDatesBetween', () {
    test('catches up multiple months when last_applied is old', () {
      final r = _rule(
        dayOfMonth: 1,
        start: DateTime(2025, 1, 1),
      );
      final dates = dueDatesBetween(
        r,
        DateTime(2024, 12, 31),
        DateTime(2025, 4, 15),
      );
      expect(dates.length, 4);
      expect(dates.first, DateTime(2025, 1, 1));
      expect(dates.last, DateTime(2025, 4, 1));
    });

    test('respects endDate', () {
      final r = _rule(
        dayOfMonth: 15,
        start: DateTime(2025, 1, 1),
        end: DateTime(2025, 3, 1),
      );
      final dates = dueDatesBetween(
        r,
        DateTime(2024, 12, 31),
        DateTime(2025, 12, 31),
      );
      // Only Jan 15 + Feb 15 are <= 2025-03-01.
      expect(dates, [
        DateTime(2025, 1, 15),
        DateTime(2025, 2, 15),
      ]);
    });

    test('returns empty when rule starts after window', () {
      final r = _rule(
        dayOfMonth: 1,
        start: DateTime(2026, 1, 1),
      );
      final dates = dueDatesBetween(
        r,
        DateTime(2025, 1, 1),
        DateTime(2025, 12, 31),
      );
      expect(dates, isEmpty);
    });
  });

  group('RecurringRule JSON round-trip', () {
    test('preserves all fields', () {
      final r = RecurringRule(
        id: 'r1',
        name: 'Subscription',
        type: TxType.expense,
        amount: 9.99,
        categoryId: 'c1',
        walletId: 'w1',
        freq: RecurFreq.monthly,
        dayOfMonth: 15,
        startDate: DateTime(2025, 1, 1),
        endDate: DateTime(2025, 12, 31),
        lastApplied: DateTime(2025, 6, 15),
        active: false,
        note: 'Spotify Family',
      );
      final back = RecurringRule.fromJson(r.toJson());
      expect(back.name, r.name);
      expect(back.amount, r.amount);
      expect(back.freq, r.freq);
      expect(back.dayOfMonth, r.dayOfMonth);
      expect(back.endDate, r.endDate);
      expect(back.lastApplied, r.lastApplied);
      expect(back.active, false);
    });
  });
}
