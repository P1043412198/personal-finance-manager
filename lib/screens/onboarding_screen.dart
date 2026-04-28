import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/app_state.dart';
import '../theme/app_theme.dart';
import '../utils/i18n.dart';
import 'home_shell.dart';

class OnboardingScreen extends StatelessWidget {
  const OnboardingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final i18n = context.watch<I18n>();
    final app = context.read<AppState>();
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 24),
              Text(
                i18n.t('onboarding_title'),
                style: const TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.w700,
                  height: 1.15,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                i18n.t('onboarding_subtitle'),
                style: const TextStyle(
                  fontSize: 16,
                  color: AppColors.textSecondary,
                  height: 1.4,
                ),
              ),
              const Spacer(),
              Center(
                child: Container(
                  width: 220,
                  height: 220,
                  decoration: BoxDecoration(
                    color: AppColors.muted,
                    shape: BoxShape.circle,
                  ),
                  child: const Center(
                    child: Text(
                      '🌱📈',
                      style: TextStyle(fontSize: 90),
                    ),
                  ),
                ),
              ),
              const Spacer(),
              ElevatedButton(
                onPressed: () async {
                  await app.setOnboardingDone(true);
                  if (!context.mounted) return;
                  Navigator.of(context).pushReplacement(
                      MaterialPageRoute(builder: (_) => const HomeShell()));
                },
                child: Text(i18n.t('onboarding_start')),
              ),
              const SizedBox(height: 12),
              Center(
                child: TextButton(
                  onPressed: () async {
                    await app.setOnboardingDone(true);
                    if (!context.mounted) return;
                    Navigator.of(context).pushReplacement(
                        MaterialPageRoute(builder: (_) => const HomeShell()));
                  },
                  child: RichText(
                    text: TextSpan(
                      style: const TextStyle(color: AppColors.textSecondary, fontSize: 14),
                      children: [
                        TextSpan(text: '${i18n.t('have_account')} '),
                        TextSpan(
                          text: i18n.t('sign_in'),
                          style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
