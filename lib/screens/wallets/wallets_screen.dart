import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/wallet.dart';
import '../../providers/app_state.dart';
import '../../theme/app_theme.dart';
import '../../utils/format.dart' as fmt;
import '../../utils/i18n.dart';
import '../../widgets/section.dart';

class WalletsScreen extends StatelessWidget {
  const WalletsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final i18n = context.watch<I18n>();
    final list = app.walletAll();
    final total = app.walletsTotalBalance();

    return Scaffold(
      appBar: AppBar(title: Text(i18n.t('wallets'))),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _edit(context, null),
        child: const Icon(Icons.add),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
            child: AppCard(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(i18n.t('total_balance'),
                            style: const TextStyle(
                                color: AppColors.textSecondary, fontSize: 13)),
                        const SizedBox(height: 4),
                        Text(
                          fmt.Fmt.currency(total, symbol: app.currency, decimals: 2),
                          style: TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w700,
                            color: total < 0
                                ? AppColors.danger
                                : AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.account_balance_wallet,
                      color: AppColors.primary, size: 36),
                ],
              ),
            ),
          ),
          Expanded(
            child: list.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Text(
                        i18n.t('wallets_empty'),
                        style: const TextStyle(color: AppColors.textSecondary),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  )
                : ReorderableListView(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
                    buildDefaultDragHandles: true,
                    onReorder: (o, n) => app.reorderWallets(o, n),
                    children: [
                      for (final w in list)
                        Padding(
                          key: ValueKey('wallet_${w.id}'),
                          padding: const EdgeInsets.only(bottom: 8),
                          child: AppCard(
                            padding: const EdgeInsets.all(12),
                            onTap: () => _edit(context, w),
                            child: Row(
                              children: [
                                Container(
                                  width: 44,
                                  height: 44,
                                  decoration: BoxDecoration(
                                    color: Color(w.colorValue).withOpacity(0.18),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  alignment: Alignment.center,
                                  child: Icon(_kindIcon(w.kind),
                                      color: Color(w.colorValue)),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(w.name,
                                          style: const TextStyle(
                                              fontWeight: FontWeight.w600,
                                              fontSize: 16)),
                                      Text(_kindLabel(w.kind, i18n),
                                          style: const TextStyle(
                                              color: AppColors.textSecondary,
                                              fontSize: 12)),
                                    ],
                                  ),
                                ),
                                Text(
                                  fmt.Fmt.currency(app.walletBalance(w.id), symbol: w.currency, decimals: 2),
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: app.walletBalance(w.id) < 0
                                        ? AppColors.danger
                                        : AppColors.textPrimary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  static IconData _kindIcon(WalletKind k) {
    switch (k) {
      case WalletKind.cash:
        return Icons.payments_outlined;
      case WalletKind.card:
        return Icons.credit_card;
      case WalletKind.account:
        return Icons.account_balance;
    }
  }

  static String _kindLabel(WalletKind k, I18n i18n) {
    switch (k) {
      case WalletKind.cash:
        return i18n.t('wallet_cash');
      case WalletKind.card:
        return i18n.t('wallet_card');
      case WalletKind.account:
        return i18n.t('wallet_account');
    }
  }

  void _edit(BuildContext context, WalletModel? existing) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: _WalletForm(existing: existing),
      ),
    );
  }
}

class _WalletForm extends StatefulWidget {
  final WalletModel? existing;
  const _WalletForm({this.existing});

  @override
  State<_WalletForm> createState() => _WalletFormState();
}

class _WalletFormState extends State<_WalletForm> {
  late TextEditingController _name;
  late TextEditingController _initial;
  late WalletKind _kind;
  late String _currency;
  late int _color;

  static const _palette = [
    0xFF2E7D32,
    0xFF1976D2,
    0xFFE53935,
    0xFFF9A825,
    0xFF8E24AA,
    0xFF00897B,
    0xFFE64A19,
    0xFF455A64,
  ];

  @override
  void initState() {
    super.initState();
    final w = widget.existing;
    _name = TextEditingController(text: w?.name ?? '');
    _initial = TextEditingController(
        text: w == null ? '0' : w.initialBalance.toStringAsFixed(2));
    _kind = w?.kind ?? WalletKind.card;
    _currency = w?.currency ?? '₽';
    _color = w?.colorValue ?? _palette.first;
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
          Text(widget.existing == null ? i18n.t('wallet_new') : i18n.t('wallet_edit'),
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          TextField(
            controller: _name,
            decoration: InputDecoration(labelText: i18n.t('name')),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _initial,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(labelText: i18n.t('initial_balance')),
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
          Wrap(
            spacing: 8,
            children: [
              for (final k in WalletKind.values)
                ChoiceChip(
                  label: Text(WalletsScreen._kindLabel(k, i18n)),
                  selected: _kind == k,
                  onSelected: (_) => setState(() => _kind = k),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final c in _palette)
                GestureDetector(
                  onTap: () => setState(() => _color = c),
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: Color(c),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: _color == c ? AppColors.textPrimary : Colors.transparent,
                        width: 3,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              if (widget.existing != null)
                Expanded(
                  child: OutlinedButton(
                    onPressed: () async {
                      await app.deleteWallet(widget.existing!.id);
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
                    final initial = double.tryParse(
                            _initial.text.replaceAll(',', '.')) ??
                        0;
                    final w = WalletModel(
                      id: widget.existing?.id ?? app.newId(),
                      name: _name.text.trim(),
                      kind: _kind,
                      currency: _currency,
                      initialBalance: initial,
                      colorValue: _color,
                      sortIndex:
                          widget.existing?.sortIndex ?? app.walletAll().length,
                      createdAt:
                          widget.existing?.createdAt ?? DateTime.now(),
                    );
                    await app.upsertWallet(w);
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
