import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/category.dart';
import '../../models/transaction.dart';
import '../../providers/app_state.dart';
import '../../theme/app_theme.dart';
import '../../utils/format.dart';
import '../../utils/i18n.dart';
import '../../widgets/section.dart';
import '../transaction/add_transaction_screen.dart';

class OperationsTab extends StatefulWidget {
  final bool asPage;
  const OperationsTab({super.key, this.asPage = false});

  @override
  State<OperationsTab> createState() => _OperationsTabState();
}

class _OperationsTabState extends State<OperationsTab> {
  String _filter = 'all';

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final i18n = context.watch<I18n>();
    final all = app.txAll();
    final list = all.where((t) {
      if (_filter == 'expense') return t.type == TxType.expense;
      if (_filter == 'income') return t.type == TxType.income;
      return true;
    }).toList();

    final byDay = <String, List<TransactionModel>>{};
    for (final t in list) {
      final k = Fmt.dayKey(t.date);
      byDay.putIfAbsent(k, () => []).add(t);
    }
    final dayKeys = byDay.keys.toList()..sort((a, b) => b.compareTo(a));

    return Scaffold(
      appBar: AppBar(
        leading: widget.asPage ? const BackButton() : null,
        title: Text(i18n.t('operations')),
        actions: [
          IconButton(onPressed: () {}, icon: const Icon(Icons.tune)),
          IconButton(onPressed: () {}, icon: const Icon(Icons.search)),
          const SizedBox(width: 4),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => const AddTransactionScreen(initialType: TxType.expense)));
        },
        child: const Icon(Icons.add),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                _Chip(
                    label: i18n.t('all'),
                    selected: _filter == 'all',
                    onTap: () => setState(() => _filter = 'all')),
                const SizedBox(width: 8),
                _Chip(
                    label: i18n.t('expenses'),
                    selected: _filter == 'expense',
                    onTap: () => setState(() => _filter = 'expense')),
                const SizedBox(width: 8),
                _Chip(
                    label: i18n.t('income'),
                    selected: _filter == 'income',
                    onTap: () => setState(() => _filter = 'income')),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: list.isEmpty
                ? Center(
                    child: Text(i18n.t('no_data'),
                        style: const TextStyle(color: AppColors.textSecondary)))
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
                    itemCount: dayKeys.length,
                    itemBuilder: (context, i) {
                      final k = dayKeys[i];
                      final items = byDay[k]!;
                      final date = items.first.date;
                      final label = Fmt.isSameDay(date, DateTime.now())
                          ? i18n.t('today')
                          : Fmt.isYesterday(date, DateTime.now())
                              ? i18n.t('yesterday')
                              : Fmt.date(date, pattern: 'd MMMM', locale: i18n.locale.languageCode);
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(4, 12, 4, 8),
                            child: Text(label,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                          ),
                          AppCard(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Column(
                              children: [
                                for (final t in items)
                                  _TxRow(
                                    t: t,
                                    onTap: () => Navigator.of(context).push(MaterialPageRoute(
                                        builder: (_) => AddTransactionScreen(existing: t))),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _Chip({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : AppColors.muted,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(label,
            style: TextStyle(
              color: selected ? Colors.white : AppColors.textPrimary,
              fontWeight: FontWeight.w600,
              fontSize: 13,
            )),
      ),
    );
  }
}

class _TxRow extends StatelessWidget {
  final TransactionModel t;
  final VoidCallback? onTap;
  const _TxRow({required this.t, this.onTap});

  @override
  Widget build(BuildContext context) {
    final app = context.read<AppState>();
    final cat = app.categoryById(t.categoryId);
    final emoji = cat != null ? CategoryIcons.resolve(cat.iconKey) : '📦';
    final isExpense = t.type == TxType.expense;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            IconBadge(
              emoji: emoji,
              bg: (cat?.color ?? AppColors.muted).withOpacity(0.15),
              heroTag: 'tx_icon_${t.id}',
            ),
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
                Text(Fmt.time(t.date),
                    style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
