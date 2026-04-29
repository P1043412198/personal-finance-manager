import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/debt.dart';
import '../../providers/app_state.dart';
import '../../theme/app_theme.dart';
import '../../utils/format.dart';
import '../../utils/i18n.dart';
import '../../widgets/section.dart';

class DebtsScreen extends StatelessWidget {
  const DebtsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final i18n = context.watch<I18n>();
    final list = app.debtAll();
    final totalBalance = list.fold(0.0, (s, d) => s + d.balance);
    final totalMin = list.fold(0.0, (s, d) => s + d.minPayment);
    final snowball = [...list]..sort((a, b) => a.balance.compareTo(b.balance));
    final avalanche = [...list]..sort((a, b) => b.rate.compareTo(a.rate));

    return Scaffold(
      appBar: AppBar(title: Text(i18n.t('debts'))),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _edit(context, null),
        child: const Icon(Icons.add),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
        children: [
          AppCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(i18n.t('total_debt'),
                    style: const TextStyle(color: AppColors.textSecondary)),
                const SizedBox(height: 4),
                Text(Fmt.currency(totalBalance, symbol: app.currency),
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
                const SizedBox(height: 6),
                Text('${i18n.t('min_payment')}: ${Fmt.currency(totalMin, symbol: app.currency)}',
                    style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
              ],
            ),
          ),
          if (list.length >= 2) ...[
            const SizedBox(height: 16),
            SectionHeader(title: i18n.t('strategy_snowball')),
            AppCard(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  Text(i18n.t('snowball_desc'),
                      style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                  const SizedBox(height: 8),
                  for (var i = 0; i < snowball.length; i++)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: CircleAvatar(child: Text('${i + 1}')),
                      title: Text(snowball[i].name),
                      trailing: Text(Fmt.currency(snowball[i].balance, symbol: app.currency)),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            SectionHeader(title: i18n.t('strategy_avalanche')),
            AppCard(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  Text(i18n.t('avalanche_desc'),
                      style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                  const SizedBox(height: 8),
                  for (var i = 0; i < avalanche.length; i++)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: CircleAvatar(child: Text('${i + 1}')),
                      title: Text(avalanche[i].name),
                      subtitle: Text('${avalanche[i].rate.toStringAsFixed(1)}% годовых'),
                      trailing: Text(Fmt.currency(avalanche[i].balance, symbol: app.currency)),
                    ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 16),
          SectionHeader(title: i18n.t('debts')),
          if (list.isEmpty)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(i18n.t('no_data'),
                  style: const TextStyle(color: AppColors.textSecondary)),
            ),
          for (final d in list)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: AppCard(
                padding: const EdgeInsets.all(12),
                child: InkWell(
                  onTap: () => _edit(context, d),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Container(
                          width: 36, height: 36,
                          decoration: BoxDecoration(
                            color: Color(d.colorValue).withOpacity(0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(Icons.credit_card, color: Color(d.colorValue), size: 20),
                        ),
                        const SizedBox(width: 12),
                        Expanded(child: Text(d.name,
                            style: const TextStyle(fontWeight: FontWeight.w600))),
                        Text(Fmt.currency(d.balance, symbol: app.currency),
                            style: const TextStyle(
                                fontWeight: FontWeight.w700, color: AppColors.expense)),
                      ]),
                      const SizedBox(height: 8),
                      LinearProgressIndicator(
                        value: d.progress,
                        minHeight: 6,
                        backgroundColor: AppColors.muted,
                        valueColor: AlwaysStoppedAnimation(Color(d.colorValue)),
                      ),
                      const SizedBox(height: 6),
                      Row(children: [
                        Text('Выплачено ${(d.progress * 100).toStringAsFixed(0)}%',
                            style: const TextStyle(
                                color: AppColors.textSecondary, fontSize: 12)),
                        const Spacer(),
                        if (d.rate > 0)
                          Text('${d.rate.toStringAsFixed(1)}%',
                              style: const TextStyle(
                                  color: AppColors.textSecondary, fontSize: 12)),
                      ]),
                      if (d.rate > 0 && d.minPayment > 0)
                        _AmortizationHint(d: d, currency: app.currency),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _edit(BuildContext context, DebtModel? existing) async {
    final app = context.read<AppState>();
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => Padding(
        padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom, left: 16, right: 16, top: 16),
        child: _DebtForm(
          existing: existing,
          onSave: (d) async {
            await app.upsertDebt(d);
            if (context.mounted) Navigator.pop(context);
          },
          onDelete: existing == null ? null : () async {
            await app.deleteDebt(existing.id);
            if (context.mounted) Navigator.pop(context);
          },
        ),
      ),
    );
  }
}

class _AmortizationHint extends StatelessWidget {
  final DebtModel d;
  final String currency;
  const _AmortizationHint({required this.d, required this.currency});

  @override
  Widget build(BuildContext context) {
    if (d.balance <= 0 || d.minPayment <= 0) return const SizedBox.shrink();
    final r = d.rate / 100 / 12;
    int months;
    if (r == 0) {
      months = (d.balance / d.minPayment).ceil();
    } else {
      final v = d.minPayment / (d.minPayment - r * d.balance);
      if (v <= 0 || !v.isFinite) {
        return Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Text(
            'Минимальный платеж не покрывает проценты',
            style: const TextStyle(color: AppColors.danger, fontSize: 12),
          ),
        );
      }
      months = (log(v) / log(1 + r)).ceil();
    }
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Text('Закроется через ~$months мес. при текущем минимуме',
          style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
    );
  }
}

class _DebtForm extends StatefulWidget {
  final DebtModel? existing;
  final void Function(DebtModel) onSave;
  final VoidCallback? onDelete;
  const _DebtForm({this.existing, required this.onSave, this.onDelete});

  @override
  State<_DebtForm> createState() => _DebtFormState();
}

class _DebtFormState extends State<_DebtForm> {
  late TextEditingController nameC;
  late TextEditingController principalC;
  late TextEditingController balanceC;
  late TextEditingController rateC;
  late TextEditingController minC;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    nameC = TextEditingController(text: e?.name ?? '');
    principalC = TextEditingController(text: e?.principal.toStringAsFixed(0) ?? '');
    balanceC = TextEditingController(text: e?.balance.toStringAsFixed(0) ?? '');
    rateC = TextEditingController(text: e?.rate.toStringAsFixed(1) ?? '0');
    minC = TextEditingController(text: e?.minPayment.toStringAsFixed(0) ?? '0');
  }

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
          Expanded(child: TextField(
            controller: principalC,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(hintText: 'Сумма долга'),
          )),
          const SizedBox(width: 8),
          Expanded(child: TextField(
            controller: balanceC,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(hintText: 'Остаток'),
          )),
        ]),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(child: TextField(
            controller: rateC,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(hintText: 'Ставка % годовых'),
          )),
          const SizedBox(width: 8),
          Expanded(child: TextField(
            controller: minC,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(hintText: 'Мин. платёж'),
          )),
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
                final p = double.tryParse(principalC.text.replaceAll(',', '.')) ?? 0;
                final b = double.tryParse(balanceC.text.replaceAll(',', '.')) ?? p;
                final r = double.tryParse(rateC.text.replaceAll(',', '.')) ?? 0;
                final m = double.tryParse(minC.text.replaceAll(',', '.')) ?? 0;
                widget.onSave(DebtModel(
                  id: widget.existing?.id ?? app.newId(),
                  name: nameC.text.trim(),
                  principal: p,
                  balance: b,
                  rate: r,
                  minPayment: m,
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
