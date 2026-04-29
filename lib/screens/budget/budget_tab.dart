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
          if (budget == null)
            AppCard(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(i18n.t('no_budget_yet'),
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  Text(i18n.t('budget_planner'),
                      style: const TextStyle(
                          color: AppColors.textSecondary, fontSize: 13)),
                  const SizedBox(height: 14),
                  ElevatedButton(
                    onPressed: () => _openPlanner(context),
                    child: Text(i18n.t('create_budget')),
                  ),
                ],
              ),
            )
          else ...[
            _PlanFactSummary(metrics: metrics),
            const SizedBox(height: 12),
            _SafeTodayCard(metrics: metrics),
            const SizedBox(height: 18),
            SectionHeader(title: i18n.t('daily_pace')),
            _DailyPaceCard(month: _month, tx: tx, plan: budget.totalLimit),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(child: SectionHeader(title: i18n.t('category_limits'))),
                TextButton.icon(
                  onPressed: () => _openPlanner(context, existing: budget),
                  icon: const Icon(Icons.edit, size: 16),
                  label: Text(i18n.t('edit')),
                ),
              ],
            ),
            AppCard(
              padding: const EdgeInsets.all(16),
              child: breakdown.isEmpty
                  ? Center(
                      child: Text(i18n.t('no_data_yet'),
                          style: const TextStyle(
                              color: AppColors.textSecondary)),
                    )
                  : Column(
                      children: [
                        for (final r in breakdown) _CategoryRow(row: r),
                      ],
                    ),
            ),
            const SizedBox(height: 18),
            SectionHeader(title: i18n.t('forecast_short')),
            AppCard(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(Fmt.currency(metrics.forecast, symbol: app.currency),
                      style: const TextStyle(
                          fontSize: 22, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  Text(
                      '${i18n.t('avg_per_day')}: ${Fmt.currency(metrics.dayNumber > 0 ? metrics.expense / metrics.dayNumber : 0, symbol: app.currency)}',
                      style: const TextStyle(color: AppColors.textSecondary)),
                  const SizedBox(height: 12),
                  _BudgetHealthBadge(
                      forecast: metrics.forecast, plan: budget.totalLimit),
                ],
              ),
            ),
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
        padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom),
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

class _PlanFactSummary extends StatelessWidget {
  final BudgetMetrics metrics;
  const _PlanFactSummary({required this.metrics});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final i18n = context.watch<I18n>();
    String money(double v) =>
        Fmt.currency(v, symbol: app.currency, decimals: 0);
    String signed(double v) {
      if (v == 0) return money(0);
      final sign = v > 0 ? '+' : '−';
      return '$sign${money(v.abs())}';
    }

    final pct = metrics.plannedExpense > 0
        ? (metrics.expense / metrics.plannedExpense).clamp(0.0, 1.0)
        : 0.0;

    return AppCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(i18n.t('plan_vs_fact'),
              style:
                  const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(height: 14),
          // Header
          Row(
            children: [
              const Expanded(flex: 3, child: SizedBox()),
              Expanded(
                flex: 2,
                child: Text(i18n.t('plan'),
                    textAlign: TextAlign.right,
                    style: const TextStyle(
                        color: AppColors.textSecondary, fontSize: 12)),
              ),
              Expanded(
                flex: 2,
                child: Text(i18n.t('fact'),
                    textAlign: TextAlign.right,
                    style: const TextStyle(
                        color: AppColors.textSecondary, fontSize: 12)),
              ),
              Expanded(
                flex: 2,
                child: Text(i18n.t('delta'),
                    textAlign: TextAlign.right,
                    style: const TextStyle(
                        color: AppColors.textSecondary, fontSize: 12)),
              ),
            ],
          ),
          const Divider(height: 16),
          _PFRow(
            label: i18n.t('income'),
            plan: money(metrics.plannedIncome),
            fact: money(metrics.income),
            delta: signed(metrics.income - metrics.plannedIncome),
            deltaColor: metrics.income >= metrics.plannedIncome
                ? AppColors.income
                : AppColors.danger,
          ),
          _PFRow(
            label: i18n.t('expenses'),
            plan: money(metrics.plannedExpense),
            fact: money(metrics.expense),
            delta: signed(metrics.expense - metrics.plannedExpense),
            deltaColor: metrics.expense <= metrics.plannedExpense
                ? AppColors.income
                : AppColors.danger,
          ),
          _PFRow(
            label: i18n.t('free_funds'),
            plan: money(metrics.freeFundsPlan),
            fact: money(metrics.freeFundsFact),
            delta: signed(metrics.freeFundsFact - metrics.freeFundsPlan),
            deltaColor: metrics.freeFundsFact >= metrics.freeFundsPlan
                ? AppColors.income
                : AppColors.danger,
            highlight: true,
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: pct,
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
          Text('${(pct * 100).round()}% ${i18n.t('on_plan')}',
              style: const TextStyle(color: AppColors.textSecondary)),
        ],
      ),
    );
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
                style: TextStyle(
                    fontWeight:
                        highlight ? FontWeight.w800 : FontWeight.w500)),
          ),
          Expanded(
            flex: 2,
            child: Text(plan, textAlign: TextAlign.right, style: style),
          ),
          Expanded(
            flex: 2,
            child: Text(fact, textAlign: TextAlign.right, style: style),
          ),
          Expanded(
            flex: 2,
            child: Text(delta,
                textAlign: TextAlign.right,
                style: style.copyWith(color: deltaColor)),
          ),
        ],
      ),
    );
  }
}

class _SafeTodayCard extends StatelessWidget {
  final BudgetMetrics metrics;
  const _SafeTodayCard({required this.metrics});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final i18n = context.watch<I18n>();
    final daysLeft = metrics.daysLeft;
    final isRu = i18n.lang == AppLang.ru;
    final dayWord = isRu
        ? daysWord(
            n: daysLeft,
            one: i18n.t('days_left_one'),
            few: i18n.t('days_left_few'),
            many: i18n.t('days_left'),
          )
        : (daysLeft == 1 ? i18n.t('days_left_one') : i18n.t('days_left'));
    return AppCard(
      padding: const EdgeInsets.all(18),
      color: AppColors.muted,
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(i18n.t('safe_per_day'),
                    style: const TextStyle(
                        color: AppColors.textSecondary, fontSize: 13)),
                const SizedBox(height: 4),
                Text(Fmt.currency(metrics.safePerDay, symbol: app.currency),
                    style: const TextStyle(
                        fontSize: 22, fontWeight: FontWeight.w800)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.cardBg,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                Text('$daysLeft',
                    style: const TextStyle(
                        fontSize: 22, fontWeight: FontWeight.w800)),
                Text(dayWord,
                    style: const TextStyle(
                        fontSize: 11, color: AppColors.textSecondary)),
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

    final maxY = [
      ...cumActual,
      ...cumPlan,
      1.0,
    ].reduce((a, b) => a > b ? a : b);

    final actualSpots = <FlSpot>[];
    for (var i = 0; i < lastDay && i < cumActual.length; i++) {
      actualSpots.add(FlSpot((i + 1).toDouble(), cumActual[i]));
    }
    final planSpots = <FlSpot>[
      for (var i = 0; i < cumPlan.length; i++)
        FlSpot((i + 1).toDouble(), cumPlan[i]),
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
              getDrawingHorizontalLine: (_) => FlLine(
                color: AppColors.muted,
                strokeWidth: 1,
              ),
            ),
            titlesData: FlTitlesData(
              topTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false)),
              rightTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false)),
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
                        style: const TextStyle(
                            fontSize: 9, color: AppColors.textSecondary),
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
                        style: const TextStyle(
                            fontSize: 10, color: AppColors.textSecondary)),
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
                belowBarData: BarAreaData(
                  show: true,
                  color: AppColors.expense.withOpacity(0.10),
                ),
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

class _CategoryRow extends StatelessWidget {
  final CategoryPlanFact row;
  const _CategoryRow({required this.row});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final i18n = context.watch<I18n>();
    final color = Color(row.colorValue);
    final overspent = row.delta > 0;
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
                    Expanded(
                        child: Text(row.name,
                            style:
                                const TextStyle(fontWeight: FontWeight.w600))),
                    Text(
                      '${Fmt.currency(row.fact, symbol: app.currency)} / ${Fmt.currency(row.plan, symbol: app.currency)}',
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.textSecondary),
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
                  overspent
                      ? '+${Fmt.currency(row.delta, symbol: app.currency)} ${i18n.t('over_plan')}'
                      : (row.plan == 0
                          ? '—'
                          : '${Fmt.currency(-row.delta, symbol: app.currency)} ${i18n.t('under_plan')}'),
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

class _BudgetHealthBadge extends StatelessWidget {
  final double forecast;
  final double? plan;
  const _BudgetHealthBadge({required this.forecast, this.plan});

  @override
  Widget build(BuildContext context) {
    final i18n = context.watch<I18n>();
    String label;
    Color color;
    if (plan == null || plan == 0) {
      label = '—';
      color = AppColors.textSecondary;
    } else if (forecast > plan! * 1.05) {
      label = i18n.t('risk');
      color = AppColors.danger;
    } else if (forecast > plan! * 0.85) {
      label = i18n.t('warning');
      color = AppColors.warning;
    } else {
      label = i18n.t('good');
      color = AppColors.income;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
          color: color.withOpacity(0.12),
          borderRadius: BorderRadius.circular(10)),
      child: Text('${i18n.t('budget_health')}: $label',
          style: TextStyle(
              color: color, fontWeight: FontWeight.w700, fontSize: 13)),
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
                          style: const TextStyle(
                              color: AppColors.textPrimary, fontSize: 14))),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

/// Bottom-sheet planner: per-category limits + auto-distribution + live free-funds preview.
class BudgetPlannerSheet extends StatefulWidget {
  final DateTime month;
  final MonthlyBudget? existing;
  const BudgetPlannerSheet({super.key, required this.month, this.existing});

  @override
  State<BudgetPlannerSheet> createState() => _BudgetPlannerSheetState();
}

class _BudgetPlannerSheetState extends State<BudgetPlannerSheet> {
  late TextEditingController _incomeCtrl;
  late Map<String, TextEditingController> _limitCtrls;

  @override
  void initState() {
    super.initState();
    _incomeCtrl = TextEditingController(
        text: widget.existing?.income == null || widget.existing!.income == 0
            ? ''
            : widget.existing!.income.toStringAsFixed(0));
    _limitCtrls = {};
    for (final l in widget.existing?.limits ?? const <CategoryLimit>[]) {
      _limitCtrls[l.categoryId] = TextEditingController(
          text: l.limit == 0 ? '' : l.limit.toStringAsFixed(0));
    }
  }

  @override
  void dispose() {
    _incomeCtrl.dispose();
    for (final c in _limitCtrls.values) {
      c.dispose();
    }
    super.dispose();
  }

  double get _income =>
      double.tryParse(_incomeCtrl.text.replaceAll(',', '.')) ?? 0;

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

  void _applyDistribution(
      DistributionStrategy strategy, AppState app) {
    final txCats = app.categoriesByScope('tx');
    // Build historical map from previous 3 months.
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
    );
    setState(() {
      // Reset all current to empty first, then fill.
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

    // Pre-create controllers for existing tx categories.
    for (final c in txCats) {
      _ensureCtrl(c.id);
    }

    final sum = _sumLimits;
    final free = _income - sum;
    final negative = free < 0;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
              widget.existing == null
                  ? i18n.t('create_budget')
                  : i18n.t('edit'),
              style:
                  const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          Text(i18n.t('income_label'),
              style: const TextStyle(
                  color: AppColors.textSecondary, fontSize: 12)),
          const SizedBox(height: 6),
          TextField(
            controller: _incomeCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(hintText: i18n.t('income')),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 14),
          Text(i18n.t('auto_distribute'),
              style: const TextStyle(
                  color: AppColors.textSecondary, fontSize: 12)),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _DistChip(
                  label: i18n.t('distribute_50_30_20'),
                  onTap: () => _applyDistribution(
                      DistributionStrategy.fiftyThirtyTwenty, app)),
              _DistChip(
                  label: i18n.t('distribute_zero'),
                  onTap: () => _applyDistribution(
                      DistributionStrategy.zeroBased, app)),
              _DistChip(
                  label: i18n.t('distribute_envelope'),
                  onTap: () => _applyDistribution(
                      DistributionStrategy.envelope, app)),
              _DistChip(
                  label: i18n.t('distribute_proportional'),
                  onTap: () => _applyDistribution(
                      DistributionStrategy.proportional, app)),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.muted,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _MiniStat(
                      label: i18n.t('income'),
                      value:
                          Fmt.currency(_income, symbol: app.currency),
                      color: AppColors.income),
                ),
                Expanded(
                  child: _MiniStat(
                      label: i18n.t('sum_of_limits'),
                      value: Fmt.currency(sum, symbol: app.currency),
                      color: AppColors.expense),
                ),
                Expanded(
                  child: _MiniStat(
                      label: i18n.t('free_funds'),
                      value: Fmt.currency(free, symbol: app.currency),
                      color: negative ? AppColors.danger : AppColors.primary,
                      subtitle: negative ? i18n.t('in_minus') : null),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Text(i18n.t('category_limits'),
              style:
                  const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
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
                      final v = double.tryParse(
                              entry.value.text.replaceAll(',', '.')) ??
                          0;
                      if (v > 0) {
                        limits
                            .add(CategoryLimit(categoryId: entry.key, limit: v));
                      }
                    }
                    final total =
                        limits.fold<double>(0, (a, l) => a + l.limit);
                    Navigator.of(context).pop(MonthlyBudget(
                      monthKey: Fmt.monthKey(widget.month),
                      income: _income,
                      totalLimit: total,
                      limits: limits,
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
  final String? subtitle;
  const _MiniStat({
    required this.label,
    required this.value,
    required this.color,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                color: AppColors.textSecondary, fontSize: 11)),
        const SizedBox(height: 4),
        Text(value,
            style: TextStyle(
                color: color, fontWeight: FontWeight.w800, fontSize: 14)),
        if (subtitle != null)
          Text(subtitle!,
              style: TextStyle(color: color, fontSize: 10)),
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
          Expanded(
            child: Text(category.name,
                style: const TextStyle(fontWeight: FontWeight.w600)),
          ),
          SizedBox(
            width: 130,
            child: TextField(
              controller: controller,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              textAlign: TextAlign.right,
              decoration: InputDecoration(
                isDense: true,
                hintText: '0',
                suffixText: currency,
              ),
              onChanged: (_) => onChanged(),
            ),
          ),
        ],
      ),
    );
  }
}
