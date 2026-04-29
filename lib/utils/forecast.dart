import '../models/snapshot.dart';
import '../models/transaction.dart';

/// Aggregate income/expense for a single past month directly from transactions.
class MonthAggregate {
  final String monthKey;
  final double income;
  final double expense;

  const MonthAggregate({
    required this.monthKey,
    required this.income,
    required this.expense,
  });

  double get net => income - expense;
}

String _key(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}';

/// Build aggregates for the last [n] months ending with [endMonth] (inclusive,
/// month-precision). Combines snapshot data with raw transactions: snapshots
/// take precedence over raw aggregation when present (to preserve historical
/// state even if older transactions are deleted later).
List<MonthAggregate> monthlyHistory({
  required DateTime endMonth,
  required int n,
  required Iterable<TransactionModel> allTx,
  required Iterable<MonthSnapshot> snapshots,
}) {
  final snapByKey = {for (final s in snapshots) s.monthKey: s};
  final byMonth = <String, MonthAggregate>{};
  for (final t in allTx) {
    final k = _key(t.date);
    final cur = byMonth[k] ??
        MonthAggregate(monthKey: k, income: 0, expense: 0);
    if (t.type == TxType.income) {
      byMonth[k] =
          MonthAggregate(monthKey: k, income: cur.income + t.amount, expense: cur.expense);
    } else {
      byMonth[k] =
          MonthAggregate(monthKey: k, income: cur.income, expense: cur.expense + t.amount);
    }
  }
  final result = <MonthAggregate>[];
  for (var i = n - 1; i >= 0; i--) {
    final m = DateTime(endMonth.year, endMonth.month - i);
    final key = _key(m);
    final s = snapByKey[key];
    if (s != null) {
      result.add(MonthAggregate(
          monthKey: key, income: s.income, expense: s.expense));
    } else {
      result.add(byMonth[key] ??
          MonthAggregate(monthKey: key, income: 0, expense: 0));
    }
  }
  return result;
}

/// Predict end-of-month expense using current run-rate.
class EndOfMonthForecast {
  final double currentSpent;
  final double currentIncome;
  final double projectedSpent;
  final double projectedNet;
  final int dayNumber;
  final int daysInMonth;
  final double avgDailySpend;

  const EndOfMonthForecast({
    required this.currentSpent,
    required this.currentIncome,
    required this.projectedSpent,
    required this.projectedNet,
    required this.dayNumber,
    required this.daysInMonth,
    required this.avgDailySpend,
  });
}

EndOfMonthForecast forecastEndOfMonth({
  required DateTime month,
  required Iterable<TransactionModel> txInMonth,
  required Iterable<TransactionModel> last30DaysTx,
  required double plannedIncome,
  DateTime? now,
}) {
  final today = now ?? DateTime.now();
  final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
  final isCurrent = today.year == month.year && today.month == month.month;
  final dayNumber = isCurrent ? today.day : daysInMonth;
  final daysLeft = isCurrent ? (daysInMonth - dayNumber) : 0;

  final spent = txInMonth
      .where((t) => t.type == TxType.expense)
      .fold<double>(0, (a, t) => a + t.amount);
  final income = txInMonth
      .where((t) => t.type == TxType.income)
      .fold<double>(0, (a, t) => a + t.amount);

  // Average daily spend over last 30 calendar days (or current month if
  // history is empty).
  final last30Spend = last30DaysTx
      .where((t) => t.type == TxType.expense)
      .fold<double>(0, (a, t) => a + t.amount);
  final avgDaily = last30Spend > 0 ? last30Spend / 30.0 : (dayNumber > 0 ? spent / dayNumber : 0.0);
  final projectedSpend = spent + avgDaily * daysLeft;
  final projectedIncome = income > plannedIncome ? income : plannedIncome;
  return EndOfMonthForecast(
    currentSpent: spent,
    currentIncome: income,
    projectedSpent: projectedSpend,
    projectedNet: projectedIncome - projectedSpend,
    dayNumber: dayNumber,
    daysInMonth: daysInMonth,
    avgDailySpend: avgDaily,
  );
}

/// Net-worth projection: cumulative running balance forward [horizonMonths]
/// months using mean monthly net of the historical window. Returns one entry
/// per month, including the starting balance at index 0.
class NetWorthPoint {
  final String monthKey;
  final double cumulative;
  final bool projected;
  const NetWorthPoint({
    required this.monthKey,
    required this.cumulative,
    required this.projected,
  });
}

List<NetWorthPoint> netWorthProjection({
  required List<MonthAggregate> history,
  required int horizonMonths,
  double startingBalance = 0,
}) {
  final points = <NetWorthPoint>[];
  double running = startingBalance;
  for (final m in history) {
    running += m.net;
    points.add(NetWorthPoint(
        monthKey: m.monthKey, cumulative: running, projected: false));
  }
  if (history.isEmpty) return points;
  final mean =
      history.map((m) => m.net).reduce((a, b) => a + b) / history.length;
  // Parse last month forward.
  final last = history.last.monthKey;
  final parts = last.split('-');
  var y = int.parse(parts[0]);
  var mo = int.parse(parts[1]);
  for (var i = 1; i <= horizonMonths; i++) {
    mo += 1;
    if (mo > 12) {
      mo = 1;
      y += 1;
    }
    running += mean;
    final mk = '${y.toString().padLeft(4, '0')}-${mo.toString().padLeft(2, '0')}';
    points.add(
        NetWorthPoint(monthKey: mk, cumulative: running, projected: true));
  }
  return points;
}

/// Sankey-style flow data: list of (categoryName, amount, isIncome). Each
/// entry is a node in the Sankey diagram; income nodes flow into the
/// central "Budget" node, which flows out to expense nodes.
class SankeyNode {
  final String label;
  final double amount;
  final int color;
  final bool isIncome;
  const SankeyNode({
    required this.label,
    required this.amount,
    required this.color,
    required this.isIncome,
  });
}

class SankeyData {
  final List<SankeyNode> incomes;
  final List<SankeyNode> expenses;
  final double totalIncome;
  final double totalExpense;
  const SankeyData({
    required this.incomes,
    required this.expenses,
    required this.totalIncome,
    required this.totalExpense,
  });
}

SankeyData buildSankey({
  required Iterable<TransactionModel> txInMonth,
  required String Function(String?) labelFor,
  required int Function(String?) colorFor,
  int maxNodes = 8,
}) {
  final inc = <String, double>{};
  final exp = <String, double>{};
  for (final t in txInMonth) {
    final id = t.categoryId ?? 'none';
    if (t.type == TxType.income) {
      inc.update(id, (v) => v + t.amount, ifAbsent: () => t.amount);
    } else {
      exp.update(id, (v) => v + t.amount, ifAbsent: () => t.amount);
    }
  }
  List<SankeyNode> top(Map<String, double> src, bool isIncome) {
    final entries = src.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final keep = entries.take(maxNodes).toList();
    final rest = entries.skip(maxNodes);
    final nodes = <SankeyNode>[
      for (final e in keep)
        SankeyNode(
          label: labelFor(e.key),
          amount: e.value,
          color: colorFor(e.key),
          isIncome: isIncome,
        ),
    ];
    final restSum = rest.fold<double>(0, (a, e) => a + e.value);
    if (restSum > 0) {
      nodes.add(SankeyNode(
        label: '…',
        amount: restSum,
        color: 0xFF9E9E9E,
        isIncome: isIncome,
      ));
    }
    return nodes;
  }

  return SankeyData(
    incomes: top(inc, true),
    expenses: top(exp, false),
    totalIncome: inc.values.fold(0, (a, b) => a + b),
    totalExpense: exp.values.fold(0, (a, b) => a + b),
  );
}
