import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/category.dart';
import '../../models/transaction.dart';
import '../../providers/app_state.dart';
import '../../theme/app_theme.dart';
import '../../utils/budget_calc.dart';
import '../../utils/format.dart';
import '../../utils/i18n.dart';
import '../../widgets/section.dart';
import '../budget/budget_tab.dart';
import '../goals/goals_screen.dart';
import '../habits/habits_screen.dart';
import '../operations/operations_tab.dart';
import '../transaction/add_transaction_screen.dart';
import '../transaction/scan_receipt_screen.dart';

class HomeTab extends StatelessWidget {
  const HomeTab({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final i18n = context.watch<I18n>();
    final now = DateTime.now();
    final monthTx = app.txInMonth(now);
    final income = monthTx.where((t) => t.type == TxType.income).fold<double>(0, (a, t) => a + t.amount);
    final expense = monthTx.where((t) => t.type == TxType.expense).fold<double>(0, (a, t) => a + t.amount);
    final budget = app.budgetFor(now);
    final planned = budget?.totalLimit ?? (income > 0 ? income : (expense * 1.1));
    final remaining = planned - expense;
    final percent = planned > 0 ? (remaining / planned).clamp(0.0, 1.0) : 0.0;
    final metrics = BudgetMetrics.compute(
      month: now,
      txInMonth: monthTx,
      budget: budget,
    );

    final recent = app.txAll().take(3).toList();

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      RichText(
                        text: TextSpan(
                          style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 24,
                              fontWeight: FontWeight.w700),
                          children: [
                            TextSpan(text: i18n.t('hello')),
                            TextSpan(text: app.userName.isNotEmpty ? ', ${app.userName}!' : '!'),
                            const TextSpan(text: ' 👋'),
                          ],
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(i18n.t('lets_finance'),
                          style: const TextStyle(color: AppColors.textSecondary, fontSize: 14)),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text(i18n.t('no_data')),
                      duration: const Duration(seconds: 1),
                    ));
                  },
                  icon: const Icon(Icons.notifications_none),
                ),
              ],
            ),
            if (app.recurringAppliedCount > 0) ...[
              const SizedBox(height: 12),
              AppCard(
                padding: const EdgeInsets.fromLTRB(14, 10, 6, 10),
                color: AppColors.income.withOpacity(0.12),
                child: Row(
                  children: [
                    const Text('🔁', style: TextStyle(fontSize: 22)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        '${i18n.t('recurring_applied')}: ${app.recurringAppliedCount}',
                        style: TextStyle(
                            color: AppColors.income,
                            fontWeight: FontWeight.w600),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 18),
                      onPressed: app.clearRecurringAppliedBadge,
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 16),
            // Budget card
            AppCard(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(i18n.t('my_budget'),
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                      const Spacer(),
                      GestureDetector(
                        onTap: () {
                          Navigator.of(context).push(
                              MaterialPageRoute(builder: (_) => const BudgetTab(asPage: true)));
                        },
                        child: Row(
                          children: [
                            Text(
                              '${i18n.lang == AppLang.ru ? 'на' : 'for'} ${Fmt.monthName(now, locale: i18n.locale.languageCode).toLowerCase()}',
                              style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                            ),
                            const Icon(Icons.chevron_right, color: AppColors.textSecondary, size: 20),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(i18n.t('income'),
                                style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                            const SizedBox(height: 4),
                            Text(Fmt.currency(income, symbol: app.currency),
                                style: TextStyle(
                                    fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.income)),
                            const SizedBox(height: 12),
                            Text(i18n.t('expenses'),
                                style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                            const SizedBox(height: 4),
                            Text(Fmt.currency(expense, symbol: app.currency),
                                style: TextStyle(
                                    fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.expense)),
                          ],
                        ),
                      ),
                      SizedBox(
                        width: 140,
                        height: 140,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            PieChart(
                              PieChartData(
                                centerSpaceRadius: 50,
                                sectionsSpace: 2,
                                startDegreeOffset: -90,
                                sections: [
                                  PieChartSectionData(
                                    value: expense.clamp(0, planned).toDouble(),
                                    color: AppColors.expense.withOpacity(0.85),
                                    radius: 16,
                                    showTitle: false,
                                  ),
                                  PieChartSectionData(
                                    value: remaining.clamp(0, planned).toDouble(),
                                    color: AppColors.primary,
                                    radius: 16,
                                    showTitle: false,
                                  ),
                                ],
                              ),
                            ),
                            Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(Fmt.currency(remaining.clamp(0, double.infinity), symbol: app.currency),
                                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                                Text(i18n.t('remaining'),
                                    style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Text('${(percent * 100).round()}% ${i18n.t('on_plan')}',
                          style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600)),
                      const Spacer(),
                      Text(
                        '${i18n.t('plan')}: ${Fmt.currency(planned, symbol: app.currency)}',
                        style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                      ),
                      const SizedBox(width: 4),
                      const Icon(Icons.edit, size: 14, color: AppColors.textSecondary),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: percent,
                      minHeight: 6,
                      backgroundColor: AppColors.muted,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
            ),
            if (budget != null) ...[
              const SizedBox(height: 12),
              _FreeTodayCard(metrics: metrics),
            ],
            const SizedBox(height: 18),
            SectionHeader(title: i18n.t('quick_actions')),
            _QuickActions(),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: SectionHeader(title: i18n.t('recent')),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const OperationsTab(asPage: true)));
                  },
                  child: Text(i18n.t('see_all')),
                ),
              ],
            ),
            if (recent.isEmpty)
              AppCard(
                padding: const EdgeInsets.all(20),
                child: Center(
                    child: Text(i18n.t('no_data'),
                        style: const TextStyle(color: AppColors.textSecondary))),
              )
            else
              AppCard(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Column(
                  children: [
                    for (final t in recent)
                      _TxRow(t: t, app: app, last: t == recent.last),
                  ],
                ),
              ),
            const SizedBox(height: 18),
            // Bottom info cards
            GridView(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 1.05,
              ),
              children: [
                _InfoCard(
                  emoji: '🎓',
                  title: i18n.t('card_learn_title'),
                  subtitle: i18n.t('card_learn_subtitle'),
                  onTap: () {},
                ),
                _InfoCard(
                  emoji: '🎯',
                  title: i18n.t('card_goals_title'),
                  subtitle: i18n.t('card_goals_subtitle'),
                  onTap: () {
                    Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const GoalsScreen()));
                  },
                ),
                _InfoCard(
                  emoji: '🌱',
                  title: i18n.t('card_habits_title'),
                  subtitle: i18n.t('card_habits_subtitle'),
                  onTap: () {
                    Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const HabitsScreen()));
                  },
                ),
                _InfoCard(
                  emoji: '🛡️',
                  title: i18n.t('card_security_title'),
                  subtitle: i18n.t('card_security_subtitle'),
                  onTap: () {},
                ),
              ],
            ),
            const SizedBox(height: 20),
            AppCard(
              padding: const EdgeInsets.all(16),
              color: AppColors.muted,
              child: Row(
                children: [
                  const Text('💡', style: TextStyle(fontSize: 24)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(i18n.t('small_steps'),
                        style: const TextStyle(color: AppColors.textPrimary, fontSize: 14)),
                  ),
                  const Text('📈', style: TextStyle(fontSize: 22)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FreeTodayCard extends StatelessWidget {
  final BudgetMetrics metrics;
  const _FreeTodayCard({required this.metrics});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final i18n = context.watch<I18n>();
    final negative = metrics.freeFundsFact < 0;
    final isRu = i18n.lang == AppLang.ru;
    final dayWord = isRu
        ? daysWord(
            n: metrics.daysLeft,
            one: i18n.t('days_left_one'),
            few: i18n.t('days_left_few'),
            many: i18n.t('days_left'),
          )
        : (metrics.daysLeft == 1
            ? i18n.t('days_left_one')
            : i18n.t('days_left'));
    final accent = negative ? AppColors.danger : AppColors.income;

    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: () => Navigator.of(context)
          .push(MaterialPageRoute(builder: (_) => const BudgetTab(asPage: true))),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              accent.withOpacity(0.10),
              accent.withOpacity(0.04),
            ],
          ),
          border: Border.all(color: accent.withOpacity(0.25)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  negative ? Icons.warning_amber_rounded : Icons.savings_outlined,
                  color: accent,
                ),
                const SizedBox(width: 8),
                Text(i18n.t('free_today'),
                    style: TextStyle(
                      color: accent,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    )),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              Fmt.currency(metrics.freeFundsFact, symbol: app.currency),
              style: TextStyle(
                color: accent,
                fontSize: 28,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${i18n.t('safe_per_day')}: ${Fmt.currency(metrics.safePerDay, symbol: app.currency)}',
                    style: const TextStyle(
                        color: AppColors.textSecondary, fontSize: 12),
                  ),
                ),
                Text(
                  '${metrics.daysLeft} $dayWord',
                  style: const TextStyle(
                      color: AppColors.textSecondary, fontSize: 12),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickActions extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final i18n = context.watch<I18n>();
    final actions = [
      (Icons.shopping_cart_outlined, i18n.t('add_purchase'), () {
        Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => const AddTransactionScreen(initialType: TxType.expense)));
      }),
      (Icons.qr_code_scanner_outlined, i18n.t('scan_receipt'), () {
        Navigator.of(context)
            .push(MaterialPageRoute(builder: (_) => const ScanReceiptScreen()));
      }),
      (Icons.show_chart, i18n.t('plan_budget'), () {
        Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const BudgetTab(asPage: true)));
      }),
      (Icons.flag_outlined, i18n.t('goals'), () {
        Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const GoalsScreen()));
      }),
    ];
    return AppCard(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          for (final a in actions)
            _ActionItem(icon: a.$1, label: a.$2, onTap: a.$3),
        ],
      ),
    );
  }
}

class _ActionItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _ActionItem({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.muted,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: AppColors.primary),
            ),
            const SizedBox(height: 6),
            SizedBox(
              width: 72,
              child: Text(
                label,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 12, color: AppColors.textPrimary),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TxRow extends StatelessWidget {
  final TransactionModel t;
  final AppState app;
  final bool last;
  const _TxRow({required this.t, required this.app, required this.last});

  @override
  Widget build(BuildContext context) {
    final i18n = context.watch<I18n>();
    final cat = app.categoryById(t.categoryId);
    final emoji = cat != null ? CategoryIcons.resolve(cat.iconKey) : '📦';
    final color = cat?.color ?? AppColors.muted;
    final isExpense = t.type == TxType.expense;
    final dateStr = Fmt.isSameDay(t.date, DateTime.now())
        ? i18n.t('today')
        : Fmt.isYesterday(t.date, DateTime.now())
            ? i18n.t('yesterday')
            : Fmt.shortDate(t.date, locale: i18n.locale.languageCode);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          IconBadge(emoji: emoji, bg: color.withOpacity(0.15)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(t.shop?.isNotEmpty == true ? t.shop! : (cat?.name ?? '—'),
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                const SizedBox(height: 2),
                Text(cat?.name ?? '',
                    style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${isExpense ? '−' : '+'}${Fmt.currency(t.amount, symbol: app.currency)}',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: isExpense ? AppColors.expense : AppColors.income,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 2),
              Text(dateStr,
                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
            ],
          ),
        ],
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final String emoji;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  const _InfoCard({required this.emoji, required this.title, required this.subtitle, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 56,
            height: 56,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.muted,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(emoji, style: const TextStyle(fontSize: 30)),
          ),
          const SizedBox(height: 10),
          Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
          const SizedBox(height: 4),
          Expanded(
            child: Text(
              subtitle,
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 12, height: 1.3),
            ),
          ),
          const Align(
            alignment: Alignment.bottomRight,
            child: Icon(Icons.arrow_forward, size: 18, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}
