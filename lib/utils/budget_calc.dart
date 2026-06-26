import '../models/budget.dart';
import '../models/category.dart';
import '../models/transaction.dart';

/// Aggregated plan-vs-fact metrics for a single month.
class BudgetMetrics {
  final double income;
  final double expense;

  /// Variable category budget, without fixed payments.
  final double plannedExpense;

  /// Income from the budget plan (manually set).
  final double plannedIncome;

  /// Predictable required costs: rent, utilities, loans, subscriptions.
  final double fixedCosts;

  /// Full planned monthly outflow = fixedCosts + plannedExpense.
  final double plannedOutflow;

  /// Free funds = plannedIncome - fixedCosts - plannedExpense (план).
  final double freeFundsPlan;

  /// Free funds today = max(plannedIncome, factIncome) - fixedCosts - factExpense (факт).
  final double freeFundsFact;

  /// Calendar info.
  final int daysInMonth;
  final int dayNumber;
  final int daysLeft;

  /// Forecast at current variable-spending pace + fixed costs.
  final double forecast;

  /// How much is safe to spend per day from now until end of month.
  final double safePerDay;

  const BudgetMetrics({
    required this.income,
    required this.expense,
    required this.plannedExpense,
    required this.plannedIncome,
    required this.fixedCosts,
    required this.plannedOutflow,
    required this.freeFundsPlan,
    required this.freeFundsFact,
    required this.daysInMonth,
    required this.dayNumber,
    required this.daysLeft,
    required this.forecast,
    required this.safePerDay,
  });

  double get variableUsage => plannedExpense > 0
      ? (expense / plannedExpense).clamp(0.0, 999.0).toDouble()
      : 0.0;

  double get outflowUsage => plannedOutflow > 0
      ? ((expense + fixedCosts) / plannedOutflow).clamp(0.0, 999.0).toDouble()
      : 0.0;

  double get projectedDelta => plannedOutflow - forecast;

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
    final fixedCosts = budget?.fixedCostsTotal ?? 0;
    final plannedOutflow = plannedExpense + fixedCosts;

    final freeFundsPlan = plannedIncome - plannedOutflow;
    final actualIncomeBase = income > plannedIncome ? income : plannedIncome;
    final freeFundsFact = actualIncomeBase - fixedCosts - expense;

    final perDayActual = dayNumber > 0 ? expense / dayNumber : 0.0;
    final forecast = perDayActual * daysInMonth + fixedCosts;

    final remainingVariablePlan =
        (plannedExpense - expense).clamp(0, double.infinity).toDouble();
    final divisor = isCurrent ? (daysLeft + 1) : daysInMonth;
    final safePerDay = divisor > 0 ? remainingVariablePlan / divisor : 0.0;

    return BudgetMetrics(
      income: income,
      expense: expense,
      plannedExpense: plannedExpense,
      plannedIncome: plannedIncome,
      fixedCosts: fixedCosts,
      plannedOutflow: plannedOutflow,
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
    final i = (t.date.day - 1).clamp(0, daysInMonth - 1).toInt();
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
  double get remaining => (plan - fact).clamp(0, double.infinity).toDouble();
  double get progress => plan > 0
      ? (fact / plan).clamp(0.0, 1.0).toDouble()
      : (fact > 0 ? 1.0 : 0.0);
  double get weeklyLimit => plan / 4.345;
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
    final aOver = a.fact > a.plan && a.plan > 0;
    final bOver = b.fact > b.plan && b.plan > 0;
    if (aOver != bOver) return aOver ? -1 : 1;
    return b.fact.compareTo(a.fact);
  });
  return rows;
}

class BudgetAlert {
  final String title;
  final String message;
  final BudgetAlertLevel level;

  const BudgetAlert({
    required this.title,
    required this.message,
    required this.level,
  });
}

enum BudgetAlertLevel { good, warning, danger }

List<BudgetAlert> buildBudgetAlerts({
  required BudgetMetrics metrics,
  required List<CategoryPlanFact> categories,
}) {
  final alerts = <BudgetAlert>[];

  if (metrics.freeFundsFact < 0) {
    alerts.add(BudgetAlert(
      title: 'Бюджет ушёл в минус',
      message: 'Свободные средства ниже нуля. Включи режим экономии и проверь крупные категории.',
      level: BudgetAlertLevel.danger,
    ));
  } else if (metrics.safePerDay > 0) {
    alerts.add(BudgetAlert(
      title: 'Лимит на сегодня',
      message: 'Безопасная сумма на день рассчитана с учётом оставшихся дней месяца.',
      level: BudgetAlertLevel.good,
    ));
  }

  if (metrics.forecast > metrics.plannedOutflow * 1.05 && metrics.plannedOutflow > 0) {
    alerts.add(BudgetAlert(
      title: 'Риск перерасхода к концу месяца',
      message: 'Текущий темп трат выше плана. Прогноз уже превышает месячный бюджет.',
      level: BudgetAlertLevel.danger,
    ));
  } else if (metrics.forecast > metrics.plannedOutflow * 0.9 && metrics.plannedOutflow > 0) {
    alerts.add(BudgetAlert(
      title: 'План почти исчерпан',
      message: 'Ты близко к лимиту. Лучше держать ежедневные траты ниже безопасной суммы.',
      level: BudgetAlertLevel.warning,
    ));
  }

  for (final row in categories.where((c) => c.plan > 0 && c.fact >= c.plan * 0.85).take(4)) {
    final over = row.fact > row.plan;
    alerts.add(BudgetAlert(
      title: over ? 'Перерасход: ${row.name}' : 'Почти лимит: ${row.name}',
      message: over
          ? 'Категория превысила план. Следующие покупки лучше перенести или сократить.'
          : 'Потрачено 85%+ лимита. Остаток по категории небольшой.',
      level: over ? BudgetAlertLevel.danger : BudgetAlertLevel.warning,
    ));
  }

  if (alerts.isEmpty) {
    alerts.add(const BudgetAlert(
      title: 'Всё под контролем',
      message: 'Нет критичных перерасходов. Продолжай вести операции ежедневно.',
      level: BudgetAlertLevel.good,
    ));
  }

  return alerts;
}

class BudgetHealthReport {
  final int score;
  final String label;
  final String message;

  const BudgetHealthReport({
    required this.score,
    required this.label,
    required this.message,
  });
}

BudgetHealthReport budgetHealthReport({
  required BudgetMetrics metrics,
  required List<CategoryPlanFact> categories,
}) {
  var score = 100;
  if (metrics.freeFundsFact < 0) score -= 30;
  if (metrics.projectedDelta < 0) score -= 25;
  if (metrics.variableUsage > 0.9) score -= 15;
  if (metrics.fixedCosts > metrics.plannedIncome * 0.5 && metrics.plannedIncome > 0) score -= 10;
  score -= categories.where((c) => c.plan > 0 && c.fact > c.plan).length * 5;
  score = score.clamp(0, 100).toInt();

  if (score >= 80) {
    return BudgetHealthReport(
      score: score,
      label: 'Отлично',
      message: 'Бюджет здоровый: темп расходов и свободные средства выглядят спокойно.',
    );
  }
  if (score >= 55) {
    return BudgetHealthReport(
      score: score,
      label: 'Внимание',
      message: 'Есть риск перерасхода. Следи за категориями, где лимит почти выбран.',
    );
  }
  return BudgetHealthReport(
    score: score,
    label: 'Риск',
    message: 'Нужно сокращать переменные расходы или пересмотреть обязательные платежи.',
  );
}

class MonthComparison {
  final double incomeDelta;
  final double expenseDelta;
  final double expensePercent;
  final List<CategoryPlanFact> categoryDeltas;

  const MonthComparison({
    required this.incomeDelta,
    required this.expenseDelta,
    required this.expensePercent,
    required this.categoryDeltas,
  });
}

MonthComparison compareWithPreviousMonth({
  required DateTime month,
  required Iterable<TransactionModel> currentTx,
  required Iterable<TransactionModel> previousTx,
  required CategoryModel? Function(String?) categoryById,
}) {
  double sum(Iterable<TransactionModel> tx, TxType type) =>
      tx.where((t) => t.type == type).fold<double>(0, (a, t) => a + t.amount);

  final currentExpense = sum(currentTx, TxType.expense);
  final previousExpense = sum(previousTx, TxType.expense);
  final currentIncome = sum(currentTx, TxType.income);
  final previousIncome = sum(previousTx, TxType.income);

  Map<String, double> byCat(Iterable<TransactionModel> tx) {
    final map = <String, double>{};
    for (final t in tx.where((t) => t.type == TxType.expense)) {
      final id = t.categoryId ?? 'none';
      map.update(id, (v) => v + t.amount, ifAbsent: () => t.amount);
    }
    return map;
  }

  final cur = byCat(currentTx);
  final prev = byCat(previousTx);
  final ids = {...cur.keys, ...prev.keys};
  final deltas = <CategoryPlanFact>[];
  for (final id in ids) {
    final cat = categoryById(id);
    deltas.add(CategoryPlanFact(
      categoryId: id,
      name: cat?.name ?? '—',
      emoji: cat != null ? CategoryIcons.resolve(cat.iconKey) : '📦',
      colorValue: cat?.colorValue ?? 0xFF9E9E9E,
      plan: prev[id] ?? 0,
      fact: cur[id] ?? 0,
    ));
  }
  deltas.sort((a, b) => b.delta.abs().compareTo(a.delta.abs()));

  final percent = previousExpense > 0
      ? ((currentExpense - previousExpense) / previousExpense) * 100
      : 0.0;

  return MonthComparison(
    incomeDelta: currentIncome - previousIncome,
    expenseDelta: currentExpense - previousExpense,
    expensePercent: percent,
    categoryDeltas: deltas,
  );
}

class WeeklyBudget {
  final int week;
  final double plan;
  final double fact;

  const WeeklyBudget({
    required this.week,
    required this.plan,
    required this.fact,
  });

  double get remaining => (plan - fact).clamp(0, double.infinity).toDouble();
  double get progress => plan > 0 ? (fact / plan).clamp(0.0, 1.0).toDouble() : 0.0;
}

List<WeeklyBudget> weeklyBudgets({
  required DateTime month,
  required Iterable<TransactionModel> txInMonth,
  required double variablePlan,
}) {
  const weeks = 4;
  final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
  final planPerWeek = variablePlan / weeks;
  final result = <WeeklyBudget>[];
  for (var w = 0; w < weeks; w++) {
    final startDay = (daysInMonth * w / weeks).floor() + 1;
    final endDay = (daysInMonth * (w + 1) / weeks).floor();
    final fact = txInMonth
        .where((t) => t.type == TxType.expense)
        .where((t) => t.date.day >= startDay && t.date.day <= endDay)
        .fold<double>(0, (a, t) => a + t.amount);
    result.add(WeeklyBudget(week: w + 1, plan: planPerWeek, fact: fact));
  }
  return result;
}

class EconomySuggestion {
  final String title;
  final String message;
  final double monthlySaving;

  const EconomySuggestion({
    required this.title,
    required this.message,
    required this.monthlySaving,
  });
}

List<EconomySuggestion> economySuggestions({
  required BudgetMetrics metrics,
  required List<CategoryPlanFact> categories,
}) {
  final top = [...categories]..sort((a, b) => b.fact.compareTo(a.fact));
  final suggestions = <EconomySuggestion>[];

  for (final row in top.take(3)) {
    if (row.fact <= 0) continue;
    final saving = row.fact * 0.1;
    suggestions.add(EconomySuggestion(
      title: 'Сократить ${row.name} на 10%',
      message: 'Мягкий режим экономии без полного отказа от категории.',
      monthlySaving: saving,
    ));
  }

  if (metrics.safePerDay > 0) {
    suggestions.add(EconomySuggestion(
      title: 'Держать дневной лимит',
      message: 'Не тратить больше безопасной суммы до конца месяца.',
      monthlySaving: metrics.safePerDay * 0.15 * (metrics.daysLeft + 1),
    ));
  }

  if (metrics.fixedCosts > 0) {
    suggestions.add(EconomySuggestion(
      title: 'Проверить подписки',
      message: 'Отключи неиспользуемые сервисы или перенеси платежи.',
      monthlySaving: metrics.fixedCosts * 0.05,
    ));
  }

  return suggestions.where((s) => s.monthlySaving > 0).toList();
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

enum DistributionStrategy { fiftyThirtyTwenty, zeroBased, envelope, proportional }

/// Suggest per-category limits based on historical spend (last few months).
List<CategoryLimit> suggestDistribution({
  required DistributionStrategy strategy,
  required double income,
  required Map<String, double> historicalSpendByCat,
  List<CategoryModel> fallbackCategories = const [],
  double fixedCosts = 0,
}) {
  final availableIncome = (income - fixedCosts).clamp(0, double.infinity).toDouble();
  double targetTotal;
  switch (strategy) {
    case DistributionStrategy.fiftyThirtyTwenty:
      targetTotal = availableIncome * 0.8;
      break;
    case DistributionStrategy.zeroBased:
      targetTotal = availableIncome;
      break;
    case DistributionStrategy.envelope:
      targetTotal = availableIncome * 0.9;
      break;
    case DistributionStrategy.proportional:
      targetTotal = availableIncome * 0.85;
      break;
  }
  if (targetTotal <= 0) return const [];

  final totalSpent = historicalSpendByCat.values.fold<double>(0, (a, b) => a + b);
  if (totalSpent > 0) {
    return historicalSpendByCat.entries
        .map((e) => CategoryLimit(
              categoryId: e.key,
              limit: (targetTotal * (e.value / totalSpent)),
            ))
        .where((l) => l.limit > 0)
        .toList();
  }
  final txCats = fallbackCategories.where((c) => c.scopes.contains('tx')).toList();
  if (txCats.isEmpty) return const [];
  final per = targetTotal / txCats.length;
  return txCats.map((c) => CategoryLimit(categoryId: c.id, limit: per)).toList();
}
