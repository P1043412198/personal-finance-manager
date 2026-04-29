import 'package:flutter/services.dart' show rootBundle;
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../models/budget.dart';
import '../models/transaction.dart';
import 'budget_calc.dart';

/// Build a "plan vs actual" PDF for the given month.
Future<pw.Document> buildBudgetPdf({
  required DateTime month,
  required Iterable<TransactionModel> txInMonth,
  required MonthlyBudget? budget,
  required List<CategoryPlanFact> categories,
  required BudgetMetrics metrics,
  required String currencySymbol,
  required String localeCode, // 'ru' | 'en'
  Map<String, String> labels = const {},
}) async {
  final doc = pw.Document();

  // Try to use a font that supports Cyrillic. Fall back to default if missing.
  pw.Font? base;
  pw.Font? bold;
  try {
    base = await PdfGoogleFonts.robotoRegular();
    bold = await PdfGoogleFonts.robotoBold();
  } catch (_) {
    base = null;
    bold = null;
  }
  // Suppress unused warning if assets bundle isn't required.
  // ignore: unused_local_variable
  final _ = rootBundle;

  String txt(String key, String fallback) => labels[key] ?? fallback;

  final fmt = NumberFormat.currency(
    locale: localeCode == 'ru' ? 'ru_RU' : 'en_US',
    symbol: currencySymbol,
    decimalDigits: 0,
  );
  String money(double v) => fmt.format(v).replaceAll('\u00A0', ' ');

  final monthName = DateFormat('LLLL yyyy', localeCode).format(month);

  pw.Widget statRow(String label, String plan, String fact, String delta,
      {PdfColor color = PdfColors.black}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 4),
      child: pw.Row(
        children: [
          pw.Expanded(flex: 3, child: pw.Text(label)),
          pw.Expanded(
              flex: 2,
              child: pw.Text(plan, textAlign: pw.TextAlign.right)),
          pw.Expanded(
              flex: 2,
              child: pw.Text(fact, textAlign: pw.TextAlign.right)),
          pw.Expanded(
            flex: 2,
            child: pw.Text(delta,
                textAlign: pw.TextAlign.right,
                style: pw.TextStyle(color: color)),
          ),
        ],
      ),
    );
  }

  final theme = pw.ThemeData.withFont(
    base: base ?? pw.Font.helvetica(),
    bold: bold ?? pw.Font.helveticaBold(),
  );

  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      theme: theme,
      build: (ctx) => [
        pw.Text(txt('title', 'Бюджет: план vs факт'),
            style: pw.TextStyle(
                fontSize: 22, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 4),
        pw.Text('${txt('period', 'Период')}: $monthName',
            style: const pw.TextStyle(color: PdfColors.grey700)),
        pw.SizedBox(height: 16),
        pw.Container(
          padding: const pw.EdgeInsets.all(12),
          decoration: pw.BoxDecoration(
            color: PdfColors.grey100,
            borderRadius: pw.BorderRadius.circular(8),
          ),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(txt('summary', 'Итоги'),
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 8),
              pw.Row(
                children: [
                  pw.Expanded(
                      flex: 3,
                      child: pw.Text('',
                          style: const pw.TextStyle(
                              color: PdfColors.grey700))),
                  pw.Expanded(
                      flex: 2,
                      child: pw.Text(txt('plan', 'План'),
                          textAlign: pw.TextAlign.right,
                          style: const pw.TextStyle(
                              color: PdfColors.grey700))),
                  pw.Expanded(
                      flex: 2,
                      child: pw.Text(txt('fact', 'Факт'),
                          textAlign: pw.TextAlign.right,
                          style: const pw.TextStyle(
                              color: PdfColors.grey700))),
                  pw.Expanded(
                      flex: 2,
                      child: pw.Text(txt('delta', 'Отклонение'),
                          textAlign: pw.TextAlign.right,
                          style: const pw.TextStyle(
                              color: PdfColors.grey700))),
                ],
              ),
              pw.Divider(),
              statRow(
                txt('income', 'Доход'),
                money(metrics.plannedIncome),
                money(metrics.income),
                _signed(metrics.income - metrics.plannedIncome, money),
                color: metrics.income >= metrics.plannedIncome
                    ? PdfColors.green700
                    : PdfColors.red700,
              ),
              statRow(
                txt('expense', 'Расход'),
                money(metrics.plannedExpense),
                money(metrics.expense),
                _signed(metrics.expense - metrics.plannedExpense, money),
                color: metrics.expense <= metrics.plannedExpense
                    ? PdfColors.green700
                    : PdfColors.red700,
              ),
              statRow(
                txt('free_funds', 'Свободные средства'),
                money(metrics.freeFundsPlan),
                money(metrics.freeFundsFact),
                _signed(metrics.freeFundsFact - metrics.freeFundsPlan, money),
                color: metrics.freeFundsFact >= metrics.freeFundsPlan
                    ? PdfColors.green700
                    : PdfColors.red700,
              ),
            ],
          ),
        ),
        pw.SizedBox(height: 16),
        pw.Text(txt('categories', 'По категориям'),
            style: pw.TextStyle(
                fontSize: 16, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 8),
        pw.Table(
          border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
          columnWidths: {
            0: const pw.FlexColumnWidth(3),
            1: const pw.FlexColumnWidth(2),
            2: const pw.FlexColumnWidth(2),
            3: const pw.FlexColumnWidth(2),
          },
          children: [
            pw.TableRow(
              decoration: const pw.BoxDecoration(color: PdfColors.grey100),
              children: [
                _cell(txt('category', 'Категория'), bold: true),
                _cell(txt('plan', 'План'), bold: true, align: pw.TextAlign.right),
                _cell(txt('fact', 'Факт'), bold: true, align: pw.TextAlign.right),
                _cell(txt('delta', 'Отклонение'),
                    bold: true, align: pw.TextAlign.right),
              ],
            ),
            for (final c in categories)
              pw.TableRow(children: [
                _cell('${c.emoji} ${c.name}'),
                _cell(money(c.plan), align: pw.TextAlign.right),
                _cell(money(c.fact), align: pw.TextAlign.right),
                _cell(_signed(c.delta, money),
                    align: pw.TextAlign.right,
                    color: c.delta > 0
                        ? PdfColors.red700
                        : (c.delta < 0
                            ? PdfColors.green700
                            : PdfColors.black)),
              ]),
          ],
        ),
        pw.SizedBox(height: 24),
        pw.Text(
          'Generated by Personal Finance Manager · ${DateFormat('d MMM yyyy, HH:mm', localeCode).format(DateTime.now())}',
          style: const pw.TextStyle(color: PdfColors.grey500, fontSize: 9),
        ),
      ],
    ),
  );

  return doc;
}

String _signed(double v, String Function(double) money) {
  if (v == 0) return money(0);
  final sign = v > 0 ? '+' : '−';
  return '$sign${money(v.abs())}';
}

pw.Widget _cell(String text,
    {bool bold = false,
    pw.TextAlign align = pw.TextAlign.left,
    PdfColor color = PdfColors.black}) {
  return pw.Padding(
    padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
    child: pw.Text(
      text,
      textAlign: align,
      style: pw.TextStyle(
        fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
        color: color,
      ),
    ),
  );
}
