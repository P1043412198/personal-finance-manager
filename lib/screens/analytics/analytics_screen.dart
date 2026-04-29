import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/transaction.dart';
import '../../providers/app_state.dart';
import '../../theme/app_theme.dart';
import '../../utils/format.dart';
import '../../utils/i18n.dart';
import '../../widgets/section.dart';

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  String _period = 'month';

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final i18n = context.watch<I18n>();
    final now = DateTime.now();
    final startDate = switch (_period) {
      'week' => now.subtract(const Duration(days: 7)),
      'month' => DateTime(now.year, now.month, 1),
      'year' => DateTime(now.year, 1, 1),
      _ => DateTime(2000),
    };

    final tx = app.txAll().where((t) => t.date.isAfter(startDate) && t.type == TxType.expense).toList();
    final byCat = <String, double>{};
    for (final t in tx) {
      byCat.update(t.categoryId ?? 'none', (v) => v + t.amount, ifAbsent: () => t.amount);
    }
    final total = tx.fold<double>(0, (a, t) => a + t.amount);
    final entries = byCat.entries.toList()..sort((a, b) => b.value.compareTo(a.value));

    // line chart: spending per day in last 30 days
    const lineDays = 30;
    final daily = List<double>.filled(lineDays, 0);
    for (final t in app.txAll().where((t) => t.type == TxType.expense)) {
      final diff = now.difference(DateTime(t.date.year, t.date.month, t.date.day)).inDays;
      if (diff >= 0 && diff < lineDays) {
        daily[lineDays - 1 - diff] += t.amount;
      }
    }

    return Scaffold(
      appBar: AppBar(title: Text(i18n.t('analytics'))),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 80),
        children: [
          Row(
            children: [
              for (final p in ['week', 'month', 'year', 'period'])
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: GestureDetector(
                    onTap: () => setState(() => _period = p),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: _period == p ? AppColors.primary : AppColors.muted,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        i18n.t(p),
                        style: TextStyle(
                            color: _period == p ? Colors.white : AppColors.textPrimary,
                            fontWeight: FontWeight.w600,
                            fontSize: 12),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          SectionHeader(title: i18n.t('expense_structure')),
          AppCard(
            padding: const EdgeInsets.all(16),
            child: entries.isEmpty
                ? Padding(
                    padding: const EdgeInsets.all(20),
                    child: Center(child: Text(i18n.t('no_data'), style: const TextStyle(color: AppColors.textSecondary))),
                  )
                : Row(
                    children: [
                      SizedBox(
                        width: 140,
                        height: 140,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            PieChart(
                              PieChartData(
                                centerSpaceRadius: 50,
                                sectionsSpace: 2,
                                startDegreeOffset: -90,
                                sections: [
                                  for (int i = 0; i < entries.length; i++)
                                    PieChartSectionData(
                                      value: entries[i].value,
                                      color: app.categoryById(entries[i].key)?.color ??
                                          Colors.primaries[i % Colors.primaries.length],
                                      radius: 16,
                                      showTitle: false,
                                    ),
                                ],
                              ),
                            ),
                            Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(Fmt.currency(total, symbol: app.currency),
                                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                                Text(i18n.t('total'),
                                    style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          children: [
                            for (final e in entries.take(5))
                              _LegendRow(
                                color: app.categoryById(e.key)?.color ?? AppColors.primary,
                                name: app.categoryById(e.key)?.name ?? '—',
                                pct: total == 0 ? 0 : ((e.value / total) * 100).round(),
                                value: e.value,
                                currency: app.currency,
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
          ),
          const SizedBox(height: 16),
          SectionHeader(title: i18n.t('expense_dynamic')),
          AppCard(
            padding: const EdgeInsets.fromLTRB(8, 14, 14, 14),
            child: SizedBox(
              height: 180,
              child: LineChart(LineChartData(
                gridData: const FlGridData(show: false),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 32,
                      getTitlesWidget: (v, meta) => Text(
                        '${(v / 1000).toStringAsFixed(0)}k',
                        style: const TextStyle(color: AppColors.textSecondary, fontSize: 10),
                      ),
                    ),
                  ),
                  bottomTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                lineBarsData: [
                  LineChartBarData(
                    spots: [
                      for (int i = 0; i < daily.length; i++) FlSpot(i.toDouble(), daily[i]),
                    ],
                    isCurved: true,
                    color: AppColors.primary,
                    barWidth: 2.5,
                    dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(
                      show: true,
                      color: AppColors.primary.withOpacity(0.18),
                    ),
                  ),
                ],
              )),
            ),
          ),
        ],
      ),
    );
  }
}

class _LegendRow extends StatelessWidget {
  final Color color;
  final String name;
  final int pct;
  final double value;
  final String currency;
  const _LegendRow(
      {required this.color,
      required this.name,
      required this.pct,
      required this.value,
      required this.currency});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 8),
          Expanded(child: Text(name, style: const TextStyle(fontSize: 12))),
          Text('$pct%', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
          const SizedBox(width: 6),
          Text(Fmt.currency(value, symbol: currency),
              style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
        ],
      ),
    );
  }
}
