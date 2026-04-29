import 'transaction.dart';

enum RecurFreq { daily, weekly, monthly, yearly }

/// A repeating transaction template. The app walks every active rule on
/// startup, materialises any due `TransactionModel`s and bumps `lastApplied`
/// to the latest applied date.
class RecurringRule {
  final String id;
  String name;
  TxType type;
  double amount;
  String? categoryId;
  String? walletId;
  RecurFreq freq;

  /// Day-of-month for [RecurFreq.monthly] / [RecurFreq.yearly] (1..31; clamped
  /// to last day of shorter months).
  int? dayOfMonth;

  /// 1=Mon..7=Sun for [RecurFreq.weekly].
  int? dayOfWeek;

  /// 1..12 for [RecurFreq.yearly].
  int? monthOfYear;

  DateTime startDate;
  DateTime? endDate;

  /// Last date for which a [TransactionModel] was created from this rule.
  DateTime? lastApplied;

  bool active;
  String? note;

  RecurringRule({
    required this.id,
    required this.name,
    required this.type,
    required this.amount,
    this.categoryId,
    this.walletId,
    required this.freq,
    this.dayOfMonth,
    this.dayOfWeek,
    this.monthOfYear,
    required this.startDate,
    this.endDate,
    this.lastApplied,
    this.active = true,
    this.note,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'type': type.name,
        'amount': amount,
        'categoryId': categoryId,
        'walletId': walletId,
        'freq': freq.name,
        'dayOfMonth': dayOfMonth,
        'dayOfWeek': dayOfWeek,
        'monthOfYear': monthOfYear,
        'startDate': startDate.toIso8601String(),
        'endDate': endDate?.toIso8601String(),
        'lastApplied': lastApplied?.toIso8601String(),
        'active': active,
        'note': note,
      };

  factory RecurringRule.fromJson(Map j) => RecurringRule(
        id: j['id'] as String,
        name: j['name'] as String,
        type: TxType.values.firstWhere((e) => e.name == j['type'],
            orElse: () => TxType.expense),
        amount: (j['amount'] as num).toDouble(),
        categoryId: j['categoryId'] as String?,
        walletId: j['walletId'] as String?,
        freq: RecurFreq.values.firstWhere((e) => e.name == j['freq'],
            orElse: () => RecurFreq.monthly),
        dayOfMonth: (j['dayOfMonth'] as num?)?.toInt(),
        dayOfWeek: (j['dayOfWeek'] as num?)?.toInt(),
        monthOfYear: (j['monthOfYear'] as num?)?.toInt(),
        startDate: DateTime.parse(j['startDate'] as String),
        endDate: j['endDate'] == null ? null : DateTime.parse(j['endDate'] as String),
        lastApplied: j['lastApplied'] == null
            ? null
            : DateTime.parse(j['lastApplied'] as String),
        active: (j['active'] as bool?) ?? true,
        note: j['note'] as String?,
      );
}
