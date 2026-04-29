import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/transaction.dart';
import '../../providers/app_state.dart';
import '../../theme/app_theme.dart';
import '../../utils/format.dart';
import '../../widgets/section.dart';
import '../transaction/add_transaction_screen.dart';

class ReceiptsScreen extends StatefulWidget {
  const ReceiptsScreen({super.key});

  @override
  State<ReceiptsScreen> createState() => _ReceiptsScreenState();
}

class _ReceiptsScreenState extends State<ReceiptsScreen> {
  String _query = '';
  DateTimeRange? _range;

  Future<void> _pickRange(BuildContext context) async {
    final now = DateTime.now();
    final r = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 1),
      initialDateRange: _range,
    );
    if (r != null) setState(() => _range = r);
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final all = app.txAll()
        .where((t) => (t.attachmentPath ?? '').isNotEmpty)
        .where((t) => File(t.attachmentPath!).existsSync())
        .toList()
      ..sort((a, b) => b.date.compareTo(a.date));
    final q = _query.trim().toLowerCase();
    Iterable<TransactionModel> result = all;
    if (q.isNotEmpty) {
      result = result.where((t) =>
          (t.shop ?? '').toLowerCase().contains(q) ||
          t.amount.toStringAsFixed(2).contains(q));
    }
    if (_range != null) {
      final from = DateTime(_range!.start.year, _range!.start.month, _range!.start.day);
      final to = DateTime(_range!.end.year, _range!.end.month, _range!.end.day, 23, 59, 59);
      result = result.where((t) => !t.date.isBefore(from) && !t.date.isAfter(to));
    }
    final filtered = result.toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Чеки'),
        actions: [
          IconButton(
            tooltip: 'Период',
            icon: Icon(_range == null ? Icons.date_range : Icons.event_available,
                color: _range == null ? null : AppColors.primary),
            onPressed: () => _pickRange(context),
          ),
          if (_range != null)
            IconButton(
              tooltip: 'Сбросить период',
              icon: const Icon(Icons.clear),
              onPressed: () => setState(() => _range = null),
            ),
        ],
        bottom: PreferredSize(
          preferredSize: Size.fromHeight(_range == null ? 56 : 80),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  onChanged: (v) => setState(() => _query = v),
                  decoration: InputDecoration(
                    hintText: 'Поиск по магазину или сумме',
                    prefixIcon: const Icon(Icons.search),
                    filled: true,
                    isDense: true,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                if (_range != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      'Период: ${Fmt.shortDate(_range!.start)} – ${Fmt.shortDate(_range!.end)}',
                      style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
      body: filtered.isEmpty
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(40),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('🧾', style: TextStyle(fontSize: 64)),
                    SizedBox(height: 12),
                    Text(
                      'Нет сохранённых чеков',
                      style: TextStyle(fontSize: 16, color: AppColors.textSecondary),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Сфотографируйте чек на экране сканера — он сохранится сюда',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
            )
          : GridView.builder(
              padding: const EdgeInsets.all(12),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 0.7,
              ),
              itemCount: filtered.length,
              itemBuilder: (ctx, i) {
                final t = filtered[i];
                return _ReceiptTile(tx: t);
              },
            ),
    );
  }
}

class _ReceiptTile extends StatelessWidget {
  final TransactionModel tx;
  const _ReceiptTile({required this.tx});

  @override
  Widget build(BuildContext context) {
    final app = context.read<AppState>();
    final cat = tx.categoryId == null ? null : app.categoryById(tx.categoryId!);
    return GestureDetector(
      onTap: () => Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => AddTransactionScreen(existing: tx),
      )),
      child: AppCard(
        padding: EdgeInsets.zero,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
                child: Image.file(
                  File(tx.attachmentPath!),
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) =>
                      const Center(child: Icon(Icons.broken_image)),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    tx.shop ?? cat?.name ?? '—',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    Fmt.currency(tx.amount, symbol: tx.currency),
                    style: const TextStyle(
                        color: AppColors.expense, fontWeight: FontWeight.w600),
                  ),
                  Text(
                    Fmt.shortDate(tx.date),
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.textSecondary),
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
