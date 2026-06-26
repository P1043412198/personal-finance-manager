class CategoryLimit {
  String categoryId;
  double limit;

  CategoryLimit({required this.categoryId, required this.limit});

  Map<String, dynamic> toJson() => {'categoryId': categoryId, 'limit': limit};

  factory CategoryLimit.fromJson(Map j) => CategoryLimit(
        categoryId: j['categoryId'] as String,
        limit: (j['limit'] as num).toDouble(),
      );
}

class FixedBudgetItem {
  final String id;
  String name;
  double amount;
  int? dayOfMonth;
  bool subscription;
  bool enabled;

  FixedBudgetItem({
    required this.id,
    required this.name,
    required this.amount,
    this.dayOfMonth,
    this.subscription = false,
    this.enabled = true,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'amount': amount,
        'dayOfMonth': dayOfMonth,
        'subscription': subscription,
        'enabled': enabled,
      };

  factory FixedBudgetItem.fromJson(Map j) => FixedBudgetItem(
        id: j['id'] as String? ?? 'fixed_${DateTime.now().microsecondsSinceEpoch}',
        name: j['name'] as String? ?? 'Обязательный платёж',
        amount: (j['amount'] as num? ?? 0).toDouble(),
        dayOfMonth: j['dayOfMonth'] as int?,
        subscription: j['subscription'] as bool? ?? false,
        enabled: j['enabled'] as bool? ?? true,
      );
}

class MonthlyBudget {
  /// yyyy-MM
  final String monthKey;
  double income;

  /// Variable category budget, without fixed payments.
  double totalLimit;
  List<CategoryLimit> limits;

  /// Rent, utilities, subscriptions, loans and other predictable payments.
  List<FixedBudgetItem> fixedCosts;
  String? template;

  MonthlyBudget({
    required this.monthKey,
    required this.income,
    required this.totalLimit,
    List<CategoryLimit>? limits,
    List<FixedBudgetItem>? fixedCosts,
    this.template,
  })  : limits = limits ?? [],
        fixedCosts = fixedCosts ?? [];

  double get fixedCostsTotal => fixedCosts
      .where((e) => e.enabled)
      .fold<double>(0, (sum, e) => sum + e.amount);

  double get plannedOutflow => totalLimit + fixedCostsTotal;

  Map<String, dynamic> toJson() => {
        'monthKey': monthKey,
        'income': income,
        'totalLimit': totalLimit,
        'limits': limits.map((e) => e.toJson()).toList(),
        'fixedCosts': fixedCosts.map((e) => e.toJson()).toList(),
        'template': template,
      };

  factory MonthlyBudget.fromJson(Map j) => MonthlyBudget(
        monthKey: j['monthKey'] as String,
        income: (j['income'] as num).toDouble(),
        totalLimit: (j['totalLimit'] as num).toDouble(),
        limits: (j['limits'] as List?)
                ?.map((e) => CategoryLimit.fromJson(e as Map))
                .toList() ??
            [],
        fixedCosts: (j['fixedCosts'] as List?)
                ?.map((e) => FixedBudgetItem.fromJson(e as Map))
                .toList() ??
            [],
        template: j['template'] as String?,
      );
}
