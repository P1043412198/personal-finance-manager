enum DebtKind { credit, loan, mortgage, friend, other }

class DebtModel {
  final String id;
  String name;
  DebtKind kind;
  double principal;
  double balance;
  double rate; // annual percent
  double minPayment;
  int? dueDay; // day of month
  DateTime? deadline;
  int colorValue;

  DebtModel({
    required this.id,
    required this.name,
    this.kind = DebtKind.credit,
    required this.principal,
    required this.balance,
    this.rate = 0,
    this.minPayment = 0,
    this.dueDay,
    this.deadline,
    this.colorValue = 0xFFD32F2F,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'kind': kind.name,
        'principal': principal,
        'balance': balance,
        'rate': rate,
        'minPayment': minPayment,
        'dueDay': dueDay,
        'deadline': deadline?.toIso8601String(),
        'colorValue': colorValue,
      };

  factory DebtModel.fromJson(Map j) => DebtModel(
        id: j['id'] as String,
        name: j['name'] as String,
        kind: DebtKind.values.firstWhere((e) => e.name == j['kind'],
            orElse: () => DebtKind.credit),
        principal: (j['principal'] as num).toDouble(),
        balance: (j['balance'] as num).toDouble(),
        rate: (j['rate'] as num?)?.toDouble() ?? 0,
        minPayment: (j['minPayment'] as num?)?.toDouble() ?? 0,
        dueDay: j['dueDay'] as int?,
        deadline: j['deadline'] != null ? DateTime.parse(j['deadline'] as String) : null,
        colorValue: j['colorValue'] as int? ?? 0xFFD32F2F,
      );

  double get progress {
    if (principal == 0) return 0;
    return (1 - balance / principal).clamp(0, 1).toDouble();
  }
}
