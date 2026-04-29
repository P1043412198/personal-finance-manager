import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

class VoiceResult {
  final double? amount;
  final String? shop;
  const VoiceResult({this.amount, this.shop});
}

class VoiceInput {
  static final _speech = stt.SpeechToText();
  static bool _initialized = false;

  static Future<VoiceResult?> listen(BuildContext context, {String localeId = 'ru_RU'}) async {
    if (!_initialized) {
      _initialized = await _speech.initialize();
    }
    if (!_initialized) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Голосовой ввод недоступен на устройстве')),
      );
      return null;
    }
    String heard = '';
    final completer = ValueNotifier<bool>(false);
    await _speech.listen(
      localeId: localeId,
      onResult: (r) {
        heard = r.recognizedWords;
        if (r.finalResult) completer.value = true;
      },
      listenFor: const Duration(seconds: 8),
    );

    if (!context.mounted) return null;
    final ok = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(builder: (ctx, set) {
        completer.addListener(() => set(() {}));
        return AlertDialog(
          title: const Text('Слушаю…'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.mic, size: 56, color: Colors.red),
              const SizedBox(height: 12),
              Text(
                heard.isEmpty ? 'Скажите: "200 рублей кофе"' : heard,
                textAlign: TextAlign.center,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () async {
                await _speech.stop();
                Navigator.of(ctx).pop(false);
              },
              child: const Text('Отмена'),
            ),
            FilledButton(
              onPressed: () async {
                await _speech.stop();
                Navigator.of(ctx).pop(true);
              },
              child: const Text('Готово'),
            ),
          ],
        );
      }),
    );
    if (ok != true || heard.isEmpty) return null;
    return _parse(heard);
  }

  static VoiceResult _parse(String text) {
    // Find first number in the speech.
    final m = RegExp(r'(\d+[.,]?\d*)').firstMatch(text);
    double? amount;
    if (m != null) {
      amount = double.tryParse(m.group(1)!.replaceAll(',', '.'));
    }
    // Strip number + currency words to get shop
    var shop = text
        .replaceAll(RegExp(r'\d+[.,]?\d*'), '')
        .replaceAll(RegExp(r'\b(рубл\w*|руб|бр|byn|usd|евро|долл\w*)\b', caseSensitive: false), '')
        .trim();
    if (shop.isEmpty) shop = '';
    return VoiceResult(amount: amount, shop: shop.isEmpty ? null : shop);
  }
}
