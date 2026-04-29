import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'providers/app_state.dart';
import 'screens/learn/tax_calc_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/home_shell.dart';
import 'screens/lock/lock_screen.dart';
import 'services/lock_service.dart';
import 'theme/app_theme.dart';
import 'utils/i18n.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('ru');
  await initializeDateFormatting('en');
  await initializeDateFormatting('be');

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

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  bool? _locked;
  bool? _lastSecure;
  static const _secureChannel = MethodChannel('com.vibesight.personal_finance/secure');

  Future<void> _applySecure(bool on) async {
    try {
      await _secureChannel.invokeMethod('setSecure', {'on': on});
    } catch (_) {}
  }

  void _onAppStateChanged() {
    final v = widget.state.secureScreen;
    if (_lastSecure != v) {
      _lastSecure = v;
      _applySecure(v);
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    widget.state.addListener(_onAppStateChanged);
    _onAppStateChanged();
    _checkLockOnLaunch();
  }

  Future<void> _checkLockOnLaunch() async {
    final enabled = await LockService.instance.isEnabled();
    if (!mounted) return;
    setState(() => _locked = enabled);
  }

  @override
  void dispose() {
    widget.state.removeListener(_onAppStateChanged);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) async {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      // mark for autolock
      LockService.instance.markUnlocked();
    } else if (state == AppLifecycleState.resumed) {
      if (await LockService.instance.needsUnlock()) {
        if (mounted) setState(() => _locked = true);
      }
    }
  }

  void _onUnlock() {
    LockService.instance.markUnlocked();
    setState(() => _locked = false);
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
          return DynamicColorBuilder(builder: (lightDyn, darkDyn) {
            final useDyn = app.dynamicColors;
            return MaterialApp(
            title: i18n.t('app_title'),
            debugShowCheckedModeBanner: false,
            theme: AppTheme.light(
                paletteKey: app.themePalette,
                dynamicScheme: useDyn ? lightDyn?.harmonized() : null),
            darkTheme: AppTheme.dark(
                paletteKey: app.themePalette,
                dynamicScheme: useDyn ? darkDyn?.harmonized() : null,
                amoled: app.amoled),
            themeMode: app.themeMode,
            locale: i18n.locale,
            supportedLocales: const [
              Locale('ru'),
              Locale('en'),
              Locale('be'),
            ],
            localizationsDelegates: const [
              GlobalMaterialLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
            ],
            home: _buildHome(app),
            routes: {
              '/tax-calc': (_) => const TaxCalcScreen(),
            },
            builder: (context, child) {
              if (_locked == null) {
                return const Scaffold(body: SizedBox.shrink());
              }
              return child ?? const SizedBox.shrink();
            },
          );
          });
        },
      ),
    );
  }

  Widget _buildHome(AppState app) {
    if (_locked == true) return LockScreen(onUnlock: _onUnlock);
    if (!app.onboardingDone) return const OnboardingScreen();
    return const HomeShell();
  }
}
