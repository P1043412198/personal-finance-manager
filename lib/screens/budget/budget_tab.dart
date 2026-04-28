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
    final expense = tx.where((t) => t.type == TxType.expense).fold<double>(0, (a, t) => a + t.amount);
    final income = tx.where((t) => t.type == TxType.income).fold<double>(0, (a, t) => a + t.amount);
    final budget = app.budgetFor(_month);

    final byCat = <String, double>{};
    for (final t in tx.where((t) => t.type == TxType.expense)) {
      byCat.update(t.categoryId ?? 'none', (v) => v + t.amount, ifAbsent: () => t.amount);
    }
    final topCats = byCat.entries.toList()..sort((a, b) => b.value.compareTo(a.value));

    final daysInMonth = DateTime(_month.year, _month.month + 1, 0).day;
    final today = DateTime.now();
    final dayNum = (today.year == _month.year && today.month == _month.month) ? today.day : daysInMonth;
    final double perDayActual = dayNum > 0 ? expense / dayNum : 0.0;
    final double forecast = perDayActual * daysInMonth;

    return Scaffold(
      appBar: AppBar(
        leading: widget.asPage ? const BackButton() : null,
        title: Text(i18n.t('budget')),
        actions: [
          IconButton(
            onPressed: () {
              setState(() {
                _month = DateTime(_month.year, _month.month - 1);
              });
            },
            icon: const Icon(Icons.chevron_left),
          ),
          Center(
            child: Text(
              Fmt.monthName(_month, locale: i18n.locale.languageCode),
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          IconButton(
            onPressed: () {
              setState(() {
                _month = DateTime(_month.year, _month.month + 1);
              });
            },
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
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  Text(i18n.t('budget_planner'),
                      style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                  const SizedBox(height: 14),
                  ElevatedButton(
                    onPressed: () => _openPlanner(context),
                    child: Text(i18n.t('create_budget')),
                  ),
                ],
              ),
            )
          else
            _BudgetSummary(budget: budget, expense: expense, income: income, forecast: forecast),
          const SizedBox(height: 18),
          SectionHeader(title: i18n.t('top_categories')),
          AppCard(
            padding: const EdgeInsets.all(16),
            child: topCats.isEmpty
                ? Center(child: Text(i18n.t('no_data'), style: const TextStyle(color: AppColors.textSecondary)))
                : Column(
                    children: [
                      for (final e in topCats.take(6))
                        _CategoryBar(
                          categoryId: e.key,
                          spent: e.value,
                          total: expense,
                          limit: budget?.limits.firstWhere(
                            (l) => l.categoryId == e.key,
                            orElse: () => CategoryLimit(categoryId: e.key, limit: 0),
                          ).limit,
                        ),
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
                Text(Fmt.currency(forecast, symbol: app.currency),
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Text('${i18n.t('avg_per_day')}: ${Fmt.currency(perDayActual.toDouble(), symbol: app.currency)}',
                    style: const TextStyle(color: AppColors.textSecondary)),
                const SizedBox(height: 12),
                _BudgetHealthBadge(forecast: forecast, plan: budget?.totalLimit),
              ],
            ),
          ),
          const SizedBox(height: 18),
          SectionHeader(title: i18n.t('debt_advice')),
          _AdvicesCard(),
          const SizedBox(height: 18),
          SectionHeader(title: i18n.t('budget_template')),
          _Templates(month: _month, income: income),
        ],
      ),
    );
  }

  Future<void> _openPlanner(BuildContext context) async {
    final result = await showModalBottomSheet<MonthlyBudget>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: _BudgetPlanner(month: _month),
      ),
    );
    if (result != null) {
      await context.read<AppState>().upsertBudget(result);
      setState(() {});
    }
  }
}

class _BudgetSummary extends StatelessWidget {
  final MonthlyBudget budget;
  final double expense;
  final double income;
  final double forecast;
  const _BudgetSummary(
      {required this.budget, required this.expense, required this.income, required this.forecast});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final i18n = context.watch<I18n>();
    final left = budget.totalLimit - expense;
    final pct = budget.totalLimit == 0 ? 0.0 : (expense / budget.totalLimit).clamp(0.0, 1.0);
    return AppCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(i18n.t('budget_summary'),
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(child: _StatBlock(label: i18n.t('planned'), value: Fmt.currency(budget.totalLimit, symbol: app.currency), color: AppColors.primary)),
              Expanded(child: _StatBlock(label: i18n.t('spent'), value: Fmt.currency(expense, symbol: app.currency), color: AppColors.expense)),
              Expanded(child: _StatBlock(label: i18n.t('left'), value: Fmt.currency(left.clamp(0, double.infinity), symbol: app.currency), color: AppColors.income)),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: pct,
              minHeight: 8,
              backgroundColor: AppColors.muted,
              color: pct > 0.95 ? AppColors.danger : pct > 0.75 ? AppColors.warning : AppColors.primary,
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

class _StatBlock extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _StatBlock({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
        const SizedBox(height: 4),
        Text(value, style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 14)),
      ],
    );
  }
}

class _CategoryBar extends StatelessWidget {
  final String categoryId;
  final double spent;
  final double total;
  final double? limit;
  const _CategoryBar({required this.categoryId, required this.spent, required this.total, this.limit});

  @override
  Widget build(BuildContext context) {
    final app = context.read<AppState>();
    final cat = app.categoryById(categoryId);
    final emoji = cat != null ? CategoryIcons.resolve(cat.iconKey) : '📦';
    final percent = limit != null && limit! > 0 ? (spent / limit!).clamp(0.0, 1.0) : (total > 0 ? (spent / total) : 0.0);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
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
                    Text(Fmt.currency(spent, symbol: app.currency),
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: percent,
                    minHeight: 6,
                    backgroundColor: AppColors.muted,
                    color: cat?.color ?? AppColors.primary,
                  ),
                ),
                if (limit != null && limit! > 0)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      'лимит ${Fmt.currency(limit!, symbol: app.currency)}',
                      style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
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
      decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(10)),
      child: Text('${i18n.t('budget_health')}: $label',
          style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 13)),
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
  const _Templates({required this.month, required this.income});

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
                    if (income <= 0) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(i18n.t('no_data'))),
                      );
                      return;
                    }
                    final budget = MonthlyBudget(
                      monthKey: Fmt.monthKey(month),
                      income: income,
                      totalLimit: t.$1 == '50_30_20'
                          ? income * 0.8
                          : t.$1 == 'zero'
                              ? income
                              : income * 0.9,
                      template: t.$1,
                    );
                    await app.upsertBudget(budget);
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

class _BudgetPlanner extends StatefulWidget {
  final DateTime month;
  const _BudgetPlanner({required this.month});

  @override
  State<_BudgetPlanner> createState() => _BudgetPlannerState();
}

class _BudgetPlannerState extends State<_BudgetPlanner> {
  final _incomeCtrl = TextEditingController();
  final _limitCtrl = TextEditingController();

  @override
  void dispose() {
    _incomeCtrl.dispose();
    _limitCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final i18n = context.watch<I18n>();
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(i18n.t('create_budget'),
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 16),
          TextField(
            controller: _incomeCtrl,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(hintText: i18n.t('income')),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _limitCtrl,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(hintText: i18n.t('planned')),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () {
              final income = double.tryParse(_incomeCtrl.text.replaceAll(',', '.')) ?? 0;
              final limit = double.tryParse(_limitCtrl.text.replaceAll(',', '.')) ?? income * 0.9;
              Navigator.of(context).pop(MonthlyBudget(
                monthKey: Fmt.monthKey(widget.month),
                income: income,
                totalLimit: limit,
              ));
            },
            child: Text(i18n.t('save')),
          ),
        ],
      ),
    );
  }
}
