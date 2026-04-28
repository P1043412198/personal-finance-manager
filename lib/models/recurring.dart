import 'transaction.dart';

enum Cadence { daily, weekly, monthly, yearly }

class RecurringTxModel {
  final String id;
  String name;
  TxType type;
  double amount;
  String? categoryId;
  String? walletId;
  PayMethod method;
  String? comment;
  Cadence cadence;
  int interval; // every N units
  DateTime startDate;
  DateTime? endDate;
  DateTime nextRun;
  bool active;

  RecurringTxModel({
    required this.id,
    required this.name,
    required this.type,
    required this.amount,
    this.categoryId,
    this.walletId,
    this.method = PayMethod.card,
    this.comment,
    this.cadence = Cadence.monthly,
    this.interval = 1,
    required this.startDate,
    this.endDate,
    required this.nextRun,
    this.active = true,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'type': type.name,
        'amount': amount,
        'categoryId': categoryId,
        'walletId': walletId,
        'method': method.name,
        'comment': comment,
        'cadence': cadence.name,
        'interval': interval,
        'startDate': startDate.toIso8601String(),
        'endDate': endDate?.toIso8601String(),
        'nextRun': nextRun.toIso8601String(),
        'active': active,
      };

  factory RecurringTxModel.fromJson(Map j) => RecurringTxModel(
        id: j['id'] as String,
        name: j['name'] as String,
        type: TxType.values.firstWhere((e) => e.name == j['type'],
            orElse: () => TxType.expense),
        amount: (j['amount'] as num).toDouble(),
        categoryId: j['categoryId'] as String?,
        walletId: j['walletId'] as String?,
        method: PayMethod.values.firstWhere((e) => e.name == j['method'],
            orElse: () => PayMethod.card),
        comment: j['comment'] as String?,
        cadence: Cadence.values.firstWhere((e) => e.name == j['cadence'],
            orElse: () => Cadence.monthly),
        interval: j['interval'] as int? ?? 1,
        startDate: DateTime.parse(j['startDate'] as String),
        endDate: j['endDate'] != null ? DateTime.parse(j['endDate'] as String) : null,
        nextRun: DateTime.parse(j['nextRun'] as String),
        active: j['active'] as bool? ?? true,
      );

  DateTime advance(DateTime from) {
    switch (cadence) {
      case Cadence.daily:
        return DateTime(from.year, from.month, from.day + interval);
      case Cadence.weekly:
        return DateTime(from.year, from.month, from.day + 7 * interval);
      case Cadence.monthly:
        return DateTime(from.year, from.month + interval, from.day);
      case Cadence.yearly:
        return DateTime(from.year + interval, from.month, from.day);
    }
  }
}
