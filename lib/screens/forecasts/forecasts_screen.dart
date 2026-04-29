import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/app_state.dart';
import '../../theme/app_theme.dart';
import '../../utils/forecast.dart';
import '../../utils/format.dart';
import '../../utils/i18n.dart';
import '../../widgets/sankey_chart.dart';
import '../../widgets/section.dart';

class ForecastsScreen extends StatefulWidget {
  const ForecastsScreen({super.key});

  @override
  State<ForecastsScreen> createState() => _ForecastsScreenState();
}

class _ForecastsScreenState extends State<ForecastsScreen> {
  int _horizon = 6;

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final i18n = context.watch<I18n>();
    final now = DateTime.now();
    final monthTx = app.txInMonth(now);
    final budget = app.budgetFor(now);
    final last30Start = now.subtract(const Duration(days: 30));
    final last30 = app
        .txAll()
        .where((t) => t.date.isAfter(last30Start) && t.date.isBefore(now))
        .toList();

    final eom = forecastEndOfMonth(
      month: now,
      txInMonth: monthTx,
      last30DaysTx: last30,
      plannedIncome: budget?.income ?? 0,
      now: now,
    );

    final history = monthlyHistory(
      endMonth: DateTime(now.year, now.month - 1),
      n: 6,
      allTx: app.txAll(),
      snapshots: app.snapshotsAll(),
    );
    final nw = netWorthProjection(
      history: history,
      horizonMonths: _horizon,
    );

    final sankey = buildSankey(
      txInMonth: monthTx,
      labelFor: (id) => id == null ? '—' : (app.categoryById(id)?.name ?? '—'),
      colorFor: (id) =>
          app.categoryById(id)?.colorValue ?? AppColors.primary.value,
    );

    final snapshots = app.snapshotsAll().reversed.toList();

    return Scaffold(
      appBar: AppBar(title: Text(i18n.t('forecasts'))),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          SectionHeader(title: i18n.t('forecast_eom')),
          AppCard(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(i18n.t('forecast_projected_net'),
                              style: const TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 12)),
                          const SizedBox(height: 4),
                          Text(
                            Fmt.currency(eom.projectedNet, symbol: app.currency),
                            style: TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.w800,
                              color: eom.projectedNet >= 0
                                  ? AppColors.income
                                  : AppColors.danger,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(i18n.t('forecast_projected_spent'),
                            style: const TextStyle(
                                color: AppColors.textSecondary, fontSize: 11)),
                        const SizedBox(height: 4),
                        Text(
                          Fmt.currency(eom.projectedSpent,
                              symbol: app.currency),
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _ForecastBar(
                  label: i18n.t('forecast_avg_per_day_30d'),
                  value: Fmt.currency(eom.avgDailySpend, symbol: app.currency),
                ),
                _ForecastBar(
                  label: i18n.t('expenses'),
                  value: Fmt.currency(eom.currentSpent, symbol: app.currency),
                ),
                _ForecastBar(
                  label: i18n.t('income'),
                  value: Fmt.currency(eom.currentIncome, symbol: app.currency),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(child: SectionHeader(title: i18n.t('net_worth'))),
              SegmentedButton<int>(
                segments: [
                  ButtonSegment(value: 6, label: Text(i18n.t('horizon_6m'))),
                  ButtonSegment(value: 12, label: Text(i18n.t('horizon_12m'))),
                ],
                selected: {_horizon},
                onSelectionChanged: (s) =>
                    setState(() => _horizon = s.first),
                showSelectedIcon: false,
                style: const ButtonStyle(
                  visualDensity: VisualDensity.compact,
                ),
              ),
            ],
          ),
          AppCard(
            padding: const EdgeInsets.fromLTRB(8, 16, 16, 8),
            child: SizedBox(
              height: 200,
              child: nw.isEmpty
                  ? Center(
                      child: Text(i18n.t('no_data_yet'),
                          style: const TextStyle(
                              color: AppColors.textSecondary)),
                    )
                  : _NetWorthChart(points: nw, currency: app.currency),
            ),
          ),
          const SizedBox(height: 18),
          SectionHeader(title: i18n.t('sankey_title')),
          AppCard(
            padding: const EdgeInsets.fromLTRB(8, 12, 8, 12),
            child: SankeyChart(
              data: sankey,
              centralLabel: i18n.t('budget'),
              height: 280,
            ),
          ),
          const SizedBox(height: 18),
          SectionHeader(title: i18n.t('snapshots')),
          if (snapshots.isEmpty)
            AppCard(
              padding: const EdgeInsets.all(20),
              child: Center(
                child: Text(i18n.t('no_data_yet'),
                    style:
                        const TextStyle(color: AppColors.textSecondary)),
              ),
            )
          else
            AppCard(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Column(
                children: [
                  for (final s in snapshots)
                    _SnapshotRow(
                      monthKey: s.monthKey,
                      income: s.income,
                      expense: s.expense,
                      net: s.net,
                      currency: app.currency,
                      topCategoryName: s.topCategoryId == null
                          ? null
                          : app.categoryById(s.topCategoryId)?.name,
                      topCategoryAmount: s.topCategoryAmount,
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _ForecastBar extends StatelessWidget {
  final String label;
  final String value;
  const _ForecastBar({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(label,
                style: const TextStyle(
                    color: AppColors.textSecondary, fontSize: 12)),
          ),
          Text(value,
              style: const TextStyle(
                  fontWeight: FontWeight.w700, fontSize: 13)),
        ],
      ),
    );
  }
}

class _NetWorthChart extends StatelessWidget {
  final List<NetWorthPoint> points;
  final String currency;
  const _NetWorthChart({required this.points, required this.currency});

  @override
  Widget build(BuildContext context) {
    final i18n = context.watch<I18n>();
    final actual = <FlSpot>[];
    final projected = <FlSpot>[];
    double minV = points.first.cumulative;
    double maxV = points.first.cumulative;
    for (var i = 0; i < points.length; i++) {
      final p = points[i];
      final spot = FlSpot(i.toDouble(), p.cumulative);
      if (p.projected) {
        projected.add(spot);
      } else {
        actual.add(spot);
      }
      if (p.cumulative < minV) minV = p.cumulative;
      if (p.cumulative > maxV) maxV = p.cumulative;
    }
    // bridge: copy last actual point into projected for visual continuity
    if (actual.isNotEmpty && projected.isNotEmpty) {
      projected.insert(0, actual.last);
    }
    final pad = (maxV - minV).abs() * 0.1 + 1;

    return LineChart(
      LineChartData(
        minX: 0,
        maxX: (points.length - 1).toDouble(),
        minY: minV - pad,
        maxY: maxV + pad,
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          getDrawingHorizontalLine: (_) =>
              FlLine(color: AppColors.muted, strokeWidth: 1),
        ),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 50,
              getTitlesWidget: (v, meta) => Padding(
                padding: const EdgeInsets.only(right: 4),
                child: Text(
                  Fmt.currency(v, symbol: currency, decimals: 0),
                  style: const TextStyle(
                      fontSize: 9, color: AppColors.textSecondary),
                ),
              ),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 26,
              interval: (points.length / 6).ceilToDouble(),
              getTitlesWidget: (v, meta) {
                final idx = v.toInt();
                if (idx < 0 || idx >= points.length) return const SizedBox();
                final mk = points[idx].monthKey;
                final parts = mk.split('-');
                return Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(parts[1],
                      style: const TextStyle(
                          fontSize: 9, color: AppColors.textSecondary)),
                );
              },
            ),
          ),
        ),
        borderData: FlBorderData(show: false),
        lineBarsData: [
          if (actual.isNotEmpty)
            LineChartBarData(
              spots: actual,
              isCurved: false,
              color: AppColors.primary,
              barWidth: 2.5,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(
                show: true,
                color: AppColors.primary.withOpacity(0.10),
              ),
            ),
          if (projected.isNotEmpty)
            LineChartBarData(
              spots: projected,
              isCurved: false,
              color: AppColors.warning,
              barWidth: 2,
              dashArray: const [6, 4],
              dotData: const FlDotData(show: false),
            ),
        ],
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (_) =>
                AppColors.textPrimary.withOpacity(0.92),
            getTooltipItems: (spots) => [
              for (final s in spots)
                LineTooltipItem(
                  '${points[s.x.toInt()].monthKey}\n${points[s.x.toInt()].projected ? i18n.t('projected') : i18n.t('historical')}: ${Fmt.currency(s.y, symbol: currency)}',
                  const TextStyle(color: Colors.white, fontSize: 10),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SnapshotRow extends StatelessWidget {
  final String monthKey;
  final double income;
  final double expense;
  final double net;
  final String currency;
  final String? topCategoryName;
  final double topCategoryAmount;
  const _SnapshotRow({
    required this.monthKey,
    required this.income,
    required this.expense,
    required this.net,
    required this.currency,
    required this.topCategoryName,
    required this.topCategoryAmount,
  });

  @override
  Widget build(BuildContext context) {
    final i18n = context.watch<I18n>();
    final positive = net >= 0;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        children: [
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.muted,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(monthKey,
                style: const TextStyle(
                    fontWeight: FontWeight.w700, fontSize: 12)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      Fmt.currency(net, symbol: currency),
                      style: TextStyle(
                          color: positive
                              ? AppColors.income
                              : AppColors.danger,
                          fontWeight: FontWeight.w800,
                          fontSize: 14),
                    ),
                  ],
                ),
                Text(
                  '+${Fmt.currency(income, symbol: currency)} / -${Fmt.currency(expense, symbol: currency)}',
                  style: const TextStyle(
                      color: AppColors.textSecondary, fontSize: 11),
                ),
                if (topCategoryName != null && topCategoryAmount > 0)
                  Text(
                    '${i18n.t('top_category')}: $topCategoryName · ${Fmt.currency(topCategoryAmount, symbol: currency)}',
                    style: const TextStyle(
                        color: AppColors.textSecondary, fontSize: 11),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
