import 'dart:convert';
import 'dart:io';

/// Fetches official exchange rates from the National Bank of Republic of Belarus.
/// Public, no API key required: https://www.nbrb.by/api/exrates/rates?periodicity=0
class NbrbService {
  NbrbService._();
  static final instance = NbrbService._();

  static const _url = 'https://api.nbrb.by/exrates/rates?periodicity=0';

  /// Returns map: currency code (USD/EUR/RUB/PLN/UAH/CNY/...) -> rate as 1 unit in BYN.
  /// NBRB returns Cur_OfficialRate per Cur_Scale units, so we normalize by scale.
  Future<Map<String, double>?> fetchRates() async {
    try {
      final client = HttpClient()
        ..connectionTimeout = const Duration(seconds: 8)
        ..idleTimeout = const Duration(seconds: 8);
      final req = await client.getUrl(Uri.parse(_url));
      final resp = await req.close().timeout(const Duration(seconds: 8));
      if (resp.statusCode != 200) {
        client.close(force: true);
        return null;
      }
      final body = await resp.transform(utf8.decoder).join();
      client.close(force: true);
      final list = jsonDecode(body);
      if (list is! List) return null;
      final out = <String, double>{};
      for (final item in list) {
        if (item is! Map) continue;
        final code = item['Cur_Abbreviation']?.toString();
        final rate = (item['Cur_OfficialRate'] as num?)?.toDouble();
        final scale = (item['Cur_Scale'] as num?)?.toDouble() ?? 1.0;
        if (code == null || rate == null || scale == 0) continue;
        out[code] = rate / scale;
      }
      out['BYN'] = 1.0;
      return out;
    } catch (_) {
      return null;
    }
  }
}
