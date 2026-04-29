import '../models/budget.dart';
import '../models/category.dart';
import '../models/transaction.dart';

/// Aggregated plan-vs-fact metrics for a single month.
class BudgetMetrics {
  final double income;
  final double expense;
  final double plannedExpense;

  /// Income from the budget plan (manually set).
  final double plannedIncome;

  /// Free funds = plannedIncome - plannedExpense (план).
  final double freeFundsPlan;

  /// Free funds today = max(plannedIncome, factIncome) - factExpense (факт).
  final double freeFundsFact;

  /// Calendar info.
  final int daysInMonth;
  final int dayNumber;
  final int daysLeft;

  /// Forecast at current pace.
  final double forecast;

  /// How much is safe to spend per day from now until end of month
  /// (uses planned limit, not income, to keep alignment with the plan).
  final double safePerDay;

  const BudgetMetrics({
    required this.income,
    required this.expense,
    required this.plannedExpense,
    required this.plannedIncome,
    required this.freeFundsPlan,
    required this.freeFundsFact,
    required this.daysInMonth,
    required this.dayNumber,
    required this.daysLeft,
    required this.forecast,
    required this.safePerDay,
  });

  static BudgetMetrics compute({
    required DateTime month,
    required Iterable<TransactionModel> txInMonth,
    MonthlyBudget? budget,
    DateTime? now,
  }) {
    final today = now ?? DateTime.now();
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    final isCurrent = today.year == month.year && today.month == month.month;
    final dayNumber = isCurrent ? today.day : daysInMonth;
    final daysLeft = isCurrent ? (daysInMonth - dayNumber) : 0;

    final expense = txInMonth
        .where((t) => t.type == TxType.expense)
        .fold<double>(0, (a, t) => a + t.amount);
    final income = txInMonth
        .where((t) => t.type == TxType.income)
        .fold<double>(0, (a, t) => a + t.amount);

    final plannedExpense = budget?.totalLimit ?? 0;
    final plannedIncome = budget?.income ?? 0;

    final freeFundsPlan = plannedIncome - plannedExpense;
    // Use realised income if higher than plan (e.g. unexpected bonus), else plan.
    final actualIncomeBase = income > plannedIncome ? income : plannedIncome;
    final freeFundsFact = actualIncomeBase - expense;

    final perDayActual = dayNumber > 0 ? expense / dayNumber : 0.0;
    final forecast = perDayActual * daysInMonth;

    final remainingPlan = (plannedExpense - expense).clamp(0, double.infinity).toDouble();
    final divisor = isCurrent ? (daysLeft + 1) : daysInMonth;
    final safePerDay = divisor > 0 ? remainingPlan / divisor : 0.0;

    return BudgetMetrics(
      income: income,
      expense: expense,
      plannedExpense: plannedExpense,
      plannedIncome: plannedIncome,
      freeFundsPlan: freeFundsPlan,
      freeFundsFact: freeFundsFact,
      daysInMonth: daysInMonth,
      dayNumber: dayNumber,
      daysLeft: daysLeft,
      forecast: forecast,
      safePerDay: safePerDay,
    );
  }
}

/// Cumulative spend per day-of-month, length == daysInMonth.
List<double> cumulativeSpentByDay({
  required DateTime month,
  required Iterable<TransactionModel> txInMonth,
}) {
  final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
  final perDay = List<double>.filled(daysInMonth, 0);
  for (final t in txInMonth.where((t) => t.type == TxType.expense)) {
    if (t.date.year != month.year || t.date.month != month.month) continue;
    final i = (t.date.day - 1).clamp(0, daysInMonth - 1);
    perDay[i] += t.amount;
  }
  final cum = List<double>.filled(daysInMonth, 0);
  double running = 0;
  for (var i = 0; i < daysInMonth; i++) {
    running += perDay[i];
    cum[i] = running;
  }
  return cum;
}

/// Linear cumulative plan curve for a constant daily target.
List<double> cumulativePlannedByDay({
  required DateTime month,
  required double totalPlanned,
}) {
  final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
  if (daysInMonth == 0) return const [];
  final perDay = totalPlanned / daysInMonth;
  return List<double>.generate(daysInMonth, (i) => perDay * (i + 1));
}

/// Plan-vs-fact row per category.
class CategoryPlanFact {
  final String categoryId;
  final String name;
  final String emoji;
  final int colorValue;
  final double plan;
  final double fact;

  CategoryPlanFact({
    required this.categoryId,
    required this.name,
    required this.emoji,
    required this.colorValue,
    required this.plan,
    required this.fact,
  });

  double get delta => fact - plan;
  double get progress =>
      plan > 0 ? (fact / plan).clamp(0.0, 1.0) : (fact > 0 ? 1.0 : 0.0);
}

List<CategoryPlanFact> categoryBreakdown({
  required Iterable<TransactionModel> txInMonth,
  required MonthlyBudget? budget,
  required CategoryModel? Function(String?) categoryById,
}) {
  final byCat = <String, double>{};
  for (final t in txInMonth.where((t) => t.type == TxType.expense)) {
    final id = t.categoryId ?? 'none';
    byCat.update(id, (v) => v + t.amount, ifAbsent: () => t.amount);
  }
  final ids = <String>{
    ...byCat.keys,
    ...?budget?.limits.map((l) => l.categoryId),
  };
  final rows = <CategoryPlanFact>[];
  for (final id in ids) {
    final cat = categoryById(id);
    final limit = budget?.limits
            .firstWhere(
              (l) => l.categoryId == id,
              orElse: () => CategoryLimit(categoryId: id, limit: 0),
            )
            .limit ??
        0;
    rows.add(CategoryPlanFact(
      categoryId: id,
      name: cat?.name ?? '—',
      emoji: cat != null ? CategoryIcons.resolve(cat.iconKey) : '📦',
      colorValue: cat?.colorValue ?? 0xFF9E9E9E,
      plan: limit,
      fact: byCat[id] ?? 0,
    ));
  }
  rows.sort((a, b) {
    // Over-plan first, then by spend.
    final aOver = a.fact > a.plan;
    final bOver = b.fact > b.plan;
    if (aOver != bOver) return aOver ? -1 : 1;
    return b.fact.compareTo(a.fact);
  });
  return rows;
}

/// Russian-style pluralization for "день/дня/дней".
String daysWord({
  required int n,
  required String one,
  required String few,
  required String many,
}) {
  final mod10 = n % 10;
  final mod100 = n % 100;
  if (mod10 == 1 && mod100 != 11) return one;
  if (mod10 >= 2 && mod10 <= 4 && (mod100 < 12 || mod100 > 14)) return few;
  return many;
}

enum DistributionStrategy {
  fiftyThirtyTwenty,
  zeroBased,
  envelope,
  proportional,
}

/// Suggest per-category limits based on historical spend (last few months).
///
/// - 50/30/20: split totalLimit across categories proportionally to historical
///   share, then clamp by 80% of income (20% savings buffer).
/// - zero: distribute totalLimit = income proportionally to historical share.
/// - envelope: distribute 90% of income proportionally to historical share.
/// - proportional: distribute totalLimit proportionally to historical share.
List<CategoryLimit> suggestDistribution({
  required DistributionStrategy strategy,
  required double income,
  required Map<String, double> historicalSpendByCat,
  List<CategoryModel> fallbackCategories = const [],
}) {
  double targetTotal;
  switch (strategy) {
    case DistributionStrategy.fiftyThirtyTwenty:
      targetTotal = income * 0.8;
      break;
    case DistributionStrategy.zeroBased:
      targetTotal = income;
      break;
    case DistributionStrategy.envelope:
      targetTotal = income * 0.9;
      break;
    case DistributionStrategy.proportional:
      targetTotal = income * 0.85;
      break;
  }
  if (targetTotal <= 0) return const [];

  final totalSpent =
      historicalSpendByCat.values.fold<double>(0, (a, b) => a + b);
  if (totalSpent > 0) {
    return historicalSpendByCat.entries
        .map((e) => CategoryLimit(
              categoryId: e.key,
              limit: (targetTotal * (e.value / totalSpent)),
            ))
        .where((l) => l.limit > 0)
        .toList();
  }
  // Even split across tx-scope categories if no history.
  final txCats = fallbackCategories
      .where((c) => c.scopes.contains('tx'))
      .toList();
  if (txCats.isEmpty) return const [];
  final per = targetTotal / txCats.length;
  return txCats
      .map((c) => CategoryLimit(categoryId: c.id, limit: per))
      .toList();
}
