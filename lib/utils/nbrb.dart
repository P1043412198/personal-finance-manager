import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

/// NBRB (National Bank of the Republic of Belarus) currency rate codes.
class NbrbCurrency {
  final String code;
  final int curId;
  final int scale;
  final String name;
  const NbrbCurrency({
    required this.code,
    required this.curId,
    required this.scale,
    required this.name,
  });
}

/// Hardcoded list of common currency codes — NBRB IDs are stable for these.
const Map<String, NbrbCurrency> kNbrbCurrencies = {
  'USD': NbrbCurrency(code: 'USD', curId: 431, scale: 1, name: 'Доллар США'),
  'EUR': NbrbCurrency(code: 'EUR', curId: 451, scale: 1, name: 'Евро'),
  'RUB': NbrbCurrency(code: 'RUB', curId: 456, scale: 100, name: 'Рубль РФ'),
  'PLN': NbrbCurrency(code: 'PLN', curId: 293, scale: 1, name: 'Польский злотый'),
  'CNY': NbrbCurrency(code: 'CNY', curId: 462, scale: 10, name: 'Юань'),
};

class NbrbRate {
  final DateTime date;
  final double value;
  final int scale;
  const NbrbRate({required this.date, required this.value, required this.scale});

  /// Per-unit rate (BYN per 1 unit of the foreign currency).
  double get perUnit => scale == 0 ? value : (value / scale);

  Map<String, dynamic> toJson() => {
        'd': date.toIso8601String().substring(0, 10),
        'v': value,
        's': scale,
      };

  factory NbrbRate.fromJson(Map j) => NbrbRate(
        date: DateTime.parse(j['d'] as String),
        value: (j['v'] as num).toDouble(),
        scale: (j['s'] as num).toInt(),
      );
}

abstract class NbrbClient {
  Future<List<NbrbRate>> dynamics({
    required NbrbCurrency cur,
    required DateTime startDate,
    required DateTime endDate,
  });
}

class HttpNbrbClient implements NbrbClient {
  final http.Client _client;
  final Duration timeout;
  HttpNbrbClient({http.Client? client, this.timeout = const Duration(seconds: 8)})
      : _client = client ?? http.Client();

  @override
  Future<List<NbrbRate>> dynamics({
    required NbrbCurrency cur,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    String fmt(DateTime d) =>
        '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
    final uri = Uri.parse(
        'https://api.nbrb.by/exrates/rates/dynamics/${cur.curId}?startDate=${fmt(startDate)}&endDate=${fmt(endDate)}');
    final res = await _client.get(uri).timeout(timeout);
    if (res.statusCode != 200) {
      throw Exception('NBRB ${res.statusCode}: ${res.body}');
    }
    final body = jsonDecode(res.body);
    if (body is! List) {
      throw Exception('Unexpected NBRB response: ${res.body}');
    }
    return body
        .map<NbrbRate>((e) => NbrbRate(
              date: DateTime.parse(e['Date'] as String),
              value: (e['Cur_OfficialRate'] as num).toDouble(),
              scale: cur.scale,
            ))
        .toList();
  }

  void close() => _client.close();
}

/// Compute month-over-month percentage change between first and last
/// available rate in [rates], or null if not enough data.
double? momChange(List<NbrbRate> rates) {
  if (rates.length < 2) return null;
  final a = rates.first.perUnit;
  final b = rates.last.perUnit;
  if (a == 0) return null;
  return (b - a) / a * 100;
}
