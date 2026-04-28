import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/category.dart';
import '../../models/template.dart';
import '../../models/transaction.dart';
import '../../providers/app_state.dart';
import '../../theme/app_theme.dart';
import '../../utils/format.dart';
import '../../utils/i18n.dart';
import '../../widgets/section.dart';

class TemplatesScreen extends StatelessWidget {
  const TemplatesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final i18n = context.watch<I18n>();
    final list = app.templateAll();

    return Scaffold(
      appBar: AppBar(title: Text(i18n.t('templates'))),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _edit(context, null),
        child: const Icon(Icons.add),
      ),
      body: list.isEmpty
          ? Center(child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(i18n.t('templates_hint'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppColors.textSecondary)),
            ))
          : ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
              children: [
                for (final t in list)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: AppCard(
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: AppColors.muted,
                          child: Text(CategoryIcons.resolve(t.iconKey)),
                        ),
                        title: Text(t.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                        subtitle: Text(app.categoryById(t.categoryId)?.name ?? '—'),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '${t.type == TxType.income ? '+' : '−'}${Fmt.currency(t.amount, symbol: app.currency)}',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                color: t.type == TxType.income ? AppColors.income : AppColors.expense,
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.flash_on, color: AppColors.primary),
                              onPressed: () async {
                                final tx = TransactionModel(
                                  id: app.newId(),
                                  type: t.type,
                                  amount: t.amount,
                                  currency: app.currency,
                                  categoryId: t.categoryId,
                                  walletId: t.walletId,
                                  shop: t.shop,
                                  date: DateTime.now(),
                                  method: t.method,
                                );
                                await app.upsertTransaction(tx);
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('Добавлено: ${t.name}')),
                                  );
                                }
                              },
                            ),
                          ],
                        ),
                        onTap: () => _edit(context, t),
                      ),
                    ),
                  ),
              ],
            ),
    );
  }

  Future<void> _edit(BuildContext context, TxTemplate? existing) async {
    final app = context.read<AppState>();
    final nameC = TextEditingController(text: existing?.name ?? '');
    final amountC = TextEditingController(text: existing?.amount.toStringAsFixed(2) ?? '');
    final shopC = TextEditingController(text: existing?.shop ?? '');
    String? catId = existing?.categoryId;
    final cats = app.categoriesByScope('tx');

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => StatefulBuilder(
        builder: (context, setState) => Padding(
          padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom, left: 16, right: 16, top: 16),
          child: ListView(shrinkWrap: true, children: [
            const SizedBox(height: 8),
            TextField(controller: nameC, decoration: const InputDecoration(hintText: 'Название')),
            const SizedBox(height: 8),
            TextField(
              controller: amountC,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(hintText: 'Сумма'),
            ),
            const SizedBox(height: 8),
            TextField(controller: shopC, decoration: const InputDecoration(hintText: 'Магазин')),
            const SizedBox(height: 8),
            DropdownButton<String?>(
              value: catId,
              isExpanded: true,
              hint: const Text('Категория'),
              items: [
                const DropdownMenuItem(value: null, child: Text('—')),
                ...cats.map((c) => DropdownMenuItem(value: c.id, child: Text(c.name))),
              ],
              onChanged: (v) => setState(() => catId = v),
            ),
            const SizedBox(height: 12),
            Row(children: [
              if (existing != null)
                Expanded(
                  child: OutlinedButton(
                    onPressed: () async {
                      await app.deleteTemplate(existing.id);
                      if (context.mounted) Navigator.pop(context);
                    },
                    style: OutlinedButton.styleFrom(foregroundColor: AppColors.danger),
                    child: const Text('Удалить'),
                  ),
                ),
              if (existing != null) const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton(
                  onPressed: () async {
                    if (nameC.text.trim().isEmpty) return;
                    final amt = double.tryParse(amountC.text.replaceAll(',', '.')) ?? 0;
                    if (amt <= 0) return;
                    await app.upsertTemplate(TxTemplate(
                      id: existing?.id ?? app.newId(),
                      name: nameC.text.trim(),
                      amount: amt,
                      categoryId: catId,
                      shop: shopC.text.trim().isEmpty ? null : shopC.text.trim(),
                      iconKey: app.categoryById(catId)?.iconKey ?? 'shopping_cart',
                    ));
                    if (context.mounted) Navigator.pop(context);
                  },
                  child: const Text('Сохранить'),
                ),
              ),
            ]),
            const SizedBox(height: 24),
          ]),
        ),
      ),
    );
  }
}
