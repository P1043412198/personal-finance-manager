import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../models/debt.dart';
import '../../providers/app_state.dart';
import '../../theme/app_theme.dart';
import '../../utils/format.dart';
import '../../utils/i18n.dart';
import '../../widgets/section.dart';

class DebtsScreen extends StatefulWidget {
  const DebtsScreen({super.key});

  @override
  State<DebtsScreen> createState() => _DebtsScreenState();
}

class _DebtsScreenState extends State<DebtsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final i18n = context.watch<I18n>();
    final totals = app.debtTotals();
    final youOwe = app
        .debtsAll()
        .where((d) => d.direction == DebtDirection.youOwe)
        .toList();
    final owesYou = app
        .debtsAll()
        .where((d) => d.direction == DebtDirection.owesYou)
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(i18n.t('debts')),
        bottom: TabBar(
          controller: _tabs,
          tabs: [
            Tab(text: i18n.t('debt_you_owe')),
            Tab(text: i18n.t('debt_owes_you')),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _edit(context, null,
            initial: _tabs.index == 0
                ? DebtDirection.youOwe
                : DebtDirection.owesYou),
        child: const Icon(Icons.add),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
            child: Row(
              children: [
                Expanded(
                  child: AppCard(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(i18n.t('debt_you_owe'),
                            style: TextStyle(
                                color: AppColors.textSecondary, fontSize: 12)),
                        const SizedBox(height: 4),
                        Text(
                          Fmt.currency(totals[DebtDirection.youOwe] ?? 0,
                              symbol: app.currency, decimals: 2),
                          style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: AppColors.expense),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: AppCard(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(i18n.t('debt_owes_you'),
                            style: TextStyle(
                                color: AppColors.textSecondary, fontSize: 12)),
                        const SizedBox(height: 4),
                        Text(
                          Fmt.currency(totals[DebtDirection.owesYou] ?? 0,
                              symbol: app.currency, decimals: 2),
                          style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: AppColors.income),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabs,
              children: [
                _DebtList(items: youOwe, onTap: (d) => _edit(context, d)),
                _DebtList(items: owesYou, onTap: (d) => _edit(context, d)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _edit(BuildContext context, DebtModel? existing,
      {DebtDirection? initial}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: _DebtForm(
            existing: existing, initialDirection: initial ?? DebtDirection.youOwe),
      ),
    );
  }
}

class _DebtList extends StatelessWidget {
  final List<DebtModel> items;
  final ValueChanged<DebtModel> onTap;
  const _DebtList({required this.items, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final i18n = context.watch<I18n>();
    if (items.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(
            i18n.t('debts_empty'),
            style: const TextStyle(color: AppColors.textSecondary),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
      children: [
        for (final d in items)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: AppCard(
              padding: const EdgeInsets.all(12),
              onTap: () => onTap(d),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          d.counterparty,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: d.isPaid
                                ? AppColors.textSecondary
                                : AppColors.textPrimary,
                            decoration: d.isPaid
                                ? TextDecoration.lineThrough
                                : null,
                          ),
                        ),
                      ),
                      Text(
                        Fmt.currency(d.remaining, symbol: d.currency, decimals: 2),
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: d.isPaid
                              ? AppColors.textSecondary
                              : (d.direction == DebtDirection.youOwe
                                  ? AppColors.expense
                                  : AppColors.income),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(
                        '${i18n.t('paid')}: ${Fmt.currency(d.paid, symbol: d.currency, decimals: 2)} / ${Fmt.currency(d.amount, symbol: d.currency, decimals: 2)}',
                        style: TextStyle(
                            color: AppColors.textSecondary, fontSize: 12),
                      ),
                      const Spacer(),
                      if (d.dueDate != null)
                        Text(
                          DateFormat('d MMM y').format(d.dueDate!),
                          style: TextStyle(
                              color: AppColors.textSecondary, fontSize: 12),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: d.amount <= 0
                          ? 0
                          : (d.paid / d.amount).clamp(0, 1).toDouble(),
                      backgroundColor: AppColors.surface,
                      color: d.isPaid ? AppColors.income : AppColors.primary,
                      minHeight: 6,
                    ),
                  ),
                  if (!d.isPaid) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        TextButton.icon(
                          onPressed: () => _addPayment(context, d, app, i18n),
                          icon: const Icon(Icons.payment, size: 16),
                          label: Text(i18n.t('add_payment')),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
      ],
    );
  }

  Future<void> _addPayment(BuildContext context, DebtModel d, AppState app,
      I18n i18n) async {
    final amount = TextEditingController(text: d.remaining.toStringAsFixed(2));
    final note = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(i18n.t('add_payment')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: amount,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(labelText: i18n.t('amount')),
              autofocus: true,
            ),
            const SizedBox(height: 8),
            TextField(
              controller: note,
              decoration: InputDecoration(labelText: i18n.t('note')),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(i18n.t('cancel'))),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(i18n.t('save'))),
        ],
      ),
    );
    if (ok != true) return;
    final v = double.tryParse(amount.text.replaceAll(',', '.')) ?? 0;
    if (v <= 0) return;
    await app.addDebtPayment(
      d.id,
      DebtPayment(
        id: app.newId(),
        amount: v,
        date: DateTime.now(),
        note: note.text.trim().isEmpty ? null : note.text.trim(),
      ),
    );
  }
}

class _DebtForm extends StatefulWidget {
  final DebtModel? existing;
  final DebtDirection initialDirection;
  const _DebtForm({this.existing, required this.initialDirection});

  @override
  State<_DebtForm> createState() => _DebtFormState();
}

class _DebtFormState extends State<_DebtForm> {
  late TextEditingController _name;
  late TextEditingController _amount;
  late TextEditingController _note;
  late DebtDirection _direction;
  late String _currency;
  DateTime? _dueDate;

  @override
  void initState() {
    super.initState();
    final d = widget.existing;
    _name = TextEditingController(text: d?.counterparty ?? '');
    _amount = TextEditingController(
        text: d == null ? '' : d.amount.toStringAsFixed(2));
    _note = TextEditingController(text: d?.note ?? '');
    _direction = d?.direction ?? widget.initialDirection;
    _currency = d?.currency ?? '₽';
    _dueDate = d?.dueDate;
  }

  @override
  Widget build(BuildContext context) {
    final app = context.read<AppState>();
    final i18n = context.watch<I18n>();
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
              widget.existing == null
                  ? i18n.t('debt_new')
                  : i18n.t('debt_edit'),
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          ToggleButtons(
            isSelected: [
              _direction == DebtDirection.youOwe,
              _direction == DebtDirection.owesYou,
            ],
            onPressed: (i) => setState(() => _direction =
                i == 0 ? DebtDirection.youOwe : DebtDirection.owesYou),
            borderRadius: BorderRadius.circular(12),
            children: [
              Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Text(i18n.t('debt_you_owe'))),
              Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Text(i18n.t('debt_owes_you'))),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _name,
            decoration: InputDecoration(labelText: i18n.t('counterparty')),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _amount,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(labelText: i18n.t('amount')),
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: 100,
                child: TextField(
                  controller: TextEditingController(text: _currency),
                  decoration: InputDecoration(labelText: i18n.t('currency')),
                  onChanged: (v) => _currency = v,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _note,
            maxLines: 2,
            decoration: InputDecoration(labelText: i18n.t('note')),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(i18n.t('due_date_opt')),
            subtitle: Text(_dueDate == null
                ? i18n.t('no_due')
                : DateFormat('d MMM y').format(_dueDate!)),
            trailing: Wrap(
              children: [
                if (_dueDate != null)
                  IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () => setState(() => _dueDate = null),
                  ),
                IconButton(
                  icon: const Icon(Icons.edit_calendar),
                  onPressed: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _dueDate ?? DateTime.now(),
                      firstDate: DateTime(2000),
                      lastDate: DateTime(2100),
                    );
                    if (picked != null) setState(() => _dueDate = picked);
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              if (widget.existing != null)
                Expanded(
                  child: OutlinedButton(
                    onPressed: () async {
                      await app.deleteDebt(widget.existing!.id);
                      if (!mounted) return;
                      Navigator.pop(context);
                    },
                    child: Text(i18n.t('delete')),
                  ),
                ),
              if (widget.existing != null) const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: () async {
                    if (_name.text.trim().isEmpty) return;
                    final amt = double.tryParse(
                            _amount.text.replaceAll(',', '.')) ??
                        0;
                    if (amt <= 0) return;
                    final d = DebtModel(
                      id: widget.existing?.id ?? app.newId(),
                      counterparty: _name.text.trim(),
                      direction: _direction,
                      amount: amt,
                      currency: _currency,
                      createdAt:
                          widget.existing?.createdAt ?? DateTime.now(),
                      dueDate: _dueDate,
                      note: _note.text.trim().isEmpty
                          ? null
                          : _note.text.trim(),
                      payments: widget.existing?.payments,
                    );
                    await app.upsertDebt(d);
                    if (!mounted) return;
                    Navigator.pop(context);
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
