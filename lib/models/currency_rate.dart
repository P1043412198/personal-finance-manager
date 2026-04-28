class CurrencyRate {
  final String code;   // e.g. USD
  String symbol;       // e.g. $
  double toBase;       // multiplier from this currency to base (e.g. 1 USD = 90 RUB → toBase=90)

  CurrencyRate({required this.code, required this.symbol, required this.toBase});

  Map<String, dynamic> toJson() => {
        'code': code,
        'symbol': symbol,
        'toBase': toBase,
      };

  factory CurrencyRate.fromJson(Map j) => CurrencyRate(
        code: j['code'] as String,
        symbol: j['symbol'] as String,
        toBase: (j['toBase'] as num).toDouble(),
      );
}
