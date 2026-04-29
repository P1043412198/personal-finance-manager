import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/category.dart';
import '../../models/habit.dart';
import '../../providers/app_state.dart';
import '../../theme/app_theme.dart';
import '../../utils/format.dart';
import '../../utils/i18n.dart';
import '../../widgets/section.dart';

class HabitsScreen extends StatelessWidget {
  const HabitsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final i18n = context.watch<I18n>();
    final habits = app.habitAll();

    return Scaffold(
      appBar: AppBar(title: Text(i18n.t('habits'))),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _edit(context, null),
        child: const Icon(Icons.add),
      ),
      body: habits.isEmpty
          ? Center(
              child: Text(i18n.t('no_habits'),
                  style: const TextStyle(color: AppColors.textSecondary)))
          : ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
              children: [
                for (final h in habits)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _HabitCard(habit: h, onTap: () => _edit(context, h)),
                  ),
              ],
            ),
    );
  }

  void _edit(BuildContext context, HabitModel? existing) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: _HabitForm(existing: existing),
      ),
    );
  }
}

class _HabitCard extends StatelessWidget {
  final HabitModel habit;
  final VoidCallback onTap;
  const _HabitCard({required this.habit, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final i18n = context.watch<I18n>();
    final today = Fmt.dayKey(DateTime.now());
    final doneToday = app.isHabitDone(habit.id, today);
    final streak = app.habitStreak(habit.id);
    final last7 = List.generate(7, (i) => DateTime.now().subtract(Duration(days: 6 - i)));

    return AppCard(
      padding: const EdgeInsets.all(14),
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconBadge(emoji: CategoryIcons.resolve(habit.iconKey), bg: Color(habit.colorValue).withOpacity(0.15)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(habit.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: habit.kind == HabitKind.good
                                ? AppColors.income.withOpacity(0.12)
                                : AppColors.danger.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            habit.kind == HabitKind.good ? i18n.t('habit_good') : i18n.t('habit_bad'),
                            style: TextStyle(
                              color: habit.kind == HabitKind.good ? AppColors.income : AppColors.danger,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        if (habit.savePerDay > 0)
                          Text(
                            '${i18n.t('habit_save_per_day')}: ${Fmt.currency(habit.savePerDay, symbol: app.currency)}',
                            style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('🔥', style: TextStyle(fontSize: streak > 0 ? 22 : 16)),
                  Text('$streak ${i18n.t('streak_days')}',
                      style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              for (final d in last7)
                _DayDot(
                  day: d,
                  done: app.isHabitDone(habit.id, Fmt.dayKey(d)),
                  isToday: Fmt.isSameDay(d, DateTime.now()),
                  color: Color(habit.colorValue),
                  onTap: () => app.toggleHabit(habit.id, Fmt.dayKey(d)),
                ),
            ],
          ),
          const SizedBox(height: 12),
          _Heatmap(habitId: habit.id, color: Color(habit.colorValue)),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: () => app.toggleHabit(habit.id, today),
            icon: Icon(doneToday ? Icons.check_circle : Icons.radio_button_unchecked),
            label: Text(doneToday ? i18n.t('habit_done_today') : i18n.t('add')),
            style: ElevatedButton.styleFrom(
              backgroundColor: doneToday ? AppColors.income : Color(habit.colorValue),
            ),
          ),
        ],
      ),
    );
  }
}

class _Heatmap extends StatelessWidget {
  final String habitId;
  final Color color;
  const _Heatmap({required this.habitId, required this.color});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    const weeks = 12;
    final days = app.habitDays(habitId).toSet();
    final today = DateTime.now();
    final start = today.subtract(Duration(days: weeks * 7 - 1));
    return SizedBox(
      height: 7 * 12.0 + 6 * 2,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var w = 0; w < weeks; w++)
            Padding(
              padding: const EdgeInsets.only(right: 2),
              child: Column(
                children: [
                  for (var d = 0; d < 7; d++)
                    () {
                      final date = start.add(Duration(days: w * 7 + d));
                      if (date.isAfter(today)) {
                        return const SizedBox(width: 12, height: 12);
                      }
                      final key =
                          '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
                      final done = days.contains(key);
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 2),
                        child: Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            color: done ? color : color.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      );
                    }(),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _DayDot extends StatelessWidget {
  final DateTime day;
  final bool done;
  final bool isToday;
  final Color color;
  final VoidCallback onTap;
  const _DayDot({required this.day, required this.done, required this.isToday, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Text(['Пн','Вт','Ср','Чт','Пт','Сб','Вс'][day.weekday - 1],
              style: const TextStyle(fontSize: 10, color: AppColors.textSecondary)),
          const SizedBox(height: 4),
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: done ? color : AppColors.muted,
              borderRadius: BorderRadius.circular(10),
              border: isToday ? Border.all(color: color, width: 2) : null,
            ),
            alignment: Alignment.center,
            child: Text(
              '${day.day}',
              style: TextStyle(
                color: done ? Colors.white : AppColors.textPrimary,
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HabitForm extends StatefulWidget {
  final HabitModel? existing;
  const _HabitForm({this.existing});

  @override
  State<_HabitForm> createState() => _HabitFormState();
}

class _HabitFormState extends State<_HabitForm> {
  late TextEditingController _name;
  late TextEditingController _save;
  HabitKind _kind = HabitKind.good;
  String _icon = 'sport';
  Color _color = AppColors.primary;
  int? _reminderMinutes;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.existing?.name ?? '');
    _save = TextEditingController(text: (widget.existing?.savePerDay ?? 0).toStringAsFixed(0));
    _kind = widget.existing?.kind ?? HabitKind.good;
    _icon = widget.existing?.iconKey ?? 'sport';
    _color = widget.existing != null ? Color(widget.existing!.colorValue) : AppColors.primary;
    _reminderMinutes = widget.existing?.reminderMinutes;
  }

  @override
  void dispose() {
    _name.dispose();
    _save.dispose();
    super.dispose();
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
          Text(widget.existing == null ? i18n.t('add_habit') : i18n.t('edit'),
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          TextField(controller: _name, decoration: InputDecoration(hintText: i18n.t('task_title'))),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _kind = HabitKind.good),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: _kind == HabitKind.good ? AppColors.income : AppColors.muted,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(i18n.t('habit_good'),
                        style: TextStyle(
                            color: _kind == HabitKind.good ? Colors.white : AppColors.textPrimary,
                            fontWeight: FontWeight.w600)),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _kind = HabitKind.bad),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: _kind == HabitKind.bad ? AppColors.danger : AppColors.muted,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(i18n.t('habit_bad'),
                        style: TextStyle(
                            color: _kind == HabitKind.bad ? Colors.white : AppColors.textPrimary,
                            fontWeight: FontWeight.w600)),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _save,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(hintText: i18n.t('habit_save_per_day')),
          ),
          const SizedBox(height: 12),
          Text(i18n.t('category_icon'),
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final entry in CategoryIcons.all.entries.take(16))
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
          const SizedBox(height: 12),
          Text(i18n.t('category_color'),
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            children: [
              for (final c in const [
                Color(0xFF2E7D32),
                Color(0xFF1976D2),
                Color(0xFFD32F2F),
                Color(0xFFF9A825),
                Color(0xFF8E24AA),
                Color(0xFF00897B),
                Color(0xFFEF6C00),
                Color(0xFF455A64),
              ])
                GestureDetector(
                  onTap: () => setState(() => _color = c),
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: c,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: _color.value == c.value ? Colors.black : Colors.transparent,
                        width: 2,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          InkWell(
            onTap: () async {
              final init = _reminderMinutes;
              final picked = await showTimePicker(
                context: context,
                initialTime: TimeOfDay(
                    hour: init != null ? init ~/ 60 : 9,
                    minute: init != null ? init % 60 : 0),
              );
              if (picked != null) {
                setState(() =>
                    _reminderMinutes = picked.hour * 60 + picked.minute);
              }
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              decoration: BoxDecoration(
                  color: AppColors.muted,
                  borderRadius: BorderRadius.circular(14)),
              child: Row(children: [
                const Icon(Icons.alarm, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(_reminderMinutes == null
                      ? 'Напоминание (не задано)'
                      : 'Напоминание: ${(_reminderMinutes! ~/ 60).toString().padLeft(2, '0')}:${(_reminderMinutes! % 60).toString().padLeft(2, '0')}'),
                ),
                if (_reminderMinutes != null)
                  GestureDetector(
                    onTap: () => setState(() => _reminderMinutes = null),
                    child: const Icon(Icons.close, size: 18),
                  ),
              ]),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              if (widget.existing != null)
                Expanded(
                  child: OutlinedButton(
                    onPressed: () async {
                      await app.deleteHabit(widget.existing!.id);
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
                    final h = HabitModel(
                      id: widget.existing?.id ?? app.newId(),
                      name: _name.text.trim(),
                      kind: _kind,
                      iconKey: _icon,
                      colorValue: _color.value,
                      savePerDay: double.tryParse(_save.text.replaceAll(',', '.')) ?? 0,
                      reminderMinutes: _reminderMinutes,
                      createdAt: widget.existing?.createdAt ?? DateTime.now(),
                    );
                    await app.upsertHabit(h);
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
