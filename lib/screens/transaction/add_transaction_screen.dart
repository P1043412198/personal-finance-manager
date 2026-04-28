import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/category.dart';
import '../../models/transaction.dart';
import '../../providers/app_state.dart';
import '../../theme/app_theme.dart';
import '../../utils/format.dart';
import '../../utils/i18n.dart';

class AddTransactionScreen extends StatefulWidget {
  final TxType initialType;
  final TransactionModel? existing;
  const AddTransactionScreen({super.key, this.initialType = TxType.expense, this.existing});

  @override
  State<AddTransactionScreen> createState() => _AddTransactionScreenState();
}

class _AddTransactionScreenState extends State<AddTransactionScreen> {
  late TxType _type;
  late TextEditingController _amountCtrl;
  late TextEditingController _shopCtrl;
  late TextEditingController _commentCtrl;
  String? _categoryId;
  DateTime _date = DateTime.now();
  PayMethod _method = PayMethod.card;
  bool _saveReceipt = true;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _type = e?.type ?? widget.initialType;
    _amountCtrl = TextEditingController(text: e == null ? '' : e.amount.toStringAsFixed(0));
    _shopCtrl = TextEditingController(text: e?.shop ?? '');
    _commentCtrl = TextEditingController(text: e?.comment ?? '');
    _categoryId = e?.categoryId;
    _date = e?.date ?? DateTime.now();
    _method = e?.method ?? PayMethod.card;
    _saveReceipt = e?.savedReceipt ?? true;
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _shopCtrl.dispose();
    _commentCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final amount = double.tryParse(_amountCtrl.text.replaceAll(',', '.').replaceAll(' ', ''));
    if (amount == null || amount <= 0) return;
    final app = context.read<AppState>();
    final tx = TransactionModel(
      id: widget.existing?.id ?? app.newId(),
      type: _type,
      amount: amount,
      categoryId: _categoryId,
      shop: _shopCtrl.text.trim().isEmpty ? null : _shopCtrl.text.trim(),
      comment: _commentCtrl.text.trim().isEmpty ? null : _commentCtrl.text.trim(),
      date: _date,
      method: _method,
      savedReceipt: _saveReceipt,
    );
    await app.upsertTransaction(tx);
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final i18n = context.watch<I18n>();
    final cats = app.categoriesByScope('tx');
    final selectedCat = cats.firstWhere(
      (c) => c.id == _categoryId,
      orElse: () => CategoryModel(id: '', name: i18n.t('category'), colorValue: 0, iconKey: 'other', scopes: const {}),
    );

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(i18n.t('new_purchase'), style: const TextStyle(fontSize: 18)),
        centerTitle: true,
        actions: [
          if (widget.existing != null)
            IconButton(
              onPressed: () async {
                await app.deleteTransaction(widget.existing!.id);
                if (!mounted) return;
                Navigator.of(context).pop();
              },
              icon: const Icon(Icons.delete_outline),
            ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          children: [
            _TypeToggle(type: _type, onChanged: (v) => setState(() => _type = v)),
            const SizedBox(height: 20),
            // Amount
            TextField(
              controller: _amountCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 38,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
              decoration: InputDecoration(
                hintText: '0 ${app.currency}',
                hintStyle: const TextStyle(
                    fontSize: 38, fontWeight: FontWeight.w700, color: AppColors.textSecondary),
                filled: false,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
              ),
            ),
            const SizedBox(height: 12),
            _DropdownTile(
              icon: selectedCat.id.isEmpty ? '📦' : CategoryIcons.resolve(selectedCat.iconKey),
              text: selectedCat.id.isEmpty ? i18n.t('category') : selectedCat.name,
              onTap: () async {
                final picked = await showModalBottomSheet<String>(
                  context: context,
                  showDragHandle: true,
                  builder: (_) => _CategoryPicker(scope: 'tx'),
                );
                if (picked != null) setState(() => _categoryId = picked);
              },
            ),
            const SizedBox(height: 8),
            _DropdownTile(
              icon: '📅',
              text: Fmt.isSameDay(_date, DateTime.now())
                  ? '${i18n.t('today')}, ${Fmt.date(_date, locale: i18n.locale.languageCode)}'
                  : Fmt.date(_date, locale: i18n.locale.languageCode),
              onTap: () async {
                final p = await showDatePicker(
                  context: context,
                  initialDate: _date,
                  firstDate: DateTime(2000),
                  lastDate: DateTime(2100),
                );
                if (p != null) setState(() => _date = p);
              },
            ),
            const SizedBox(height: 8),
            _DropdownTile(
              icon: _method == PayMethod.card ? '💳' : _method == PayMethod.cash ? '💵' : '🔁',
              text: _method == PayMethod.card
                  ? i18n.t('card')
                  : _method == PayMethod.cash
                      ? i18n.t('cash')
                      : i18n.t('transfer'),
              onTap: () async {
                final picked = await showModalBottomSheet<PayMethod>(
                  context: context,
                  showDragHandle: true,
                  builder: (_) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ListTile(
                          leading: const Text('💳', style: TextStyle(fontSize: 22)),
                          title: Text(i18n.t('card')),
                          onTap: () => Navigator.pop(context, PayMethod.card),
                        ),
                        ListTile(
                          leading: const Text('💵', style: TextStyle(fontSize: 22)),
                          title: Text(i18n.t('cash')),
                          onTap: () => Navigator.pop(context, PayMethod.cash),
                        ),
                        ListTile(
                          leading: const Text('🔁', style: TextStyle(fontSize: 22)),
                          title: Text(i18n.t('transfer')),
                          onTap: () => Navigator.pop(context, PayMethod.transfer),
                        ),
                      ],
                    ),
                  ),
                );
                if (picked != null) setState(() => _method = picked);
              },
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _shopCtrl,
              decoration: InputDecoration(hintText: i18n.t('shop')),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _commentCtrl,
              decoration: InputDecoration(hintText: i18n.t('comment')),
              maxLines: 2,
            ),
            const SizedBox(height: 12),
            SwitchListTile(
              value: _saveReceipt,
              onChanged: (v) => setState(() => _saveReceipt = v),
              title: Text(i18n.t('save_receipt')),
              activeColor: AppColors.primary,
              contentPadding: EdgeInsets.zero,
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () {},
              icon: const Icon(Icons.qr_code_scanner_outlined),
              label: Text(i18n.t('scan_or_upload')),
            ),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: _save, child: Text(i18n.t('save'))),
          ],
        ),
      ),
    );
  }
}

class _TypeToggle extends StatelessWidget {
  final TxType type;
  final ValueChanged<TxType> onChanged;
  const _TypeToggle({required this.type, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final i18n = context.watch<I18n>();
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.muted,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Expanded(
            child: _TogglePart(
                selected: type == TxType.expense,
                label: i18n.t('expense'),
                onTap: () => onChanged(TxType.expense)),
          ),
          Expanded(
            child: _TogglePart(
                selected: type == TxType.income,
                label: i18n.t('income_one'),
                onTap: () => onChanged(TxType.income)),
          ),
        ],
      ),
    );
  }
}

class _TogglePart extends StatelessWidget {
  final bool selected;
  final String label;
  final VoidCallback onTap;
  const _TogglePart({required this.selected, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        height: 40,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          boxShadow: selected
              ? [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 6, offset: const Offset(0, 2))]
              : [],
        ),
        child: Text(
          label,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: selected ? AppColors.primary : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}

class _DropdownTile extends StatelessWidget {
  final String icon;
  final String text;
  final VoidCallback onTap;
  const _DropdownTile({required this.icon, required this.text, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.muted,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Text(icon, style: const TextStyle(fontSize: 20)),
            const SizedBox(width: 12),
            Expanded(
                child: Text(text, style: const TextStyle(fontWeight: FontWeight.w500))),
            const Icon(Icons.expand_more, color: AppColors.textSecondary),
          ],
        ),
      ),
    );
  }
}

class _CategoryPicker extends StatelessWidget {
  final String scope;
  const _CategoryPicker({required this.scope});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final cats = app.categoriesByScope(scope);
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [
          for (final c in cats)
            InkWell(
              onTap: () => Navigator.pop(context, c.id),
              borderRadius: BorderRadius.circular(14),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: c.color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(CategoryIcons.resolve(c.iconKey), style: const TextStyle(fontSize: 18)),
                    const SizedBox(width: 6),
                    Text(c.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
