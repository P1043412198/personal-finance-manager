enum TxType { expense, income }

enum PayMethod { card, cash, transfer }

class TransactionModel {
  final String id;
  TxType type;
  double amount;
  String currency; // e.g. ₽, $, €
  String? categoryId;
  String? walletId;
  String? shop;
  String? comment;
  DateTime date;
  PayMethod method;
  bool savedReceipt;
  String? attachmentPath;

  TransactionModel({
    required this.id,
    required this.type,
    required this.amount,
    this.currency = '₽',
    this.categoryId,
    this.walletId,
    this.shop,
    this.comment,
    required this.date,
    this.method = PayMethod.card,
    this.savedReceipt = false,
    this.attachmentPath,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type.name,
        'amount': amount,
        'currency': currency,
        'categoryId': categoryId,
        'walletId': walletId,
        'shop': shop,
        'comment': comment,
        'date': date.toIso8601String(),
        'method': method.name,
        'savedReceipt': savedReceipt,
        'attachmentPath': attachmentPath,
      };

  factory TransactionModel.fromJson(Map j) => TransactionModel(
        id: j['id'] as String,
        type: TxType.values.firstWhere((e) => e.name == j['type'],
            orElse: () => TxType.expense),
        amount: (j['amount'] as num).toDouble(),
        currency: j['currency'] as String? ?? '₽',
        categoryId: j['categoryId'] as String?,
        walletId: j['walletId'] as String?,
        shop: j['shop'] as String?,
        comment: j['comment'] as String?,
        date: DateTime.parse(j['date'] as String),
        method: PayMethod.values.firstWhere(
          (e) => e.name == j['method'],
          orElse: () => PayMethod.card,
        ),
        savedReceipt: j['savedReceipt'] as bool? ?? false,
        attachmentPath: j['attachmentPath'] as String?,
      );
}
