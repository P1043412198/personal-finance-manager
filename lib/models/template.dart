import 'transaction.dart';

class TxTemplate {
  final String id;
  String name;
  TxType type;
  double amount;
  String? categoryId;
  String? walletId;
  PayMethod method;
  String? shop;
  String iconKey;

  TxTemplate({
    required this.id,
    required this.name,
    this.type = TxType.expense,
    required this.amount,
    this.categoryId,
    this.walletId,
    this.method = PayMethod.card,
    this.shop,
    this.iconKey = 'shopping_cart',
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'type': type.name,
        'amount': amount,
        'categoryId': categoryId,
        'walletId': walletId,
        'method': method.name,
        'shop': shop,
        'iconKey': iconKey,
      };

  factory TxTemplate.fromJson(Map j) => TxTemplate(
        id: j['id'] as String,
        name: j['name'] as String,
        type: TxType.values.firstWhere((e) => e.name == j['type'],
            orElse: () => TxType.expense),
        amount: (j['amount'] as num).toDouble(),
        categoryId: j['categoryId'] as String?,
        walletId: j['walletId'] as String?,
        method: PayMethod.values.firstWhere((e) => e.name == j['method'],
            orElse: () => PayMethod.card),
        shop: j['shop'] as String?,
        iconKey: j['iconKey'] as String? ?? 'shopping_cart',
      );
}
