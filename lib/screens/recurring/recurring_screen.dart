import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../models/recurring.dart';
import '../../models/transaction.dart';
import '../../providers/app_state.dart';
import '../../theme/app_theme.dart';
import '../../utils/format.dart';
import '../../utils/i18n.dart';
import '../../widgets/section.dart';

class RecurringScreen extends StatelessWidget {
  const RecurringScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final i18n = context.watch<I18n>();
    final list = app.recurringAll();

    return Scaffold(
      appBar: AppBar(title: Text(i18n.t('recurring'))),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _edit(context, null),
        child: const Icon(Icons.add),
      ),
      body: list.isEmpty
          ? Center(child: Text(i18n.t('no_data'),
              style: const TextStyle(color: AppColors.textSecondary)))
          : ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
              children: [
                for (final r in list)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: AppCard(
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: r.type == TxType.income
                              ? AppColors.income.withOpacity(0.15)
                              : AppColors.expense.withOpacity(0.15),
                          child: Icon(r.type == TxType.income
                              ? Icons.arrow_downward
                              : Icons.arrow_upward,
                              color: r.type == TxType.income ? AppColors.income : AppColors.expense),
                        ),
                        title: Text(r.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                        subtitle: Text(
                            '${_cadenceLabel(r.cadence)} · ${i18n.t('next')}: ${DateFormat('d MMM').format(r.nextRun)}'),
                        trailing: Text(
                          '${r.type == TxType.income ? '+' : '−'}${Fmt.currency(r.amount, symbol: app.currency)}',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: r.type == TxType.income ? AppColors.income : AppColors.expense,
                          ),
                        ),
                        onTap: () => _edit(context, r),
                      ),
                    ),
                  ),
              ],
            ),
    );
  }

  String _cadenceLabel(Cadence c) {
    switch (c) {
      case Cadence.daily:
        return 'Ежедневно';
      case Cadence.weekly:
        return 'Еженедельно';
      case Cadence.monthly:
        return 'Ежемесячно';
      case Cadence.yearly:
        return 'Ежегодно';
    }
  }

  Future<void> _edit(BuildContext context, RecurringTxModel? existing) async {
    final app = context.read<AppState>();
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => Padding(
        padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom, left: 16, right: 16, top: 16),
        child: _RecForm(
          existing: existing,
          onSave: (r) async {
            await app.upsertRecurring(r);
            if (context.mounted) Navigator.pop(context);
          },
          onDelete: existing == null ? null : () async {
            await app.deleteRecurring(existing.id);
            if (context.mounted) Navigator.pop(context);
          },
        ),
      ),
    );
  }
}

class _RecForm extends StatefulWidget {
  final RecurringTxModel? existing;
  final void Function(RecurringTxModel) onSave;
  final VoidCallback? onDelete;
  const _RecForm({this.existing, required this.onSave, this.onDelete});

  @override
  State<_RecForm> createState() => _RecFormState();
}

class _RecFormState extends State<_RecForm> {
  late TextEditingController nameC;
  late TextEditingController amountC;
  late TextEditingController commentC;
  late TxType type;
  late Cadence cadence;
  late DateTime startDate;
  late DateTime nextRun;
  String? categoryId;
  String? walletId;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    nameC = TextEditingController(text: e?.name ?? '');
    amountC = TextEditingController(text: e?.amount.toStringAsFixed(2) ?? '');
    commentC = TextEditingController(text: e?.comment ?? '');
    type = e?.type ?? TxType.expense;
    cadence = e?.cadence ?? Cadence.monthly;
    startDate = e?.startDate ?? DateTime.now();
    nextRun = e?.nextRun ?? DateTime.now();
    categoryId = e?.categoryId;
    walletId = e?.walletId;
  }

  @override
  Widget build(BuildContext context) {
    final app = context.read<AppState>();
    final i18n = context.watch<I18n>();
    final cats = app.categoriesByScope('tx');
    final wallets = app.walletAll();
    return ListView(
      shrinkWrap: true,
      children: [
        const SizedBox(height: 8),
        TextField(controller: nameC, decoration: const InputDecoration(hintText: 'Название')),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(
            child: ChoiceChip(
              label: Text(i18n.t('expense')),
              selected: type == TxType.expense,
              onSelected: (_) => setState(() => type = TxType.expense),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: ChoiceChip(
              label: Text(i18n.t('income')),
              selected: type == TxType.income,
              onSelected: (_) => setState(() => type = TxType.income),
            ),
          ),
        ]),
        const SizedBox(height: 8),
        TextField(
          controller: amountC,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(hintText: 'Сумма'),
        ),
        const SizedBox(height: 8),
        TextField(controller: commentC, decoration: const InputDecoration(hintText: 'Комментарий')),
        const SizedBox(height: 12),
        DropdownButton<Cadence>(
          value: cadence,
          isExpanded: true,
          items: Cadence.values
              .map((c) => DropdownMenuItem(value: c, child: Text(c.name)))
              .toList(),
          onChanged: (v) => v == null ? null : setState(() => cadence = v),
        ),
        if (cats.isNotEmpty) ...[
          const SizedBox(height: 8),
          DropdownButton<String?>(
            value: categoryId,
            isExpanded: true,
            hint: Text(i18n.t('category')),
            items: [
              const DropdownMenuItem(value: null, child: Text('—')),
              ...cats.map((c) => DropdownMenuItem(value: c.id, child: Text(c.name))),
            ],
            onChanged: (v) => setState(() => categoryId = v),
          ),
        ],
        if (wallets.isNotEmpty) ...[
          const SizedBox(height: 8),
          DropdownButton<String?>(
            value: walletId,
            isExpanded: true,
            hint: Text(i18n.t('wallet')),
            items: [
              const DropdownMenuItem(value: null, child: Text('—')),
              ...wallets.map((w) => DropdownMenuItem(value: w.id, child: Text(w.name))),
            ],
            onChanged: (v) => setState(() => walletId = v),
          ),
        ],
        const SizedBox(height: 8),
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: Text('Старт: ${DateFormat('d MMM yyyy').format(startDate)}'),
          trailing: const Icon(Icons.calendar_today),
          onTap: () async {
            final d = await showDatePicker(
              context: context,
              initialDate: startDate,
              firstDate: DateTime.now().subtract(const Duration(days: 365)),
              lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
            );
            if (d != null) {
              setState(() {
                startDate = d;
                nextRun = d;
              });
            }
          },
        ),
        const SizedBox(height: 12),
        Row(children: [
          if (widget.onDelete != null)
            Expanded(
              child: OutlinedButton(
                onPressed: widget.onDelete,
                style: OutlinedButton.styleFrom(foregroundColor: AppColors.danger),
                child: const Text('Удалить'),
              ),
            ),
          if (widget.onDelete != null) const SizedBox(width: 8),
          Expanded(
            child: ElevatedButton(
              onPressed: () {
                if (nameC.text.trim().isEmpty) return;
                final amt = double.tryParse(amountC.text.replaceAll(',', '.')) ?? 0;
                if (amt <= 0) return;
                widget.onSave(RecurringTxModel(
                  id: widget.existing?.id ?? context.read<AppState>().newId(),
                  name: nameC.text.trim(),
                  type: type,
                  amount: amt,
                  categoryId: categoryId,
                  walletId: walletId,
                  comment: commentC.text.trim(),
                  cadence: cadence,
                  startDate: startDate,
                  nextRun: nextRun,
                ));
              },
              child: const Text('Сохранить'),
            ),
          ),
        ]),
        const SizedBox(height: 24),
      ],
    );
  }
}
