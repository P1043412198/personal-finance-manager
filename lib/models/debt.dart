enum DebtDirection { youOwe, owesYou }

class DebtPayment {
  final String id;
  double amount;
  DateTime date;
  String? note;

  DebtPayment({
    required this.id,
    required this.amount,
    required this.date,
    this.note,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'amount': amount,
        'date': date.toIso8601String(),
        'note': note,
      };

  factory DebtPayment.fromJson(Map j) => DebtPayment(
        id: j['id'] as String,
        amount: (j['amount'] as num).toDouble(),
        date: DateTime.parse(j['date'] as String),
        note: j['note'] as String?,
      );
}

class DebtModel {
  final String id;
  String counterparty;
  DebtDirection direction;
  double amount;
  String currency;
  DateTime createdAt;
  DateTime? dueDate;
  String? note;
  List<DebtPayment> payments;
  bool archived;

  DebtModel({
    required this.id,
    required this.counterparty,
    required this.direction,
    required this.amount,
    this.currency = '₽',
    required this.createdAt,
    this.dueDate,
    this.note,
    List<DebtPayment>? payments,
    this.archived = false,
  }) : payments = payments ?? <DebtPayment>[];

  double get paid => payments.fold<double>(0, (s, p) => s + p.amount);

  double get remaining {
    final r = amount - paid;
    return r < 0 ? 0 : r;
  }

  bool get isPaid => remaining <= 0.001;

  Map<String, dynamic> toJson() => {
        'id': id,
        'counterparty': counterparty,
        'direction': direction.name,
        'amount': amount,
        'currency': currency,
        'createdAt': createdAt.toIso8601String(),
        'dueDate': dueDate?.toIso8601String(),
        'note': note,
        'payments': payments.map((p) => p.toJson()).toList(),
        'archived': archived,
      };

  factory DebtModel.fromJson(Map j) => DebtModel(
        id: j['id'] as String,
        counterparty: j['counterparty'] as String,
        direction: DebtDirection.values.firstWhere(
            (e) => e.name == j['direction'],
            orElse: () => DebtDirection.youOwe),
        amount: (j['amount'] as num).toDouble(),
        currency: (j['currency'] as String?) ?? '₽',
        createdAt: DateTime.parse(j['createdAt'] as String),
        dueDate:
            j['dueDate'] == null ? null : DateTime.parse(j['dueDate'] as String),
        note: j['note'] as String?,
        payments: (j['payments'] as List?)
                ?.map((e) => DebtPayment.fromJson(e as Map))
                .toList() ??
            <DebtPayment>[],
        archived: (j['archived'] as bool?) ?? false,
      );
}
