import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/currency_rate.dart';
import '../../providers/app_state.dart';
import '../../theme/app_theme.dart';
import '../../utils/i18n.dart';
import '../../widgets/section.dart';

class CurrencyRatesScreen extends StatelessWidget {
  const CurrencyRatesScreen({super.key});

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
