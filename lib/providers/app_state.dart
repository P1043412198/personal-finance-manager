import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../models/achievement.dart';
import '../models/budget.dart';
import '../models/category.dart';
import '../models/currency_rate.dart';
import '../models/debt.dart';
import '../models/goal.dart';
import '../models/habit.dart';
import '../models/note.dart';
import '../models/recurring.dart';
import '../models/rule.dart';
import '../models/task.dart';
import '../models/template.dart';
import '../models/transaction.dart';
import '../models/wallet.dart';
import '../repos/store.dart';
import '../services/notifications.dart';

class AppState extends ChangeNotifier {
  final _uuid = const Uuid();

  final categories = JsonStore<CategoryModel>(
    boxName: 'categories',
    toJson: (c) => c.toJson(),
    fromJson: (j) => CategoryModel.fromJson(j),
    idOf: (c) => c.id,
  );
  final transactions = JsonStore<TransactionModel>(
    boxName: 'transactions',
    toJson: (t) => t.toJson(),
    fromJson: (j) => TransactionModel.fromJson(j),
    idOf: (t) => t.id,
  );
  final tasks = JsonStore<TaskModel>(
    boxName: 'tasks',
    toJson: (t) => t.toJson(),
    fromJson: (j) => TaskModel.fromJson(j),
    idOf: (t) => t.id,
  );
  final habits = JsonStore<HabitModel>(
    boxName: 'habits',
    toJson: (h) => h.toJson(),
    fromJson: (j) => HabitModel.fromJson(j),
    idOf: (h) => h.id,
  );
  final notes = JsonStore<NoteModel>(
    boxName: 'notes',
    toJson: (n) => n.toJson(),
    fromJson: (j) => NoteModel.fromJson(j),
    idOf: (n) => n.id,
  );
  final goals = JsonStore<GoalModel>(
    boxName: 'goals',
    toJson: (g) => g.toJson(),
    fromJson: (j) => GoalModel.fromJson(j),
    idOf: (g) => g.id,
  );
  final budgets = JsonStore<MonthlyBudget>(
    boxName: 'budgets',
    toJson: (b) => b.toJson(),
    fromJson: (j) => MonthlyBudget.fromJson(j),
    idOf: (b) => b.monthKey,
  );
  final wallets = JsonStore<WalletModel>(
    boxName: 'wallets',
    toJson: (w) => w.toJson(),
    fromJson: (j) => WalletModel.fromJson(j),
    idOf: (w) => w.id,
  );
  final recurring = JsonStore<RecurringTxModel>(
    boxName: 'recurring',
    toJson: (r) => r.toJson(),
    fromJson: (j) => RecurringTxModel.fromJson(j),
    idOf: (r) => r.id,
  );
  final debts = JsonStore<DebtModel>(
    boxName: 'debts',
    toJson: (d) => d.toJson(),
    fromJson: (j) => DebtModel.fromJson(j),
    idOf: (d) => d.id,
  );
  final achievements = JsonStore<AchievementModel>(
    boxName: 'achievements',
    toJson: (a) => a.toJson(),
    fromJson: (j) => AchievementModel.fromJson(j),
    idOf: (a) => a.id,
  );
  final rules = JsonStore<CategoryRule>(
    boxName: 'rules',
    toJson: (r) => r.toJson(),
    fromJson: (j) => CategoryRule.fromJson(j),
    idOf: (r) => r.id,
  );
  final templates = JsonStore<TxTemplate>(
    boxName: 'templates',
    toJson: (t) => t.toJson(),
    fromJson: (j) => TxTemplate.fromJson(j),
    idOf: (t) => t.id,
  );
  final rates = JsonStore<CurrencyRate>(
    boxName: 'rates',
    toJson: (r) => r.toJson(),
    fromJson: (j) => CurrencyRate.fromJson(j),
    idOf: (r) => r.code,
  );

  /// habit logs: key = habitId_yyyy-MM-dd, value = 1
  final habitLogs = KvStore('habit_logs');
  final prefs = KvStore('prefs');

  String currency = 'Br';
  String userName = '';
  ThemeMode themeMode = ThemeMode.system;
  bool onboardingDone = false;
  String themePalette = 'green';
  bool notificationsEnabled = true;
  bool secureScreen = false;
  bool amoled = false;
  bool dynamicColors = false;

  Future<void> init() async {
    await Hive.initFlutter();
    await Future.wait([
      categories.open(),
      transactions.open(),
      tasks.open(),
      habits.open(),
      notes.open(),
      goals.open(),
      budgets.open(),
      wallets.open(),
      recurring.open(),
      debts.open(),
      achievements.open(),
      rules.open(),
      templates.open(),
      rates.open(),
      habitLogs.open(),
      prefs.open(),
    ]);

    final sp = await SharedPreferences.getInstance();
    onboardingDone = sp.getBool('onboarding_done') ?? false;
    userName = sp.getString('user_name') ?? '';
    currency = sp.getString('currency') ?? 'Br';
    themePalette = sp.getString('theme_palette') ?? 'green';
    notificationsEnabled = sp.getBool('notifications_enabled') ?? true;
    secureScreen = sp.getBool('secure_screen') ?? false;
    amoled = sp.getBool('amoled') ?? false;
    dynamicColors = sp.getBool('dynamic_colors') ?? false;
    final tmIdx = sp.getInt('theme_mode') ?? 0;
    themeMode = ThemeMode.values[tmIdx.clamp(0, ThemeMode.values.length - 1)];

    if (categories.all().isEmpty) {
      await _seedCategories();
    }
    if (rates.all().isEmpty) {
      await _seedRates();
    }
    if (rules.all().isEmpty) {
      await _seedBelarusRules();
    }

    await runDueRecurring();
    if (notificationsEnabled) {
      await NotificationService.instance.init();
      await rescheduleAllNotifications();
    }
  }

  Future<void> _seedCategories() async {
    final defaults = <CategoryModel>[
      CategoryModel(id: _uuid.v4(), name: 'Продукты', colorValue: 0xFF43A047, iconKey: 'shopping_cart', scopes: {'tx'}),
      CategoryModel(id: _uuid.v4(), name: 'Еда и напитки', colorValue: 0xFFFB8C00, iconKey: 'coffee', scopes: {'tx'}),
      CategoryModel(id: _uuid.v4(), name: 'Транспорт', colorValue: 0xFF1E88E5, iconKey: 'transport', scopes: {'tx'}),
      CategoryModel(id: _uuid.v4(), name: 'Здоровье', colorValue: 0xFFE53935, iconKey: 'health', scopes: {'tx'}),
      CategoryModel(id: _uuid.v4(), name: 'Развлечения', colorValue: 0xFF8E24AA, iconKey: 'entertainment', scopes: {'tx'}),
      CategoryModel(id: _uuid.v4(), name: 'Покупки', colorValue: 0xFFD81B60, iconKey: 'shopping_cart', scopes: {'tx'}),
      CategoryModel(id: _uuid.v4(), name: 'Коммунальные', colorValue: 0xFF6D4C41, iconKey: 'utility', scopes: {'tx'}),
      CategoryModel(id: _uuid.v4(), name: 'Зарплата', colorValue: 0xFF2E7D32, iconKey: 'salary', scopes: {'tx'}),
      CategoryModel(id: _uuid.v4(), name: 'Работа', colorValue: 0xFF1565C0, iconKey: 'work', scopes: {'task', 'note'}),
      CategoryModel(id: _uuid.v4(), name: 'Личное', colorValue: 0xFF6A1B9A, iconKey: 'gift', scopes: {'task', 'note', 'habit'}),
      CategoryModel(id: _uuid.v4(), name: 'Учёба', colorValue: 0xFFEF6C00, iconKey: 'education', scopes: {'task', 'note'}),
      CategoryModel(id: _uuid.v4(), name: 'Здоровье и спорт', colorValue: 0xFF00897B, iconKey: 'sport', scopes: {'habit', 'task'}),
    ];
    await categories.putAll(defaults);
  }

  Future<void> _seedRates() async {
    // Base = BYN. Approximate rates relative to 1 BYN.
    final defaults = <CurrencyRate>[
      CurrencyRate(code: 'BYN', symbol: 'Br', toBase: 1.0),
      CurrencyRate(code: 'USD', symbol: '\$', toBase: 3.27),
      CurrencyRate(code: 'EUR', symbol: '€', toBase: 3.55),
      CurrencyRate(code: 'RUB', symbol: '₽', toBase: 0.036),
      CurrencyRate(code: 'PLN', symbol: 'zł', toBase: 0.83),
      CurrencyRate(code: 'UAH', symbol: '₴', toBase: 0.082),
    ];
    await rates.putAll(defaults);
  }

  Future<void> _seedBelarusRules() async {
    final cats = categories.all();
    String? catFor(String name) => cats.firstWhere(
          (c) => c.name.toLowerCase().startsWith(name.toLowerCase()),
          orElse: () => CategoryModel(id: '', name: '', colorValue: 0, iconKey: '', scopes: const {}),
        ).id.isEmpty ? null : cats.firstWhere(
          (c) => c.name.toLowerCase().startsWith(name.toLowerCase()),
        ).id;
    final groceriesId = catFor('Продукты');
    final foodId = catFor('Еда');
    final transportId = catFor('Транспорт');
    final utilId = catFor('Комм');
    final shoppingId = catFor('Покупки');
    final entId = catFor('Развлечения');
    final healthId = catFor('Здоровье');
    final byShops = <String, String?>{
      'Евроопт': groceriesId,
      'Корона': groceriesId,
      'Соседи': groceriesId,
      'Виталюр': groceriesId,
      'Простор': groceriesId,
      'Гиппо': groceriesId,
      'Санта': groceriesId,
      'Mart Inn': groceriesId,
      'Грошы': groceriesId,
      'АЛМИ': groceriesId,
      'РубльОК': groceriesId,
      'McDonald': foodId,
      'KFC': foodId,
      'Додо': foodId,
      'PIZZA': foodId,
      'Суши': foodId,
      'OZ': shoppingId,
      'Электросила': shoppingId,
      '21 век': shoppingId,
      'Технобанк': shoppingId,
      'Метро': transportId,
      'МПС': transportId,
      'A1': utilId,
      'МТС': utilId,
      'life:)': utilId,
      'Белтелеком': utilId,
      'Жилкомхоз': utilId,
      'Минскэнерго': utilId,
      'Apteka': healthId,
      'Аптека': healthId,
      'Kinopark': entId,
      'Silver Screen': entId,
      'Falcon Club': entId,
    };
    final newRules = <CategoryRule>[];
    for (final entry in byShops.entries) {
      if (entry.value == null) continue;
      newRules.add(CategoryRule(
        id: _uuid.v4(),
        matchShop: entry.key,
        categoryId: entry.value!,
      ));
    }
    if (newRules.isNotEmpty) await rules.putAll(newRules);
  }

  String newId() => _uuid.v4();

  // --- Categories
  List<CategoryModel> categoriesByScope(String scope) =>
      categories.all().where((c) => c.scopes.contains(scope)).toList();

  CategoryModel? categoryById(String? id) {
    if (id == null) return null;
    return categories.get(id);
  }

  Future<void> upsertCategory(CategoryModel c) async {
    await categories.put(c);
    notifyListeners();
  }

  Future<void> deleteCategory(String id) async {
    await categories.delete(id);
    notifyListeners();
  }

  // --- Transactions
  List<TransactionModel> txAll() => transactions.all()
    ..sort((a, b) => b.date.compareTo(a.date));

  List<TransactionModel> txInMonth(DateTime month) {
    return txAll().where((t) => t.date.year == month.year && t.date.month == month.month).toList();
  }

  Future<void> upsertTransaction(TransactionModel t) async {
    final isNew = transactions.get(t.id) == null;
    final prev = transactions.get(t.id);
    // apply rules: if no category, try matching
    if (t.categoryId == null) {
      for (final r in rules.all()) {
        if (r.matches(t.shop, t.comment)) {
          t.categoryId = r.categoryId;
          break;
        }
      }
    }
    await transactions.put(t);
    // update wallet balance
    if (prev != null && prev.walletId != null) {
      _bumpWallet(prev.walletId!, prev.type == TxType.income ? -prev.amount : prev.amount);
    }
    if (t.walletId != null) {
      _bumpWallet(t.walletId!, t.type == TxType.income ? t.amount : -t.amount);
    }
    if (isNew) {
      _checkAchievements(triggeredBy: 'tx');
    }
    notifyListeners();
  }

  Future<void> deleteTransaction(String id) async {
    final prev = transactions.get(id);
    await transactions.delete(id);
    if (prev != null && prev.walletId != null) {
      _bumpWallet(prev.walletId!, prev.type == TxType.income ? -prev.amount : prev.amount);
    }
    notifyListeners();
  }

  void _bumpWallet(String walletId, double delta) {
    final w = wallets.get(walletId);
    if (w == null) return;
    w.balance += delta;
    wallets.put(w);
  }

  // --- Wallets
  List<WalletModel> walletAll() =>
      wallets.all().where((w) => !w.archived).toList()
        ..sort((a, b) => a.name.compareTo(b.name));

  Future<void> upsertWallet(WalletModel w) async {
    await wallets.put(w);
    _checkAchievements(triggeredBy: 'wallet');
    notifyListeners();
  }

  Future<void> deleteWallet(String id) async {
    await wallets.delete(id);
    notifyListeners();
  }

  // --- Recurring
  List<RecurringTxModel> recurringAll() =>
      recurring.all()..sort((a, b) => a.nextRun.compareTo(b.nextRun));

  Future<void> upsertRecurring(RecurringTxModel r) async {
    await recurring.put(r);
    notifyListeners();
  }

  Future<void> deleteRecurring(String id) async {
    await recurring.delete(id);
    notifyListeners();
  }

  /// Materialize all recurring transactions whose nextRun <= now.
  Future<void> runDueRecurring() async {
    final now = DateTime.now();
    bool any = false;
    for (final r in recurring.all()) {
      if (!r.active) continue;
      var safety = 0;
      while (r.nextRun.isBefore(now) && safety < 24) {
        if (r.endDate != null && r.nextRun.isAfter(r.endDate!)) break;
        final t = TransactionModel(
          id: _uuid.v4(),
          type: r.type,
          amount: r.amount,
          currency: currency,
          categoryId: r.categoryId,
          walletId: r.walletId,
          comment: r.comment ?? r.name,
          date: r.nextRun,
          method: r.method,
        );
        await transactions.put(t);
        if (t.walletId != null) {
          _bumpWallet(t.walletId!, t.type == TxType.income ? t.amount : -t.amount);
        }
        r.nextRun = r.advance(r.nextRun);
        any = true;
        safety += 1;
      }
      await recurring.put(r);
    }
    if (any) notifyListeners();
  }

  // --- Debts
  List<DebtModel> debtAll() => debts.all()..sort((a, b) => b.balance.compareTo(a.balance));

  Future<void> upsertDebt(DebtModel d) async {
    await debts.put(d);
    notifyListeners();
  }

  Future<void> deleteDebt(String id) async {
    await debts.delete(id);
    notifyListeners();
  }

  // --- Templates
  List<TxTemplate> templateAll() => templates.all()..sort((a, b) => a.name.compareTo(b.name));

  Future<void> upsertTemplate(TxTemplate t) async {
    await templates.put(t);
    notifyListeners();
  }

  Future<void> deleteTemplate(String id) async {
    await templates.delete(id);
    notifyListeners();
  }

  // --- Rules
  List<CategoryRule> ruleAll() => rules.all();

  Future<void> upsertRule(CategoryRule r) async {
    await rules.put(r);
    notifyListeners();
  }

  Future<void> deleteRule(String id) async {
    await rules.delete(id);
    notifyListeners();
  }

  // --- Rates
  List<CurrencyRate> rateAll() => rates.all()..sort((a, b) => a.code.compareTo(b.code));

  Future<void> upsertRate(CurrencyRate r) async {
    await rates.put(r);
    notifyListeners();
  }

  CurrencyRate? rateOf(String code) => rates.get(code);

  /// Convert amount in currency `from` (symbol or code) to base currency value.
  double toBase(double amount, String fromCurrencyOrSymbol) {
    final r = rates.all().firstWhere(
          (r) => r.code == fromCurrencyOrSymbol || r.symbol == fromCurrencyOrSymbol,
          orElse: () => CurrencyRate(code: 'BASE', symbol: '?', toBase: 1.0),
        );
    return amount * r.toBase;
  }

  // --- Achievements
  List<AchievementModel> achievementAll() =>
      achievements.all()..sort((a, b) => b.unlockedAt.compareTo(a.unlockedAt));

  bool hasAchievement(String key) =>
      achievements.all().any((a) => a.key == key);

  Future<void> _unlock(String key, String iconKey) async {
    if (hasAchievement(key)) return;
    await achievements.put(AchievementModel(
      id: _uuid.v4(),
      key: key,
      iconKey: iconKey,
      unlockedAt: DateTime.now(),
    ));
  }

  Future<void> _checkAchievements({String? triggeredBy}) async {
    if (triggeredBy == 'tx') {
      if (transactions.all().isNotEmpty) await _unlock('first_tx', '💰');
      if (transactions.all().length >= 100) await _unlock('hundred_tx', '💯');
    }
    if (triggeredBy == 'task' && tasks.all().isNotEmpty) {
      await _unlock('first_task', '✅');
    }
    if (triggeredBy == 'habit' && habits.all().isNotEmpty) {
      await _unlock('first_habit', '🌱');
    }
    if (triggeredBy == 'goal' && goals.all().isNotEmpty) {
      await _unlock('first_goal', '🎯');
    }
    if (triggeredBy == 'note' && notes.all().isNotEmpty) {
      await _unlock('first_note', '📝');
    }
    if (triggeredBy == 'budget' && budgets.all().isNotEmpty) {
      await _unlock('first_budget', '📊');
    }
    if (triggeredBy == 'wallet' && wallets.all().isNotEmpty) {
      await _unlock('first_wallet', '👛');
    }
  }

  // --- Tasks
  List<TaskModel> taskAll() {
    final list = tasks.all();
    list.sort((a, b) {
      if (a.done != b.done) return a.done ? 1 : -1;
      final ad = a.dueDate ?? DateTime(2999);
      final bd = b.dueDate ?? DateTime(2999);
      return ad.compareTo(bd);
    });
    return list;
  }

  Future<void> upsertTask(TaskModel t) async {
    await tasks.put(t);
    if (notificationsEnabled && t.dueDate != null && !t.done) {
      final when = t.dueDate!.subtract(const Duration(hours: 1));
      await NotificationService.instance.scheduleAt(
        id: notificationIdFor('task_${t.id}'),
        title: 'Задача: ${t.title}',
        body: t.description ?? '',
        when: when,
      );
    } else {
      await NotificationService.instance.cancel(notificationIdFor('task_${t.id}'));
    }
    _checkAchievements(triggeredBy: 'task');
    notifyListeners();
  }

  Future<void> toggleTask(TaskModel t) async {
    t.done = !t.done;
    t.completedAt = t.done ? DateTime.now() : null;
    await tasks.put(t);
    if (t.done) {
      await NotificationService.instance.cancel(notificationIdFor('task_${t.id}'));
    } else if (notificationsEnabled && t.dueDate != null) {
      await NotificationService.instance.scheduleAt(
        id: notificationIdFor('task_${t.id}'),
        title: 'Задача: ${t.title}',
        body: t.description ?? '',
        when: t.dueDate!.subtract(const Duration(hours: 1)),
      );
    }
    notifyListeners();
  }

  Future<void> deleteTask(String id) async {
    await tasks.delete(id);
    await NotificationService.instance.cancel(notificationIdFor('task_$id'));
    notifyListeners();
  }

  // --- Habits
  List<HabitModel> habitAll() => habits.all()..sort((a, b) => a.createdAt.compareTo(b.createdAt));

  Future<void> upsertHabit(HabitModel h) async {
    await habits.put(h);
    _checkAchievements(triggeredBy: 'habit');
    notifyListeners();
  }

  Future<void> deleteHabit(String id) async {
    await habits.delete(id);
    final keys = habitLogs.keys.where((k) => k.toString().startsWith('${id}_')).toList();
    for (final k in keys) {
      await habitLogs.delete(k.toString());
    }
    notifyListeners();
  }

  bool isHabitDone(String habitId, String dayKey) =>
      habitLogs.get('${habitId}_$dayKey') != null;

  Future<void> toggleHabit(String habitId, String dayKey) async {
    final k = '${habitId}_$dayKey';
    if (habitLogs.get(k) != null) {
      await habitLogs.delete(k);
    } else {
      await habitLogs.put(k, 1);
    }
    final s = habitStreak(habitId);
    if (s >= 7) await _unlock('week_streak', '🔥');
    if (s >= 30) await _unlock('month_streak', '🌟');
    notifyListeners();
  }

  /// returns a map of dayKey -> doneCount for habit
  List<String> habitDays(String habitId) {
    final prefix = '${habitId}_';
    return habitLogs.keys
        .map((e) => e.toString())
        .where((k) => k.startsWith(prefix))
        .map((k) => k.substring(prefix.length))
        .toList();
  }

  int habitStreak(String habitId) {
    final days = habitDays(habitId).toSet();
    int streak = 0;
    var cursor = DateTime.now();
    while (true) {
      final key =
          '${cursor.year.toString().padLeft(4, '0')}-${cursor.month.toString().padLeft(2, '0')}-${cursor.day.toString().padLeft(2, '0')}';
      if (days.contains(key)) {
        streak += 1;
        cursor = cursor.subtract(const Duration(days: 1));
      } else {
        break;
      }
    }
    return streak;
  }

  // --- Notes
  List<NoteModel> noteAll() =>
      notes.all()..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

  Future<void> upsertNote(NoteModel n) async {
    n.updatedAt = DateTime.now();
    await notes.put(n);
    _checkAchievements(triggeredBy: 'note');
    notifyListeners();
  }

  Future<void> deleteNote(String id) async {
    await notes.delete(id);
    notifyListeners();
  }

  // --- Goals
  List<GoalModel> goalAll() =>
      goals.all()..sort((a, b) => a.createdAt.compareTo(b.createdAt));

  Future<void> upsertGoal(GoalModel g) async {
    await goals.put(g);
    if (g.current >= g.target) {
      await _unlock('saver', '🏆');
    }
    _checkAchievements(triggeredBy: 'goal');
    notifyListeners();
  }

  Future<void> deleteGoal(String id) async {
    await goals.delete(id);
    notifyListeners();
  }

  // --- Budgets
  MonthlyBudget? budgetFor(DateTime month) {
    final key = '${month.year.toString().padLeft(4, '0')}-${month.month.toString().padLeft(2, '0')}';
    return budgets.get(key);
  }

  Future<void> upsertBudget(MonthlyBudget b) async {
    await budgets.put(b);
    _checkAchievements(triggeredBy: 'budget');
    notifyListeners();
  }

  // --- Settings
  Future<void> setOnboardingDone(bool v) async {
    onboardingDone = v;
    final sp = await SharedPreferences.getInstance();
    await sp.setBool('onboarding_done', v);
    notifyListeners();
  }

  Future<void> setUserName(String name) async {
    userName = name;
    final sp = await SharedPreferences.getInstance();
    await sp.setString('user_name', name);
    notifyListeners();
  }

  Future<void> setCurrency(String c) async {
    currency = c;
    final sp = await SharedPreferences.getInstance();
    await sp.setString('currency', c);
    notifyListeners();
  }

  Future<void> setThemeMode(ThemeMode m) async {
    themeMode = m;
    final sp = await SharedPreferences.getInstance();
    await sp.setInt('theme_mode', m.index);
    notifyListeners();
  }

  Future<void> setThemePalette(String p) async {
    themePalette = p;
    final sp = await SharedPreferences.getInstance();
    await sp.setString('theme_palette', p);
    notifyListeners();
  }

  Future<void> setNotificationsEnabled(bool v) async {
    notificationsEnabled = v;
    final sp = await SharedPreferences.getInstance();
    await sp.setBool('notifications_enabled', v);
    if (v) {
      await NotificationService.instance.init();
      await rescheduleAllNotifications();
    } else {
      await NotificationService.instance.cancelAll();
    }
    notifyListeners();
  }

  Future<void> setSecureScreen(bool v) async {
    secureScreen = v;
    final sp = await SharedPreferences.getInstance();
    await sp.setBool('secure_screen', v);
    notifyListeners();
  }

  Future<void> setAmoled(bool v) async {
    amoled = v;
    final sp = await SharedPreferences.getInstance();
    await sp.setBool('amoled', v);
    notifyListeners();
  }

  Future<void> setDynamicColors(bool v) async {
    dynamicColors = v;
    final sp = await SharedPreferences.getInstance();
    await sp.setBool('dynamic_colors', v);
    notifyListeners();
  }

  Future<void> rescheduleAllNotifications() async {
    await NotificationService.instance.cancelAll();
    if (!notificationsEnabled) return;
    for (final t in tasks.all()) {
      if (!t.done && t.dueDate != null) {
        final when = t.dueDate!.subtract(const Duration(hours: 1));
        if (when.isAfter(DateTime.now())) {
          await NotificationService.instance.scheduleAt(
            id: notificationIdFor('task_${t.id}'),
            title: 'Задача: ${t.title}',
            body: t.description ?? '',
            when: when,
          );
        }
      }
    }
    for (final r in recurring.all()) {
      if (!r.active) continue;
      await NotificationService.instance.scheduleAt(
        id: notificationIdFor('rec_${r.id}'),
        title: 'Регулярная: ${r.name}',
        body: 'Ожидается ${r.amount.toStringAsFixed(0)} $currency',
        when: r.nextRun,
      );
    }
  }

  void notify() => notifyListeners();

  Future<void> resetAll() async {
    await Future.wait([
      categories.clear(),
      transactions.clear(),
      tasks.clear(),
      habits.clear(),
      notes.clear(),
      goals.clear(),
      budgets.clear(),
      wallets.clear(),
      recurring.clear(),
      debts.clear(),
      achievements.clear(),
      rules.clear(),
      templates.clear(),
      rates.clear(),
      habitLogs.clear(),
    ]);
    await _seedCategories();
    await _seedRates();
    await _seedBelarusRules();
    await NotificationService.instance.cancelAll();
    notifyListeners();
  }
}
