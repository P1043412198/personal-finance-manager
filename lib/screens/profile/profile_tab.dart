import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../providers/app_state.dart';
import '../../theme/app_theme.dart';
import '../../utils/i18n.dart';
import '../../widgets/section.dart';
import '../analytics/analytics_screen.dart';
import '../categories/categories_screen.dart';
import '../goals/goals_screen.dart';
import '../habits/habits_screen.dart';
import '../notes/notes_screen.dart';
import '../tasks/tasks_screen.dart';

class ProfileTab extends StatelessWidget {
  const ProfileTab({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final i18n = context.watch<I18n>();

    return Scaffold(
      appBar: AppBar(title: Text(i18n.t('profile'))),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
        children: [
          AppCard(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: AppColors.muted,
                  child: Text(
                    app.userName.isEmpty ? '🙂' : app.userName.characters.first.toUpperCase(),
                    style: const TextStyle(fontSize: 22),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        app.userName.isEmpty ? i18n.t('guest') : app.userName,
                        style:
                            const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 2),
                      Text(
                          '${app.txAll().length} ${i18n.t('transactions').toLowerCase()}',
                          style: const TextStyle(
                              color: AppColors.textSecondary, fontSize: 12)),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => _editName(context, app, i18n),
                  icon: const Icon(Icons.edit, color: AppColors.primary),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          SectionHeader(title: i18n.t('analytics')),
          AppCard(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(
              children: [
                _Tile(
                  icon: '📊',
                  title: i18n.t('analytics'),
                  onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const AnalyticsScreen())),
                ),
                _Tile(
                  icon: '🎯',
                  title: i18n.t('goals'),
                  onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const GoalsScreen())),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          SectionHeader(title: i18n.t('app_title')),
          AppCard(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(
              children: [
                _Tile(
                    icon: '✅',
                    title: i18n.t('tasks'),
                    onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const TasksScreen()))),
                _Tile(
                    icon: '🌱',
                    title: i18n.t('habits'),
                    onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const HabitsScreen()))),
                _Tile(
                    icon: '📝',
                    title: i18n.t('notes'),
                    onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const NotesScreen()))),
                _Tile(
                    icon: '🏷️',
                    title: i18n.t('categories'),
                    onTap: () => Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => const CategoriesScreen()))),
              ],
            ),
          ),
          const SizedBox(height: 16),
          SectionHeader(title: i18n.t('language')),
          AppCard(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(
              children: [
                RadioListTile<AppLang>(
                  value: AppLang.ru,
                  groupValue: i18n.lang,
                  onChanged: (v) => v == null ? null : i18n.setLang(v),
                  title: const Text('Русский'),
                  activeColor: AppColors.primary,
                  contentPadding: EdgeInsets.zero,
                ),
                RadioListTile<AppLang>(
                  value: AppLang.en,
                  groupValue: i18n.lang,
                  onChanged: (v) => v == null ? null : i18n.setLang(v),
                  title: const Text('English'),
                  activeColor: AppColors.primary,
                  contentPadding: EdgeInsets.zero,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          SectionHeader(title: i18n.t('theme')),
          AppCard(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(
              children: [
                for (final m in ThemeMode.values)
                  RadioListTile<ThemeMode>(
                    value: m,
                    groupValue: app.themeMode,
                    onChanged: (v) => v == null ? null : app.setThemeMode(v),
                    title: Text(m == ThemeMode.system
                        ? i18n.t('theme_system')
                        : m == ThemeMode.light
                            ? i18n.t('theme_light')
                            : i18n.t('theme_dark')),
                    activeColor: AppColors.primary,
                    contentPadding: EdgeInsets.zero,
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          SectionHeader(title: i18n.t('data')),
          AppCard(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(
              children: [
                _Tile(
                  icon: '📤',
                  title: i18n.t('export_json'),
                  onTap: () => _exportJson(context, app),
                ),
                _Tile(
                  icon: '📑',
                  title: i18n.t('export_csv'),
                  onTap: () => _exportCsv(context, app),
                ),
                _Tile(
                  icon: '🗑️',
                  title: i18n.t('reset_data'),
                  onTap: () async {
                    final ok = await showDialog<bool>(
                      context: context,
                      builder: (_) => AlertDialog(
                        title: Text(i18n.t('confirm_reset')),
                        actions: [
                          TextButton(
                              onPressed: () => Navigator.pop(context, false),
                              child: Text(i18n.t('no'))),
                          TextButton(
                              onPressed: () => Navigator.pop(context, true),
                              child: Text(i18n.t('yes'))),
                        ],
                      ),
                    );
                    if (ok == true) {
                      await app.resetAll();
                    }
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Center(
            child: Text(
              '${i18n.t('version')} 1.0.0',
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _editName(BuildContext context, AppState app, I18n i18n) async {
    final ctrl = TextEditingController(text: app.userName);
    final result = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(i18n.t('name')),
        content: TextField(controller: ctrl, autofocus: true),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(i18n.t('cancel'))),
          TextButton(
              onPressed: () => Navigator.pop(context, ctrl.text.trim()),
              child: Text(i18n.t('save'))),
        ],
      ),
    );
    if (result != null) await app.setUserName(result);
  }

  Future<void> _exportJson(BuildContext context, AppState app) async {
    final data = {
      'categories': app.categories.all().map((c) => c.toJson()).toList(),
      'transactions': app.txAll().map((t) => t.toJson()).toList(),
      'tasks': app.taskAll().map((t) => t.toJson()).toList(),
      'habits': app.habitAll().map((h) => h.toJson()).toList(),
      'notes': app.noteAll().map((n) => n.toJson()).toList(),
      'goals': app.goalAll().map((g) => g.toJson()).toList(),
    };
    final dir = await getTemporaryDirectory();
    final f = File('${dir.path}/personal_finance_export_${DateTime.now().millisecondsSinceEpoch}.json');
    await f.writeAsString(jsonEncode(data));
    await Share.shareXFiles([XFile(f.path)], text: 'Personal finance export');
  }

  Future<void> _exportCsv(BuildContext context, AppState app) async {
    final lines = <String>['date,type,amount,category,shop,comment,method'];
    for (final t in app.txAll()) {
      final cat = app.categoryById(t.categoryId)?.name ?? '';
      lines.add(
          '${t.date.toIso8601String()},${t.type.name},${t.amount},"${cat}","${(t.shop ?? '').replaceAll('"', '""')}","${(t.comment ?? '').replaceAll('"', '""')}",${t.method.name}');
    }
    final dir = await getTemporaryDirectory();
    final f = File('${dir.path}/transactions_${DateTime.now().millisecondsSinceEpoch}.csv');
    await f.writeAsString(lines.join('\n'));
    await Share.shareXFiles([XFile(f.path)], text: 'Transactions CSV');
  }
}

class _Tile extends StatelessWidget {
  final String icon;
  final String title;
  final VoidCallback onTap;
  const _Tile({required this.icon, required this.title, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Container(
        width: 40,
        height: 40,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppColors.muted,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(icon, style: const TextStyle(fontSize: 20)),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
      trailing: const Icon(Icons.chevron_right, color: AppColors.textSecondary),
      onTap: onTap,
    );
  }
}
