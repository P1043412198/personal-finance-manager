import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';

import '../../models/budget.dart';
import '../../models/category.dart';
import '../../models/transaction.dart';
import '../../providers/app_state.dart';
import '../../theme/app_theme.dart';
import '../../utils/budget_calc.dart';
import '../../utils/budget_pdf.dart';
import '../../utils/format.dart';
import '../../utils/i18n.dart';
import '../../widgets/section.dart';

class BudgetTab extends StatefulWidget {
  final bool asPage;
  const BudgetTab({super.key, this.asPage = false});

  @override
  State<BudgetTab> createState() => _BudgetTabState();
}

class _BudgetTabState extends State<BudgetTab> {
  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final i18n = context.watch<I18n>();
    final tx = app.txInMonth(_month);
    final previousMonth = DateTime(_month.year, _month.month - 1);
    final prevTx = app.txInMonth(previousMonth);
    final budget = app.budgetFor(_month);
    final metrics = BudgetMetrics.compute(
      month: _month,
      txInMonth: tx,
      budget: budget,
    );
    final breakdown = categoryBreakdown(
      txInMonth: tx,
      budget: budget,
      categoryById: app.categoryById,
    );
    final alerts = buildBudgetAlerts(metrics: metrics, categories: breakdown);
    final health = budgetHealthReport(metrics: metrics, categories: breakdown);
    final comparison = compareWithPreviousMonth(
      month: _month,
      currentTx: tx,
      previousTx: prevTx,
      categoryById: app.categoryById,
    );
    final weeks = weeklyBudgets(
      month: _month,
      txInMonth: tx,
      variablePlan: metrics.plannedExpense,
    );
    final economy = economySuggestions(metrics: metrics, categories: breakdown);

    return Scaffold(
      appBar: AppBar(
        leading: widget.asPage ? const BackButton() : null,
        title: Text(i18n.t('budget')),
        actions: [
          IconButton(
            tooltip: i18n.t('export_pdf'),
            onPressed: budget == null
                ? null
                : () => _exportPdf(context, metrics, breakdown, budget),
            icon: const Icon(Icons.picture_as_pdf_outlined),
          ),
          IconButton(
            onPressed: () => setState(
                () => _month = DateTime(_month.year, _month.month - 1)),
            icon: const Icon(Icons.chevron_left),
          ),
          Center(
            child: Text(
              Fmt.monthName(_month, locale: i18n.locale.languageCode),
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          IconButton(
            onPressed: () => setState(
                () => _month = DateTime(_month.year, _month.month + 1)),
            icon: const Icon(Icons.chevron_right),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        children: [
          if (budget == null) ...[
            _EmptyBudgetCard(onCreate: () => _openPlanner(context)),
          ] else ...[
            _BudgetHealthCard(report: health),
            const SizedBox(height: 12),
            _TodayActionCard(metrics: metrics, categories: breakdown),
            const SizedBox(height: 12),
            _PlanFactSummary(metrics: metrics),
            const SizedBox(height: 12),
            _AlertsCard(alerts: alerts),
            const SizedBox(height: 18),
            _SectionRow(
              title: 'Обязательные платежи и подписки',
              actionLabel: i18n.t('edit'),
              onAction: () => _openPlanner(context, existing: budget),
            ),
            _FixedCostsCard(budget: budget),
            const SizedBox(height: 18),
            SectionHeader(title: 'Бюджет по неделям'),
            _WeeklyBudgetCard(weeks: weeks),
            const SizedBox(height: 18),
            SectionHeader(title: i18n.t('daily_pace')),
            _DailyPaceCard(month: _month, tx: tx, plan: metrics.plannedExpense),
            const SizedBox(height: 18),
            SectionHeader(title: 'Сравнение с прошлым месяцем'),
            _MonthComparisonCard(comparison: comparison),
            const SizedBox(height: 18),
            SectionHeader(title: 'Режим экономии'),
            _EconomyModeCard(suggestions: economy),
            const SizedBox(height: 18),
            _SectionRow(
              title: i18n.t('category_limits'),
              actionLabel: i18n.t('edit'),
              onAction: () => _openPlanner(context, existing: budget),
            ),
            AppCard(
              padding: const EdgeInsets.all(16),
              child: breakdown.isEmpty
                  ? Center(
                      child: Text(i18n.t('no_data_yet'),
                          style: const TextStyle(color: AppColors.textSecondary)),
                    )
                  : Column(
                      children: [
                        for (final r in breakdown) _CategoryRow(row: r),
                      ],
                    ),
            ),
            const SizedBox(height: 18),
            SectionHeader(title: i18n.t('forecast_short')),
            _ForecastCard(metrics: metrics),
          ],
          const SizedBox(height: 18),
          SectionHeader(title: i18n.t('debt_advice')),
          _AdvicesCard(),
        ],
      ),
      floatingActionButton: budget == null
          ? null
          : FloatingActionButton.extended(
              onPressed: () => _exportPdf(context, metrics, breakdown, budget),
              icon: const Icon(Icons.picture_as_pdf_outlined),
              label: Text(i18n.t('export_pdf')),
            ),
    );
  }

  Future<void> _openPlanner(BuildContext context,
      {MonthlyBudget? existing}) async {
    final result = await showModalBottomSheet<MonthlyBudget>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      useSafeArea: true,
      builder: (_) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: BudgetPlannerSheet(month: _month, existing: existing),
      ),
    );
    if (result != null) {
      await context.read<AppState>().upsertBudget(result);
      if (mounted) setState(() {});
    }
  }

  Future<void> _exportPdf(
    BuildContext context,
    BudgetMetrics metrics,
    List<CategoryPlanFact> breakdown,
    MonthlyBudget budget,
  ) async {
    final app = context.read<AppState>();
    final i18n = context.read<I18n>();
    final tx = app.txInMonth(_month);
    final doc = await buildBudgetPdf(
      month: _month,
      txInMonth: tx,
      budget: budget,
      categories: breakdown,
      metrics: metrics,
      currencySymbol: app.currency,
      localeCode: i18n.locale.languageCode,
      labels: {
        'title': i18n.t('budget_pdf_title'),
        'period': i18n.t('budget_pdf_period'),
        'summary': i18n.t('budget_pdf_summary'),
        'categories': i18n.t('budget_pdf_categories'),
        'plan': i18n.t('plan'),
        'fact': i18n.t('fact'),
        'delta': i18n.t('delta'),
        'income': i18n.t('income'),
        'expense': i18n.t('expenses'),
        'free_funds': i18n.t('free_funds'),
        'category': i18n.t('category'),
      },
    );
    await Printing.layoutPdf(onLayout: (_) async => doc.save());
  }
}

class _EmptyBudgetCard extends StatelessWidget {
  final VoidCallback onCreate;
  const _EmptyBudgetCard({required this.onCreate});

  @override
  Widget build(BuildContext context) {
    final i18n = context.watch<I18n>();
    return AppCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(i18n.t('no_budget_yet'),
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Text('Создай месячный план: доход, обязательные платежи, подписки и лимиты категорий.',
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
          const SizedBox(height: 14),
          ElevatedButton(onPressed: onCreate, child: Text(i18n.t('create_budget'))),
        ],
      ),
    );
  }
}

class _SectionRow extends StatelessWidget {
  final String title;
  final String actionLabel;
  final VoidCallback onAction;
  const _SectionRow({required this.title, required this.actionLabel, required this.onAction});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: SectionHeader(title: title)),
        TextButton.icon(
          onPressed: onAction,
          icon: const Icon(Icons.edit, size: 16),
          label: Text(actionLabel),
        ),
      ],
    );
  }
}

class _BudgetHealthCard extends StatelessWidget {
  final BudgetHealthReport report;
  const _BudgetHealthCard({required this.report});

  @override
  Widget build(BuildContext context) {
    final color = report.score >= 80
        ? AppColors.income
        : report.score >= 55
            ? AppColors.warning
            : AppColors.danger;
    return AppCard(
      padding: const EdgeInsets.all(18),
      color: color.withOpacity(0.08),
      child: Row(
        children: [
          SizedBox(
            width: 76,
            height: 76,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CircularProgressIndicator(
                  value: report.score / 100,
                  strokeWidth: 8,
                  backgroundColor: AppColors.muted,
                  color: color,
                ),
                Text('${report.score}',
                    style: TextStyle(fontWeight: FontWeight.w900, fontSize: 20, color: color)),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Финансовое здоровье: ${report.label}',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                const SizedBox(height: 6),
                Text(report.message,
                    style: const TextStyle(color: AppColors.textSecondary, height: 1.35)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TodayActionCard extends StatelessWidget {
  final BudgetMetrics metrics;
  final List<CategoryPlanFact> categories;
  const _TodayActionCard({required this.metrics, required this.categories});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final topRisk = categories
        .where((c) => c.plan > 0 && c.fact >= c.plan * 0.8)
        .map((c) => c.name)
        .take(2)
        .join(', ');
    final riskText = metrics.freeFundsFact < 0
        ? 'Высокий'
        : metrics.forecast > metrics.plannedOutflow
            ? 'Средний'
            : 'Низкий';
    final accent = riskText == 'Высокий'
        ? AppColors.danger
        : riskText == 'Средний'
            ? AppColors.warning
            : AppColors.income;
    return AppCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.today_outlined, color: accent),
              const SizedBox(width: 8),
              const Text('Что делать сегодня?',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
            ],
          ),
          const SizedBox(height: 12),
          Text(Fmt.currency(metrics.safePerDay, symbol: app.currency),
              style: TextStyle(fontSize: 30, fontWeight: FontWeight.w900, color: accent)),
          const SizedBox(height: 4),
          Text('Безопасно потратить сегодня. Риск перерасхода: $riskText.',
              style: const TextStyle(color: AppColors.textSecondary)),
          if (topRisk.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text('Лучше сократить: $topRisk',
                style: const TextStyle(fontWeight: FontWeight.w700)),
          ],
        ],
      ),
    );
  }
}

class _PlanFactSummary extends StatelessWidget {
  final BudgetMetrics metrics;
  const _PlanFactSummary({required this.metrics});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final i18n = context.watch<I18n>();
    String money(double v) => Fmt.currency(v, symbol: app.currency, decimals: 0);
    String signed(double v) {
      if (v == 0) return money(0);
      final sign = v > 0 ? '+' : '−';
      return '$sign${money(v.abs())}';
    }

    final pct = metrics.plannedOutflow > 0
        ? ((metrics.expense + metrics.fixedCosts) / metrics.plannedOutflow).clamp(0.0, 1.0)
        : 0.0;

    return AppCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(i18n.t('plan_vs_fact'),
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(height: 14),
          Row(
            children: [
              const Expanded(flex: 3, child: SizedBox()),
              Expanded(flex: 2, child: _HeaderCell(i18n.t('plan'))),
              Expanded(flex: 2, child: _HeaderCell(i18n.t('fact'))),
              Expanded(flex: 2, child: _HeaderCell(i18n.t('delta'))),
            ],
          ),
          const Divider(height: 16),
          _PFRow(
            label: i18n.t('income'),
            plan: money(metrics.plannedIncome),
            fact: money(metrics.income),
            delta: signed(metrics.income - metrics.plannedIncome),
            deltaColor: metrics.income >= metrics.plannedIncome ? AppColors.income : AppColors.danger,
          ),
          _PFRow(
            label: 'Обязательные',
            plan: money(metrics.fixedCosts),
            fact: money(metrics.fixedCosts),
            delta: money(0),
            deltaColor: AppColors.textSecondary,
          ),
          _PFRow(
            label: i18n.t('expenses'),
            plan: money(metrics.plannedExpense),
            fact: money(metrics.expense),
            delta: signed(metrics.expense - metrics.plannedExpense),
            deltaColor: metrics.expense <= metrics.plannedExpense ? AppColors.income : AppColors.danger,
          ),
          _PFRow(
            label: i18n.t('free_funds'),
            plan: money(metrics.freeFundsPlan),
            fact: money(metrics.freeFundsFact),
            delta: signed(metrics.freeFundsFact - metrics.freeFundsPlan),
            deltaColor: metrics.freeFundsFact >= metrics.freeFundsPlan ? AppColors.income : AppColors.danger,
            highlight: true,
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: pct.toDouble(),
              minHeight: 8,
              backgroundColor: AppColors.muted,
              color: pct > 0.95
                  ? AppColors.danger
                  : pct > 0.75
                      ? AppColors.warning
                      : AppColors.primary,
            ),
          ),
          const SizedBox(height: 8),
          Text('${(pct * 100).round()}% от полного плана расходов',
              style: const TextStyle(color: AppColors.textSecondary)),
        ],
      ),
    );
  }
}

class _HeaderCell extends StatelessWidget {
  final String text;
  const _HeaderCell(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(text,
        textAlign: TextAlign.right,
        style: const TextStyle(color: AppColors.textSecondary, fontSize: 12));
  }
}

class _PFRow extends StatelessWidget {
  final String label;
  final String plan;
  final String fact;
  final String delta;
  final Color deltaColor;
  final bool highlight;
  const _PFRow({
    required this.label,
    required this.plan,
    required this.fact,
    required this.delta,
    required this.deltaColor,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      fontWeight: highlight ? FontWeight.w800 : FontWeight.w600,
      fontSize: highlight ? 15 : 14,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Text(label,
                style: TextStyle(fontWeight: highlight ? FontWeight.w800 : FontWeight.w500)),
          ),
          Expanded(flex: 2, child: Text(plan, textAlign: TextAlign.right, style: style)),
          Expanded(flex: 2, child: Text(fact, textAlign: TextAlign.right, style: style)),
          Expanded(
            flex: 2,
            child: Text(delta,
                textAlign: TextAlign.right, style: style.copyWith(color: deltaColor)),
          ),
        ],
      ),
    );
  }
}

class _AlertsCard extends StatelessWidget {
  final List<BudgetAlert> alerts;
  const _AlertsCard({required this.alerts});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Предупреждения',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          for (final alert in alerts.take(5)) _AlertRow(alert: alert),
        ],
      ),
    );
  }
}

class _AlertRow extends StatelessWidget {
  final BudgetAlert alert;
  const _AlertRow({required this.alert});

  @override
  Widget build(BuildContext context) {
    final color = alert.level == BudgetAlertLevel.danger
        ? AppColors.danger
        : alert.level == BudgetAlertLevel.warning
            ? AppColors.warning
            : AppColors.income;
    final icon = alert.level == BudgetAlertLevel.danger
        ? Icons.error_outline
        : alert.level == BudgetAlertLevel.warning
            ? Icons.warning_amber_rounded
            : Icons.check_circle_outline;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(alert.title,
                    style: TextStyle(color: color, fontWeight: FontWeight.w800)),
                const SizedBox(height: 2),
                Text(alert.message,
                    style: const TextStyle(color: AppColors.textSecondary, fontSize: 12, height: 1.25)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FixedCostsCard extends StatelessWidget {
  final MonthlyBudget budget;
  const _FixedCostsCard({required this.budget});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final enabled = budget.fixedCosts.where((e) => e.enabled).toList();
    return AppCard(
      padding: const EdgeInsets.all(16),
      child: enabled.isEmpty
          ? const Text('Пока нет обязательных платежей. Добавь аренду, кредиты, коммуналку или подписки в планировщике.',
              style: TextStyle(color: AppColors.textSecondary))
          : Column(
              children: [
                for (final item in enabled)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      children: [
                        Icon(item.subscription ? Icons.subscriptions_outlined : Icons.receipt_long_outlined,
                            color: AppColors.primary),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(item.name,
                              style: const TextStyle(fontWeight: FontWeight.w700)),
                        ),
                        Text(Fmt.currency(item.amount, symbol: app.currency),
                            style: const TextStyle(fontWeight: FontWeight.w800)),
                      ],
                    ),
                  ),
                const Divider(height: 18),
                Row(
                  children: [
                    const Expanded(child: Text('Итого обязательных')),
                    Text(Fmt.currency(budget.fixedCostsTotal, symbol: app.currency),
                        style: const TextStyle(fontWeight: FontWeight.w900)),
                  ],
                ),
              ],
            ),
    );
  }
}

class _WeeklyBudgetCard extends StatelessWidget {
  final List<WeeklyBudget> weeks;
  const _WeeklyBudgetCard({required this.weeks});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          for (final w in weeks)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 7),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(child: Text('Неделя ${w.week}', style: const TextStyle(fontWeight: FontWeight.w700))),
                      Text('${Fmt.currency(w.fact, symbol: app.currency)} / ${Fmt.currency(w.plan, symbol: app.currency)}',
                          style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: w.progress,
                      minHeight: 6,
                      backgroundColor: AppColors.muted,
                      color: w.fact > w.plan ? AppColors.danger : AppColors.primary,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _DailyPaceCard extends StatelessWidget {
  final DateTime month;
  final List<TransactionModel> tx;
  final double plan;
  const _DailyPaceCard({required this.month, required this.tx, required this.plan});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final i18n = context.watch<I18n>();
    final cumActual = cumulativeSpentByDay(month: month, txInMonth: tx);
    final cumPlan = cumulativePlannedByDay(month: month, totalPlanned: plan);
    final daysInMonth = cumPlan.length;
    final today = DateTime.now();
    final isCurrent = today.year == month.year && today.month == month.month;
    final lastDay = isCurrent ? today.day : daysInMonth;

    final maxY = [...cumActual, ...cumPlan, 1.0].reduce((a, b) => a > b ? a : b);
    final actualSpots = <FlSpot>[];
    for (var i = 0; i < lastDay && i < cumActual.length; i++) {
      actualSpots.add(FlSpot((i + 1).toDouble(), cumActual[i]));
    }
    final planSpots = <FlSpot>[
      for (var i = 0; i < cumPlan.length; i++) FlSpot((i + 1).toDouble(), cumPlan[i]),
    ];

    return AppCard(
      padding: const EdgeInsets.fromLTRB(8, 16, 16, 8),
      child: SizedBox(
        height: 200,
        child: LineChart(
          LineChartData(
            minX: 1,
            maxX: daysInMonth.toDouble(),
            minY: 0,
            maxY: maxY * 1.1,
            gridData: FlGridData(
              show: true,
              drawVerticalLine: false,
              horizontalInterval: maxY > 0 ? maxY / 4 : 1,
              getDrawingHorizontalLine: (_) => FlLine(color: AppColors.muted, strokeWidth: 1),
            ),
            titlesData: FlTitlesData(
              topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 44,
                  getTitlesWidget: (value, meta) {
                    if (value == 0 || value == meta.max) return const SizedBox();
                    return Padding(
                      padding: const EdgeInsets.only(right: 4),
                      child: Text(
                        Fmt.currency(value, symbol: app.currency, decimals: 0),
                        style: const TextStyle(fontSize: 9, color: AppColors.textSecondary),
                      ),
                    );
                  },
                ),
              ),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 28,
                  interval: (daysInMonth / 6).ceilToDouble(),
                  getTitlesWidget: (value, meta) => Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text('${value.toInt()}',
                        style: const TextStyle(fontSize: 10, color: AppColors.textSecondary)),
                  ),
                ),
              ),
            ),
            borderData: FlBorderData(show: false),
            lineBarsData: [
              LineChartBarData(
                spots: planSpots,
                isCurved: false,
                color: AppColors.textSecondary,
                barWidth: 1.5,
                dotData: const FlDotData(show: false),
                dashArray: const [6, 4],
              ),
              LineChartBarData(
                spots: actualSpots,
                isCurved: true,
                color: AppColors.expense,
                barWidth: 2.5,
                dotData: const FlDotData(show: false),
                belowBarData: BarAreaData(show: true, color: AppColors.expense.withOpacity(0.10)),
              ),
            ],
            lineTouchData: LineTouchData(
              touchTooltipData: LineTouchTooltipData(
                getTooltipColor: (_) => AppColors.textPrimary.withOpacity(0.92),
                getTooltipItems: (spots) => [
                  for (final s in spots)
                    LineTooltipItem(
                      '${i18n.t('day') == 'day' ? 'd' : 'д'}.${s.x.toInt()}: ${Fmt.currency(s.y, symbol: app.currency)}',
                      const TextStyle(color: Colors.white, fontSize: 11),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MonthComparisonCard extends StatelessWidget {
  final MonthComparison comparison;
  const _MonthComparisonCard({required this.comparison});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final expenseColor = comparison.expenseDelta <= 0 ? AppColors.income : AppColors.danger;
    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _DeltaLine(
            label: 'Расходы',
            value: comparison.expenseDelta,
            suffix: comparison.expensePercent == 0 ? '' : ' (${comparison.expensePercent.toStringAsFixed(0)}%)',
            goodWhenNegative: true,
          ),
          _DeltaLine(label: 'Доходы', value: comparison.incomeDelta, goodWhenNegative: false),
          if (comparison.categoryDeltas.isNotEmpty) ...[
            const Divider(height: 20),
            for (final row in comparison.categoryDeltas.take(3))
              Row(
                children: [
                  Text(row.emoji),
                  const SizedBox(width: 8),
                  Expanded(child: Text(row.name)),
                  Text(
                    '${row.delta >= 0 ? '+' : '−'}${Fmt.currency(row.delta.abs(), symbol: app.currency)}',
                    style: TextStyle(
                      color: row.delta <= 0 ? AppColors.income : expenseColor,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
          ],
        ],
      ),
    );
  }
}

class _DeltaLine extends StatelessWidget {
  final String label;
  final double value;
  final String suffix;
  final bool goodWhenNegative;
  const _DeltaLine({
    required this.label,
    required this.value,
    this.suffix = '',
    required this.goodWhenNegative,
  });

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final good = goodWhenNegative ? value <= 0 : value >= 0;
    final color = good ? AppColors.income : AppColors.danger;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(child: Text(label, style: const TextStyle(fontWeight: FontWeight.w700))),
          Text('${value >= 0 ? '+' : '−'}${Fmt.currency(value.abs(), symbol: app.currency)}$suffix',
              style: TextStyle(color: color, fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}

class _EconomyModeCard extends StatelessWidget {
  final List<EconomySuggestion> suggestions;
  const _EconomyModeCard({required this.suggestions});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    if (suggestions.isEmpty) {
      return const AppCard(
        padding: EdgeInsets.all(16),
        child: Text('Пока нечего сокращать: добавь расходы и бюджетные лимиты.',
            style: TextStyle(color: AppColors.textSecondary)),
      );
    }
    final total = suggestions.fold<double>(0, (a, s) => a + s.monthlySaving);
    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Потенциальная экономия: ${Fmt.currency(total, symbol: app.currency)}',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: AppColors.income)),
          const SizedBox(height: 10),
          for (final s in suggestions.take(4))
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.savings_outlined, color: AppColors.income, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(s.title, style: const TextStyle(fontWeight: FontWeight.w800)),
                        Text(s.message,
                            style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                      ],
                    ),
                  ),
                  Text(Fmt.currency(s.monthlySaving, symbol: app.currency),
                      style: const TextStyle(fontWeight: FontWeight.w800)),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _ForecastCard extends StatelessWidget {
  final BudgetMetrics metrics;
  const _ForecastCard({required this.metrics});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final delta = metrics.plannedOutflow - metrics.forecast;
    final color = delta >= 0 ? AppColors.income : AppColors.danger;
    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(Fmt.currency(metrics.forecast, symbol: app.currency),
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
          const SizedBox(height: 4),
          Text('Прогноз учитывает текущий темп расходов и обязательные платежи.',
              style: const TextStyle(color: AppColors.textSecondary)),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              delta >= 0
                  ? 'Останется по плану: ${Fmt.currency(delta, symbol: app.currency)}'
                  : 'Превышение прогноза: ${Fmt.currency(delta.abs(), symbol: app.currency)}',
              style: TextStyle(color: color, fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryRow extends StatelessWidget {
  final CategoryPlanFact row;
  const _CategoryRow({required this.row});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final i18n = context.watch<I18n>();
    final color = Color(row.colorValue);
    final overspent = row.delta > 0 && row.plan > 0;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          IconBadge(emoji: row.emoji, bg: color.withOpacity(0.15)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(child: Text(row.name, style: const TextStyle(fontWeight: FontWeight.w600))),
                    Text(
                      '${Fmt.currency(row.fact, symbol: app.currency)} / ${Fmt.currency(row.plan, symbol: app.currency)}',
                      style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: row.progress,
                    minHeight: 6,
                    backgroundColor: AppColors.muted,
                    color: overspent ? AppColors.danger : color,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  row.plan == 0
                      ? 'Лимит не задан'
                      : overspent
                          ? '+${Fmt.currency(row.delta, symbol: app.currency)} ${i18n.t('over_plan')}'
                          : '${Fmt.currency(row.remaining, symbol: app.currency)} осталось · ${Fmt.currency(row.weeklyLimit, symbol: app.currency)} / неделя',
                  style: TextStyle(
                    fontSize: 11,
                    color: overspent ? AppColors.danger : AppColors.income,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AdvicesCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final i18n = context.watch<I18n>();
    final tips = [
      i18n.t('tip_save_more'),
      i18n.t('tip_track'),
      i18n.t('tip_emergency'),
      'Разделяй обязательные платежи и переменные расходы — так бюджет честнее.',
    ];
    return Column(
      children: [
        for (int i = 0; i < tips.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: AppCard(
              padding: const EdgeInsets.all(14),
              color: AppColors.muted,
              child: Row(
                children: [
                  const Text('💡', style: TextStyle(fontSize: 22)),
                  const SizedBox(width: 12),
                  Expanded(
                      child: Text(tips[i],
                          style: const TextStyle(color: AppColors.textPrimary, fontSize: 14))),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

/// Bottom-sheet planner: income + fixed costs + per-category limits + auto-distribution.
class BudgetPlannerSheet extends StatefulWidget {
  final DateTime month;
  final MonthlyBudget? existing;
  const BudgetPlannerSheet({super.key, required this.month, this.existing});

  @override
  State<BudgetPlannerSheet> createState() => _BudgetPlannerSheetState();
}

class _BudgetPlannerSheetState extends State<BudgetPlannerSheet> {
  late TextEditingController _incomeCtrl;
  late TextEditingController _fixedCtrl;
  late Map<String, TextEditingController> _limitCtrls;

  @override
  void initState() {
    super.initState();
    _incomeCtrl = TextEditingController(
        text: widget.existing?.income == null || widget.existing!.income == 0
            ? ''
            : widget.existing!.income.toStringAsFixed(0));
    _fixedCtrl = TextEditingController(
        text: widget.existing == null || widget.existing!.fixedCostsTotal == 0
            ? ''
            : widget.existing!.fixedCostsTotal.toStringAsFixed(0));
    _limitCtrls = {};
    for (final l in widget.existing?.limits ?? const <CategoryLimit>[]) {
      _limitCtrls[l.categoryId] = TextEditingController(
          text: l.limit == 0 ? '' : l.limit.toStringAsFixed(0));
    }
  }

  @override
  void dispose() {
    _incomeCtrl.dispose();
    _fixedCtrl.dispose();
    for (final c in _limitCtrls.values) {
      c.dispose();
    }
    super.dispose();
  }

  double get _income => double.tryParse(_incomeCtrl.text.replaceAll(',', '.')) ?? 0;
  double get _fixed => double.tryParse(_fixedCtrl.text.replaceAll(',', '.')) ?? 0;

  double get _sumLimits {
    double s = 0;
    for (final c in _limitCtrls.values) {
      s += double.tryParse(c.text.replaceAll(',', '.')) ?? 0;
    }
    return s;
  }

  void _ensureCtrl(String id) {
    _limitCtrls.putIfAbsent(id, () => TextEditingController());
  }

  void _applyDistribution(DistributionStrategy strategy, AppState app) {
    final txCats = app.categoriesByScope('tx');
    final hist = <String, double>{};
    for (var i = 1; i <= 3; i++) {
      final m = DateTime(widget.month.year, widget.month.month - i);
      for (final t in app.txInMonth(m).where((t) => t.type == TxType.expense)) {
        final id = t.categoryId;
        if (id == null) continue;
        hist.update(id, (v) => v + t.amount, ifAbsent: () => t.amount);
      }
    }
    final suggested = suggestDistribution(
      strategy: strategy,
      income: _income,
      historicalSpendByCat: hist,
      fallbackCategories: txCats,
      fixedCosts: _fixed,
    );
    setState(() {
      for (final c in _limitCtrls.values) {
        c.text = '';
      }
      for (final lim in suggested) {
        _ensureCtrl(lim.categoryId);
        _limitCtrls[lim.categoryId]!.text = lim.limit.toStringAsFixed(0);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final i18n = context.watch<I18n>();
    final txCats = app.categoriesByScope('tx');

    for (final c in txCats) {
      _ensureCtrl(c.id);
    }

    final sum = _sumLimits;
    final plannedOutflow = sum + _fixed;
    final free = _income - plannedOutflow;
    final negative = free < 0;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(widget.existing == null ? i18n.t('create_budget') : i18n.t('edit'),
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          Text(i18n.t('income_label'),
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
          const SizedBox(height: 6),
          TextField(
            controller: _incomeCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(hintText: i18n.t('income')),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 14),
          const Text('Обязательные платежи и подписки',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
          const SizedBox(height: 6),
          TextField(
            controller: _fixedCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              hintText: 'Аренда, коммуналка, кредиты, подписки',
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 14),
          Text(i18n.t('auto_distribute'),
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _DistChip(label: i18n.t('distribute_50_30_20'), onTap: () => _applyDistribution(DistributionStrategy.fiftyThirtyTwenty, app)),
              _DistChip(label: i18n.t('distribute_zero'), onTap: () => _applyDistribution(DistributionStrategy.zeroBased, app)),
              _DistChip(label: i18n.t('distribute_envelope'), onTap: () => _applyDistribution(DistributionStrategy.envelope, app)),
              _DistChip(label: i18n.t('distribute_proportional'), onTap: () => _applyDistribution(DistributionStrategy.proportional, app)),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.muted,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(child: _MiniStat(label: i18n.t('income'), value: Fmt.currency(_income, symbol: app.currency), color: AppColors.income)),
                    Expanded(child: _MiniStat(label: 'Обязательные', value: Fmt.currency(_fixed, symbol: app.currency), color: AppColors.warning)),
                    Expanded(child: _MiniStat(label: i18n.t('sum_of_limits'), value: Fmt.currency(sum, symbol: app.currency), color: AppColors.expense)),
                  ],
                ),
                const Divider(height: 18),
                Row(
                  children: [
                    Expanded(child: Text(i18n.t('free_funds'))),
                    Text(Fmt.currency(free, symbol: app.currency),
                        style: TextStyle(color: negative ? AppColors.danger : AppColors.primary, fontWeight: FontWeight.w900)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Text(i18n.t('category_limits'),
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          for (final c in txCats)
            _CategoryLimitField(
              category: c,
              controller: _limitCtrls[c.id]!,
              currency: app.currency,
              onChanged: () => setState(() {}),
            ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(i18n.t('cancel')),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    final limits = <CategoryLimit>[];
                    for (final entry in _limitCtrls.entries) {
                      final v = double.tryParse(entry.value.text.replaceAll(',', '.')) ?? 0;
                      if (v > 0) limits.add(CategoryLimit(categoryId: entry.key, limit: v));
                    }
                    final total = limits.fold<double>(0, (a, l) => a + l.limit);
                    final fixedCosts = <FixedBudgetItem>[];
                    if (_fixed > 0) {
                      fixedCosts.add(FixedBudgetItem(
                        id: 'fixed_${Fmt.monthKey(widget.month)}',
                        name: 'Обязательные платежи и подписки',
                        amount: _fixed,
                        subscription: true,
                      ));
                    }
                    Navigator.of(context).pop(MonthlyBudget(
                      monthKey: Fmt.monthKey(widget.month),
                      income: _income,
                      totalLimit: total,
                      limits: limits,
                      fixedCosts: fixedCosts,
                      template: widget.existing?.template,
                    ));
                  },
                  child: Text(i18n.t('save')),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DistChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _DistChip({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      label: Text(label),
      onPressed: onTap,
      backgroundColor: AppColors.muted,
      side: BorderSide.none,
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _MiniStat({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 11)),
        const SizedBox(height: 4),
        Text(value, style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 14)),
      ],
    );
  }
}

class _CategoryLimitField extends StatelessWidget {
  final CategoryModel category;
  final TextEditingController controller;
  final String currency;
  final VoidCallback onChanged;
  const _CategoryLimitField({
    required this.category,
    required this.controller,
    required this.currency,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final emoji = CategoryIcons.resolve(category.iconKey);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          IconBadge(emoji: emoji, bg: category.color.withOpacity(0.15)),
          const SizedBox(width: 12),
          Expanded(child: Text(category.name, style: const TextStyle(fontWeight: FontWeight.w600))),
          SizedBox(
            width: 130,
            child: TextField(
              controller: controller,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              textAlign: TextAlign.right,
              decoration: InputDecoration(isDense: true, hintText: '0', suffixText: currency),
              onChanged: (_) => onChanged(),
            ),
          ),
        ],
      ),
    );
  }
}
