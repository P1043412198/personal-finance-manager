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

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final all = app.txAll()
        .where((t) => (t.attachmentPath ?? '').isNotEmpty)
        .where((t) => File(t.attachmentPath!).existsSync())
        .toList()
      ..sort((a, b) => b.date.compareTo(a.date));
    final q = _query.trim().toLowerCase();
    final filtered = q.isEmpty
        ? all
        : all.where((t) {
            return (t.shop ?? '').toLowerCase().contains(q) ||
                t.amount.toStringAsFixed(2).contains(q);
          }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Чеки'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: TextField(
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
