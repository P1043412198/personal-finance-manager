import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import '../../utils/format.dart';
import '../../widgets/section.dart';

/// Belarus salary calculator: gross/net conversion, employer cost,
/// and rough simple-tax (УНП) for IP/freelance modes.
class TaxCalcScreen extends StatefulWidget {
  const TaxCalcScreen({super.key});

  @override
  State<TaxCalcScreen> createState() => _TaxCalcScreenState();
}

enum _Mode { grossToNet, netToGross, ipSingleTax }

class _TaxCalcScreenState extends State<TaxCalcScreen> {
  final _amountC = TextEditingController(text: '1500');
  _Mode _mode = _Mode.grossToNet;
  int _children = 0;
  bool _smallSalary = false; // if salary ≤ 1054 BYN (2025) — standard deduction

  static const double _piRate = 0.13; // подоходный
  static const double _fsznEmployee = 0.01; // ФСЗН с работника
  static const double _fsznEmployer = 0.34; // ФСЗН с работодателя
  static const double _stdDeduction = 174; // стандартный вычет (≤ порог)
  static const double _stdThreshold = 1054;
  static const double _childDeduction = 51;

  double _deduction(double gross) {
    var d = 0.0;
    if (_smallSalary || gross <= _stdThreshold) d += _stdDeduction;
    d += _children * _childDeduction;
    return d;
  }

  Map<String, double> _calcGrossToNet(double gross) {
    final deduction = _deduction(gross);
    final taxBase = (gross - deduction).clamp(0, double.infinity).toDouble();
    final pi = taxBase * _piRate;
    final fszn = gross * _fsznEmployee;
    final net = gross - pi - fszn;
    final employerCost = gross + gross * _fsznEmployer;
    return {
      'gross': gross,
      'pi': pi,
      'fszn': fszn,
      'deduction': deduction,
      'net': net,
      'employer_cost': employerCost,
    };
  }

  Map<String, double> _calcNetToGross(double net) {
    // Solve: net = gross - 0.13 * (gross - deduction(gross)) - 0.01 * gross
    // Approx with iteration, since deduction may depend on gross threshold.
    var gross = net / 0.86; // initial estimate (no deduction)
    for (var i = 0; i < 12; i++) {
      final d = _deduction(gross);
      gross = (net - _piRate * d) / (1 - _piRate - _fsznEmployee);
    }
    return _calcGrossToNet(gross);
  }

  Map<String, double> _calcIpSingleTax(double monthlyRevenue) {
    // Rough estimate. Real УНП for ИП varies by region/activity.
    // Use approx 60 BYN/month + 6% over revenue when limit exceeded — simplified to 6% flat.
    final tax = monthlyRevenue * 0.06;
    final fsznIp = 1180 * 0.34 / 12; // approx min wage * social per month
    return {
      'revenue': monthlyRevenue,
      'unp': tax,
      'fszn_ip': fsznIp,
      'net': monthlyRevenue - tax - fsznIp,
    };
  }

  @override
  Widget build(BuildContext context) {
    final amt = double.tryParse(_amountC.text.replaceAll(',', '.')) ?? 0;
    Map<String, double> r;
    switch (_mode) {
      case _Mode.grossToNet:
        r = _calcGrossToNet(amt);
        break;
      case _Mode.netToGross:
        r = _calcNetToGross(amt);
        break;
      case _Mode.ipSingleTax:
        r = _calcIpSingleTax(amt);
        break;
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Калькулятор зарплаты РБ')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 80),
        children: [
          AppCard(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Режим', style: TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                Wrap(spacing: 8, runSpacing: 8, children: [
                  ChoiceChip(
                    label: const Text('Грязная → Чистая'),
                    selected: _mode == _Mode.grossToNet,
                    onSelected: (_) => setState(() => _mode = _Mode.grossToNet),
                  ),
                  ChoiceChip(
                    label: const Text('Чистая → Грязная'),
                    selected: _mode == _Mode.netToGross,
                    onSelected: (_) => setState(() => _mode = _Mode.netToGross),
                  ),
                  ChoiceChip(
                    label: const Text('ИП (упрощённо)'),
                    selected: _mode == _Mode.ipSingleTax,
                    onSelected: (_) => setState(() => _mode = _Mode.ipSingleTax),
                  ),
                ]),
                const SizedBox(height: 12),
                TextField(
                  controller: _amountC,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: _mode == _Mode.grossToNet
                        ? 'Сумма «грязными», Br'
                        : _mode == _Mode.netToGross
                            ? 'Сумма «на руки», Br'
                            : 'Месячная выручка ИП, Br',
                  ),
                  onChanged: (_) => setState(() {}),
                ),
                if (_mode != _Mode.ipSingleTax) ...[
                  const SizedBox(height: 8),
                  Row(children: [
                    Expanded(
                      child: SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        value: _smallSalary,
                        onChanged: (v) => setState(() => _smallSalary = v),
                        title: const Text('Стандартный вычет 174 Br'),
                        subtitle: const Text('Если зарплата ≤ 1054 Br/мес'),
                      ),
                    ),
                  ]),
                  Row(children: [
                    const Text('Дети до 18:'),
                    const SizedBox(width: 12),
                    IconButton(
                      onPressed: () => setState(() => _children = (_children - 1).clamp(0, 10)),
                      icon: const Icon(Icons.remove_circle_outline),
                    ),
                    Text('$_children',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                    IconButton(
                      onPressed: () => setState(() => _children = (_children + 1).clamp(0, 10)),
                      icon: const Icon(Icons.add_circle_outline),
                    ),
                    Text('× 51 Br вычет',
                        style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                  ]),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),
          SectionHeader(title: 'Результат'),
          if (_mode == _Mode.ipSingleTax)
            AppCard(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _row('Выручка', r['revenue'] ?? 0, AppColors.primary, fontSize: 18),
                  const Divider(),
                  _row('Налог УСН ~6%', -(r['unp'] ?? 0), AppColors.expense),
                  _row('ФСЗН ИП (~)', -(r['fszn_ip'] ?? 0), AppColors.expense),
                  const Divider(),
                  _row('Чистыми', r['net'] ?? 0, AppColors.income,
                      fontSize: 22, bold: true),
                  const SizedBox(height: 8),
                  const Text(
                      'Это упрощённый расчёт. Реальный УНП для ИП зависит от региона, '
                      'вида деятельности и ставки. Уточняй в ИМНС.',
                      style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                ],
              ),
            )
          else
            AppCard(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _row('Грязная зарплата', r['gross'] ?? 0, AppColors.primary,
                      fontSize: 18, bold: true),
                  if ((r['deduction'] ?? 0) > 0)
                    _row('Налоговый вычет', r['deduction'] ?? 0, AppColors.textSecondary,
                        fontSize: 13),
                  const Divider(),
                  _row('Подоходный 13%', -(r['pi'] ?? 0), AppColors.expense),
                  _row('ФСЗН (1%)', -(r['fszn'] ?? 0), AppColors.expense),
                  const Divider(),
                  _row('На руки', r['net'] ?? 0, AppColors.income,
                      fontSize: 22, bold: true),
                  const SizedBox(height: 12),
                  const Divider(),
                  const Text('Стоимость для работодателя',
                      style: TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  _row('Зарплата + ФСЗН 34%', r['employer_cost'] ?? 0, AppColors.textSecondary),
                  const SizedBox(height: 8),
                  Text(
                      'Эффективная ставка налога: '
                      '${(((r['gross'] ?? 1) - (r['net'] ?? 0)) / ((r['gross'] ?? 1)) * 100).toStringAsFixed(1)}%',
                      style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                ],
              ),
            ),
          const SizedBox(height: 16),
          AppCard(
            color: AppColors.muted,
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text('Что учитывает калькулятор',
                    style: TextStyle(fontWeight: FontWeight.w700)),
                SizedBox(height: 6),
                Text('• Подоходный 13% от облагаемой базы',
                    style: TextStyle(fontSize: 13)),
                Text('• ФСЗН с работника 1% от грязной зарплаты',
                    style: TextStyle(fontSize: 13)),
                Text('• Стандартный вычет 174 Br/мес при зп ≤ 1054 Br',
                    style: TextStyle(fontSize: 13)),
                Text('• Вычет 51 Br/мес на каждого ребёнка до 18 лет',
                    style: TextStyle(fontSize: 13)),
                Text('• ФСЗН работодателя 34% (для расчёта полной стоимости)',
                    style: TextStyle(fontSize: 13)),
                SizedBox(height: 6),
                Text(
                    'Льготы по обучению, ипотеке, многодетным — не учитываются. '
                    'Для точного расчёта обратись в бухгалтерию или ИМНС.',
                    style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _row(String label, double value, Color color,
      {double fontSize = 15, bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
              child: Text(label,
                  style: TextStyle(fontSize: fontSize, fontWeight: FontWeight.w500))),
          Text(
            (value < 0 ? '−' : '') + Fmt.currency(value.abs(), symbol: 'Br'),
            style: TextStyle(
              fontSize: fontSize,
              color: color,
              fontWeight: bold ? FontWeight.w800 : FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
