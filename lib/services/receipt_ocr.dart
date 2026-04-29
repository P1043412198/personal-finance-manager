import 'dart:io';

import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

class ParsedReceipt {
  final String rawText;
  final double? total;
  final String? shop;
  final DateTime? date;
  final List<({String name, double price})> items;

  const ParsedReceipt({
    required this.rawText,
    this.total,
    this.shop,
    this.date,
    this.items = const [],
  });
}

class ReceiptOcr {
  static final _recognizer =
      TextRecognizer(script: TextRecognitionScript.latin);

  static Future<ParsedReceipt> recognize(File image) async {
    final input = InputImage.fromFile(image);
    final result = await _recognizer.processImage(input);
    return _parse(result.text);
  }

  static Future<void> dispose() async {
    await _recognizer.close();
  }

  static ParsedReceipt _parse(String text) {
    final lines = text
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();

    // 1) Total: look for keywords TOTAL, ИТОГО, СУМА, СУМ, USPLATA, RAZAM, РАЗАМ, СПЛАЦІЦЬ
    final totalKeywords = RegExp(
      r'(итог[оа]?|тотал|total|сум[ма]|разам|сплаціць|спл\.|к ?оплате|sum)\s*[:.]?',
      caseSensitive: false,
    );
    double? total;
    final amountRe = RegExp(r'(\d{1,3}(?:[ \u00a0]?\d{3})*(?:[.,]\d{1,2})|\d+[.,]\d{1,2}|\d+)');
    for (final l in lines) {
      if (totalKeywords.hasMatch(l)) {
        final m = amountRe.allMatches(l).toList();
        if (m.isNotEmpty) {
          final v = _toDouble(m.last.group(1)!);
          if (v != null && v > 0) {
            total = v;
            break;
          }
        }
      }
    }
    // Fallback: largest numeric value on the receipt with 2 decimals.
    total ??= _largestAmount(lines);

    // 2) Shop: usually first non-numeric, non-junk line.
    String? shop;
    for (final l in lines.take(6)) {
      final cleaned = l.replaceAll(RegExp(r'[^a-zа-яёА-ЯЁёA-Z0-9\s\-\.]', caseSensitive: false), '').trim();
      if (cleaned.length < 3) continue;
      if (RegExp(r'^[\d\s.,:\-/]+$').hasMatch(cleaned)) continue;
      shop = cleaned;
      break;
    }

    // 3) Date: 12.05.2025 / 2025-05-12 / 12/05/25
    DateTime? date;
    final dateRe = RegExp(
      r'(\d{1,2})[.\-/](\d{1,2})[.\-/](\d{2,4})|(\d{4})[.\-/](\d{1,2})[.\-/](\d{1,2})',
    );
    for (final l in lines) {
      final m = dateRe.firstMatch(l);
      if (m != null) {
        try {
          if (m.group(1) != null) {
            final dd = int.parse(m.group(1)!);
            final mm = int.parse(m.group(2)!);
            var yy = int.parse(m.group(3)!);
            if (yy < 100) yy += 2000;
            date = DateTime(yy, mm, dd);
          } else {
            date = DateTime(
              int.parse(m.group(4)!),
              int.parse(m.group(5)!),
              int.parse(m.group(6)!),
            );
          }
          break;
        } catch (_) {}
      }
    }

    // 4) Items: lines that contain text + amount, but not the total line.
    final items = <({String name, double price})>[];
    for (final l in lines) {
      if (totalKeywords.hasMatch(l)) continue;
      final m = amountRe.firstMatch(l);
      if (m == null) continue;
      final priceRaw = m.group(1)!;
      // require 2 decimals OR an obvious price-like token
      if (!priceRaw.contains('.') && !priceRaw.contains(',')) continue;
      final price = _toDouble(priceRaw);
      if (price == null || price <= 0) continue;
      final name = l.replaceAll(amountRe, '').replaceAll(RegExp(r'[*xXхХ]\s*\d+'), '').trim();
      if (name.length < 2) continue;
      if (items.length < 60) items.add((name: name, price: price));
    }

    return ParsedReceipt(
      rawText: text,
      total: total,
      shop: shop,
      date: date,
      items: items,
    );
  }

  static double? _toDouble(String s) {
    final cleaned = s.replaceAll(RegExp(r'[\s\u00a0]'), '').replaceAll(',', '.');
    return double.tryParse(cleaned);
  }

  static double? _largestAmount(List<String> lines) {
    final re = RegExp(r'\d+[.,]\d{2}');
    double? best;
    for (final l in lines) {
      for (final m in re.allMatches(l)) {
        final v = _toDouble(m.group(0)!);
        if (v == null) continue;
        if (best == null || v > best) best = v;
      }
    }
    return best;
  }
}
