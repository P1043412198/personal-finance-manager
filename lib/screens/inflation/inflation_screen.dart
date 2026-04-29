import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../theme/app_theme.dart';
import '../../utils/i18n.dart';
import '../../utils/nbrb.dart';
import '../../widgets/section.dart';

enum _InflationPeriod { threeMonth, sixMonth, oneYear }

class InflationScreen extends StatefulWidget {
  const InflationScreen({super.key});

  @override
  State<InflationScreen> createState() => _InflationScreenState();
}

class _InflationScreenState extends State<InflationScreen> {
  String _curCode = 'USD';
  _InflationPeriod _period = _InflationPeriod.sixMonth;
  late HttpNbrbClient _client;
  Future<List<NbrbRate>>? _future;

  @override
  void initState() {
    super.initState();
    _client = HttpNbrbClient();
    _future = _load();
  }

  @override
  void dispose() {
    _client.close();
    super.dispose();
  }

  Future<List<NbrbRate>> _load() {
    final cur = kNbrbCurrencies[_curCode]!;
    final end = DateTime.now();
    final months = switch (_period) {
      _InflationPeriod.threeMonth => 3,
      _InflationPeriod.sixMonth => 6,
      _InflationPeriod.oneYear => 12,
    };
    // Use day=1 to avoid DateTime overflow when end.day exceeds the target
    // month's last day (e.g. Mar 31 - 1 month would normalize to Mar 3).
    final start = DateTime(end.year, end.month - months, 1);
    return _client.dynamics(cur: cur, startDate: start, endDate: end);
  }

  void _refresh() => setState(() => _future = _load());

  @override
  Widget build(BuildContext context) {
    final i18n = context.watch<I18n>();
    return Scaffold(
      appBar: AppBar(
        title: Text(i18n.t('inflation')),
        actions: [
          IconButton(
            onPressed: _refresh,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          _CurrencyPicker(
            current: _curCode,
            onChanged: (c) => setState(() {
              _curCode = c;
              _future = _load();
            }),
          ),
          const SizedBox(height: 12),
          _PeriodPicker(
            current: _period,
            onChanged: (p) => setState(() {
              _period = p;
              _future = _load();
            }),
          ),
          const SizedBox(height: 16),
          SectionHeader(
              title: i18n
                  .t('inflation_chart_title')
                  .replaceAll('{cur}', _curCode)),
          AppCard(
            padding: const EdgeInsets.fromLTRB(8, 16, 16, 8),
            child: SizedBox(
              height: 220,
              child: FutureBuilder<List<NbrbRate>>(
                future: _future,
                builder: (context, snap) {
                  if (snap.connectionState != ConnectionState.done) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(strokeWidth: 2)),
                          const SizedBox(height: 12),
                          Text(i18n.t('inflation_loading'),
                              style: const TextStyle(
                                  color: AppColors.textSecondary)),
                        ],
                      ),
                    );
                  }
                  if (snap.hasError) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(8),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.cloud_off,
                                size: 32, color: AppColors.danger),
                            const SizedBox(height: 8),
                            Text(i18n.t('inflation_error'),
                                style: const TextStyle(
                                    color: AppColors.textSecondary)),
                            const SizedBox(height: 8),
                            Text(snap.error.toString(),
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: 11)),
                          ],
                        ),
                      ),
                    );
                  }
                  final rates = snap.data ?? const <NbrbRate>[];
                  if (rates.isEmpty) {
                    return Center(
                      child: Text(i18n.t('no_data_yet'),
                          style: const TextStyle(
                              color: AppColors.textSecondary)),
                    );
                  }
                  return _RateChart(rates: rates);
                },
              ),
            ),
          ),
          const SizedBox(height: 12),
          FutureBuilder<List<NbrbRate>>(
            future: _future,
            builder: (context, snap) {
              if (snap.connectionState != ConnectionState.done ||
                  snap.hasError ||
                  (snap.data?.isEmpty ?? true)) {
                return const SizedBox.shrink();
              }
              final rates = snap.data!;
              final change = momChange(rates) ?? 0;
              final positive = change >= 0;
              return AppCard(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(i18n.t('inflation_change'),
                          style: const TextStyle(
                              color: AppColors.textSecondary, fontSize: 13)),
                    ),
                    Text(
                      '${positive ? '+' : ''}${change.toStringAsFixed(2)}%',
                      style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 18,
                          color: positive
                              ? AppColors.danger
                              : AppColors.income),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _CurrencyPicker extends StatelessWidget {
  final String current;
  final ValueChanged<String> onChanged;
  const _CurrencyPicker({required this.current, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      children: [
        for (final c in kNbrbCurrencies.values)
          ChoiceChip(
            label: Text(c.code),
            selected: current == c.code,
            onSelected: (_) => onChanged(c.code),
            backgroundColor: AppColors.muted,
            selectedColor: AppColors.primary.withOpacity(0.15),
            side: BorderSide.none,
          ),
      ],
    );
  }
}

class _PeriodPicker extends StatelessWidget {
  final _InflationPeriod current;
  final ValueChanged<_InflationPeriod> onChanged;
  const _PeriodPicker({required this.current, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final i18n = context.watch<I18n>();
    final items = [
      (_InflationPeriod.threeMonth, i18n.t('inflation_period_3m')),
      (_InflationPeriod.sixMonth, i18n.t('inflation_period_6m')),
      (_InflationPeriod.oneYear, i18n.t('inflation_period_1y')),
    ];
    return SegmentedButton<_InflationPeriod>(
      segments: [
        for (final it in items)
          ButtonSegment(value: it.$1, label: Text(it.$2)),
      ],
      selected: {current},
      onSelectionChanged: (s) => onChanged(s.first),
      showSelectedIcon: false,
      style: const ButtonStyle(visualDensity: VisualDensity.compact),
    );
  }
}

class _RateChart extends StatelessWidget {
  final List<NbrbRate> rates;
  const _RateChart({required this.rates});

  @override
  Widget build(BuildContext context) {
    if (rates.isEmpty) return const SizedBox.shrink();
    double minV = rates.first.perUnit;
    double maxV = rates.first.perUnit;
    final spots = <FlSpot>[];
    for (var i = 0; i < rates.length; i++) {
      final v = rates[i].perUnit;
      spots.add(FlSpot(i.toDouble(), v));
      if (v < minV) minV = v;
      if (v > maxV) maxV = v;
    }
    final pad = (maxV - minV).abs() * 0.1 + 0.001;

    return LineChart(
      LineChartData(
        minX: 0,
        maxX: (rates.length - 1).toDouble(),
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
              reservedSize: 44,
              getTitlesWidget: (v, meta) => Padding(
                padding: const EdgeInsets.only(right: 4),
                child: Text(v.toStringAsFixed(2),
                    style: const TextStyle(
                        fontSize: 9, color: AppColors.textSecondary)),
              ),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 26,
              interval: (rates.length / 6).ceilToDouble(),
              getTitlesWidget: (v, meta) {
                final idx = v.toInt();
                if (idx < 0 || idx >= rates.length) return const SizedBox();
                final d = rates[idx].date;
                return Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                      '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}',
                      style: const TextStyle(
                          fontSize: 9, color: AppColors.textSecondary)),
                );
              },
            ),
          ),
        ),
        borderData: FlBorderData(show: false),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: AppColors.primary,
            barWidth: 2.2,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              color: AppColors.primary.withOpacity(0.12),
            ),
          ),
        ],
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (_) =>
                AppColors.textPrimary.withOpacity(0.92),
            getTooltipItems: (touched) => [
              for (final s in touched)
                LineTooltipItem(
                  '${rates[s.x.toInt()].date.toIso8601String().substring(0, 10)}\n${s.y.toStringAsFixed(4)}',
                  const TextStyle(color: Colors.white, fontSize: 10),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
