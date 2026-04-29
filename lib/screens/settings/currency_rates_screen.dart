import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/currency_rate.dart';
import '../../providers/app_state.dart';
import '../../services/nbrb_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/i18n.dart';
import '../../widgets/section.dart';

class CurrencyRatesScreen extends StatefulWidget {
  const CurrencyRatesScreen({super.key});

  @override
  State<CurrencyRatesScreen> createState() => _CurrencyRatesScreenState();
}

class _CurrencyRatesScreenState extends State<CurrencyRatesScreen> {
  bool _refreshing = false;
  String? _msg;

  Future<void> _refreshFromNbrb() async {
    final app = context.read<AppState>();
    setState(() {
      _refreshing = true;
      _msg = null;
    });
    final rates = await NbrbService.instance.fetchRates();
    if (!mounted) return;
    if (rates == null) {
      setState(() {
        _refreshing = false;
        _msg = 'Не удалось получить курсы НБ РБ. Проверь интернет.';
      });
      return;
    }
    final existing = {for (final r in app.rateAll()) r.code: r};
    final symbols = <String, String>{
      'USD': '\$',
      'EUR': '€',
      'RUB': '₽',
      'PLN': 'zł',
      'UAH': '₴',
      'CNY': '¥',
      'GBP': '£',
      'CHF': '₣',
      'JPY': '¥',
      'BYN': 'Br',
    };
    var updated = 0;
    for (final entry in rates.entries) {
      final code = entry.key;
      final symbol = existing[code]?.symbol ?? symbols[code] ?? code;
      await app.upsertRate(CurrencyRate(code: code, symbol: symbol, toBase: entry.value));
      updated++;
    }
    setState(() {
      _refreshing = false;
      _msg = 'Обновлено ${updated} курсов от НБ РБ ${DateTime.now().toString().substring(0, 16)}';
    });
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final i18n = context.watch<I18n>();
    final list = app.rateAll();

    return Scaffold(
      appBar: AppBar(title: Text(i18n.t('currency_rates'))),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _edit(context, null),
        child: const Icon(Icons.add),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(i18n.t('currency_rates_hint'),
                style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
          ),
          AppCard(
            color: AppColors.primary.withOpacity(0.08),
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Курсы Национального Банка РБ',
                    style: TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                const Text('Загрузить официальные курсы с api.nbrb.by',
                    style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                const SizedBox(height: 10),
                Row(children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _refreshing ? null : _refreshFromNbrb,
                      icon: _refreshing
                          ? const SizedBox(
                              width: 16, height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.cloud_download_outlined),
                      label: Text(_refreshing ? 'Загрузка...' : 'Обновить курсы НБ РБ'),
                    ),
                  ),
                ]),
                if (_msg != null) ...[
                  const SizedBox(height: 8),
                  Text(_msg!, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),
          for (final r in list)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: AppCard(
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: AppColors.muted,
                    child: Text(r.symbol),
                  ),
                  title: Text(r.code, style: const TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text('1 ${r.code} = ${r.toBase.toStringAsFixed(2)} ${app.currency}'),
                  onTap: () => _edit(context, r),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _edit(BuildContext context, CurrencyRate? existing) async {
    final app = context.read<AppState>();
    final codeC = TextEditingController(text: existing?.code ?? '');
    final symC = TextEditingController(text: existing?.symbol ?? '');
    final rateC = TextEditingController(text: existing?.toBase.toStringAsFixed(4) ?? '');
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => Padding(
        padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom, left: 16, right: 16, top: 16),
        child: ListView(shrinkWrap: true, children: [
          const SizedBox(height: 8),
          TextField(controller: codeC, decoration: const InputDecoration(hintText: 'Код (USD)')),
          const SizedBox(height: 8),
          TextField(controller: symC, decoration: const InputDecoration(hintText: 'Символ (\$)')),
          const SizedBox(height: 8),
          TextField(
            controller: rateC,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(hintText: '1 единица = ? ${app.currency}'),
          ),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: () async {
              if (codeC.text.trim().isEmpty || symC.text.trim().isEmpty) return;
              final r = double.tryParse(rateC.text.replaceAll(',', '.')) ?? 1;
              await app.upsertRate(CurrencyRate(
                code: codeC.text.trim().toUpperCase(),
                symbol: symC.text.trim(),
                toBase: r,
              ));
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('Сохранить'),
          ),
          const SizedBox(height: 24),
        ]),
      ),
    );
  }
}
