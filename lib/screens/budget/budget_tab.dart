import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/budget.dart';
import '../../models/category.dart';
import '../../models/transaction.dart';
import '../../providers/app_state.dart';
import '../../theme/app_theme.dart';
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
    final actualExpense = tx.where((t) => t.type == TxType.expense).fold<double>(0, (a, t) => a + t.amount);
    final actualIncome = tx.where((t) => t.type == TxType.income).fold<double>(0, (a, t) => a + t.amount);
    final budget = app.budgetFor(_month);

    final byCat = <String, double>{};
    for (final t in tx.where((t) => t.type == TxType.expense)) {
      byCat.update(t.categoryId ?? 'none', (v) => v + t.amount, ifAbsent: () => t.amount);
    }

    final daysInMonth = DateTime(_month.year, _month.month + 1, 0).day;
    final today = DateTime.now();
    final isCurrentMonth = today.year == _month.year && today.month == _month.month;
    final dayNum = isCurrentMonth ? today.day : daysInMonth;
    final daysLeft = isCurrentMonth ? (daysInMonth - today.day + 1) : daysInMonth;
    final perDayActual = dayNum > 0 ? actualExpense / dayNum : 0.0;
    final forecast = perDayActual * daysInMonth;

    return Scaffold(
      appBar: AppBar(
        leading: widget.asPage ? const BackButton() : null,
        title: Text(i18n.t('budget')),
        actions: [
          IconButton(
            onPressed: () => setState(() => _month = DateTime(_month.year, _month.month - 1)),
            icon: const Icon(Icons.chevron_left),
          ),
          Center(
            child: Text(Fmt.monthName(_month, locale: i18n.locale.languageCode),
                style: const TextStyle(fontWeight: FontWeight.w600)),
          ),
          IconButton(
            onPressed: () => setState(() => _month = DateTime(_month.year, _month.month + 1)),
            icon: const Icon(Icons.chevron_right),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        children: [
          if (budget == null)
            _NoBudgetCard(onCreate: () => _openPlanner(context, null, actualIncome))
          else ...[
            _BudgetSummary(
              budget: budget,
              actualIncome: actualIncome,
              actualExpense: actualExpense,
              onEdit: () => _openPlanner(context, budget, actualIncome),
            ),
            const SizedBox(height: 14),
            _SafeToSpend(budget: budget, actualExpense: actualExpense, daysLeft: daysLeft),
            const SizedBox(height: 18),
            SectionHeader(title: i18n.t('distribution')),
            _DistributionDonut(budget: budget),
            const SizedBox(height: 18),
            SectionHeader(title: i18n.t('spending_limits')),
            _CategoryLimits(budget: budget, byCat: byCat),
          ],
          const SizedBox(height: 18),
          SectionHeader(title: i18n.t('top_categories')),
          _TopCategories(byCat: byCat, total: actualExpense, budget: budget),
          const SizedBox(height: 18),
          SectionHeader(title: i18n.t('forecast_short')),
          _ForecastCard(forecast: forecast, perDay: perDayActual, plan: budget?.totalLimit),
          const SizedBox(height: 18),
          SectionHeader(title: i18n.t('debt_advice')),
          const _AdvicesCard(),
          const SizedBox(height: 18),
          SectionHeader(title: i18n.t('budget_template')),
          _Templates(month: _month, income: actualIncome, onApply: () => setState(() {})),
          const SizedBox(height: 18),
          SectionHeader(title: i18n.t('budget_history')),
          _BudgetHistory(currentMonth: _month, onTap: (m) => setState(() => _month = m)),
        ],
      ),
    );
  }

  Future<void> _openPlanner(BuildContext context, MonthlyBudget? existing, double actualIncome) async {
    final app = context.read<AppState>();
    final result = await Navigator.of(context).push<MonthlyBudget>(
      MaterialPageRoute(
        builder: (_) => _BudgetPlannerScreen(
          month: _month,
          initial: existing,
          actualIncome: actualIncome,
        ),
        fullscreenDialog: true,
      ),
    );
    if (result != null) {
      await app.upsertBudget(result);
      setState(() {});
    }
  }
}

class _NoBudgetCard extends StatelessWidget {
  final VoidCallback onCreate;
  const _NoBudgetCard({required this.onCreate});

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
          Text(i18n.t('budget_planner'),
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
          const SizedBox(height: 14),
          ElevatedButton(onPressed: onCreate, child: Text(i18n.t('create_budget'))),
        ],
      ),
    );
  }
}

class _BudgetSummary extends StatelessWidget {
  final MonthlyBudget budget;
  final double actualIncome;
  final double actualExpense;
  final VoidCallback onEdit;
  const _BudgetSummary({
    required this.budget,
    required this.actualIncome,
    required this.actualExpense,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final i18n = context.watch<I18n>();
    final cur = app.currency;
    final plannedIncome = budget.income;
    final plannedExpense = budget.sumOfLimits > 0 ? budget.sumOfLimits : budget.totalLimit;
    final freeFromPlan = plannedIncome + budget.carriedOver - plannedExpense;
    final freeFromActual = actualIncome - actualExpense;
    final pct = plannedExpense == 0 ? 0.0 : (actualExpense / plannedExpense).clamp(0.0, 1.0);

    return AppCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(i18n.t('budget_summary'),
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              ),
              IconButton(
                onPressed: onEdit,
                icon: const Icon(Icons.edit_outlined),
                tooltip: i18n.t('edit_budget'),
              ),
            ],
          ),
          const SizedBox(height: 6),
          _SummaryRow(
            label: i18n.t('income'),
            planned: plannedIncome,
            actual: actualIncome,
            color: AppColors.income,
            symbol: cur,
          ),
          const SizedBox(height: 8),
          _SummaryRow(
            label: i18n.t('expenses'),
            planned: plannedExpense,
            actual: actualExpense,
            color: AppColors.expense,
            symbol: cur,
          ),
          const SizedBox(height: 8),
          _SummaryRow(
            label: i18n.t('free_funds'),
            planned: freeFromPlan,
            actual: freeFromActual,
            color: AppColors.primary,
            symbol: cur,
            highlight: true,
          ),
          const SizedBox(height: 14),
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
          const SizedBox(height: 6),
          Text('${(pct * 100).round()}% ${i18n.t('on_plan')}',
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
          if (budget.carriedOver > 0) ...[
            const SizedBox(height: 8),
            Text(
              '+ ${Fmt.currency(budget.carriedOver, symbol: cur)} ${i18n.t('carry_over').toLowerCase()}',
              style: const TextStyle(color: AppColors.income, fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ],
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final String label;
  final double planned;
  final double actual;
  final Color color;
  final String symbol;
  final bool highlight;
  const _SummaryRow({
    required this.label,
    required this.planned,
    required this.actual,
    required this.color,
    required this.symbol,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) {
    final i18n = context.watch<I18n>();
    return Container(
      padding: highlight ? const EdgeInsets.all(10) : EdgeInsets.zero,
      decoration: highlight
          ? BoxDecoration(
              color: color.withOpacity(0.08),
              borderRadius: BorderRadius.circular(10),
            )
          : null,
      child: Row(
        children: [
          Container(width: 4, height: 32, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
                Text(
                  '${i18n.t('plan')}: ${Fmt.currency(planned, symbol: symbol)}',
                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 11),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                Fmt.currency(actual, symbol: symbol),
                style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 15),
              ),
              Text(
                i18n.t('actual'),
                style: const TextStyle(color: AppColors.textSecondary, fontSize: 11),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SafeToSpend extends StatelessWidget {
  final MonthlyBudget budget;
  final double actualExpense;
  final int daysLeft;
  const _SafeToSpend({required this.budget, required this.actualExpense, required this.daysLeft});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final i18n = context.watch<I18n>();
    final plan = budget.sumOfLimits > 0 ? budget.sumOfLimits : budget.totalLimit;
    final remaining = (plan - actualExpense).clamp(0.0, double.infinity);
    final perDay = daysLeft > 0 ? remaining / daysLeft : 0.0;
    final perWeek = perDay * 7;
    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(i18n.t('safe_to_spend'),
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _SafeBlock(
                  title: i18n.t('safe_per_day'),
                  value: Fmt.currency(perDay, symbol: app.currency),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _SafeBlock(
                  title: i18n.t('safe_per_week'),
                  value: Fmt.currency(perWeek, symbol: app.currency),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SafeBlock extends StatelessWidget {
  final String title;
  final String value;
  const _SafeBlock({required this.title, required this.value});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 11)),
          const SizedBox(height: 4),
          Text(value,
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
        ],
      ),
    );
  }
}

class _DistributionDonut extends StatelessWidget {
  final MonthlyBudget budget;
  const _DistributionDonut({required this.budget});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final i18n = context.watch<I18n>();
    if (budget.limits.isEmpty) {
      return AppCard(
        padding: const EdgeInsets.all(16),
        child: Text(i18n.t('no_limits_yet'),
            style: const TextStyle(color: AppColors.textSecondary)),
      );
    }
    final segments = <_Seg>[];
    for (final l in budget.limits) {
      final cat = app.categoryById(l.categoryId);
      segments.add(_Seg(
        value: l.limit,
        color: cat?.color ?? AppColors.primary,
        label: cat?.name ?? '—',
      ));
    }
    final freeFunds = budget.freeFunds;
    if (freeFunds > 0) {
      segments.add(_Seg(value: freeFunds, color: AppColors.income, label: i18n.t('free_funds')));
    }
    final total = segments.fold<double>(0, (a, s) => a + s.value);
    if (total <= 0) {
      return AppCard(
        padding: const EdgeInsets.all(16),
        child: Text(i18n.t('no_data'),
            style: const TextStyle(color: AppColors.textSecondary)),
      );
    }

    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          SizedBox(
            width: 130,
            height: 130,
            child: CustomPaint(
              painter: _DonutPainter(segments: segments, total: total),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(Fmt.currency(total, symbol: app.currency),
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                    Text(i18n.t('total_planned'),
                        style: const TextStyle(color: AppColors.textSecondary, fontSize: 10)),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final s in segments.take(7))
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Row(
                      children: [
                        Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            color: s.color,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(s.label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 12)),
                        ),
                        Text('${(s.value / total * 100).round()}%',
                            style: const TextStyle(
                                fontWeight: FontWeight.w600, fontSize: 12)),
                      ],
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

class _Seg {
  final double value;
  final Color color;
  final String label;
  _Seg({required this.value, required this.color, required this.label});
}

class _DonutPainter extends CustomPainter {
  final List<_Seg> segments;
  final double total;
  _DonutPainter({required this.segments, required this.total});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2;
    final stroke = 16.0;
    final rect = Rect.fromCircle(center: center, radius: radius - stroke / 2);
    var start = -math.pi / 2;
    for (final s in segments) {
      final sweep = (s.value / total) * 2 * math.pi;
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.butt
        ..color = s.color;
      canvas.drawArc(rect, start, sweep, false, paint);
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant _DonutPainter oldDelegate) =>
      oldDelegate.total != total || oldDelegate.segments != segments;
}

class _CategoryLimits extends StatelessWidget {
  final MonthlyBudget budget;
  final Map<String, double> byCat;
  const _CategoryLimits({required this.budget, required this.byCat});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final i18n = context.watch<I18n>();
    if (budget.limits.isEmpty) {
      return AppCard(
        padding: const EdgeInsets.all(16),
        child: Text(i18n.t('no_limits_yet'),
            style: const TextStyle(color: AppColors.textSecondary)),
      );
    }
    return Column(
      children: [
        for (final l in budget.limits)
          _CategoryBar(
            categoryId: l.categoryId,
            spent: byCat[l.categoryId] ?? 0,
            limit: l.limit,
            symbol: app.currency,
          ),
      ],
    );
  }
}

class _CategoryBar extends StatelessWidget {
  final String categoryId;
  final double spent;
  final double limit;
  final String symbol;
  const _CategoryBar({
    required this.categoryId,
    required this.spent,
    required this.limit,
    required this.symbol,
  });

  @override
  Widget build(BuildContext context) {
    final app = context.read<AppState>();
    final i18n = context.watch<I18n>();
    final cat = app.categoryById(categoryId);
    final emoji = cat != null ? CategoryIcons.resolve(cat.iconKey) : '📦';
    final pct = limit > 0 ? (spent / limit).clamp(0.0, 1.0) : 0.0;
    final left = (limit - spent);
    final color = pct > 1.0
        ? AppColors.danger
        : pct > 0.8
            ? AppColors.warning
            : (cat?.color ?? AppColors.primary);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: AppCard(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            IconBadge(emoji: emoji, bg: (cat?.color ?? AppColors.muted).withOpacity(0.15)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(cat?.name ?? '—',
                            style: const TextStyle(fontWeight: FontWeight.w600)),
                      ),
                      Text('${Fmt.currency(spent, symbol: symbol)} / ${Fmt.currency(limit, symbol: symbol)}',
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: pct,
                      minHeight: 6,
                      backgroundColor: AppColors.muted,
                      color: color,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    spent > limit
                        ? '${i18n.t('over_limit')}: ${Fmt.currency(spent - limit, symbol: symbol)}'
                        : '${i18n.t('left')}: ${Fmt.currency(left, symbol: symbol)}',
                    style: TextStyle(
                      color: spent > limit ? AppColors.danger : AppColors.textSecondary,
                      fontSize: 11,
                      fontWeight: spent > limit ? FontWeight.w600 : FontWeight.normal,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TopCategories extends StatelessWidget {
  final Map<String, double> byCat;
  final double total;
  final MonthlyBudget? budget;
  const _TopCategories({required this.byCat, required this.total, required this.budget});

  @override
  Widget build(BuildContext context) {
    final app = context.read<AppState>();
    final i18n = context.watch<I18n>();
    final list = byCat.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    if (list.isEmpty) {
      return AppCard(
        padding: const EdgeInsets.all(16),
        child: Center(child: Text(i18n.t('no_data'),
            style: const TextStyle(color: AppColors.textSecondary))),
      );
    }
    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          for (final e in list.take(6))
            _BarRow(
              cat: app.categoryById(e.key),
              spent: e.value,
              total: total,
              symbol: app.currency,
            ),
        ],
      ),
    );
  }
}

class _BarRow extends StatelessWidget {
  final CategoryModel? cat;
  final double spent;
  final double total;
  final String symbol;
  const _BarRow({required this.cat, required this.spent, required this.total, required this.symbol});

  @override
  Widget build(BuildContext context) {
    final emoji = cat != null ? CategoryIcons.resolve(cat!.iconKey) : '📦';
    final pct = total > 0 ? (spent / total).clamp(0.0, 1.0) : 0.0;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          IconBadge(emoji: emoji, bg: (cat?.color ?? AppColors.muted).withOpacity(0.15)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(child: Text(cat?.name ?? '—', style: const TextStyle(fontWeight: FontWeight.w600))),
                    Text(Fmt.currency(spent, symbol: symbol), style: const TextStyle(fontWeight: FontWeight.w600)),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: pct,
                    minHeight: 6,
                    backgroundColor: AppColors.muted,
                    color: cat?.color ?? AppColors.primary,
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

class _ForecastCard extends StatelessWidget {
  final double forecast;
  final double perDay;
  final double? plan;
  const _ForecastCard({required this.forecast, required this.perDay, this.plan});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final i18n = context.watch<I18n>();
    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(Fmt.currency(forecast, symbol: app.currency),
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text('${i18n.t('avg_per_day')}: ${Fmt.currency(perDay, symbol: app.currency)}',
              style: const TextStyle(color: AppColors.textSecondary)),
          const SizedBox(height: 12),
          _BudgetHealthBadge(forecast: forecast, plan: plan),
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
      decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(10)),
      child: Text('${i18n.t('budget_health')}: $label',
          style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 13)),
    );
  }
}

class _AdvicesCard extends StatelessWidget {
  const _AdvicesCard();
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
                          style: const TextStyle(color: AppColors.textPrimary, fontSize: 14))),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _Templates extends StatelessWidget {
  final DateTime month;
  final double income;
  final VoidCallback onApply;
  const _Templates({required this.month, required this.income, required this.onApply});

  @override
  Widget build(BuildContext context) {
    final app = context.read<AppState>();
    final i18n = context.watch<I18n>();
    final templates = [
      ('50_30_20', i18n.t('template_50_30_20'), i18n.t('tip_50_30_20')),
      ('zero', i18n.t('template_zero'), i18n.t('tip_zero')),
      ('envelope', i18n.t('template_envelope'), i18n.t('tip_envelope')),
    ];
    return Column(
      children: [
        for (final t in templates)
          AppCard(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppColors.muted,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.dashboard_customize, color: AppColors.primary)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(t.$2, style: const TextStyle(fontWeight: FontWeight.w700)),
                      Text(t.$3,
                          style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: () async {
                    var inc = income;
                    if (inc <= 0) {
                      final existing = app.budgetFor(month);
                      inc = existing?.income ?? 0;
                    }
                    if (inc <= 0) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(i18n.t('no_data'))),
                      );
                      return;
                    }
                    final budget = _buildFromTemplate(app, month, t.$1, inc);
                    await app.upsertBudget(budget);
                    onApply();
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(i18n.t('apply'))),
                    );
                  },
                  child: Text(i18n.t('apply')),
                ),
              ],
            ),
          ),
        const SizedBox(height: 8),
      ],
    );
  }
}

MonthlyBudget _buildFromTemplate(AppState app, DateTime month, String template, double income) {
  final cats = app.categoriesByScope('tx').where((c) => !_incomeLikeCategory(c)).toList();
  final limits = <CategoryLimit>[];
  double totalLimit = 0;
  if (template == '50_30_20') {
    final needs = income * 0.50;
    final wants = income * 0.30;
    totalLimit = needs + wants;
    final needCats = cats.where((c) => _isNeed(c)).toList();
    final wantCats = cats.where((c) => !_isNeed(c)).toList();
    if (needCats.isNotEmpty) {
      final each = needs / needCats.length;
      for (final c in needCats) {
        limits.add(CategoryLimit(categoryId: c.id, limit: each));
      }
    }
    if (wantCats.isNotEmpty) {
      final each = wants / wantCats.length;
      for (final c in wantCats) {
        limits.add(CategoryLimit(categoryId: c.id, limit: each));
      }
    }
  } else if (template == 'zero') {
    totalLimit = income;
    if (cats.isNotEmpty) {
      final each = income / cats.length;
      for (final c in cats) {
        limits.add(CategoryLimit(categoryId: c.id, limit: each));
      }
    }
  } else {
    // envelope: 90% across all
    totalLimit = income * 0.9;
    if (cats.isNotEmpty) {
      final each = (income * 0.9) / cats.length;
      for (final c in cats) {
        limits.add(CategoryLimit(categoryId: c.id, limit: each));
      }
    }
  }
  return MonthlyBudget(
    monthKey: Fmt.monthKey(month),
    income: income,
    totalLimit: totalLimit,
    limits: limits,
    template: template,
  );
}

bool _isNeed(CategoryModel c) {
  final n = c.name.toLowerCase();
  return n.contains('продукт') ||
      n.contains('коммун') ||
      n.contains('транспорт') ||
      n.contains('здоров') ||
      n.contains('аренд') ||
      n.contains('квартир');
}

bool _incomeLikeCategory(CategoryModel c) {
  final n = c.name.toLowerCase();
  return n.contains('зарплат') || n.contains('salary') || n.contains('доход');
}

class _BudgetHistory extends StatelessWidget {
  final DateTime currentMonth;
  final ValueChanged<DateTime> onTap;
  const _BudgetHistory({required this.currentMonth, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final i18n = context.watch<I18n>();
    final all = app.budgets.all().toList()
      ..sort((a, b) => b.monthKey.compareTo(a.monthKey));
    if (all.isEmpty) {
      return AppCard(
        padding: const EdgeInsets.all(16),
        child: Text(i18n.t('no_data'),
            style: const TextStyle(color: AppColors.textSecondary)),
      );
    }
    return Column(
      children: [
        for (final b in all.take(6))
          _HistoryRow(budget: b, currentKey: Fmt.monthKey(currentMonth), onTap: onTap),
      ],
    );
  }
}

class _HistoryRow extends StatelessWidget {
  final MonthlyBudget budget;
  final String currentKey;
  final ValueChanged<DateTime> onTap;
  const _HistoryRow({required this.budget, required this.currentKey, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final i18n = context.watch<I18n>();
    final parts = budget.monthKey.split('-');
    final year = int.tryParse(parts[0]) ?? DateTime.now().year;
    final month = int.tryParse(parts[1]) ?? 1;
    final m = DateTime(year, month);
    final tx = app.txInMonth(m);
    final actual = tx.where((t) => t.type == TxType.expense).fold<double>(0, (a, t) => a + t.amount);
    final plan = budget.sumOfLimits > 0 ? budget.sumOfLimits : budget.totalLimit;
    final ratio = plan == 0 ? 0.0 : (actual / plan);
    final isCurrent = budget.monthKey == currentKey;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: AppCard(
        padding: const EdgeInsets.all(12),
        color: isCurrent ? AppColors.primary.withOpacity(0.08) : null,
        child: InkWell(
          onTap: () => onTap(m),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(Fmt.monthName(m, locale: i18n.locale.languageCode),
                        style: const TextStyle(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 4),
                    Text(
                      '${i18n.t('plan')}: ${Fmt.currency(plan, symbol: app.currency)} · '
                      '${i18n.t('actual')}: ${Fmt.currency(actual, symbol: app.currency)}',
                      style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: ratio > 1.05
                      ? AppColors.danger.withOpacity(0.15)
                      : ratio > 0.85
                          ? AppColors.warning.withOpacity(0.15)
                          : AppColors.income.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${(ratio * 100).round()}%',
                  style: TextStyle(
                    color: ratio > 1.05
                        ? AppColors.danger
                        : ratio > 0.85
                            ? AppColors.warning
                            : AppColors.income,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ===================================================================
// PLANNER (full-screen sheet) =====================================
// ===================================================================

class _BudgetPlannerScreen extends StatefulWidget {
  final DateTime month;
  final MonthlyBudget? initial;
  final double actualIncome;
  const _BudgetPlannerScreen({
    required this.month,
    required this.initial,
    required this.actualIncome,
  });

  @override
  State<_BudgetPlannerScreen> createState() => _BudgetPlannerScreenState();
}

class _BudgetPlannerScreenState extends State<_BudgetPlannerScreen> {
  late TextEditingController _incomeCtrl;
  final Map<String, TextEditingController> _limitCtrls = {};
  bool _carryOver = false;

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    _incomeCtrl = TextEditingController(
      text: initial != null
          ? initial.income.toStringAsFixed(0)
          : (widget.actualIncome > 0 ? widget.actualIncome.toStringAsFixed(0) : ''),
    );
    _carryOver = initial?.carryOver ?? false;
    if (initial != null) {
      for (final l in initial.limits) {
        _limitCtrls[l.categoryId] =
            TextEditingController(text: l.limit.toStringAsFixed(0));
      }
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
      double.tryParse(_incomeCtrl.text.replaceAll(',', '.').replaceAll(' ', '')) ?? 0;

  double _sumOfLimits() {
    double s = 0;
    for (final c in _limitCtrls.values) {
      s += double.tryParse(c.text.replaceAll(',', '.').replaceAll(' ', '')) ?? 0;
    }
    return s;
  }

  double get _free => _income - _sumOfLimits();

  void _autoDistribute(String template) {
    final inc = _income;
    if (inc <= 0) return;
    final cats =
        context.read<AppState>().categoriesByScope('tx').where((c) => !_incomeLikeCategory(c)).toList();
    final tmp = _buildFromTemplate(context.read<AppState>(), widget.month, template, inc);
    setState(() {
      for (final c in cats) {
        _limitCtrls[c.id] ??= TextEditingController();
      }
      for (final c in cats) {
        final l = tmp.limits.firstWhere(
          (x) => x.categoryId == c.id,
          orElse: () => CategoryLimit(categoryId: c.id, limit: 0),
        );
        _limitCtrls[c.id]!.text = l.limit.toStringAsFixed(0);
      }
    });
  }

  void _save() {
    final app = context.read<AppState>();
    final cats = app.categoriesByScope('tx').where((c) => !_incomeLikeCategory(c)).toList();
    final limits = <CategoryLimit>[];
    for (final c in cats) {
      final raw = _limitCtrls[c.id]?.text ?? '';
      final v = double.tryParse(raw.replaceAll(',', '.').replaceAll(' ', '')) ?? 0;
      if (v > 0) limits.add(CategoryLimit(categoryId: c.id, limit: v));
    }
    final result = MonthlyBudget(
      monthKey: Fmt.monthKey(widget.month),
      income: _income,
      totalLimit: limits.fold<double>(0, (a, l) => a + l.limit),
      limits: limits,
      template: widget.initial?.template,
      carryOver: _carryOver,
      carriedOver: widget.initial?.carriedOver ?? 0,
    );
    Navigator.of(context).pop(result);
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final i18n = context.watch<I18n>();
    final cats = app.categoriesByScope('tx').where((c) => !_incomeLikeCategory(c)).toList();
    for (final c in cats) {
      _limitCtrls[c.id] ??= TextEditingController();
    }
    final free = _free;
    final freeColor = free < 0
        ? AppColors.danger
        : free == 0
            ? AppColors.warning
            : AppColors.income;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.initial == null ? i18n.t('create_budget') : i18n.t('edit_budget')),
        actions: [
          TextButton(
            onPressed: _income > 0 ? _save : null,
            child: Text(i18n.t('save'),
                style: TextStyle(
                    color: _income > 0 ? AppColors.primary : AppColors.textSecondary,
                    fontWeight: FontWeight.w700)),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          AppCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(i18n.t('income'),
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                const SizedBox(height: 8),
                TextField(
                  controller: _incomeCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    suffixText: app.currency,
                    hintText: '0',
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          AppCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(i18n.t('income'),
                              style: const TextStyle(
                                  color: AppColors.textSecondary, fontSize: 11)),
                          Text(Fmt.currency(_income, symbol: app.currency),
                              style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.income,
                                  fontSize: 15)),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(i18n.t('expenses'),
                              style: const TextStyle(
                                  color: AppColors.textSecondary, fontSize: 11)),
                          Text(Fmt.currency(_sumOfLimits(), symbol: app.currency),
                              style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.expense,
                                  fontSize: 15)),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(i18n.t('free_funds'),
                              style: const TextStyle(
                                  color: AppColors.textSecondary, fontSize: 11)),
                          Text(Fmt.currency(free, symbol: app.currency),
                              style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: freeColor,
                                  fontSize: 15)),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ActionChip(
                avatar: const Icon(Icons.auto_awesome, size: 16, color: AppColors.primary),
                label: Text('${i18n.t('auto_distribute')}: 50/30/20'),
                onPressed: _income > 0 ? () => _autoDistribute('50_30_20') : null,
              ),
              ActionChip(
                avatar: const Icon(Icons.equalizer, size: 16, color: AppColors.primary),
                label: Text('${i18n.t('auto_distribute')}: ${i18n.t('template_zero')}'),
                onPressed: _income > 0 ? () => _autoDistribute('zero') : null,
              ),
              ActionChip(
                avatar: const Icon(Icons.inbox, size: 16, color: AppColors.primary),
                label: Text('${i18n.t('auto_distribute')}: ${i18n.t('template_envelope')}'),
                onPressed: _income > 0 ? () => _autoDistribute('envelope') : null,
              ),
            ],
          ),
          const SizedBox(height: 16),
          SwitchListTile(
            value: _carryOver,
            onChanged: (v) => setState(() => _carryOver = v),
            title: Text(i18n.t('carry_over')),
            subtitle: Text(i18n.t('carry_over_hint'),
                style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
            activeColor: AppColors.primary,
            contentPadding: EdgeInsets.zero,
          ),
          const SizedBox(height: 12),
          Text(i18n.t('spending_limits'),
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
          const SizedBox(height: 4),
          Text(i18n.t('set_for_each'),
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
          const SizedBox(height: 8),
          for (final c in cats) _LimitField(category: c, controller: _limitCtrls[c.id]!, onChanged: () => setState(() {})),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _income > 0 ? _save : null,
            child: Text(i18n.t('save')),
          ),
        ],
      ),
    );
  }
}

class _LimitField extends StatelessWidget {
  final CategoryModel category;
  final TextEditingController controller;
  final VoidCallback onChanged;
  const _LimitField({required this.category, required this.controller, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: AppCard(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            IconBadge(
              emoji: CategoryIcons.resolve(category.iconKey),
              bg: category.color.withOpacity(0.15),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(category.name,
                  style: const TextStyle(fontWeight: FontWeight.w600)),
            ),
            SizedBox(
              width: 110,
              child: TextField(
                controller: controller,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                textAlign: TextAlign.right,
                decoration: InputDecoration(
                  isDense: true,
                  border: const OutlineInputBorder(),
                  hintText: '0',
                  suffixText: app.currency,
                ),
                onChanged: (_) => onChanged(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
