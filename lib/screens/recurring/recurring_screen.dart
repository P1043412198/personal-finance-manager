import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../models/recurring.dart';
import '../../models/transaction.dart';
import '../../providers/app_state.dart';
import '../../theme/app_theme.dart';
import '../../utils/format.dart';
import '../../utils/i18n.dart';
import '../../utils/recurring_calc.dart';
import '../../widgets/section.dart';

class RecurringScreen extends StatelessWidget {
  const RecurringScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final i18n = context.watch<I18n>();
    final list = app.recurringAll();

    return Scaffold(
      appBar: AppBar(title: Text(i18n.t('recurring'))),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _edit(context, null),
        child: const Icon(Icons.add),
      ),
      body: list.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text(
                  i18n.t('recurring_empty'),
                  style: const TextStyle(color: AppColors.textSecondary),
                  textAlign: TextAlign.center,
                ),
              ),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
              children: [
                for (final r in list)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: AppCard(
                      padding: const EdgeInsets.all(12),
                      onTap: () => _edit(context, r),
                      child: Row(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: (r.type == TxType.income
                                      ? AppColors.income
                                      : AppColors.expense)
                                  .withOpacity(0.18),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            alignment: Alignment.center,
                            child: Icon(
                              _freqIcon(r.freq),
                              color: r.type == TxType.income
                                  ? AppColors.income
                                  : AppColors.expense,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(r.name,
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 16,
                                      color: r.active
                                          ? AppColors.textPrimary
                                          : AppColors.textSecondary,
                                      decoration: r.active
                                          ? null
                                          : TextDecoration.lineThrough,
                                    )),
                                Text(
                                  _scheduleLabel(r, i18n),
                                  style: const TextStyle(
                                      color: AppColors.textSecondary,
                                      fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                '${r.type == TxType.income ? '+' : '−'}${Fmt.currency(r.amount, symbol: app.currency, decimals: 2)}',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: r.type == TxType.income
                                      ? AppColors.income
                                      : AppColors.expense,
                                ),
                              ),
                              if (r.active)
                                Text(
                                  _nextLabel(r, i18n),
                                  style: const TextStyle(
                                      color: AppColors.textSecondary,
                                      fontSize: 11),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
    );
  }

  static IconData _freqIcon(RecurFreq f) {
    switch (f) {
      case RecurFreq.daily:
        return Icons.today;
      case RecurFreq.weekly:
        return Icons.view_week;
      case RecurFreq.monthly:
        return Icons.calendar_month;
      case RecurFreq.yearly:
        return Icons.event;
    }
  }

  static String _freqLabel(RecurFreq f, I18n i18n) {
    switch (f) {
      case RecurFreq.daily:
        return i18n.t('freq_daily');
      case RecurFreq.weekly:
        return i18n.t('freq_weekly');
      case RecurFreq.monthly:
        return i18n.t('freq_monthly');
      case RecurFreq.yearly:
        return i18n.t('freq_yearly');
    }
  }

  static String _scheduleLabel(RecurringRule r, I18n i18n) {
    final base = _freqLabel(r.freq, i18n);
    switch (r.freq) {
      case RecurFreq.daily:
        return base;
      case RecurFreq.weekly:
        return '$base · ${_dayOfWeekLabel(r.dayOfWeek ?? r.startDate.weekday, i18n)}';
      case RecurFreq.monthly:
        return '$base · ${i18n.t('day')} ${r.dayOfMonth ?? r.startDate.day}';
      case RecurFreq.yearly:
        return '$base · ${(r.monthOfYear ?? r.startDate.month).toString().padLeft(2, '0')}-${(r.dayOfMonth ?? r.startDate.day).toString().padLeft(2, '0')}';
    }
  }

  static String _dayOfWeekLabel(int dow, I18n i18n) {
    const ru = ['Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Вс'];
    const en = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final i = (dow.clamp(1, 7)) - 1;
    return i18n.locale.languageCode == 'ru' ? ru[i] : en[i];
  }

  static String _nextLabel(RecurringRule r, I18n i18n) {
    final n = nextDue(r, DateTime.now());
    if (n == null) return '';
    return '${i18n.t('next')}: ${DateFormat('d MMM').format(n)}';
  }

  void _edit(BuildContext context, RecurringRule? existing) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: _RecurringForm(existing: existing),
      ),
    );
  }
}

class _RecurringForm extends StatefulWidget {
  final RecurringRule? existing;
  const _RecurringForm({this.existing});

  @override
  State<_RecurringForm> createState() => _RecurringFormState();
}

class _RecurringFormState extends State<_RecurringForm> {
  late TextEditingController _name;
  late TextEditingController _amount;
  late TxType _type;
  late RecurFreq _freq;
  int? _dayOfMonth;
  int? _dayOfWeek;
  int? _monthOfYear;
  late DateTime _startDate;
  DateTime? _endDate;
  String? _walletId;
  String? _categoryId;
  late bool _active;

  @override
  void initState() {
    super.initState();
    final r = widget.existing;
    _name = TextEditingController(text: r?.name ?? '');
    _amount = TextEditingController(
        text: r == null ? '' : r.amount.toStringAsFixed(2));
    _type = r?.type ?? TxType.expense;
    _freq = r?.freq ?? RecurFreq.monthly;
    _dayOfMonth = r?.dayOfMonth;
    _dayOfWeek = r?.dayOfWeek;
    _monthOfYear = r?.monthOfYear;
    _startDate = r?.startDate ?? DateTime.now();
    _endDate = r?.endDate;
    _walletId = r?.walletId;
    _categoryId = r?.categoryId;
    _active = r?.active ?? true;
  }

  @override
  Widget build(BuildContext context) {
    final app = context.read<AppState>();
    final i18n = context.watch<I18n>();
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
              widget.existing == null
                  ? i18n.t('recurring_new')
                  : i18n.t('recurring_edit'),
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          TextField(
            controller: _name,
            decoration: InputDecoration(labelText: i18n.t('name')),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _amount,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(labelText: i18n.t('amount')),
                ),
              ),
              const SizedBox(width: 12),
              ToggleButtons(
                isSelected: [
                  _type == TxType.expense,
                  _type == TxType.income,
                ],
                onPressed: (i) => setState(
                    () => _type = i == 0 ? TxType.expense : TxType.income),
                borderRadius: BorderRadius.circular(12),
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Text(i18n.t('expense_short')),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Text(i18n.t('income_short')),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            children: [
              for (final f in RecurFreq.values)
                ChoiceChip(
                  label: Text(RecurringScreen._freqLabel(f, i18n)),
                  selected: _freq == f,
                  onSelected: (_) => setState(() => _freq = f),
                ),
            ],
          ),
          const SizedBox(height: 12),
          if (_freq == RecurFreq.weekly)
            DropdownButtonFormField<int>(
              value: _dayOfWeek ?? _startDate.weekday,
              decoration: InputDecoration(labelText: i18n.t('day_of_week')),
              items: [
                for (var d = 1; d <= 7; d++)
                  DropdownMenuItem(
                      value: d,
                      child:
                          Text(RecurringScreen._dayOfWeekLabel(d, i18n))),
              ],
              onChanged: (v) => setState(() => _dayOfWeek = v),
            ),
          if (_freq == RecurFreq.monthly || _freq == RecurFreq.yearly)
            TextField(
              controller: TextEditingController(
                  text: (_dayOfMonth ?? _startDate.day).toString()),
              keyboardType: TextInputType.number,
              decoration: InputDecoration(labelText: i18n.t('day_of_month')),
              onChanged: (v) => _dayOfMonth = int.tryParse(v),
            ),
          if (_freq == RecurFreq.yearly) ...[
            const SizedBox(height: 12),
            TextField(
              controller: TextEditingController(
                  text: (_monthOfYear ?? _startDate.month).toString()),
              keyboardType: TextInputType.number,
              decoration: InputDecoration(labelText: i18n.t('month_of_year')),
              onChanged: (v) => _monthOfYear = int.tryParse(v),
            ),
          ],
          const SizedBox(height: 12),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(i18n.t('start_date')),
            subtitle: Text(DateFormat('d MMM y').format(_startDate)),
            trailing: const Icon(Icons.edit_calendar),
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: _startDate,
                firstDate: DateTime(2000),
                lastDate: DateTime(2100),
              );
              if (picked != null) setState(() => _startDate = picked);
            },
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(i18n.t('end_date_opt')),
            subtitle: Text(_endDate == null
                ? i18n.t('no_end')
                : DateFormat('d MMM y').format(_endDate!)),
            trailing: Wrap(
              children: [
                if (_endDate != null)
                  IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () => setState(() => _endDate = null),
                  ),
                IconButton(
                  icon: const Icon(Icons.edit_calendar),
                  onPressed: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _endDate ?? _startDate,
                      firstDate: _startDate,
                      lastDate: DateTime(2100),
                    );
                    if (picked != null) setState(() => _endDate = picked);
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String?>(
            value: _walletId,
            decoration: InputDecoration(labelText: i18n.t('wallet_opt')),
            items: [
              DropdownMenuItem(value: null, child: Text(i18n.t('any_wallet'))),
              for (final w in app.walletAll())
                DropdownMenuItem(value: w.id, child: Text(w.name)),
            ],
            onChanged: (v) => setState(() => _walletId = v),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String?>(
            value: _categoryId,
            decoration: InputDecoration(labelText: i18n.t('category_opt')),
            items: [
              DropdownMenuItem(value: null, child: Text(i18n.t('no_category'))),
              for (final c in app.categoriesAllSorted())
                DropdownMenuItem(value: c.id, child: Text(c.name)),
            ],
            onChanged: (v) => setState(() => _categoryId = v),
          ),
          const SizedBox(height: 12),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(i18n.t('active')),
            value: _active,
            onChanged: (v) => setState(() => _active = v),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              if (widget.existing != null)
                Expanded(
                  child: OutlinedButton(
                    onPressed: () async {
                      await app.deleteRecurring(widget.existing!.id);
                      if (!mounted) return;
                      Navigator.pop(context);
                    },
                    child: Text(i18n.t('delete')),
                  ),
                ),
              if (widget.existing != null) const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: () async {
                    if (_name.text.trim().isEmpty) return;
                    final amt = double.tryParse(
                            _amount.text.replaceAll(',', '.')) ??
                        0;
                    if (amt <= 0) return;
                    final r = RecurringRule(
                      id: widget.existing?.id ?? app.newId(),
                      name: _name.text.trim(),
                      type: _type,
                      amount: amt,
                      categoryId: _categoryId,
                      walletId: _walletId,
                      freq: _freq,
                      dayOfMonth: _dayOfMonth,
                      dayOfWeek: _dayOfWeek,
                      monthOfYear: _monthOfYear,
                      startDate: _startDate,
                      endDate: _endDate,
                      lastApplied: widget.existing?.lastApplied,
                      active: _active,
                    );
                    await app.upsertRecurring(r);
                    if (!mounted) return;
                    Navigator.pop(context);
                  },
                  child: Text(i18n.t('save')),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
