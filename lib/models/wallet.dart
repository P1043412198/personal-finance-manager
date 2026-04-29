enum WalletKind { cash, card, account }

class WalletModel {
  final String id;
  String name;
  WalletKind kind;
  String currency;
  double initialBalance;
  String iconKey;
  int colorValue;
  bool archived;
  int sortIndex;
  DateTime createdAt;

  WalletModel({
    required this.id,
    required this.name,
    this.kind = WalletKind.card,
    this.currency = '₽',
    this.initialBalance = 0,
    this.iconKey = 'wallet',
    this.colorValue = 0xFF2E7D32,
    this.archived = false,
    this.sortIndex = 0,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'kind': kind.name,
        'currency': currency,
        'initialBalance': initialBalance,
        'iconKey': iconKey,
        'colorValue': colorValue,
        'archived': archived,
        'sortIndex': sortIndex,
        'createdAt': createdAt.toIso8601String(),
      };

  factory WalletModel.fromJson(Map j) => WalletModel(
        id: j['id'] as String,
        name: j['name'] as String,
        kind: WalletKind.values.firstWhere((e) => e.name == j['kind'],
            orElse: () => WalletKind.card),
        currency: (j['currency'] as String?) ?? '₽',
        initialBalance: (j['initialBalance'] as num?)?.toDouble() ?? 0,
        iconKey: (j['iconKey'] as String?) ?? 'wallet',
        colorValue: (j['colorValue'] as num?)?.toInt() ?? 0xFF2E7D32,
        archived: (j['archived'] as bool?) ?? false,
        sortIndex: (j['sortIndex'] as num?)?.toInt() ?? 0,
        createdAt: DateTime.parse(j['createdAt'] as String),
      );
}
