import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/lessons.dart';
import '../../providers/app_state.dart';
import '../../theme/app_theme.dart';
import '../../utils/i18n.dart';
import '../../widgets/section.dart';
import 'lesson_screen.dart';

class LearnTab extends StatelessWidget {
  const LearnTab({super.key});

  @override
  Widget build(BuildContext context) {
    final i18n = context.watch<I18n>();
    final app = context.watch<AppState>();
    final readSet = (app.prefs.get('learn_read') as String?)?.split(',').toSet() ?? <String>{};
    final progress = lessonsRu.isEmpty ? 0.0 : readSet.length / lessonsRu.length;
    return Scaffold(
      appBar: AppBar(
        title: Text(i18n.t('learn')),
        actions: [
          IconButton(
            icon: const Icon(Icons.calculate_outlined),
            tooltip: 'Калькулятор зарплаты РБ',
            onPressed: () => Navigator.of(context).pushNamed('/tax-calc'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
        children: [
          AppCard(
            color: AppColors.muted,
            padding: const EdgeInsets.all(18),
            child: Row(
              children: [
                const Text('📈', style: TextStyle(fontSize: 36)),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Финансовая грамотность',
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                      const SizedBox(height: 4),
                      Text(
                        'Прочитано ${readSet.length} из ${lessonsRu.length}',
                        style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                      ),
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: LinearProgressIndicator(
                          value: progress,
                          minHeight: 6,
                          backgroundColor: Colors.white,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          AppCard(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: ListTile(
              leading: const Text('🧮', style: TextStyle(fontSize: 28)),
              title: const Text('Калькулятор зарплаты РБ'),
              subtitle: const Text('Подоходный 13% + ФСЗН 1% — грязная ↔ чистая'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context).pushNamed('/tax-calc'),
            ),
          ),
          const SizedBox(height: 16),
          SectionHeader(title: 'Уроки'),
          for (final l in lessonsRu)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: AppCard(
                onTap: () async {
                  await Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => LessonScreen(lesson: l),
                  ));
                  final updated = (app.prefs.get('learn_read') as String?)?.split(',').toSet() ??
                      <String>{};
                  updated.add(l.id);
                  await app.prefs.put('learn_read', updated.join(','));
                  app.notify();
                },
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: AppColors.muted,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Text(l.emoji, style: const TextStyle(fontSize: 24)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(children: [
                            Expanded(
                              child: Text(l.title,
                                  style: const TextStyle(fontWeight: FontWeight.w700)),
                            ),
                            if (readSet.contains(l.id))
                              const Icon(Icons.check_circle,
                                  color: AppColors.income, size: 18),
                          ]),
                          const SizedBox(height: 2),
                          Text(l.summary,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  color: AppColors.textSecondary, fontSize: 12)),
                          const SizedBox(height: 4),
                          Row(children: [
                            _Tag(text: l.tag),
                            const SizedBox(width: 6),
                            Text(l.readMin,
                                style: const TextStyle(
                                    color: AppColors.textSecondary, fontSize: 11)),
                          ]),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right, color: AppColors.textSecondary),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  final String text;
  const _Tag({required this.text});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(text,
          style: const TextStyle(
              color: AppColors.primary, fontSize: 10, fontWeight: FontWeight.w600)),
    );
  }
}
