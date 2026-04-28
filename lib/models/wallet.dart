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

  WalletModel({
    required this.id,
    required this.name,
    this.type = WalletType.card,
    this.currency = '₽',
    this.balance = 0,
    this.colorValue = 0xFF2E7D32,
    this.iconKey = 'card',
    this.archived = false,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'type': type.name,
        'currency': currency,
        'balance': balance,
        'colorValue': colorValue,
        'iconKey': iconKey,
        'archived': archived,
      };

  factory WalletModel.fromJson(Map j) => WalletModel(
        id: j['id'] as String,
        name: j['name'] as String,
        type: WalletType.values.firstWhere((e) => e.name == j['type'],
            orElse: () => WalletType.card),
        currency: j['currency'] as String? ?? '₽',
        balance: (j['balance'] as num?)?.toDouble() ?? 0,
        colorValue: j['colorValue'] as int? ?? 0xFF2E7D32,
        iconKey: j['iconKey'] as String? ?? 'card',
        archived: j['archived'] as bool? ?? false,
      );
}
