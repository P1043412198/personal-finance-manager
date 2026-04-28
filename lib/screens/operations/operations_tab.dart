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
  bool _searchOpen = false;
  String _query = '';
  String? _categoryId;
  PayMethod? _method;
  DateTimeRange? _dateRange;

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final i18n = context.watch<I18n>();
    final all = app.txAll();
    final list = all.where((t) {
      if (_filter == 'expense' && t.type != TxType.expense) return false;
      if (_filter == 'income' && t.type != TxType.income) return false;
      if (_categoryId != null && t.categoryId != _categoryId) return false;
      if (_method != null && t.method != _method) return false;
      if (_dateRange != null) {
        if (t.date.isBefore(_dateRange!.start) ||
            t.date.isAfter(_dateRange!.end.add(const Duration(days: 1)))) {
          return false;
        }
      }
      if (_query.isNotEmpty) {
        final q = _query.toLowerCase();
        final parts = [
          t.shop ?? '',
          t.comment ?? '',
          app.categoryById(t.categoryId)?.name ?? '',
          t.amount.toString(),
        ].join(' ').toLowerCase();
        if (!parts.contains(q)) return false;
      }
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
        title: _searchOpen
            ? TextField(
                autofocus: true,
                decoration: InputDecoration(
                  hintText: i18n.t('search'),
                  border: InputBorder.none,
                ),
                onChanged: (v) => setState(() => _query = v),
              )
            : Text(i18n.t('operations')),
        actions: [
          IconButton(
            onPressed: _showFilters,
            icon: Icon(Icons.tune,
                color: (_categoryId != null || _method != null || _dateRange != null)
                    ? AppColors.primary
                    : null),
          ),
          IconButton(
            onPressed: () => setState(() {
              _searchOpen = !_searchOpen;
              if (!_searchOpen) _query = '';
            }),
            icon: Icon(_searchOpen ? Icons.close : Icons.search),
          ),
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
            child: Row(children: [
              _Chip(label: i18n.t('all'), selected: _filter == 'all',
                  onTap: () => setState(() => _filter = 'all')),
              const SizedBox(width: 8),
              _Chip(label: i18n.t('expenses'), selected: _filter == 'expense',
                  onTap: () => setState(() => _filter = 'expense')),
              const SizedBox(width: 8),
              _Chip(label: i18n.t('income'), selected: _filter == 'income',
                  onTap: () => setState(() => _filter = 'income')),
            ]),
          ),
          if (_categoryId != null || _method != null || _dateRange != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
              child: Wrap(spacing: 6, children: [
                if (_categoryId != null)
                  Chip(
                    label: Text(app.categoryById(_categoryId)?.name ?? ''),
                    onDeleted: () => setState(() => _categoryId = null),
                  ),
                if (_method != null)
                  Chip(
                    label: Text(_method!.name),
                    onDeleted: () => setState(() => _method = null),
                  ),
                if (_dateRange != null)
                  Chip(
                    label: Text(
                        '${Fmt.date(_dateRange!.start, pattern: "d MMM")} – ${Fmt.date(_dateRange!.end, pattern: "d MMM")}'),
                    onDeleted: () => setState(() => _dateRange = null),
                  ),
              ]),
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
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textPrimary)),
                          ),
                          AppCard(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Column(children: [
                              for (final t in items)
                                Dismissible(
                                  key: ValueKey(t.id),
                                  background: Container(
                                    color: AppColors.income.withOpacity(0.15),
                                    alignment: Alignment.centerLeft,
                                    padding: const EdgeInsets.only(left: 16),
                                    child: const Icon(Icons.copy, color: AppColors.income),
                                  ),
                                  secondaryBackground: Container(
                                    color: AppColors.danger.withOpacity(0.15),
                                    alignment: Alignment.centerRight,
                                    padding: const EdgeInsets.only(right: 16),
                                    child: const Icon(Icons.delete, color: AppColors.danger),
                                  ),
                                  confirmDismiss: (dir) async {
                                    if (dir == DismissDirection.startToEnd) {
                                      final dup = TransactionModel(
                                        id: app.newId(),
                                        type: t.type,
                                        amount: t.amount,
                                        currency: t.currency,
                                        categoryId: t.categoryId,
                                        walletId: t.walletId,
                                        shop: t.shop,
                                        comment: t.comment,
                                        date: DateTime.now(),
                                        method: t.method,
                                      );
                                      await app.upsertTransaction(dup);
                                      return false;
                                    } else {
                                      return await showDialog<bool>(
                                            context: context,
                                            builder: (_) => AlertDialog(
                                              title: Text(i18n.t('confirm_reset').replaceAll('?',
                                                  ': ${i18n.t('expense').toLowerCase()}?')),
                                              actions: [
                                                TextButton(
                                                    onPressed: () => Navigator.pop(context, false),
                                                    child: Text(i18n.t('no'))),
                                                TextButton(
                                                    onPressed: () => Navigator.pop(context, true),
                                                    child: Text(i18n.t('yes'))),
                                              ],
                                            ),
                                          ) ??
                                          false;
                                    }
                                  },
                                  onDismissed: (dir) {
                                    if (dir == DismissDirection.endToStart) {
                                      app.deleteTransaction(t.id);
                                    }
                                  },
                                  child: _TxRow(
                                    t: t,
                                    onTap: () => Navigator.of(context).push(MaterialPageRoute(
                                        builder: (_) => AddTransactionScreen(existing: t))),
                                  ),
                                ),
                            ]),
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

  Future<void> _showFilters() async {
    final app = context.read<AppState>();
    final i18n = context.read<I18n>();
    final cats = app.categoriesByScope('tx');
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => StatefulBuilder(
        builder: (context, setM) => Padding(
          padding: const EdgeInsets.all(16),
          child: Wrap(
            runSpacing: 12,
            children: [
              Text(i18n.t('filter'),
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(i18n.t('category')),
                subtitle: Text(app.categoryById(_categoryId)?.name ?? '—'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () async {
                  final id = await showDialog<String?>(
                    context: context,
                    builder: (_) => SimpleDialog(
                      title: Text(i18n.t('category')),
                      children: [
                        SimpleDialogOption(
                            child: const Text('—'),
                            onPressed: () => Navigator.pop(context, null)),
                        for (final c in cats)
                          SimpleDialogOption(
                              child: Text(c.name),
                              onPressed: () => Navigator.pop(context, c.id)),
                      ],
                    ),
                  );
                  setState(() => _categoryId = id);
                  setM(() {});
                },
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(i18n.t('payment_method')),
                subtitle: Text(_method?.name ?? '—'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () async {
                  final m = await showDialog<PayMethod?>(
                    context: context,
                    builder: (_) => SimpleDialog(
                      title: Text(i18n.t('payment_method')),
                      children: [
                        SimpleDialogOption(
                            child: const Text('—'),
                            onPressed: () => Navigator.pop(context, null)),
                        for (final m in PayMethod.values)
                          SimpleDialogOption(
                              child: Text(m.name),
                              onPressed: () => Navigator.pop(context, m)),
                      ],
                    ),
                  );
                  setState(() => _method = m);
                  setM(() {});
                },
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text('${i18n.t('from')} – ${i18n.t('to')}'),
                subtitle: Text(_dateRange == null
                    ? '—'
                    : '${Fmt.date(_dateRange!.start, pattern: "d MMM")} – ${Fmt.date(_dateRange!.end, pattern: "d MMM")}'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () async {
                  final r = await showDateRangePicker(
                    context: context,
                    firstDate: DateTime(2020),
                    lastDate: DateTime.now().add(const Duration(days: 1)),
                  );
                  setState(() => _dateRange = r);
                  setM(() {});
                },
              ),
              Row(children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      setState(() {
                        _categoryId = null;
                        _method = null;
                        _dateRange = null;
                      });
                      Navigator.pop(context);
                    },
                    child: Text(i18n.t('reset')),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(i18n.t('apply')),
                  ),
                ),
              ]),
            ],
          ),
        ),
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
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? theme.colorScheme.primary : AppColors.muted,
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
            IconBadge(emoji: emoji, bg: (cat?.color ?? AppColors.muted).withOpacity(0.15)),
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
                  '${isExpense ? '−' : '+'}${Fmt.currency(t.amount, symbol: t.currency)}',
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
