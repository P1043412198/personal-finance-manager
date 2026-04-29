import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/category.dart';
import '../../models/goal.dart';
import '../../providers/app_state.dart';
import '../../theme/app_theme.dart';
import '../../utils/format.dart';
import '../../utils/i18n.dart';
import '../../widgets/section.dart';

class GoalsScreen extends StatelessWidget {
  const GoalsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final i18n = context.watch<I18n>();
    final goals = app.goalAll();
    return Scaffold(
      appBar: AppBar(title: Text(i18n.t('goals'))),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _edit(context, null),
        child: const Icon(Icons.add),
      ),
      body: goals.isEmpty
          ? Center(
              child: Text(i18n.t('set_goal'),
                  style: const TextStyle(color: AppColors.textSecondary)))
          : ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
              children: [
                for (final g in goals)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: AppCard(
                      onTap: () => _edit(context, g),
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              IconBadge(emoji: CategoryIcons.resolve(g.iconKey), bg: Color(g.colorValue).withOpacity(0.15)),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(g.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                                    Text(
                                      '${Fmt.currency(g.current, symbol: app.currency)} / ${Fmt.currency(g.target, symbol: app.currency)}',
                                      style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                                    ),
                                  ],
                                ),
                              ),
                              Text('${(g.progress * 100).round()}%',
                                  style: TextStyle(color: Color(g.colorValue), fontWeight: FontWeight.w700)),
                            ],
                          ),
                          const SizedBox(height: 12),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: LinearProgressIndicator(
                              value: g.progress,
                              minHeight: 8,
                              backgroundColor: AppColors.muted,
                              color: Color(g.colorValue),
                            ),
                          ),
                          if (g.deadline != null) ...[
                            const SizedBox(height: 6),
                            Text('${i18n.t('goal_deadline')}: ${Fmt.date(g.deadline!, locale: i18n.locale.languageCode)}',
                                style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                          ]
                        ],
                      ),
                    ),
                  ),
              ],
            ),
    );
  }

  void _edit(BuildContext context, GoalModel? existing) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: _GoalForm(existing: existing),
      ),
    );
  }
}

class _GoalForm extends StatefulWidget {
  final GoalModel? existing;
  const _GoalForm({this.existing});

  @override
  State<_GoalForm> createState() => _GoalFormState();
}

class _GoalFormState extends State<_GoalForm> {
  late TextEditingController _name;
  late TextEditingController _target;
  late TextEditingController _current;
  late TextEditingController _autoDep;
  DateTime? _deadline;
  String _icon = 'savings';
  Color _color = AppColors.primary;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _name = TextEditingController(text: e?.name ?? '');
    _target = TextEditingController(text: e == null ? '' : e.target.toStringAsFixed(0));
    _current = TextEditingController(text: e == null ? '' : e.current.toStringAsFixed(0));
    _autoDep = TextEditingController(
        text: (e == null || e.autoDepositMonthly == 0) ? '' : e.autoDepositMonthly.toStringAsFixed(0));
    _deadline = e?.deadline;
    _icon = e?.iconKey ?? 'savings';
    _color = e != null ? Color(e.colorValue) : AppColors.primary;
  }

  @override
  void dispose() {
    _name.dispose();
    _target.dispose();
    _current.dispose();
    _autoDep.dispose();
    super.dispose();
  }

  String _suggestText(String currency) {
    final tgt = double.tryParse(_target.text.replaceAll(',', '.')) ?? 0;
    final cur = double.tryParse(_current.text.replaceAll(',', '.')) ?? 0;
    if (tgt <= 0 || _deadline == null) return 'Сколько добавлять каждый месяц';
    final months = ((_deadline!.year - DateTime.now().year) * 12 +
            (_deadline!.month - DateTime.now().month))
        .clamp(1, 999);
    final suggested = ((tgt - cur).clamp(0, double.infinity)) / months;
    return 'Чтобы успеть к дедлайну — около ${suggested.toStringAsFixed(0)} $currency / мес';
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
          Text(widget.existing == null ? i18n.t('add_goal') : i18n.t('edit'),
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          TextField(controller: _name, decoration: InputDecoration(hintText: i18n.t('task_title'))),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _target,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(hintText: i18n.t('goal_target')),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _current,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(hintText: i18n.t('goal_current')),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          InkWell(
            onTap: () async {
              final p = await showDatePicker(
                context: context,
                initialDate: _deadline ?? DateTime.now().add(const Duration(days: 90)),
                firstDate: DateTime.now(),
                lastDate: DateTime(2100),
              );
              if (p != null) setState(() => _deadline = p);
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              decoration: BoxDecoration(color: AppColors.muted, borderRadius: BorderRadius.circular(14)),
              child: Row(
                children: [
                  const Icon(Icons.event, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(_deadline == null
                        ? i18n.t('goal_deadline')
                        : Fmt.date(_deadline!, locale: i18n.locale.languageCode)),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _autoDep,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              hintText: 'Авто-копилка / месяц, ${app.currency}',
              helperText: _suggestText(app.currency),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final entry in CategoryIcons.all.entries.take(12))
                GestureDetector(
                  onTap: () => setState(() => _icon = entry.key),
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: _icon == entry.key ? AppColors.primary.withOpacity(0.15) : AppColors.muted,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _icon == entry.key ? AppColors.primary : Colors.transparent,
                        width: 2,
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Text(entry.value, style: const TextStyle(fontSize: 22)),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              if (widget.existing != null)
                Expanded(
                  child: OutlinedButton(
                    onPressed: () async {
                      await app.deleteGoal(widget.existing!.id);
                      if (!mounted) return;
                      Navigator.pop(context);
                    },
                    child: Text(i18n.t('delete')),
                  ),
                ),
              if (widget.existing != null) const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () async {
                    if (_name.text.trim().isEmpty) return;
                    final g = GoalModel(
                      id: widget.existing?.id ?? app.newId(),
                      name: _name.text.trim(),
                      target: double.tryParse(_target.text.replaceAll(',', '.')) ?? 0,
                      current: double.tryParse(_current.text.replaceAll(',', '.')) ?? 0,
                      deadline: _deadline,
                      iconKey: _icon,
                      colorValue: _color.value,
                      autoDepositMonthly:
                          double.tryParse(_autoDep.text.replaceAll(',', '.')) ?? 0,
                      walletId: widget.existing?.walletId,
                      createdAt: widget.existing?.createdAt ?? DateTime.now(),
                    );
                    await app.upsertGoal(g);
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
