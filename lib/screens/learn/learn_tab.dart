import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../theme/app_theme.dart';
import '../../utils/i18n.dart';
import '../../widgets/section.dart';

class LearnTab extends StatelessWidget {
  const LearnTab({super.key});

  @override
  Widget build(BuildContext context) {
    final i18n = context.watch<I18n>();
    final lessons = [
      ('🌱', 'Зачем нужен бюджет', '5 мин', 'Базы личных финансов: куда уходят деньги.'),
      ('💼', 'Подушка безопасности', '7 мин', 'Сколько копить и как защититься от форс-мажоров.'),
      ('💳', 'Кредиты без боли', '8 мин', 'Снежок vs лавина — как быстрее закрыть долги.'),
      ('🎯', 'Sinking funds', '6 мин', 'Конверты на крупные траты заранее.'),
      ('📊', '50/30/20', '4 мин', 'Простая формула распределения дохода.'),
      ('🏦', 'Инвестиции 101', '10 мин', 'С чего начать без риска впасть в стресс.'),
    ];
    return Scaffold(
      appBar: AppBar(title: Text(i18n.t('learn'))),
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
                      Text(i18n.t('learn'),
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                      const SizedBox(height: 4),
                      Text(i18n.t('small_steps'),
                          style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          SectionHeader(title: i18n.t('learn')),
          for (final l in lessons)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: AppCard(
                onTap: () {
                  showModalBottomSheet(
                    context: context,
                    showDragHandle: true,
                    builder: (_) => Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('${l.$1} ${l.$2}',
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                          const SizedBox(height: 8),
                          Text(l.$4,
                              style: const TextStyle(color: AppColors.textSecondary, height: 1.4)),
                          const SizedBox(height: 16),
                        ],
                      ),
                    ),
                  );
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
                      child: Text(l.$1, style: const TextStyle(fontSize: 24)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(l.$2, style: const TextStyle(fontWeight: FontWeight.w700)),
                          const SizedBox(height: 2),
                          Text(l.$3,
                              style: const TextStyle(
                                  color: AppColors.textSecondary, fontSize: 12)),
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
