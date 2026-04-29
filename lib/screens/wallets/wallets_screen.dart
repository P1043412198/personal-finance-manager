import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/wallet.dart';
import '../../providers/app_state.dart';
import '../../theme/app_theme.dart';
import '../../utils/format.dart';
import '../../utils/i18n.dart';
import '../../widgets/section.dart';

class WalletsScreen extends StatelessWidget {
  const WalletsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final i18n = context.watch<I18n>();
    final list = app.walletAll();
    final totalByCurrency = <String, double>{};
    for (final w in list) {
      totalByCurrency[w.currency] = (totalByCurrency[w.currency] ?? 0) + w.balance;
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(i18n.t('wallets')),
        actions: [
          if (list.length >= 2)
            IconButton(
              icon: const Icon(Icons.swap_horiz),
              tooltip: 'Перевод между кошельками',
              onPressed: () => _transfer(context),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _edit(context, null),
        child: const Icon(Icons.add),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
        children: [
          if (totalByCurrency.isNotEmpty)
            AppCard(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(i18n.t('total_balance'),
                      style: const TextStyle(color: AppColors.textSecondary)),
                  const SizedBox(height: 6),
                  for (final e in totalByCurrency.entries)
                    Text(Fmt.currency(e.value, symbol: e.key),
                        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
                ],
              ),
            ),
          const SizedBox(height: 16),
          if (list.isEmpty)
            Padding(
              padding: const EdgeInsets.all(24),
              child: Text(i18n.t('no_data'),
                  style: const TextStyle(color: AppColors.textSecondary)),
            ),
          for (final w in list)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: AppCard(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                child: Column(children: [
                  ListTile(
                    leading: Container(
                      width: 44,
                      height: 44,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: Color(w.colorValue).withOpacity(0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(_iconOf(w.type), color: Color(w.colorValue)),
                    ),
                    title: Text(w.name,
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text(_typeLabel(w.type, i18n)),
                    trailing: Text(
                      Fmt.currency(w.balance, symbol: w.currency),
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: w.balance < 0 ? AppColors.expense : AppColors.income,
                      ),
                    ),
                    onTap: () => _edit(context, w),
                  ),
                  if (w.sinkingProgress != null)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: LinearProgressIndicator(
                              value: w.sinkingProgress,
                              minHeight: 6,
                              backgroundColor: AppColors.muted,
                              color: Color(w.colorValue),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Цель ${Fmt.currency(w.targetAmount!, symbol: w.currency)} '
                            '· ${(w.sinkingProgress! * 100).toStringAsFixed(0)}%',
                            style: const TextStyle(
                                fontSize: 12, color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                    ),
                ]),
              ),
            ),
        ],
      ),
    );
  }

  IconData _iconOf(WalletType t) {
    switch (t) {
      case WalletType.card:
        return Icons.credit_card;
      case WalletType.cash:
        return Icons.payments;
      case WalletType.deposit:
        return Icons.savings;
      case WalletType.credit:
        return Icons.credit_score;
      case WalletType.other:
        return Icons.account_balance_wallet;
    }
  }

  String _typeLabel(WalletType t, I18n i18n) {
    switch (t) {
      case WalletType.card:
        return i18n.t('w_card');
      case WalletType.cash:
        return i18n.t('w_cash');
      case WalletType.deposit:
        return i18n.t('w_deposit');
      case WalletType.credit:
        return i18n.t('w_credit');
      case WalletType.other:
        return i18n.t('w_other');
    }
  }

  Future<void> _transfer(BuildContext context) async {
    final app = context.read<AppState>();
    final wallets = app.walletAll();
    if (wallets.length < 2) return;
    String? fromId = wallets.first.id;
    String? toId = wallets[1].id;
    final amountC = TextEditingController();
    final commentC = TextEditingController();
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => StatefulBuilder(builder: (ctx, setS) {
        return Padding(
          padding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: 16,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 24),
          child: ListView(shrinkWrap: true, children: [
            const Text('Перевод между кошельками',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: fromId,
              decoration: const InputDecoration(labelText: 'Откуда'),
              items: [
                for (final w in wallets)
                  DropdownMenuItem(
                      value: w.id,
                      child: Text(
                          '${w.name} (${w.balance.toStringAsFixed(2)} ${w.currency})')),
              ],
              onChanged: (v) => setS(() => fromId = v),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: toId,
              decoration: const InputDecoration(labelText: 'Куда'),
              items: [
                for (final w in wallets)
                  DropdownMenuItem(
                      value: w.id,
                      child: Text(
                          '${w.name} (${w.balance.toStringAsFixed(2)} ${w.currency})')),
              ],
              onChanged: (v) => setS(() => toId = v),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: amountC,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Сумма'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: commentC,
              decoration: const InputDecoration(labelText: 'Комментарий (необязательно)'),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              icon: const Icon(Icons.check),
              label: const Text('Перевести'),
              onPressed: () async {
                final amt = double.tryParse(amountC.text.replaceAll(',', '.')) ?? 0;
                if (amt <= 0 || fromId == null || toId == null || fromId == toId) return;
                await app.transferBetweenWallets(
                  fromWalletId: fromId!,
                  toWalletId: toId!,
                  amount: amt,
                  comment: commentC.text.trim().isEmpty ? null : commentC.text.trim(),
                );
                if (ctx.mounted) Navigator.pop(ctx);
              },
            ),
          ]),
        );
      }),
    );
  }

  Future<void> _edit(BuildContext context, WalletModel? existing) async {
    final app = context.read<AppState>();
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => Padding(
        padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom, left: 16, right: 16, top: 16),
        child: _WalletForm(
          existing: existing,
          onSave: (w) async {
            await app.upsertWallet(w);
            if (context.mounted) Navigator.pop(context);
          },
          onDelete: existing == null
              ? null
              : () async {
                  await app.deleteWallet(existing.id);
                  if (context.mounted) Navigator.pop(context);
                },
        ),
      ),
    );
  }
}

class _WalletForm extends StatefulWidget {
  final WalletModel? existing;
  final void Function(WalletModel) onSave;
  final VoidCallback? onDelete;
  const _WalletForm({this.existing, required this.onSave, this.onDelete});

  @override
  State<_WalletForm> createState() => _WalletFormState();
}

class _WalletFormState extends State<_WalletForm> {
  late TextEditingController nameC;
  late TextEditingController balC;
  late WalletType type;
  late String currency;
  late int color;

  static const _colors = [
    0xFF2E7D32, 0xFF1565C0, 0xFF6A1B9A, 0xFFE65100,
    0xFFC2185B, 0xFF00796B, 0xFF6D4C41, 0xFF455A64,
  ];

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    nameC = TextEditingController(text: e?.name ?? '');
    balC = TextEditingController(text: e?.balance.toStringAsFixed(2) ?? '0');
    type = e?.type ?? WalletType.card;
    currency = e?.currency ?? 'Br';
    color = e?.colorValue ?? _colors.first;
    targetC = TextEditingController(text: e?.targetAmount?.toStringAsFixed(0) ?? '');
    targetDate = e?.targetDate;
  }

  late TextEditingController targetC;
  DateTime? targetDate;

  @override
  Widget build(BuildContext context) {
    final app = context.read<AppState>();
    return ListView(
      shrinkWrap: true,
      children: [
        const SizedBox(height: 8),
        TextField(controller: nameC, decoration: const InputDecoration(hintText: 'Название')),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(
            child: TextField(
              controller: balC,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(hintText: 'Баланс'),
            ),
          ),
          const SizedBox(width: 8),
          DropdownButton<String>(
            value: currency,
            items: app.rateAll()
                .map((r) => DropdownMenuItem(value: r.symbol, child: Text('${r.code} ${r.symbol}')))
                .toList(),
            onChanged: (v) => v == null ? null : setState(() => currency = v),
          ),
        ]),
        const SizedBox(height: 12),
        Wrap(spacing: 8, children: [
          for (final t in WalletType.values)
            ChoiceChip(
              label: Text(t.name),
              selected: type == t,
              onSelected: (_) => setState(() => type = t),
            ),
        ]),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(
            child: TextField(
              controller: targetC,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                hintText: 'Sinking fund: цель',
                helperText: 'Накопить эту сумму',
              ),
            ),
          ),
          const SizedBox(width: 8),
          OutlinedButton.icon(
            onPressed: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: targetDate ?? DateTime.now().add(const Duration(days: 90)),
                firstDate: DateTime.now(),
                lastDate: DateTime.now().add(const Duration(days: 365 * 10)),
              );
              if (picked != null) setState(() => targetDate = picked);
            },
            icon: const Icon(Icons.event),
            label: Text(targetDate == null ? 'к дате' : '${targetDate!.day}.${targetDate!.month}.${targetDate!.year}'),
            style: OutlinedButton.styleFrom(minimumSize: const Size(0, 56)),
          ),
        ]),
        const SizedBox(height: 12),
        Wrap(spacing: 8, children: [
          for (final c in _colors)
            GestureDetector(
              onTap: () => setState(() => color = c),
              child: Container(
                width: 32, height: 32,
                decoration: BoxDecoration(
                  color: Color(c),
                  shape: BoxShape.circle,
                  border: color == c ? Border.all(color: Colors.black, width: 2) : null,
                ),
              ),
            ),
        ]),
        const SizedBox(height: 16),
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
                final bal = double.tryParse(balC.text.replaceAll(',', '.')) ?? 0;
                final tgt = double.tryParse(targetC.text.replaceAll(',', '.'));
                final w = WalletModel(
                  id: widget.existing?.id ?? app.newId(),
                  name: nameC.text.trim(),
                  type: type,
                  balance: bal,
                  currency: currency,
                  colorValue: color,
                  targetAmount: tgt,
                  targetDate: targetDate,
                );
                widget.onSave(w);
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
