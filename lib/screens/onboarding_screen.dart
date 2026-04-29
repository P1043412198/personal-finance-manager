import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/app_state.dart';
import '../theme/app_theme.dart';
import '../utils/i18n.dart';
import 'home_shell.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _ctrl = PageController();
  int _idx = 0;

  @override
  Widget build(BuildContext context) {
    final i18n = context.watch<I18n>();
    final app = context.read<AppState>();
    final pages = [
      _Page(emoji: '🌱📈', title: i18n.t('onboarding_title'), subtitle: i18n.t('onboarding_subtitle')),
      _Page(emoji: '💰', title: 'Учёт расходов', subtitle: 'Добавляй траты в один тап. Категории и шаблоны помогут.'),
      _Page(emoji: '🎯', title: 'Цели и привычки', subtitle: 'Копи на мечты, отслеживай привычки и серии дней.'),
      _Page(emoji: '🔒', title: 'Безопасность', subtitle: 'PIN, биометрия и блокировка скриншотов.'),
    ];

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView.builder(
                controller: _ctrl,
                itemCount: pages.length,
                onPageChanged: (i) => setState(() => _idx = i),
                itemBuilder: (_, i) => pages[i],
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(pages.length, (i) => Container(
                margin: const EdgeInsets.symmetric(horizontal: 4),
                width: i == _idx ? 24 : 8,
                height: 8,
                decoration: BoxDecoration(
                  color: i == _idx
                      ? Theme.of(context).colorScheme.primary
                      : AppColors.muted,
                  borderRadius: BorderRadius.circular(4),
                ),
              )),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
              child: ElevatedButton(
                onPressed: () async {
                  if (_idx < pages.length - 1) {
                    _ctrl.nextPage(
                        duration: const Duration(milliseconds: 250),
                        curve: Curves.easeOut);
                  } else {
                    await app.setOnboardingDone(true);
                    if (!context.mounted) return;
                    Navigator.of(context).pushReplacement(
                        MaterialPageRoute(builder: (_) => const HomeShell()));
                  }
                },
                child: Text(_idx < pages.length - 1
                    ? 'Далее'
                    : i18n.t('onboarding_start')),
              ),
            ),
            TextButton(
              onPressed: () async {
                await app.setOnboardingDone(true);
                if (!context.mounted) return;
                Navigator.of(context).pushReplacement(
                    MaterialPageRoute(builder: (_) => const HomeShell()));
              },
              child: const Text('Пропустить'),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

class _Page extends StatelessWidget {
  final String emoji;
  final String title;
  final String subtitle;
  const _Page({required this.emoji, required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 24),
          Text(title,
              style: const TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.w700,
                  height: 1.15,
                  color: AppColors.textPrimary)),
          const SizedBox(height: 14),
          Text(subtitle,
              style: const TextStyle(
                  fontSize: 16,
                  color: AppColors.textSecondary,
                  height: 1.4)),
          const Spacer(),
          Center(
            child: Container(
              width: 220, height: 220,
              decoration: const BoxDecoration(
                  color: AppColors.muted, shape: BoxShape.circle),
              child: Center(child: Text(emoji, style: const TextStyle(fontSize: 90))),
            ),
          ),
          const Spacer(),
        ],
      ),
    );
  }
}
