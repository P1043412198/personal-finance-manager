import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../models/transaction.dart';
import '../providers/app_state.dart';

class PdfExport {
  static Future<void> exportMonth(AppState app, DateTime month) async {
    final tx = app.txInMonth(month);
    final income = tx.where((t) => t.type == TxType.income).fold<double>(0, (a, t) => a + t.amount);
    final expense = tx.where((t) => t.type == TxType.expense).fold<double>(0, (a, t) => a + t.amount);
    final byCat = <String, double>{};
    for (final t in tx.where((t) => t.type == TxType.expense)) {
      final c = app.categoryById(t.categoryId)?.name ?? '—';
      byCat[c] = (byCat[c] ?? 0) + t.amount;
    }
    final pdf = pw.Document();
    final fmt = NumberFormat('#,##0.00', 'ru');
    final df = DateFormat('dd.MM.yyyy', 'ru');
    pdf.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      build: (ctx) => [
        pw.Header(
          level: 0,
          child: pw.Text('Отчёт за ${DateFormat('LLLL yyyy', 'ru').format(month)}',
              style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold)),
        ),
        pw.SizedBox(height: 12),
        pw.Row(children: [
          pw.Expanded(
            child: _box('Доходы', '${fmt.format(income)} ${app.currency}', PdfColors.green700),
          ),
          pw.SizedBox(width: 8),
          pw.Expanded(
            child: _box('Расходы', '${fmt.format(expense)} ${app.currency}', PdfColors.red700),
          ),
          pw.SizedBox(width: 8),
          pw.Expanded(
            child: _box('Баланс', '${fmt.format(income - expense)} ${app.currency}', PdfColors.blue700),
          ),
        ]),
        pw.SizedBox(height: 24),
        pw.Text('По категориям', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 8),
        pw.Table.fromTextArray(
          headers: ['Категория', 'Сумма'],
          data: byCat.entries
              .toList()
              .also((l) => l.sort((a, b) => b.value.compareTo(a.value)))
              .map((e) => [e.key, '${fmt.format(e.value)} ${app.currency}'])
              .toList(),
          headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 24),
        pw.Text('Все операции', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 8),
        pw.Table.fromTextArray(
          headers: ['Дата', 'Тип', 'Магазин', 'Категория', 'Сумма'],
          data: tx
              .map((t) => [
                    df.format(t.date),
                    t.type == TxType.expense ? 'Расход' : 'Доход',
                    t.shop ?? '',
                    app.categoryById(t.categoryId)?.name ?? '—',
                    '${t.type == TxType.expense ? '-' : '+'}${fmt.format(t.amount)} ${t.currency}',
                  ])
              .toList(),
          headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
          cellAlignment: pw.Alignment.centerLeft,
        ),
      ],
    ));
    await Printing.sharePdf(
      bytes: await pdf.save(),
      filename: 'finance-${DateFormat('yyyy-MM').format(month)}.pdf',
    );
  }

  static pw.Widget _box(String label, String value, PdfColor color) => pw.Container(
        padding: const pw.EdgeInsets.all(12),
        decoration: pw.BoxDecoration(
          color: PdfColors.grey100,
          borderRadius: pw.BorderRadius.circular(8),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(label, style: pw.TextStyle(color: color, fontSize: 11, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 4),
            pw.Text(value, style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
          ],
        ),
      );
}

extension _Also<T> on T {
  T also(void Function(T) fn) {
    fn(this);
    return this;
  }
}
