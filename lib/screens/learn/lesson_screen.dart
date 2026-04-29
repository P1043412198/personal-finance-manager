import 'package:flutter/material.dart';

import '../../data/lessons.dart';
import '../../theme/app_theme.dart';
import '../../widgets/section.dart';

class LessonScreen extends StatelessWidget {
  final Lesson lesson;
  const LessonScreen({super.key, required this.lesson});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(lesson.title)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 60),
        children: [
          Row(
            children: [
              Container(
                width: 64,
                height: 64,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.muted,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Text(lesson.emoji, style: const TextStyle(fontSize: 36)),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(lesson.title,
                        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 4),
                    Row(children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(lesson.tag,
                            style: const TextStyle(
                                color: AppColors.primary,
                                fontWeight: FontWeight.w700,
                                fontSize: 11)),
                      ),
                      const SizedBox(width: 8),
                      Text(lesson.readMin,
                          style: const TextStyle(
                              color: AppColors.textSecondary, fontSize: 12)),
                    ]),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Text(lesson.summary,
              style: const TextStyle(fontSize: 15, height: 1.45, fontStyle: FontStyle.italic)),
          const SizedBox(height: 18),
          for (final s in lesson.sections) ...[
            SectionHeader(title: s.heading),
            const SizedBox(height: 4),
            Text(s.body,
                style: const TextStyle(fontSize: 15, height: 1.55)),
            const SizedBox(height: 18),
          ],
          AppCard(
            color: AppColors.primary.withOpacity(0.08),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Главное',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                const SizedBox(height: 8),
                for (final t in lesson.takeaways)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('• ', style: TextStyle(fontWeight: FontWeight.w900)),
                        Expanded(
                          child: Text(t,
                              style: const TextStyle(fontSize: 14, height: 1.4)),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            icon: const Icon(Icons.check_circle_outline),
            label: const Text('Урок прочитан'),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }
}
