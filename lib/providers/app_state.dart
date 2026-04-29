import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../models/budget.dart';
import '../models/category.dart';
import '../models/goal.dart';
import '../models/habit.dart';
import '../models/note.dart';
import '../models/snapshot.dart';
import '../models/task.dart';
import '../models/transaction.dart';
import '../repos/store.dart';
import '../theme/app_theme.dart';
import '../theme/palettes.dart';
import '../utils/home_widget_service.dart';

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
  final snapshots = JsonStore<MonthSnapshot>(
    boxName: 'month_snapshots',
    toJson: (s) => s.toJson(),
    fromJson: (j) => MonthSnapshot.fromJson(j),
    idOf: (s) => s.monthKey,
  );

  /// habit logs: key = habitId_yyyy-MM-dd, value = 1
  final habitLogs = KvStore('habit_logs');
  final prefs = KvStore('prefs');

  String currency = '₽';
  String userName = '';
  ThemeMode themeMode = ThemeMode.system;
  AppPalette palette = AppPalette.forest;
  bool onboardingDone = false;

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
      snapshots.open(),
      habitLogs.open(),
      prefs.open(),
    ]);

    final sp = await SharedPreferences.getInstance();
    onboardingDone = sp.getBool('onboarding_done') ?? false;
    userName = sp.getString('user_name') ?? '';
    currency = sp.getString('currency') ?? '₽';
    final tmIdx = sp.getInt('theme_mode') ?? 0;
    themeMode = ThemeMode.values[tmIdx.clamp(0, ThemeMode.values.length - 1)];
    final palIdx = sp.getInt('palette') ?? 0;
    palette = AppPalette.values[palIdx.clamp(0, AppPalette.values.length - 1)];
    AppColors.applyPalette(palette);

    if (categories.all().isEmpty) {
      await _seedCategories();
    }
    await _captureMissingSnapshots();
    await _pushHomeWidget();
  }

  /// Walk the past 12 months and ensure each non-current month has a stored
  /// snapshot. Called at startup; cheap because we only re-aggregate months
  /// that don't already have a snapshot.
  Future<void> _captureMissingSnapshots() async {
    final now = DateTime.now();
    for (var i = 1; i <= 12; i++) {
      final m = DateTime(now.year, now.month - i);
      final key =
          '${m.year.toString().padLeft(4, '0')}-${m.month.toString().padLeft(2, '0')}';
      if (snapshots.get(key) != null) continue;
      final tx = transactions.all().where(
          (t) => t.date.year == m.year && t.date.month == m.month);
      if (tx.isEmpty) continue;
      double income = 0;
      double expense = 0;
      final byCat = <String, double>{};
      var count = 0;
      for (final t in tx) {
        count += 1;
        if (t.type == TxType.income) {
          income += t.amount;
        } else {
          expense += t.amount;
          final id = t.categoryId ?? 'none';
          byCat.update(id, (v) => v + t.amount, ifAbsent: () => t.amount);
        }
      }
      String? topId;
      double topAmt = 0;
      for (final e in byCat.entries) {
        if (e.value > topAmt) {
          topAmt = e.value;
          topId = e.key;
        }
      }
      await snapshots.put(MonthSnapshot(
        monthKey: key,
        income: income,
        expense: expense,
        txCount: count,
        topCategoryId: topId,
        topCategoryAmount: topAmt,
        takenAt: DateTime.now(),
      ));
    }
  }

  List<MonthSnapshot> snapshotsAll() {
    final list = snapshots.all();
    list.sort((a, b) => a.monthKey.compareTo(b.monthKey));
    return list;
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
      CategoryModel(id: _uuid.v4(), name: 'Здоровье', colorValue: 0xFF00897B, iconKey: 'sport', scopes: {'habit', 'task'}),
    ];
    await categories.putAll(defaults);
  }

  String newId() => _uuid.v4();

  // --- Categories
  List<CategoryModel> categoriesByScope(String scope) {
    final list = categories.all().where((c) => c.scopes.contains(scope)).toList();
    list.sort((a, b) => a.sortIndex.compareTo(b.sortIndex));
    return list;
  }

  List<CategoryModel> categoriesAllSorted() {
    final list = categories.all();
    list.sort((a, b) => a.sortIndex.compareTo(b.sortIndex));
    return list;
  }

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

  /// Reorder categories within a scope. [oldIndex] and [newIndex] are indices
  /// into [categoriesByScope(scope)]. Persists the new order via sortIndex.
  Future<void> reorderCategories(String scope, int oldIndex, int newIndex) async {
    final list = categoriesByScope(scope);
    if (newIndex > oldIndex) newIndex -= 1;
    if (oldIndex < 0 || oldIndex >= list.length) return;
    if (newIndex < 0 || newIndex >= list.length) return;
    final moved = list.removeAt(oldIndex);
    list.insert(newIndex, moved);
    for (var i = 0; i < list.length; i++) {
      list[i].sortIndex = i;
      await categories.put(list[i]);
    }
    notifyListeners();
  }

  // --- Transactions
  List<TransactionModel> txAll() => transactions.all()
    ..sort((a, b) => b.date.compareTo(a.date));

  List<TransactionModel> txInMonth(DateTime month) {
    return txAll().where((t) => t.date.year == month.year && t.date.month == month.month).toList();
  }

  Future<void> upsertTransaction(TransactionModel t) async {
    await transactions.put(t);
    notifyListeners();
    _pushHomeWidget();
  }

  Future<void> deleteTransaction(String id) async {
    await transactions.delete(id);
    notifyListeners();
    _pushHomeWidget();
  }

  Future<void> _pushHomeWidget() async {
    await HomeWidgetService.push(transactions.all(), currency: currency);
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
    notifyListeners();
  }

  Future<void> toggleTask(TaskModel t) async {
    t.done = !t.done;
    t.completedAt = t.done ? DateTime.now() : null;
    await tasks.put(t);
    notifyListeners();
  }

  Future<void> deleteTask(String id) async {
    await tasks.delete(id);
    notifyListeners();
  }

  // --- Habits
  List<HabitModel> habitAll() => habits.all()..sort((a, b) => a.createdAt.compareTo(b.createdAt));

  Future<void> upsertHabit(HabitModel h) async {
    await habits.put(h);
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
    notifyListeners();
  }

  Future<void> deleteNote(String id) async {
    await notes.delete(id);
    notifyListeners();
  }

  // --- Goals
  List<GoalModel> goalAll() {
    final list = goals.all();
    list.sort((a, b) {
      final s = a.sortIndex.compareTo(b.sortIndex);
      if (s != 0) return s;
      return a.createdAt.compareTo(b.createdAt);
    });
    return list;
  }

  Future<void> upsertGoal(GoalModel g) async {
    await goals.put(g);
    notifyListeners();
  }

  Future<void> deleteGoal(String id) async {
    await goals.delete(id);
    notifyListeners();
  }

  Future<void> reorderGoals(int oldIndex, int newIndex) async {
    final list = goalAll();
    if (newIndex > oldIndex) newIndex -= 1;
    if (oldIndex < 0 || oldIndex >= list.length) return;
    if (newIndex < 0 || newIndex >= list.length) return;
    final moved = list.removeAt(oldIndex);
    list.insert(newIndex, moved);
    for (var i = 0; i < list.length; i++) {
      list[i].sortIndex = i;
      await goals.put(list[i]);
    }
    notifyListeners();
  }

  // --- Budgets
  MonthlyBudget? budgetFor(DateTime month) {
    final key = '${month.year.toString().padLeft(4, '0')}-${month.month.toString().padLeft(2, '0')}';
    return budgets.get(key);
  }

  Future<void> upsertBudget(MonthlyBudget b) async {
    await budgets.put(b);
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
    _pushHomeWidget();
  }

  Future<void> setThemeMode(ThemeMode m) async {
    themeMode = m;
    final sp = await SharedPreferences.getInstance();
    await sp.setInt('theme_mode', m.index);
    notifyListeners();
  }

  Future<void> setPalette(AppPalette p) async {
    palette = p;
    AppColors.applyPalette(p);
    final sp = await SharedPreferences.getInstance();
    await sp.setInt('palette', p.index);
    notifyListeners();
  }

  Future<void> resetAll() async {
    await Future.wait([
      categories.clear(),
      transactions.clear(),
      tasks.clear(),
      habits.clear(),
      notes.clear(),
      goals.clear(),
      budgets.clear(),
      snapshots.clear(),
      habitLogs.clear(),
    ]);
    await _seedCategories();
    notifyListeners();
    _pushHomeWidget();
  }
}
