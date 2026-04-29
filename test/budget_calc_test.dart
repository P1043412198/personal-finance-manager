import 'package:flutter_test/flutter_test.dart';
import 'package:personal_finance/models/budget.dart';
import 'package:personal_finance/models/category.dart';
import 'package:personal_finance/models/transaction.dart';
import 'package:personal_finance/utils/budget_calc.dart';

TransactionModel _tx({
  required double amount,
  required TxType type,
  required DateTime date,
  String? cat,
}) =>
    TransactionModel(
      id: '$amount-${date.day}-${type.name}',
      type: type,
      amount: amount,
      date: date,
      categoryId: cat,
    );

void main() {
  group('BudgetMetrics.compute', () {
    test('plan vs fact basics', () {
      final month = DateTime(2026, 4);
      final budget = MonthlyBudget(
        monthKey: '2026-04',
        income: 5000,
        totalLimit: 4000,
        limits: [
          CategoryLimit(categoryId: 'food', limit: 1500),
          CategoryLimit(categoryId: 'transport', limit: 500),
        ],
      );
      final tx = [
        _tx(amount: 5000, type: TxType.income, date: DateTime(2026, 4, 1)),
        _tx(amount: 1200, type: TxType.expense, date: DateTime(2026, 4, 5), cat: 'food'),
        _tx(amount: 800, type: TxType.expense, date: DateTime(2026, 4, 10), cat: 'transport'),
      ];
      final m = BudgetMetrics.compute(
        month: month,
        txInMonth: tx,
        budget: budget,
        now: DateTime(2026, 4, 15),
      );
      expect(m.income, 5000);
      expect(m.expense, 2000);
      expect(m.plannedExpense, 4000);
      expect(m.plannedIncome, 5000);
      expect(m.freeFundsPlan, 1000);
      expect(m.freeFundsFact, 3000);
      expect(m.daysInMonth, 30);
      expect(m.dayNumber, 15);
      expect(m.daysLeft, 15);
      // safe per day = (4000 - 2000) / (15 + 1) = 125
      expect(m.safePerDay, closeTo(125, 0.01));
    });

    test('handles missing budget gracefully', () {
      final m = BudgetMetrics.compute(
        month: DateTime(2026, 4),
        txInMonth: const [],
        budget: null,
        now: DateTime(2026, 4, 1),
      );
      expect(m.plannedExpense, 0);
      expect(m.plannedIncome, 0);
      expect(m.freeFundsPlan, 0);
      expect(m.freeFundsFact, 0);
      expect(m.safePerDay, 0);
    });

    test('over-plan reflected in negative freeFundsFact', () {
      final tx = [
        _tx(amount: 6000, type: TxType.expense, date: DateTime(2026, 4, 5)),
      ];
      final m = BudgetMetrics.compute(
        month: DateTime(2026, 4),
        txInMonth: tx,
        budget: MonthlyBudget(
            monthKey: '2026-04', income: 5000, totalLimit: 4000),
        now: DateTime(2026, 4, 30),
      );
      expect(m.freeFundsFact, -1000);
      expect(m.expense, 6000);
    });
  });

  group('cumulativeSpentByDay', () {
    test('aggregates per-day expenses and accumulates', () {
      final month = DateTime(2026, 4);
      final tx = [
        _tx(amount: 100, type: TxType.expense, date: DateTime(2026, 4, 1)),
        _tx(amount: 50, type: TxType.expense, date: DateTime(2026, 4, 1)),
        _tx(amount: 80, type: TxType.expense, date: DateTime(2026, 4, 3)),
        _tx(amount: 200, type: TxType.income, date: DateTime(2026, 4, 2)),
      ];
      final cum = cumulativeSpentByDay(month: month, txInMonth: tx);
      expect(cum.length, 30);
      expect(cum[0], 150);
      expect(cum[1], 150); // no expenses on day 2
      expect(cum[2], 230);
      expect(cum[29], 230);
    });
  });

  group('cumulativePlannedByDay', () {
    test('linear', () {
      final cum = cumulativePlannedByDay(
          month: DateTime(2026, 4), totalPlanned: 3000);
      expect(cum.length, 30);
      expect(cum.first, closeTo(100, 0.01));
      expect(cum.last, closeTo(3000, 0.01));
    });
  });

  group('daysWord ru pluralization', () {
    test('1, 21 -> one', () {
      for (final n in [1, 21, 101]) {
        expect(
            daysWord(n: n, one: 'день', few: 'дня', many: 'дней'), 'день');
      }
    });
    test('2-4, 22-24 -> few', () {
      for (final n in [2, 3, 4, 22, 23]) {
        expect(daysWord(n: n, one: 'день', few: 'дня', many: 'дней'), 'дня');
      }
    });
    test('5-20, 25-30 -> many', () {
      for (final n in [5, 11, 15, 20, 25]) {
        expect(
            daysWord(n: n, one: 'день', few: 'дня', many: 'дней'), 'дней');
      }
    });
  });

  group('categoryBreakdown', () {
    test('joins limits with actual spend', () {
      final budget = MonthlyBudget(
        monthKey: '2026-04',
        income: 0,
        totalLimit: 0,
        limits: [
          CategoryLimit(categoryId: 'food', limit: 1500),
          CategoryLimit(categoryId: 'unused', limit: 200),
        ],
      );
      final tx = [
        _tx(amount: 1800, type: TxType.expense, date: DateTime(2026, 4, 1), cat: 'food'),
        _tx(amount: 100, type: TxType.expense, date: DateTime(2026, 4, 2), cat: 'misc'),
      ];
      CategoryModel? lookup(String? id) => id == 'food'
          ? CategoryModel(
              id: 'food',
              name: 'Food',
              colorValue: 0xFF000000,
              iconKey: 'fastfood',
              scopes: {'tx'},
            )
          : null;
      final rows = categoryBreakdown(
        txInMonth: tx,
        budget: budget,
        categoryById: lookup,
      );
      // overspent first
      expect(rows.first.categoryId, 'food');
      expect(rows.first.delta, 300);
      // unused appears with 0 fact
      final unused = rows.firstWhere((r) => r.categoryId == 'unused');
      expect(unused.fact, 0);
      expect(unused.plan, 200);
    });
  });

  group('suggestDistribution', () {
    test('proportional to history when present', () {
      final hist = {
        'food': 800.0,
        'transport': 200.0,
      };
      final res = suggestDistribution(
        strategy: DistributionStrategy.envelope,
        income: 1000,
        historicalSpendByCat: hist,
      );
      // total = 1000 * 0.9 = 900, food share = 800/1000 = 0.8 -> 720
      final food = res.firstWhere((l) => l.categoryId == 'food');
      expect(food.limit, closeTo(720, 0.01));
      final tr = res.firstWhere((l) => l.categoryId == 'transport');
      expect(tr.limit, closeTo(180, 0.01));
    });

    test('falls back to even split when no history', () {
      final cats = [
        CategoryModel(
            id: 'a',
            name: 'A',
            colorValue: 0,
            iconKey: 'other',
            scopes: {'tx'}),
        CategoryModel(
            id: 'b',
            name: 'B',
            colorValue: 0,
            iconKey: 'other',
            scopes: {'tx'}),
      ];
      final res = suggestDistribution(
        strategy: DistributionStrategy.fiftyThirtyTwenty,
        income: 1000,
        historicalSpendByCat: const {},
        fallbackCategories: cats,
      );
      // total = 800, evenly split => 400 each
      expect(res.length, 2);
      expect(res[0].limit, closeTo(400, 0.01));
      expect(res[1].limit, closeTo(400, 0.01));
    });

    test('zero income produces empty', () {
      final res = suggestDistribution(
        strategy: DistributionStrategy.zeroBased,
        income: 0,
        historicalSpendByCat: const {'a': 100.0},
      );
      expect(res, isEmpty);
    });
  });
}
