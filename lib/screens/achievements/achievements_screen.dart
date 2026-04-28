import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/achievement.dart';
import '../../providers/app_state.dart';
import '../../theme/app_theme.dart';
import '../../utils/i18n.dart';
import '../../widgets/section.dart';

class AchievementsScreen extends StatelessWidget {
  const AchievementsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final i18n = context.watch<I18n>();
    final unlocked = {for (final a in app.achievementAll()) a.key: a};

    return Scaffold(
      appBar: AppBar(title: Text(i18n.t('achievements'))),
      body: GridView.count(
        padding: const EdgeInsets.all(16),
        crossAxisCount: 3,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 0.85,
        children: [
          for (final entry in AchievementCatalog.items)
            AppCard(
              padding: const EdgeInsets.all(8),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Opacity(
                    opacity: unlocked.containsKey(entry.$1) ? 1.0 : 0.25,
                    child: Text(entry.$2, style: const TextStyle(fontSize: 36)),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    i18n.t('ach_${entry.$1}'),
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (!unlocked.containsKey(entry.$1))
                    const Padding(
                      padding: EdgeInsets.only(top: 4),
                      child: Icon(Icons.lock, size: 12, color: AppColors.textSecondary),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
