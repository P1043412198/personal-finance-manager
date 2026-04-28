import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'providers/app_state.dart';
import 'screens/onboarding_screen.dart';
import 'screens/home_shell.dart';
import 'theme/app_theme.dart';
import 'utils/i18n.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('ru');
  await initializeDateFormatting('en');

  final state = AppState();
  await state.init();

  runApp(MyApp(state: state));
}

class MyApp extends StatelessWidget {
  final AppState state;
  const MyApp({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: state),
        ChangeNotifierProvider(create: (_) => I18n()),
      ],
      child: Consumer2<AppState, I18n>(
        builder: (context, app, i18n, _) {
          return MaterialApp(
            title: i18n.t('app_title'),
            debugShowCheckedModeBanner: false,
            theme: AppTheme.light(),
            darkTheme: AppTheme.dark(),
            themeMode: app.themeMode,
            locale: i18n.locale,
            supportedLocales: const [
              Locale('ru'),
              Locale('en'),
            ],
            localizationsDelegates: const [
              GlobalMaterialLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
            ],
            home: app.onboardingDone ? const HomeShell() : const OnboardingScreen(),
          );
        },
      ),
    );
  }
}
