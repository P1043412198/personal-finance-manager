class GoalModel {
  final String id;
  String name;
  double target;
  double current;
  DateTime? deadline;
  String iconKey;
  int colorValue;
  /// Auto-deposit amount per month (in BYN equivalent). 0 = off.
  double autoDepositMonthly;
  /// Optional walletId where auto-deposit virtually accumulates.
  String? walletId;
  DateTime createdAt;

  GoalModel({
    required this.id,
    required this.name,
    required this.target,
    this.current = 0,
    this.deadline,
    this.iconKey = 'savings',
    this.colorValue = 0xFF2E7D32,
    this.autoDepositMonthly = 0,
    this.walletId,
    required this.createdAt,
  });

  double get progress => target == 0 ? 0 : (current / target).clamp(0.0, 1.0);

  /// Months left until deadline (1 if no deadline).
  int monthsLeft() {
    if (deadline == null) return 1;
    final now = DateTime.now();
    var months = (deadline!.year - now.year) * 12 + (deadline!.month - now.month);
    if (months <= 0) return 1;
    return months;
  }

  /// Suggested per-month deposit to reach the goal on time.
  double suggestedPerMonth() {
    final left = (target - current).clamp(0.0, double.infinity);
    return left / monthsLeft();
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'target': target,
        'current': current,
        'deadline': deadline?.toIso8601String(),
        'iconKey': iconKey,
        'colorValue': colorValue,
        'autoDepositMonthly': autoDepositMonthly,
        'walletId': walletId,
        'createdAt': createdAt.toIso8601String(),
      };

  factory GoalModel.fromJson(Map j) => GoalModel(
        id: j['id'] as String,
        name: j['name'] as String,
        target: (j['target'] as num).toDouble(),
        current: (j['current'] as num?)?.toDouble() ?? 0,
        deadline: j['deadline'] != null ? DateTime.parse(j['deadline']) : null,
        iconKey: j['iconKey'] as String? ?? 'savings',
        colorValue: (j['colorValue'] as num?)?.toInt() ?? 0xFF2E7D32,
        autoDepositMonthly: (j['autoDepositMonthly'] as num?)?.toDouble() ?? 0,
        walletId: j['walletId'] as String?,
        createdAt: DateTime.parse(j['createdAt']),
      );
}
