import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/category.dart';
import '../../models/rule.dart';
import '../../providers/app_state.dart';
import '../../theme/app_theme.dart';
import '../../utils/i18n.dart';
import '../../widgets/section.dart';

class RulesScreen extends StatelessWidget {
  const RulesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final i18n = context.watch<I18n>();
    final list = app.ruleAll();

    return Scaffold(
      appBar: AppBar(title: Text(i18n.t('rules'))),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _edit(context, null),
        child: const Icon(Icons.add),
      ),
      body: list.isEmpty
          ? Center(child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(i18n.t('rules_hint'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppColors.textSecondary)),
            ))
          : ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
              children: [
                for (final r in list)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: AppCard(
                      child: ListTile(
                        title: Text(r.matchShop.isNotEmpty ? 'Магазин: ${r.matchShop}' : 'Комментарий: ${r.matchComment}'),
                        subtitle: Text('→ ${app.categoryById(r.categoryId)?.name ?? '—'}'),
                        trailing: IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => app.deleteRule(r.id),
                        ),
                        onTap: () => _edit(context, r),
                      ),
                    ),
                  ),
              ],
            ),
    );
  }

  Future<void> _edit(BuildContext context, CategoryRule? existing) async {
    final app = context.read<AppState>();
    final shopC = TextEditingController(text: existing?.matchShop ?? '');
    final cmtC = TextEditingController(text: existing?.matchComment ?? '');
    String? catId = existing?.categoryId;
    final cats = app.categoriesByScope('tx');
    if (catId == null && cats.isNotEmpty) catId = cats.first.id;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => StatefulBuilder(
        builder: (context, setState) => Padding(
          padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom, left: 16, right: 16, top: 16),
          child: ListView(
            shrinkWrap: true,
            children: [
              const SizedBox(height: 8),
              TextField(controller: shopC, decoration: const InputDecoration(hintText: 'Если магазин содержит…')),
              const SizedBox(height: 8),
              TextField(controller: cmtC, decoration: const InputDecoration(hintText: 'Или комментарий содержит…')),
              const SizedBox(height: 8),
              DropdownButton<String>(
                value: catId,
                isExpanded: true,
                items: cats
                    .map((c) => DropdownMenuItem(
                          value: c.id,
                          child: Row(children: [
                            Text(CategoryIcons.resolve(c.iconKey)),
                            const SizedBox(width: 8),
                            Text(c.name),
                          ]),
                        ))
                    .toList(),
                onChanged: (v) => setState(() => catId = v),
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: () async {
                  if (catId == null) return;
                  if (shopC.text.trim().isEmpty && cmtC.text.trim().isEmpty) return;
                  await app.upsertRule(CategoryRule(
                    id: existing?.id ?? app.newId(),
                    matchShop: shopC.text.trim(),
                    matchComment: cmtC.text.trim(),
                    categoryId: catId!,
                  ));
                  if (context.mounted) Navigator.pop(context);
                },
                child: const Text('Сохранить'),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
