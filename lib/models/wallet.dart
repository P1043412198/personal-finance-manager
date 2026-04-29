enum WalletType { card, cash, deposit, credit, other }

class WalletModel {
  final String id;
  String name;
  WalletType type;
  String currency;
  double balance;
  int colorValue;
  String iconKey;
  bool archived;
  double? targetAmount;
  DateTime? targetDate;

  WalletModel({
    required this.id,
    required this.name,
    this.type = WalletType.card,
    this.currency = 'Br',
    this.balance = 0,
    this.colorValue = 0xFF2E7D32,
    this.iconKey = 'card',
    this.archived = false,
    this.targetAmount,
    this.targetDate,
  });

  /// Sinking fund progress 0..1; null when no target set.
  double? get sinkingProgress {
    if (targetAmount == null || targetAmount! <= 0) return null;
    return (balance / targetAmount!).clamp(0.0, 1.0);
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'type': type.name,
        'currency': currency,
        'balance': balance,
        'colorValue': colorValue,
        'iconKey': iconKey,
        'archived': archived,
        'targetAmount': targetAmount,
        'targetDate': targetDate?.toIso8601String(),
      };

  factory WalletModel.fromJson(Map j) => WalletModel(
        id: j['id'] as String,
        name: j['name'] as String,
        type: WalletType.values.firstWhere((e) => e.name == j['type'],
            orElse: () => WalletType.card),
        currency: j['currency'] as String? ?? 'Br',
        balance: (j['balance'] as num?)?.toDouble() ?? 0,
        colorValue: j['colorValue'] as int? ?? 0xFF2E7D32,
        iconKey: j['iconKey'] as String? ?? 'card',
        archived: j['archived'] as bool? ?? false,
        targetAmount: (j['targetAmount'] as num?)?.toDouble(),
        targetDate: j['targetDate'] != null ? DateTime.parse(j['targetDate'] as String) : null,
      );
}
