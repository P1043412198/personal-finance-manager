import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../theme/app_theme.dart';
import '../../utils/i18n.dart';
import '../../models/transaction.dart';
import 'add_transaction_screen.dart';

class ScanReceiptScreen extends StatelessWidget {
  const ScanReceiptScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final i18n = context.watch<I18n>();
    return Scaffold(
      backgroundColor: const Color(0xFF3E2A1A),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(i18n.t('scan_receipt'),
            style: const TextStyle(color: Colors.white, fontSize: 18)),
        centerTitle: true,
        actions: const [
          Icon(Icons.bolt, color: Colors.white),
          SizedBox(width: 12),
        ],
      ),
      body: SafeArea(
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Faux receipt artwork
            Center(
              child: Container(
                width: 280,
                height: 360,
                decoration: BoxDecoration(
                  color: const Color(0xFFF7F2E8),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Padding(
                  padding: EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Center(
                        child: Text('🧾',
                            style: TextStyle(fontSize: 36)),
                      ),
                      SizedBox(height: 8),
                      Center(
                        child: Text('КАССОВЫЙ ЧЕК',
                            style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                      SizedBox(height: 14),
                      _ReceiptLine('Помидоры', '129.90'),
                      _ReceiptLine('Огурцы', '59.99'),
                      _ReceiptLine('Бананы', '71.99'),
                      _ReceiptLine('Молоко', '69.99'),
                      _ReceiptLine('Хлеб', '49.99'),
                      _ReceiptLine('Сыр', '199.99'),
                      Divider(),
                      _ReceiptLine('ИТОГО', '581.92'),
                      SizedBox(height: 10),
                      Center(
                        child: Text('СПАСИБО ЗА ПОКУПКУ!',
                            style: TextStyle(fontSize: 12)),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            // Frame corners
            Positioned.fill(
              child: CustomPaint(painter: _FramePainter()),
            ),
            // Bottom controls
            Positioned(
              bottom: 24,
              left: 0,
              right: 0,
              child: Column(
                children: [
                  Text(
                    i18n.lang == AppLang.ru
                        ? 'Наведите камеру на чек'
                        : 'Aim the camera at the receipt',
                    style: const TextStyle(color: Colors.white70),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.18),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(Icons.image, color: Colors.white),
                      ),
                      GestureDetector(
                        onTap: () {
                          Navigator.of(context).pushReplacement(
                            MaterialPageRoute(
                              builder: (_) =>
                                  const AddTransactionScreen(initialType: TxType.expense),
                            ),
                          );
                        },
                        child: Container(
                          width: 76,
                          height: 76,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            border: Border.all(color: AppColors.primary, width: 4),
                          ),
                        ),
                      ),
                      const SizedBox(width: 56),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReceiptLine extends StatelessWidget {
  final String name;
  final String price;
  const _ReceiptLine(this.name, this.price);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: Row(
        children: [
          Expanded(child: Text(name, style: const TextStyle(fontSize: 12))),
          Text(price, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _FramePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = AppColors.primary
      ..strokeWidth = 4
      ..style = PaintingStyle.stroke;
    const inset = 24.0;
    final w = size.width;
    final h = size.height;
    const corner = 36.0;
    // top-left
    canvas.drawLine(Offset(inset, inset + corner), Offset(inset, inset), p);
    canvas.drawLine(Offset(inset, inset), Offset(inset + corner, inset), p);
    // top-right
    canvas.drawLine(Offset(w - inset - corner, inset), Offset(w - inset, inset), p);
    canvas.drawLine(Offset(w - inset, inset), Offset(w - inset, inset + corner), p);
    // bottom-left
    canvas.drawLine(Offset(inset, h - inset - corner), Offset(inset, h - inset), p);
    canvas.drawLine(Offset(inset, h - inset), Offset(inset + corner, h - inset), p);
    // bottom-right
    canvas.drawLine(Offset(w - inset - corner, h - inset), Offset(w - inset, h - inset), p);
    canvas.drawLine(Offset(w - inset, h - inset - corner), Offset(w - inset, h - inset), p);
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}
