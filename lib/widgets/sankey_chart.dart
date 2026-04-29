import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../utils/forecast.dart';

/// Compact Sankey-style "Откуда → Куда" visualization. Income nodes are drawn
/// on the left, expense nodes on the right, connected by a central "Budget"
/// pillar with curved bands sized proportionally to the amount.
class SankeyChart extends StatelessWidget {
  final SankeyData data;
  final double height;
  final String centralLabel;
  const SankeyChart({
    super.key,
    required this.data,
    this.height = 320,
    this.centralLabel = 'Бюджет',
  });

  @override
  Widget build(BuildContext context) {
    if (data.incomes.isEmpty && data.expenses.isEmpty) {
      return SizedBox(
        height: 120,
        child: Center(
          child: Text('—',
              style: const TextStyle(color: AppColors.textSecondary)),
        ),
      );
    }
    return SizedBox(
      height: height,
      child: CustomPaint(
        size: Size.infinite,
        painter: _SankeyPainter(
          data: data,
          centralLabel: centralLabel,
        ),
      ),
    );
  }
}

class _SankeyPainter extends CustomPainter {
  final SankeyData data;
  final String centralLabel;
  _SankeyPainter({required this.data, required this.centralLabel});

  static const double _gap = 6;
  static const double _nodeWidth = 8;
  static const double _labelPad = 4;

  @override
  void paint(Canvas canvas, Size size) {
    final maxFlow = [
      data.totalIncome,
      data.totalExpense,
      1.0,
    ].reduce((a, b) => a > b ? a : b);

    // Reserve space for labels on either side.
    const labelW = 110.0;
    final innerLeft = labelW;
    final innerRight = size.width - labelW;
    final centerX = (innerLeft + innerRight) / 2;
    final innerHeight = size.height - 16;
    final topY = 8.0;

    // Heights (proportional, but at least visible).
    double scaleH(double v) => (v / maxFlow) * innerHeight;
    final incomeTotalH = scaleH(data.totalIncome);
    final expenseTotalH = scaleH(data.totalExpense);
    final centralH = (incomeTotalH > expenseTotalH ? incomeTotalH : expenseTotalH);

    final incomeStartY = topY + (innerHeight - incomeTotalH) / 2;
    final expenseStartY = topY + (innerHeight - expenseTotalH) / 2;
    final centralStartY = topY + (innerHeight - centralH) / 2;

    // Draw central pillar.
    final centralRect = Rect.fromLTWH(
      centerX - _nodeWidth / 2,
      centralStartY,
      _nodeWidth,
      centralH,
    );
    final centralPaint = Paint()..color = AppColors.primary;
    canvas.drawRRect(
      RRect.fromRectAndRadius(centralRect, const Radius.circular(3)),
      centralPaint,
    );

    final centralLabelTp = _textPainter(
      centralLabel,
      const TextStyle(
        color: AppColors.textPrimary,
        fontSize: 11,
        fontWeight: FontWeight.w700,
      ),
    );
    centralLabelTp.layout(maxWidth: 90);
    centralLabelTp.paint(
      canvas,
      Offset(
        centerX - centralLabelTp.width / 2,
        centralStartY - centralLabelTp.height - 2,
      ),
    );

    // Helper: paint a side bunch of nodes with curved bands to the central
    // pillar.
    void paintSide({
      required List<SankeyNode> nodes,
      required double startY,
      required double totalH,
      required bool isIncome,
    }) {
      if (nodes.isEmpty) return;
      final totalAmount = nodes.fold<double>(0, (a, n) => a + n.amount);
      if (totalAmount <= 0) return;
      double cursor = startY;
      double centralCursor = isIncome ? centralStartY : centralStartY;
      for (final n in nodes) {
        final h = totalH * (n.amount / totalAmount);
        final centralH2 = centralH * (n.amount / (data.totalIncome > 0 && isIncome
            ? data.totalIncome
            : (data.totalExpense > 0 && !isIncome ? data.totalExpense : totalAmount)));
        final color = Color(n.color);
        final nodeX = isIncome ? innerLeft - _nodeWidth : innerRight;
        // Node bar.
        final nodeRect = Rect.fromLTWH(nodeX, cursor, _nodeWidth, h);
        canvas.drawRRect(
          RRect.fromRectAndRadius(nodeRect, const Radius.circular(3)),
          Paint()..color = color,
        );
        // Curved band.
        final bandPath = Path();
        if (isIncome) {
          bandPath.moveTo(nodeX + _nodeWidth, cursor);
          bandPath.cubicTo(
            (nodeX + _nodeWidth + centerX) / 2, cursor,
            (nodeX + _nodeWidth + centerX) / 2, centralCursor,
            centerX - _nodeWidth / 2, centralCursor,
          );
          bandPath.lineTo(centerX - _nodeWidth / 2, centralCursor + centralH2);
          bandPath.cubicTo(
            (nodeX + _nodeWidth + centerX) / 2, centralCursor + centralH2,
            (nodeX + _nodeWidth + centerX) / 2, cursor + h,
            nodeX + _nodeWidth, cursor + h,
          );
          bandPath.close();
        } else {
          bandPath.moveTo(nodeX, cursor);
          bandPath.cubicTo(
            (nodeX + centerX) / 2, cursor,
            (nodeX + centerX) / 2, centralCursor,
            centerX + _nodeWidth / 2, centralCursor,
          );
          bandPath.lineTo(centerX + _nodeWidth / 2, centralCursor + centralH2);
          bandPath.cubicTo(
            (nodeX + centerX) / 2, centralCursor + centralH2,
            (nodeX + centerX) / 2, cursor + h,
            nodeX, cursor + h,
          );
          bandPath.close();
        }
        canvas.drawPath(
          bandPath,
          Paint()
            ..color = color.withOpacity(0.35)
            ..style = PaintingStyle.fill,
        );
        // Label.
        final labelTp = _textPainter(
          n.label,
          const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 10,
              fontWeight: FontWeight.w600),
        );
        labelTp.layout(maxWidth: labelW - _labelPad - 4);
        final labelX = isIncome
            ? (nodeX - labelTp.width - _labelPad)
            : (nodeX + _nodeWidth + _labelPad);
        labelTp.paint(
          canvas,
          Offset(labelX, cursor + (h - labelTp.height) / 2),
        );
        cursor += h + _gap;
        centralCursor += centralH2;
      }
    }

    paintSide(
      nodes: data.incomes,
      startY: incomeStartY,
      totalH: incomeTotalH,
      isIncome: true,
    );
    paintSide(
      nodes: data.expenses,
      startY: expenseStartY,
      totalH: expenseTotalH,
      isIncome: false,
    );
  }

  TextPainter _textPainter(String text, TextStyle style) {
    return TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
      maxLines: 2,
      ellipsis: '…',
    );
  }

  @override
  bool shouldRepaint(covariant _SankeyPainter old) =>
      old.data != data || old.centralLabel != centralLabel;
}
