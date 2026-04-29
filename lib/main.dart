import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:quick_actions/quick_actions.dart';

import 'models/transaction.dart';
import 'providers/app_state.dart';
import 'screens/onboarding_screen.dart';
import 'screens/home_shell.dart';
import 'screens/transaction/add_transaction_screen.dart';
import 'screens/transaction/scan_receipt_screen.dart';
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

class MyApp extends StatefulWidget {
  final AppState state;
  const MyApp({super.key, required this.state});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final _navKey = GlobalKey<NavigatorState>();
  final _quickActions = const QuickActions();

  @override
  void initState() {
    super.initState();
    _setupQuickActions();
  }

  Future<void> _setupQuickActions() async {
    try {
      _quickActions.initialize((shortcutType) {
        // The home is built lazily; defer until navigator is ready.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          final nav = _navKey.currentState;
          if (nav == null) return;
          switch (shortcutType) {
            case 'add_expense':
              nav.push(MaterialPageRoute(
                  builder: (_) => const AddTransactionScreen(
                      initialType: TxType.expense)));
              break;
            case 'scan_receipt':
              nav.push(MaterialPageRoute(
                  builder: (_) => const ScanReceiptScreen()));
              break;
          }
        });
      });
      await _quickActions.setShortcutItems(const [
        ShortcutItem(
          type: 'add_expense',
          localizedTitle: 'Add expense',
          icon: 'ic_launcher',
        ),
        ShortcutItem(
          type: 'scan_receipt',
          localizedTitle: 'Scan receipt',
          icon: 'ic_launcher',
        ),
      ]);
    } catch (_) {
      // Quick actions unavailable on this platform; ignore.
    }
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: widget.state),
        ChangeNotifierProvider(create: (_) => I18n()),
      ],
      child: Consumer2<AppState, I18n>(
        builder: (context, app, i18n, _) {
          return MaterialApp(
            navigatorKey: _navKey,
            title: i18n.t('app_title'),
            debugShowCheckedModeBanner: false,
            theme: AppTheme.light(palette: app.palette),
            darkTheme: AppTheme.dark(palette: app.palette),
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
