import 'package:flutter_test/flutter_test.dart';
import 'package:personal_finance/models/recurring.dart';
import 'package:personal_finance/models/snapshot.dart';
import 'package:personal_finance/models/transaction.dart';
import 'package:personal_finance/utils/forecast.dart';

TransactionModel _tx({
  required double amount,
  required TxType type,
  required DateTime date,
  String? cat,
}) =>
    TransactionModel(
      id: '${amount}_${date.millisecondsSinceEpoch}_${type.name}',
      type: type,
      amount: amount,
      date: date,
      categoryId: cat,
    );

void main() {
  group('monthlyHistory', () {
    test('uses snapshots when available, falls back to tx', () {
      final tx = [
        _tx(amount: 1000, type: TxType.income, date: DateTime(2026, 1, 5)),
        _tx(amount: 200, type: TxType.expense, date: DateTime(2026, 1, 5)),
        _tx(amount: 800, type: TxType.income, date: DateTime(2026, 2, 1)),
      ];
      final snaps = [
        MonthSnapshot(
          monthKey: '2026-02',
          income: 999, // override raw
          expense: 100,
          txCount: 1,
          topCategoryId: null,
          topCategoryAmount: 0,
          takenAt: DateTime(2026, 3, 1),
        ),
      ];
      final h = monthlyHistory(
        endMonth: DateTime(2026, 2),
        n: 2,
        allTx: tx,
        snapshots: snaps,
      );
      expect(h.length, 2);
      // Jan from raw tx
      expect(h[0].monthKey, '2026-01');
      expect(h[0].income, 1000);
      expect(h[0].expense, 200);
      // Feb from snapshot (overrides raw)
      expect(h[1].monthKey, '2026-02');
      expect(h[1].income, 999);
      expect(h[1].expense, 100);
    });

    test('returns empty months when no data', () {
      final h = monthlyHistory(
        endMonth: DateTime(2026, 2),
        n: 3,
        allTx: const [],
        snapshots: const [],
      );
      expect(h.length, 3);
      expect(h.every((m) => m.income == 0 && m.expense == 0), isTrue);
    });
  });

  group('forecastEndOfMonth', () {
    test('projects spending from 30d average', () {
      final month = DateTime(2026, 4);
      final txInMonth = [
        _tx(amount: 200, type: TxType.expense, date: DateTime(2026, 4, 5)),
      ];
      final last30 = [
        _tx(amount: 600, type: TxType.expense, date: DateTime(2026, 3, 25)),
        _tx(amount: 600, type: TxType.expense, date: DateTime(2026, 4, 5)),
        // total 1200 / 30 = 40 per day
      ];
      final eom = forecastEndOfMonth(
        month: month,
        txInMonth: txInMonth,
        last30DaysTx: last30,
        plannedIncome: 5000,
        now: DateTime(2026, 4, 10), // 20 days left in 30-day April
      );
      expect(eom.dayNumber, 10);
      expect(eom.daysInMonth, 30);
      expect(eom.avgDailySpend, closeTo(40, 0.01));
      // 200 spent + 40 * 20 = 1000
      expect(eom.projectedSpent, closeTo(1000, 0.01));
      // income > planned: projected = max(income, planned) - projectedSpent
      expect(eom.projectedNet, closeTo(5000 - 1000, 0.01));
    });

    test('past month uses last day, no extrapolation', () {
      final month = DateTime(2026, 3);
      final eom = forecastEndOfMonth(
        month: month,
        txInMonth: [
          _tx(amount: 1000, type: TxType.expense, date: DateTime(2026, 3, 15)),
        ],
        last30DaysTx: const [],
        plannedIncome: 0,
        now: DateTime(2026, 4, 15),
      );
      expect(eom.dayNumber, 31);
      // No extrapolation past month
      expect(eom.projectedSpent, 1000);
    });

    test('upcoming recurring adds to projection only AFTER today', () {
      final month = DateTime(2026, 4);
      // Today is the 15th and the recurring tx for the 15th was already
      // applied at startup, so it lives in txInMonth.
      final txInMonth = [
        _tx(amount: 100, type: TxType.expense, date: DateTime(2026, 4, 15)),
      ];
      final rules = [
        RecurringRule(
          id: 'r',
          name: 'Subscription',
          type: TxType.expense,
          amount: 100,
          freq: RecurFreq.monthly,
          dayOfMonth: 15,
          startDate: DateTime(2026, 1, 1),
        ),
      ];
      final eom = forecastEndOfMonth(
        month: month,
        txInMonth: txInMonth,
        last30DaysTx: const [],
        plannedIncome: 0,
        recurringRules: rules,
        now: DateTime(2026, 4, 15),
      );
      expect(eom.currentSpent, 100);
      // Without rules this run-rate forecast is: 100 + (100/15)*15 = 200.
      // With the buggy `from = today - 1d` the April 15 occurrence would be
      // double-counted as +100 ⇒ 300. The correct behaviour skips it.
      expect(eom.projectedSpent, closeTo(200, 1e-6));

      // Also verify the run-rate-only baseline.
      final eomNoRules = forecastEndOfMonth(
        month: month,
        txInMonth: txInMonth,
        last30DaysTx: const [],
        plannedIncome: 0,
        now: DateTime(2026, 4, 15),
      );
      expect(eomNoRules.projectedSpent, eom.projectedSpent);
    });

    test('upcoming recurring after today is added once', () {
      final month = DateTime(2026, 4);
      // Today is the 10th. Subscription on the 20th is still upcoming.
      final rules = [
        RecurringRule(
          id: 'r',
          name: 'Subscription',
          type: TxType.expense,
          amount: 100,
          freq: RecurFreq.monthly,
          dayOfMonth: 20,
          startDate: DateTime(2026, 1, 1),
        ),
      ];
      final eom = forecastEndOfMonth(
        month: month,
        txInMonth: const [],
        last30DaysTx: const [],
        plannedIncome: 0,
        recurringRules: rules,
        now: DateTime(2026, 4, 10),
      );
      expect(eom.projectedSpent, 100);
    });
  });

  group('netWorthProjection', () {
    test('extends history by mean of net', () {
      final h = [
        const MonthAggregate(monthKey: '2026-01', income: 1000, expense: 600),
        const MonthAggregate(monthKey: '2026-02', income: 1100, expense: 700),
      ];
      final out = netWorthProjection(
        history: h,
        horizonMonths: 2,
      );
      expect(out.length, 4);
      expect(out[0].cumulative, 400); // 1000-600
      expect(out[1].cumulative, 800); // +400
      expect(out[1].projected, isFalse);
      // mean net = 400. Projection: +400 next, +400 after that
      expect(out[2].cumulative, 1200);
      expect(out[2].monthKey, '2026-03');
      expect(out[2].projected, isTrue);
      expect(out[3].cumulative, 1600);
      expect(out[3].monthKey, '2026-04');
    });

    test('rolls year boundary', () {
      final h = [
        const MonthAggregate(monthKey: '2026-12', income: 1000, expense: 500),
      ];
      final out = netWorthProjection(history: h, horizonMonths: 2);
      expect(out[1].monthKey, '2027-01');
      expect(out[2].monthKey, '2027-02');
    });

    test('empty history returns empty', () {
      expect(
          netWorthProjection(history: const [], horizonMonths: 6), isEmpty);
    });
  });

  group('buildSankey', () {
    test('aggregates by category, separates inc/exp', () {
      final tx = [
        _tx(amount: 1000, type: TxType.income, date: DateTime(2026, 4, 1), cat: 'salary'),
        _tx(amount: 200, type: TxType.income, date: DateTime(2026, 4, 5), cat: 'salary'),
        _tx(amount: 100, type: TxType.income, date: DateTime(2026, 4, 5), cat: 'gift'),
        _tx(amount: 500, type: TxType.expense, date: DateTime(2026, 4, 7), cat: 'food'),
        _tx(amount: 300, type: TxType.expense, date: DateTime(2026, 4, 8), cat: 'rent'),
      ];
      final s = buildSankey(
        txInMonth: tx,
        labelFor: (id) => id ?? '?',
        colorFor: (_) => 0xFF000000,
      );
      expect(s.totalIncome, 1300);
      expect(s.totalExpense, 800);
      // largest income first
      expect(s.incomes.first.label, 'salary');
      expect(s.incomes.first.amount, 1200);
      expect(s.expenses.first.label, 'food');
    });

    test('caps at maxNodes and groups remainder under …', () {
      final tx = <TransactionModel>[];
      for (var i = 0; i < 12; i++) {
        tx.add(_tx(
            amount: (12 - i).toDouble(),
            type: TxType.expense,
            date: DateTime(2026, 4, 1),
            cat: 'c$i'));
      }
      final s = buildSankey(
        txInMonth: tx,
        labelFor: (id) => id ?? '?',
        colorFor: (_) => 0xFF000000,
        maxNodes: 5,
      );
      // 5 top + 1 catchall
      expect(s.expenses.length, 6);
      expect(s.expenses.last.label, '…');
    });
  });
}
