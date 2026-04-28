import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/category.dart';
import '../../providers/app_state.dart';
import '../../theme/app_theme.dart';
import '../../utils/i18n.dart';
import '../../widgets/section.dart';

class CategoriesScreen extends StatelessWidget {
  const CategoriesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final i18n = context.watch<I18n>();
    final cats = app.categories.all();
    return Scaffold(
      appBar: AppBar(title: Text(i18n.t('categories'))),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _edit(context, null),
        child: const Icon(Icons.add),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
        children: [
          for (final c in cats)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: AppCard(
                padding: const EdgeInsets.all(12),
                onTap: () => _edit(context, c),
                child: Row(
                  children: [
                    IconBadge(emoji: CategoryIcons.resolve(c.iconKey), bg: c.color.withOpacity(0.15)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(c.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                          Text(c.scopes.join(' · '),
                              style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                        ],
                      ),
                    ),
                    Container(width: 12, height: 12, decoration: BoxDecoration(color: c.color, shape: BoxShape.circle)),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _edit(BuildContext context, CategoryModel? existing) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: _CategoryForm(existing: existing),
      ),
    );
  }
}

class _CategoryForm extends StatefulWidget {
  final CategoryModel? existing;
  const _CategoryForm({this.existing});

  @override
  State<_CategoryForm> createState() => _CategoryFormState();
}

class _CategoryFormState extends State<_CategoryForm> {
  late TextEditingController _name;
  late Set<String> _scopes;
  late String _icon;
  late Color _color;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.existing?.name ?? '');
    _scopes = Set.from(widget.existing?.scopes ?? {'tx'});
    _icon = widget.existing?.iconKey ?? 'other';
    _color = widget.existing != null ? Color(widget.existing!.colorValue) : AppColors.primary;
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
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
          Text(widget.existing == null ? i18n.t('add_category') : i18n.t('edit'),
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          TextField(controller: _name, decoration: InputDecoration(hintText: i18n.t('category_name'))),
          const SizedBox(height: 12),
          Text('Scope', style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            children: [
              for (final s in const ['tx', 'task', 'habit', 'note'])
                FilterChip(
                  label: Text(s),
                  selected: _scopes.contains(s),
                  onSelected: (v) => setState(() {
                    if (v) {
                      _scopes.add(s);
                    } else {
                      _scopes.remove(s);
                    }
                  }),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final entry in CategoryIcons.all.entries)
                GestureDetector(
                  onTap: () => setState(() => _icon = entry.key),
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: _icon == entry.key ? AppColors.primary.withOpacity(0.15) : AppColors.muted,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _icon == entry.key ? AppColors.primary : Colors.transparent,
                        width: 2,
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Text(entry.value, style: const TextStyle(fontSize: 22)),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            children: [
              for (final c in const [
                Color(0xFF2E7D32),
                Color(0xFF1976D2),
                Color(0xFFD32F2F),
                Color(0xFFF9A825),
                Color(0xFF8E24AA),
                Color(0xFF00897B),
                Color(0xFFEF6C00),
                Color(0xFF455A64),
                Color(0xFFD81B60),
                Color(0xFF6D4C41),
              ])
                GestureDetector(
                  onTap: () => setState(() => _color = c),
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: c,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: _color.value == c.value ? Colors.black : Colors.transparent,
                        width: 2,
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
                      await app.deleteCategory(widget.existing!.id);
                      if (!mounted) return;
                      Navigator.pop(context);
                    },
                    child: Text(i18n.t('delete')),
                  ),
                ),
              if (widget.existing != null) const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () async {
                    if (_name.text.trim().isEmpty || _scopes.isEmpty) return;
                    final c = CategoryModel(
                      id: widget.existing?.id ?? app.newId(),
                      name: _name.text.trim(),
                      colorValue: _color.value,
                      iconKey: _icon,
                      scopes: _scopes,
                    );
                    await app.upsertCategory(c);
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
