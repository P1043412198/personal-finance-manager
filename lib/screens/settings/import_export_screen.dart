import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../models/budget.dart';
import '../../models/category.dart';
import '../../models/debt.dart';
import '../../models/goal.dart';
import '../../models/habit.dart';
import '../../models/note.dart';
import '../../models/recurring.dart';
import '../../models/rule.dart';
import '../../models/task.dart';
import '../../models/template.dart';
import '../../models/transaction.dart';
import '../../models/wallet.dart';
import '../../providers/app_state.dart';
import '../../theme/app_theme.dart';
import '../../services/pdf_export.dart';
import '../../utils/i18n.dart';
import '../../widgets/section.dart';

class ImportExportScreen extends StatelessWidget {
  const ImportExportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.read<AppState>();
    final i18n = context.watch<I18n>();
    return Scaffold(
      appBar: AppBar(title: Text(i18n.t('import_export'))),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          AppCard(
            child: Column(children: [
              ListTile(
                leading: const Icon(Icons.cloud_upload, color: AppColors.primary),
                title: Text(i18n.t('export_json')),
                subtitle: Text(i18n.t('export_full_hint'),
                    style: const TextStyle(fontSize: 12)),
                onTap: () => _exportJson(context, app),
              ),
              ListTile(
                leading: const Icon(Icons.text_snippet, color: AppColors.primary),
                title: Text(i18n.t('export_csv')),
                subtitle: Text(i18n.t('export_csv_hint'),
                    style: const TextStyle(fontSize: 12)),
                onTap: () => _exportCsv(context, app),
              ),
              ListTile(
                leading: const Icon(Icons.cloud_download, color: AppColors.primary),
                title: Text(i18n.t('import_json')),
                subtitle: Text(i18n.t('import_hint'),
                    style: const TextStyle(fontSize: 12)),
                onTap: () => _importJson(context, app),
              ),
              ListTile(
                leading: const Icon(Icons.import_export, color: AppColors.primary),
                title: Text(i18n.t('import_csv')),
                subtitle: Text(i18n.t('import_csv_hint'),
                    style: const TextStyle(fontSize: 12)),
                onTap: () => _importCsv(context, app),
              ),
              ListTile(
                leading: const Icon(Icons.picture_as_pdf, color: AppColors.primary),
                title: const Text('PDF отчёт за месяц'),
                subtitle: const Text('Экспорт операций и сводки в PDF',
                    style: TextStyle(fontSize: 12)),
                onTap: () => PdfExport.exportMonth(app, DateTime.now()),
              ),
              ListTile(
                leading: const Icon(Icons.backup, color: AppColors.primary),
                title: Text(i18n.t('backup_now')),
                subtitle: Text(i18n.t('backup_hint'),
                    style: const TextStyle(fontSize: 12)),
                onTap: () => _backup(context, app),
              ),
            ]),
          ),
        ],
      ),
    );
  }

  Map<String, dynamic> _fullDump(AppState app) => {
        'version': 2,
        'exported_at': DateTime.now().toIso8601String(),
        'categories': app.categories.all().map((c) => c.toJson()).toList(),
        'transactions': app.txAll().map((t) => t.toJson()).toList(),
        'tasks': app.taskAll().map((t) => t.toJson()).toList(),
        'habits': app.habitAll().map((h) => h.toJson()).toList(),
        'habit_logs': [
          for (final k in app.habitLogs.keys) {'k': k, 'v': app.habitLogs.get(k as String)}
        ],
        'notes': app.noteAll().map((n) => n.toJson()).toList(),
        'goals': app.goalAll().map((g) => g.toJson()).toList(),
        'budgets': app.budgets.all().map((b) => b.toJson()).toList(),
        'wallets': app.wallets.all().map((w) => w.toJson()).toList(),
        'recurring': app.recurring.all().map((r) => r.toJson()).toList(),
        'debts': app.debts.all().map((d) => d.toJson()).toList(),
        'rules': app.rules.all().map((r) => r.toJson()).toList(),
        'templates': app.templates.all().map((t) => t.toJson()).toList(),
        'rates': app.rates.all().map((r) => r.toJson()).toList(),
      };

  Future<void> _exportJson(BuildContext context, AppState app) async {
    final dir = await getTemporaryDirectory();
    final f = File('${dir.path}/pfm_full_${DateTime.now().millisecondsSinceEpoch}.json');
    await f.writeAsString(jsonEncode(_fullDump(app)));
    await Share.shareXFiles([XFile(f.path)], text: 'Personal finance backup');
  }

  Future<void> _exportCsv(BuildContext context, AppState app) async {
    final lines = <String>['date,type,amount,currency,category,wallet,shop,comment,method'];
    for (final t in app.txAll()) {
      final cat = app.categoryById(t.categoryId)?.name ?? '';
      final w = t.walletId != null ? (app.wallets.get(t.walletId!)?.name ?? '') : '';
      lines.add(
          '${t.date.toIso8601String()},${t.type.name},${t.amount},${t.currency},"$cat","$w","${(t.shop ?? '').replaceAll('"', '""')}","${(t.comment ?? '').replaceAll('"', '""')}",${t.method.name}');
    }
    final dir = await getTemporaryDirectory();
    final f = File('${dir.path}/transactions_${DateTime.now().millisecondsSinceEpoch}.csv');
    await f.writeAsString(lines.join('\n'));
    await Share.shareXFiles([XFile(f.path)], text: 'Transactions CSV');
  }

  Future<void> _backup(BuildContext context, AppState app) async {
    final dir = await getApplicationDocumentsDirectory();
    final backup = Directory('${dir.path}/backups');
    if (!await backup.exists()) await backup.create(recursive: true);
    final f = File('${backup.path}/backup_${DateTime.now().millisecondsSinceEpoch}.json');
    await f.writeAsString(jsonEncode(_fullDump(app)));
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Бэкап создан: ${f.path}')),
      );
    }
  }

  Future<void> _importJson(BuildContext context, AppState app) async {
    final res = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
    );
    if (res == null || res.files.isEmpty) return;
    try {
      final text = await File(res.files.single.path!).readAsString();
      final j = jsonDecode(text) as Map;
      int imported = 0;
      if (j['categories'] is List) {
        for (final c in j['categories'] as List) {
          await app.categories.put(CategoryModel.fromJson(c as Map));
          imported++;
        }
      }
      if (j['transactions'] is List) {
        for (final t in j['transactions'] as List) {
          await app.transactions.put(TransactionModel.fromJson(t as Map));
          imported++;
        }
      }
      if (j['tasks'] is List) {
        for (final t in j['tasks'] as List) {
          await app.tasks.put(TaskModel.fromJson(t as Map));
          imported++;
        }
      }
      if (j['habits'] is List) {
        for (final h in j['habits'] as List) {
          await app.habits.put(HabitModel.fromJson(h as Map));
          imported++;
        }
      }
      if (j['habit_logs'] is List) {
        for (final e in j['habit_logs'] as List) {
          if (e is Map) await app.habitLogs.put(e['k'] as String, e['v']);
        }
      }
      if (j['notes'] is List) {
        for (final n in j['notes'] as List) {
          await app.notes.put(NoteModel.fromJson(n as Map));
          imported++;
        }
      }
      if (j['goals'] is List) {
        for (final g in j['goals'] as List) {
          await app.goals.put(GoalModel.fromJson(g as Map));
          imported++;
        }
      }
      if (j['budgets'] is List) {
        for (final b in j['budgets'] as List) {
          await app.budgets.put(MonthlyBudget.fromJson(b as Map));
          imported++;
        }
      }
      if (j['wallets'] is List) {
        for (final w in j['wallets'] as List) {
          await app.wallets.put(WalletModel.fromJson(w as Map));
          imported++;
        }
      }
      if (j['recurring'] is List) {
        for (final r in j['recurring'] as List) {
          await app.recurring.put(RecurringTxModel.fromJson(r as Map));
          imported++;
        }
      }
      if (j['debts'] is List) {
        for (final d in j['debts'] as List) {
          await app.debts.put(DebtModel.fromJson(d as Map));
          imported++;
        }
      }
      if (j['rules'] is List) {
        for (final r in j['rules'] as List) {
          await app.rules.put(CategoryRule.fromJson(r as Map));
          imported++;
        }
      }
      if (j['templates'] is List) {
        for (final t in j['templates'] as List) {
          await app.templates.put(TxTemplate.fromJson(t as Map));
          imported++;
        }
      }
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Импортировано записей: $imported')),
        );
      }
      app.notify();
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка импорта: $e')),
        );
      }
    }
  }

  Future<void> _importCsv(BuildContext context, AppState app) async {
    final res = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv'],
    );
    if (res == null || res.files.isEmpty) return;
    try {
      final text = await File(res.files.single.path!).readAsString();
      final lines = const LineSplitter().convert(text);
      var imported = 0;
      for (var i = 1; i < lines.length; i++) {
        final parts = _parseCsvLine(lines[i]);
        if (parts.length < 3) continue;
        final date = DateTime.tryParse(parts[0]) ?? DateTime.now();
        final type = parts[1] == 'income' ? TxType.income : TxType.expense;
        final amount = double.tryParse(parts[2]) ?? 0;
        if (amount <= 0) continue;
        final t = TransactionModel(
          id: app.newId(),
          type: type,
          amount: amount,
          currency: parts.length > 3 ? parts[3] : app.currency,
          shop: parts.length > 6 ? parts[6] : null,
          comment: parts.length > 7 ? parts[7] : null,
          date: date,
        );
        await app.transactions.put(t);
        imported++;
      }
      app.notify();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('CSV: импортировано $imported транзакций')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ошибка: $e')));
      }
    }
  }

  List<String> _parseCsvLine(String line) {
    final result = <String>[];
    final sb = StringBuffer();
    var inQ = false;
    for (var i = 0; i < line.length; i++) {
      final c = line[i];
      if (c == '"') {
        if (inQ && i + 1 < line.length && line[i + 1] == '"') {
          sb.write('"');
          i++;
        } else {
          inQ = !inQ;
        }
      } else if (c == ',' && !inQ) {
        result.add(sb.toString());
        sb.clear();
      } else {
        sb.write(c);
      }
    }
    result.add(sb.toString());
    return result;
  }
}
