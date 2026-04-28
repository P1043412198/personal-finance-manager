import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/recurring.dart';
import '../../models/transaction.dart';
import '../../providers/app_state.dart';
import '../../theme/app_theme.dart';
import '../../utils/format.dart';
import '../../widgets/section.dart';

/// Belarus public holidays (recurring, simplified — uses month/day only).
const _byHolidays = <(int month, int day, String name)>[
  (1, 1, 'Новы год'),
  (1, 2, 'Новы год (2-гі дзень)'),
  (1, 7, 'Раство Хрыстова (правасл.)'),
  (3, 8, 'Дзень жанчын'),
  (5, 1, 'Дзень працы'),
  (5, 9, 'Дзень Перамогі'),
  (7, 3, 'Дзень Незалежнасці'),
  (11, 7, 'Дзень Кастрычніцкай рэвалюцыі'),
  (12, 25, 'Раство Хрыстова (катал.)'),
];

class InsightsScreen extends StatelessWidget {
  const InsightsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Аналітыка/Insights')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: const [
          _ForecastCard(),
          SizedBox(height: 12),
          _NetWorthCard(),
          SizedBox(height: 12),
          _SubscriptionCard(),
          SizedBox(height: 12),
          _TopShopsMoMCard(),
          SizedBox(height: 12),
          _CashflowCalendarCard(),
        ],
      ),
    );
  }
}

class _ForecastCard extends StatelessWidget {
  const _ForecastCard();

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final now = DateTime.now();
    final daysInMonth = DateTime(now.year, now.month + 1, 0).day;
    final monthTx = app.txInMonth(now)
        .where((t) => t.type == TxType.expense)
        .toList();
    // Build cumulative spend by day
    final byDay = List<double>.filled(daysInMonth + 1, 0);
    for (final t in monthTx) {
      if (t.date.day <= daysInMonth) byDay[t.date.day] += t.amount;
    }
    final cumulative = <double>[];
    var run = 0.0;
    for (var i = 1; i <= daysInMonth; i++) {
      run += byDay[i];
      cumulative.add(run);
    }
    // Linear regression on points up to today
    final n = now.day;
    double slope = 0;
    if (n >= 2) {
      double sumX = 0, sumY = 0, sumXY = 0, sumX2 = 0;
      for (var i = 1; i <= n; i++) {
        sumX += i;
        sumY += cumulative[i - 1];
        sumXY += i * cumulative[i - 1];
        sumX2 += i * i;
      }
      final denom = n * sumX2 - sumX * sumX;
      slope = denom == 0 ? 0 : (n * sumXY - sumX * sumY) / denom;
    }
    final spentNow = n > 0 ? cumulative[n - 1] : 0;
    final projectedEnd = spentNow + slope * (daysInMonth - n);
    final budget = app.budgetFor(now)?.totalLimit ?? 0;
    String? warning;
    if (budget > 0 && projectedEnd > budget) {
      // day when we'll exceed budget
      if (slope > 0 && spentNow < budget) {
        final dayCross = n + ((budget - spentNow) / slope).ceil();
        if (dayCross <= daysInMonth) {
          warning = 'Пры тэмпе тратаў выйдзеш з бюджэту ${dayCross}-га чысла';
        }
      } else if (spentNow >= budget) {
        warning = 'Бюджэт ужо перавышаны';
      }
    }

    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Прогноз расходов на месяц',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
          const SizedBox(height: 6),
          Text(
              'Сейчас: ${Fmt.currency(spentNow.toDouble(), symbol: app.currency)}\n'
              'Прогноз к концу месяца: ${Fmt.currency(projectedEnd, symbol: app.currency)}',
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
          if (warning != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.warning.withOpacity(0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text('⚠️ $warning',
                  style: const TextStyle(
                      color: AppColors.warning, fontWeight: FontWeight.w600)),
            ),
          ],
          const SizedBox(height: 12),
          SizedBox(
            height: 120,
            child: LineChart(LineChartData(
              gridData: const FlGridData(show: false),
              titlesData: const FlTitlesData(show: false),
              borderData: FlBorderData(show: false),
              lineBarsData: [
                LineChartBarData(
                  spots: [
                    for (var i = 1; i <= n; i++) FlSpot(i.toDouble(), cumulative[i - 1]),
                  ],
                  isCurved: true,
                  color: Theme.of(context).colorScheme.primary,
                  barWidth: 3,
                  dotData: const FlDotData(show: false),
                  belowBarData: BarAreaData(
                    show: true,
                    color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                  ),
                ),
                if (n >= 2)
                  LineChartBarData(
                    spots: [
                      FlSpot(n.toDouble(), spentNow.toDouble()),
                      FlSpot(daysInMonth.toDouble(), projectedEnd),
                    ],
                    color: AppColors.warning,
                    barWidth: 2,
                    dashArray: [4, 4],
                    dotData: const FlDotData(show: false),
                  ),
                if (budget > 0)
                  LineChartBarData(
                    spots: [
                      FlSpot(1, budget),
                      FlSpot(daysInMonth.toDouble(), budget),
                    ],
                    color: AppColors.danger,
                    barWidth: 1,
                    dashArray: [2, 4],
                    dotData: const FlDotData(show: false),
                  ),
              ],
            )),
          ),
        ],
      ),
    );
  }
}

class _NetWorthCard extends StatelessWidget {
  const _NetWorthCard();

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final wallets = app.wallets.all();
    final debts = app.debts.all();
    final assets =
        wallets.fold<double>(0, (a, w) => a + w.balance);
    final liab = debts.fold<double>(0, (a, d) => a + d.balance);
    final net = assets - liab;
    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Net Worth',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
          const SizedBox(height: 8),
          Text(Fmt.currency(net, symbol: app.currency),
              style: const TextStyle(
                  fontSize: 28, fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          Row(children: [
            Expanded(
              child: _Pill(
                  label: 'Активы',
                  value: Fmt.currency(assets, symbol: app.currency),
                  color: AppColors.income),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _Pill(
                  label: 'Долги',
                  value: Fmt.currency(liab, symbol: app.currency),
                  color: AppColors.danger),
            ),
          ]),
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _Pill({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: TextStyle(
                  color: color, fontSize: 12, fontWeight: FontWeight.w600)),
          const SizedBox(height: 2),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

class _SubscriptionCard extends StatelessWidget {
  const _SubscriptionCard();

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final recs = app.recurring.all();
    final monthly = recs.fold<double>(0, (a, r) {
      switch (r.cadence) {
        case Cadence.daily:
          return a + r.amount * 30;
        case Cadence.weekly:
          return a + r.amount * 4.33;
        case Cadence.monthly:
          return a + r.amount;
        case Cadence.yearly:
          return a + r.amount / 12;
      }
    });
    final now = DateTime.now();
    final monthlyIncome = app.txInMonth(now)
        .where((t) => t.type == TxType.income)
        .fold<double>(0, (a, t) => a + t.amount);
    final pct = monthlyIncome > 0 ? (monthly / monthlyIncome * 100) : 0.0;

    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Подписки и регулярные платежи',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
          const SizedBox(height: 6),
          Text('${recs.length} активных, ~${Fmt.currency(monthly, symbol: app.currency)} / мес',
              style: const TextStyle(color: AppColors.textSecondary)),
          if (monthlyIncome > 0)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text('${pct.toStringAsFixed(1)}% от дохода',
                  style: TextStyle(
                      color: pct > 30 ? AppColors.warning : AppColors.income,
                      fontWeight: FontWeight.w600)),
            ),
          const SizedBox(height: 8),
          for (final r in recs.take(8))
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  const Text('🔁'),
                  const SizedBox(width: 8),
                  Expanded(child: Text(r.name)),
                  Text(
                      '${Fmt.currency(r.amount, symbol: app.currency)} · ${r.cadence.name}',
                      style: const TextStyle(
                          color: AppColors.textSecondary, fontSize: 12)),
                ],
              ),
            ),
          if (recs.isEmpty)
            const Text('Пока нет регулярных платежей',
                style: TextStyle(color: AppColors.textSecondary)),
        ],
      ),
    );
  }
}

class _TopShopsMoMCard extends StatelessWidget {
  const _TopShopsMoMCard();

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final now = DateTime.now();
    final prevMonth = DateTime(now.year, now.month - 1, 1);
    final cur = <String, double>{};
    final prev = <String, double>{};
    for (final t in app.txInMonth(now).where((t) => t.type == TxType.expense)) {
      final k = (t.shop?.isNotEmpty ?? false) ? t.shop! : '—';
      cur[k] = (cur[k] ?? 0) + t.amount;
    }
    for (final t in app.txInMonth(prevMonth).where((t) => t.type == TxType.expense)) {
      final k = (t.shop?.isNotEmpty ?? false) ? t.shop! : '—';
      prev[k] = (prev[k] ?? 0) + t.amount;
    }
    final keys = cur.keys.toList()
      ..sort((a, b) => (cur[b] ?? 0).compareTo(cur[a] ?? 0));
    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Топ магазинов / vs прошлый месяц',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
          const SizedBox(height: 6),
          if (keys.isEmpty)
            const Text('Нет данных за этот месяц',
                style: TextStyle(color: AppColors.textSecondary))
          else
            for (final k in keys.take(6))
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(children: [
                  Expanded(child: Text(k)),
                  Text(Fmt.currency(cur[k] ?? 0, symbol: app.currency),
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(width: 8),
                  () {
                    final p = prev[k] ?? 0;
                    final c = cur[k] ?? 0;
                    if (p == 0) {
                      return const Text('NEW',
                          style: TextStyle(
                              color: AppColors.info,
                              fontWeight: FontWeight.w600,
                              fontSize: 12));
                    }
                    final delta = (c - p) / p * 100;
                    final color = delta > 0 ? AppColors.danger : AppColors.income;
                    final sign = delta > 0 ? '+' : '';
                    return Text('$sign${delta.toStringAsFixed(0)}%',
                        style: TextStyle(
                            color: color,
                            fontWeight: FontWeight.w600,
                            fontSize: 12));
                  }(),
                ]),
              ),
        ],
      ),
    );
  }
}

class _CashflowCalendarCard extends StatelessWidget {
  const _CashflowCalendarCard();

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final now = DateTime.now();
    final monthTx = app.txInMonth(now);
    final daysInMonth = DateTime(now.year, now.month + 1, 0).day;
    final firstWd = DateTime(now.year, now.month, 1).weekday; // 1..7 Mon..Sun
    final cells = <Widget>[];
    for (var i = 1; i < firstWd; i++) {
      cells.add(const SizedBox.shrink());
    }
    for (var d = 1; d <= daysInMonth; d++) {
      final dayTx = monthTx
          .where((t) => t.date.day == d)
          .toList();
      final inc = dayTx.where((t) => t.type == TxType.income).fold<double>(0, (a, t) => a + t.amount);
      final exp = dayTx.where((t) => t.type == TxType.expense).fold<double>(0, (a, t) => a + t.amount);
      final hol = _byHolidays.firstWhere(
        (h) => h.$1 == now.month && h.$2 == d,
        orElse: () => (0, 0, ''),
      );
      final isToday = d == now.day;
      cells.add(Container(
        margin: const EdgeInsets.all(2),
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: isToday
              ? Theme.of(context).colorScheme.primary.withOpacity(0.1)
              : AppColors.muted.withOpacity(0.4),
          borderRadius: BorderRadius.circular(6),
          border: hol.$3.isNotEmpty ? Border.all(color: AppColors.warning, width: 1.4) : null,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Text('$d',
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: isToday ? FontWeight.w700 : FontWeight.w500)),
              if (hol.$3.isNotEmpty) const Text(' 🇧🇾', style: TextStyle(fontSize: 9)),
            ]),
            if (exp > 0)
              Text('-${exp.toStringAsFixed(0)}',
                  style: const TextStyle(fontSize: 9, color: AppColors.expense)),
            if (inc > 0)
              Text('+${inc.toStringAsFixed(0)}',
                  style: const TextStyle(fontSize: 9, color: AppColors.income)),
          ],
        ),
      ));
    }
    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Cashflow на ${Fmt.monthName(now, locale: 'ru')}',
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
          const SizedBox(height: 4),
          const Text('Праздники РБ выделены рамкой',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
          const SizedBox(height: 8),
          GridView.count(
            crossAxisCount: 7,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            childAspectRatio: 0.85,
            children: cells,
          ),
        ],
      ),
    );
  }
}
