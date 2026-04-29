import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';

import '../../models/transaction.dart';
import '../../services/receipt_ocr.dart';
import '../../theme/app_theme.dart';
import '../../utils/i18n.dart';
import '../../widgets/section.dart';
import 'add_transaction_screen.dart';

class ScanReceiptScreen extends StatefulWidget {
  const ScanReceiptScreen({super.key});

  @override
  State<ScanReceiptScreen> createState() => _ScanReceiptScreenState();
}

class _ScanReceiptScreenState extends State<ScanReceiptScreen> {
  final _picker = ImagePicker();
  bool _busy = false;
  File? _image;
  ParsedReceipt? _parsed;
  String? _savedPath;

  Future<void> _pick(ImageSource source) async {
    setState(() => _busy = true);
    try {
      final x = await _picker.pickImage(
        source: source,
        imageQuality: 88,
        maxWidth: 2200,
      );
      if (x == null) return;
      // Persist photo to app docs dir so it survives across sessions.
      final dir = await getApplicationDocumentsDirectory();
      final receiptsDir = Directory('${dir.path}/receipts');
      if (!await receiptsDir.exists()) await receiptsDir.create(recursive: true);
      final ts = DateTime.now().millisecondsSinceEpoch;
      final dest = File('${receiptsDir.path}/r_$ts.jpg');
      await File(x.path).copy(dest.path);

      final parsed = await ReceiptOcr.recognize(dest);
      if (!mounted) return;
      setState(() {
        _image = dest;
        _parsed = parsed;
        _savedPath = dest.path;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка распознавания: $e')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final i18n = context.watch<I18n>();
    return Scaffold(
      backgroundColor: const Color(0xFF1F1A14),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(i18n.t('scan_receipt'),
            style: const TextStyle(color: Colors.white, fontSize: 18)),
        centerTitle: true,
      ),
      body: SafeArea(
        child: _busy
            ? const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(color: Colors.white),
                    SizedBox(height: 12),
                    Text('Распознаю чек…',
                        style: TextStyle(color: Colors.white)),
                  ],
                ),
              )
            : _image == null
                ? _PickPrompt(
                    onCamera: () => _pick(ImageSource.camera),
                    onGallery: () => _pick(ImageSource.gallery),
                  )
                : _ParsedView(
                    image: _image!,
                    parsed: _parsed,
                    savedPath: _savedPath!,
                    onRetake: () {
                      setState(() {
                        _image = null;
                        _parsed = null;
                        _savedPath = null;
                      });
                    },
                  ),
      ),
    );
  }
}

class _PickPrompt extends StatelessWidget {
  final VoidCallback onCamera;
  final VoidCallback onGallery;
  const _PickPrompt({required this.onCamera, required this.onGallery});

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        Center(
          child: Container(
            width: 280,
            height: 360,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.white24, width: 2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Center(
              child: Text('🧾',
                  style: TextStyle(fontSize: 80, color: Colors.white70)),
            ),
          ),
        ),
        Positioned(
          bottom: 24,
          left: 0,
          right: 0,
          child: Column(
            children: [
              const Text(
                'Сфотографируйте чек или выберите из галереи',
                style: TextStyle(color: Colors.white70),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  GestureDetector(
                    onTap: onGallery,
                    child: Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.18),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(Icons.image, color: Colors.white),
                    ),
                  ),
                  GestureDetector(
                    onTap: onCamera,
                    child: Container(
                      width: 76,
                      height: 76,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        border:
                            Border.all(color: AppColors.primary, width: 4),
                      ),
                      child: const Icon(Icons.camera_alt, size: 32),
                    ),
                  ),
                  const SizedBox(width: 56),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ParsedView extends StatelessWidget {
  final File image;
  final ParsedReceipt? parsed;
  final String savedPath;
  final VoidCallback onRetake;

  const _ParsedView({
    required this.image,
    required this.parsed,
    required this.savedPath,
    required this.onRetake,
  });

  @override
  Widget build(BuildContext context) {
    final p = parsed;
    return Container(
      color: AppColors.background,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.file(image, height: 220, fit: BoxFit.cover),
          ),
          const SizedBox(height: 12),
          AppCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Распознано',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                const SizedBox(height: 8),
                _kv('Сумма',
                    p?.total != null ? p!.total!.toStringAsFixed(2) : '—'),
                _kv('Магазин', p?.shop ?? '—'),
                _kv(
                    'Дата',
                    p?.date != null
                        ? '${p!.date!.day.toString().padLeft(2, '0')}.${p.date!.month.toString().padLeft(2, '0')}.${p.date!.year}'
                        : '—'),
                _kv('Позиций', '${p?.items.length ?? 0}'),
                if (p != null && p.items.isNotEmpty) ...[
                  const Divider(),
                  for (final it in p.items.take(20))
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Row(children: [
                        Expanded(child: Text(it.name, maxLines: 1, overflow: TextOverflow.ellipsis)),
                        Text(it.price.toStringAsFixed(2),
                            style: const TextStyle(fontWeight: FontWeight.w600)),
                      ]),
                    ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: onRetake,
                icon: const Icon(Icons.refresh),
                label: const Text('Другое фото'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              flex: 2,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(
                      builder: (_) => AddTransactionScreen(
                        initialType: TxType.expense,
                        prefill: TransactionPrefill(
                          amount: p?.total,
                          shop: p?.shop,
                          date: p?.date,
                          attachmentPath: savedPath,
                        ),
                      ),
                    ),
                  );
                },
                icon: const Icon(Icons.check),
                label: const Text('Создать операцию'),
              ),
            ),
          ]),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _kv(String k, String v) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(children: [
          Expanded(
            flex: 2,
            child: Text(k, style: const TextStyle(color: AppColors.textSecondary)),
          ),
          Expanded(
            flex: 3,
            child: Text(v,
                style: const TextStyle(fontWeight: FontWeight.w600),
                textAlign: TextAlign.right),
          ),
        ]),
      );
}
