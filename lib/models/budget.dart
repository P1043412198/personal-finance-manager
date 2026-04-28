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

  MonthlyBudget({
    required this.monthKey,
    required this.income,
    required this.totalLimit,
    List<CategoryLimit>? limits,
    this.template,
  }) : limits = limits ?? [];

  Map<String, dynamic> toJson() => {
        'monthKey': monthKey,
        'income': income,
        'totalLimit': totalLimit,
        'limits': limits.map((e) => e.toJson()).toList(),
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
        template: j['template'] as String?,
      );
}
