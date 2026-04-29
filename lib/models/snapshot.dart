/// Snapshot of monthly aggregates captured automatically on the 1st of each
/// month (or the first time the app is opened in a new month). Used as a
/// stable historical baseline for forecasts and the snapshots timeline.
class MonthSnapshot {
  /// Month being summarised (yyyy-MM).
  final String monthKey;
  final double income;
  final double expense;
  final int txCount;
  final String? topCategoryId;
  final double topCategoryAmount;

  /// When the snapshot was actually captured.
  final DateTime takenAt;

  const MonthSnapshot({
    required this.monthKey,
    required this.income,
    required this.expense,
    required this.txCount,
    required this.topCategoryId,
    required this.topCategoryAmount,
    required this.takenAt,
  });

  double get net => income - expense;

  Map<String, dynamic> toJson() => {
        'monthKey': monthKey,
        'income': income,
        'expense': expense,
        'txCount': txCount,
        'topCategoryId': topCategoryId,
        'topCategoryAmount': topCategoryAmount,
        'takenAt': takenAt.toIso8601String(),
      };

  factory MonthSnapshot.fromJson(Map j) => MonthSnapshot(
        monthKey: j['monthKey'] as String,
        income: (j['income'] as num).toDouble(),
        expense: (j['expense'] as num).toDouble(),
        txCount: (j['txCount'] as num).toInt(),
        topCategoryId: j['topCategoryId'] as String?,
        topCategoryAmount: ((j['topCategoryAmount'] ?? 0) as num).toDouble(),
        takenAt: DateTime.parse(j['takenAt'] as String),
      );
}
