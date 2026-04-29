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

class MonthlyBudget {
  /// yyyy-MM
  final String monthKey;
  double income;
  double totalLimit;
  List<CategoryLimit> limits;
  String? template;
  bool carryOver;
  double carriedOver;

  MonthlyBudget({
    required this.monthKey,
    required this.income,
    required this.totalLimit,
    List<CategoryLimit>? limits,
    this.template,
    this.carryOver = false,
    this.carriedOver = 0,
  }) : limits = limits ?? [];

  /// Sum of all per-category limits.
  double get sumOfLimits => limits.fold<double>(0, (a, l) => a + l.limit);

  /// Free funds = income (+ carried over) − sum of category limits.
  double get freeFunds => income + carriedOver - sumOfLimits;

  Map<String, dynamic> toJson() => {
        'monthKey': monthKey,
        'income': income,
        'totalLimit': totalLimit,
        'limits': limits.map((e) => e.toJson()).toList(),
        'template': template,
        'carryOver': carryOver,
        'carriedOver': carriedOver,
      };

  factory MonthlyBudget.fromJson(Map j) => MonthlyBudget(
        monthKey: j['monthKey'] as String,
        income: (j['income'] as num).toDouble(),
        totalLimit: (j['totalLimit'] as num).toDouble(),
        limits: (j['limits'] as List?)
                ?.map((e) => CategoryLimit.fromJson(e as Map))
                .toList() ??
            [],
        template: j['template'] as String?,
        carryOver: j['carryOver'] as bool? ?? false,
        carriedOver: (j['carriedOver'] as num?)?.toDouble() ?? 0,
      );
}
