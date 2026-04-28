import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/app_state.dart';
import '../../theme/app_theme.dart';
import '../../utils/i18n.dart';
import '../../widgets/section.dart';
import '../achievements/achievements_screen.dart';
import '../analytics/analytics_screen.dart';
import '../categories/categories_screen.dart';
import '../debts/debts_screen.dart';
import '../goals/goals_screen.dart';
import '../habits/habits_screen.dart';
import '../notes/notes_screen.dart';
import '../pomodoro/pomodoro_screen.dart';
import '../recurring/recurring_screen.dart';
import '../rules/rules_screen.dart';
import '../settings/currency_rates_screen.dart';
import '../settings/import_export_screen.dart';
import '../settings/lock_settings_screen.dart';
import '../settings/palette_screen.dart';
import '../tasks/tasks_screen.dart';
import '../templates/templates_screen.dart';
import '../wallets/wallets_screen.dart';

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
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${app.txAll().length} ${i18n.t('transactions').toLowerCase()} · ${app.achievementAll().length} 🏆',
                        style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                      ),
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
          SectionHeader(title: i18n.t('finance')),
          AppCard(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(children: [
              _Tile(icon: '👛', title: i18n.t('wallets'),
                  onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const WalletsScreen()))),
              _Tile(icon: '🔁', title: i18n.t('recurring'),
                  onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const RecurringScreen()))),
              _Tile(icon: '💳', title: i18n.t('debts'),
                  onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const DebtsScreen()))),
              _Tile(icon: '⚡', title: i18n.t('templates'),
                  onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const TemplatesScreen()))),
              _Tile(icon: '🧮', title: i18n.t('rules'),
                  onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const RulesScreen()))),
              _Tile(icon: '💱', title: i18n.t('currency_rates'),
                  onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const CurrencyRatesScreen()))),
              _Tile(icon: '📊', title: i18n.t('analytics'),
                  onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const AnalyticsScreen()))),
              _Tile(icon: '🎯', title: i18n.t('goals'),
                  onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const GoalsScreen()))),
            ]),
          ),
          const SizedBox(height: 16),
          SectionHeader(title: i18n.t('tools')),
          AppCard(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(children: [
              _Tile(icon: '✅', title: i18n.t('tasks'),
                  onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const TasksScreen()))),
              _Tile(icon: '🌱', title: i18n.t('habits'),
                  onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const HabitsScreen()))),
              _Tile(icon: '📝', title: i18n.t('notes'),
                  onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const NotesScreen()))),
              _Tile(icon: '🍅', title: 'Pomodoro',
                  onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const PomodoroScreen()))),
              _Tile(icon: '🏷️', title: i18n.t('categories'),
                  onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const CategoriesScreen()))),
              _Tile(icon: '🏆', title: i18n.t('achievements'),
                  onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const AchievementsScreen()))),
            ]),
          ),
          const SizedBox(height: 16),
          SectionHeader(title: i18n.t('security')),
          AppCard(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(children: [
              _Tile(icon: '🔒', title: i18n.t('lock_settings'),
                  onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const LockSettingsScreen()))),
              SwitchListTile(
                value: app.notificationsEnabled,
                title: Text(i18n.t('notifications')),
                onChanged: (v) => app.setNotificationsEnabled(v),
              ),
            ]),
          ),
          const SizedBox(height: 16),
          SectionHeader(title: i18n.t('language')),
          AppCard(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(children: [
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
            ]),
          ),
          const SizedBox(height: 16),
          SectionHeader(title: i18n.t('theme')),
          AppCard(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(children: [
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
              _Tile(icon: '🎨', title: i18n.t('palette'),
                  onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const PaletteScreen()))),
            ]),
          ),
          const SizedBox(height: 16),
          SectionHeader(title: i18n.t('data')),
          AppCard(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(children: [
              _Tile(icon: '📤', title: i18n.t('import_export'),
                  onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const ImportExportScreen()))),
              _Tile(
                icon: '🗑️',
                title: i18n.t('reset_data'),
                onTap: () async {
                  final ok = await showDialog<bool>(
                    context: context,
                    builder: (_) => AlertDialog(
                      title: Text(i18n.t('confirm_reset')),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(context, false),
                            child: Text(i18n.t('no'))),
                        TextButton(onPressed: () => Navigator.pop(context, true),
                            child: Text(i18n.t('yes'))),
                      ],
                    ),
                  );
                  if (ok == true) await app.resetAll();
                },
              ),
            ]),
          ),
          const SizedBox(height: 16),
          Center(
            child: Text('${i18n.t('version')} 2.0.0',
                style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
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
          TextButton(onPressed: () => Navigator.pop(context), child: Text(i18n.t('cancel'))),
          TextButton(onPressed: () => Navigator.pop(context, ctrl.text.trim()),
              child: Text(i18n.t('save'))),
        ],
      ),
    );
    if (result != null) await app.setUserName(result);
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
        width: 40, height: 40,
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
