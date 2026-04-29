import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/category.dart';
import '../../models/task.dart';
import '../../providers/app_state.dart';
import '../../theme/app_theme.dart';
import '../../utils/format.dart';
import '../../utils/i18n.dart';
import '../../widgets/section.dart';

class TasksScreen extends StatefulWidget {
  const TasksScreen({super.key});

  @override
  State<TasksScreen> createState() => _TasksScreenState();
}

class _TasksScreenState extends State<TasksScreen> {
  bool _hideDone = false;

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final i18n = context.watch<I18n>();
    final all = app.taskAll();
    final list = _hideDone ? all.where((t) => !t.done).toList() : all;
    final completed = all.where((t) => t.done).length;
    final progress = all.isEmpty ? 0.0 : completed / all.length;

    return Scaffold(
      appBar: AppBar(
        title: Text(i18n.t('tasks')),
        actions: [
          IconButton(
            icon: Icon(_hideDone ? Icons.check_box : Icons.check_box_outline_blank),
            onPressed: () => setState(() => _hideDone = !_hideDone),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _editTask(context, null),
        child: const Icon(Icons.add),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
        children: [
          AppCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text('${i18n.t('progress')}: $completed/${all.length}',
                        style: const TextStyle(fontWeight: FontWeight.w700)),
                    const Spacer(),
                    Text('${(progress * 100).round()}%',
                        style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700)),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 8,
                    backgroundColor: AppColors.muted,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          if (list.isEmpty)
            AppCard(
              padding: const EdgeInsets.all(24),
              child: Center(
                  child: Text(i18n.t('no_tasks'),
                      style: const TextStyle(color: AppColors.textSecondary))),
            )
          else
            for (final t in list)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _TaskRow(task: t, onEdit: () => _editTask(context, t)),
              ),
        ],
      ),
    );
  }

  void _editTask(BuildContext context, TaskModel? existing) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: _TaskForm(existing: existing),
      ),
    );
  }
}

class _TaskRow extends StatelessWidget {
  final TaskModel task;
  final VoidCallback onEdit;
  const _TaskRow({required this.task, required this.onEdit});

  @override
  Widget build(BuildContext context) {
    final app = context.read<AppState>();
    final i18n = context.watch<I18n>();
    final cat = app.categoryById(task.categoryId);
    Color priorityColor = task.priority == TaskPriority.high
        ? AppColors.danger
        : task.priority == TaskPriority.medium
            ? AppColors.warning
            : AppColors.info;
    final overdue = task.dueDate != null && !task.done && task.dueDate!.isBefore(DateTime.now());
    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        children: [
          Checkbox(
            value: task.done,
            onChanged: (_) => app.toggleTask(task),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            activeColor: AppColors.primary,
          ),
          Container(
            width: 4,
            height: 32,
            decoration: BoxDecoration(
              color: priorityColor,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Expanded(
                    child: Text(task.title,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          decoration: task.done ? TextDecoration.lineThrough : null,
                          color: task.done ? AppColors.textSecondary : AppColors.textPrimary,
                        )),
                  ),
                  if (task.subtasks.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: Text(
                        '${task.subtasks.where((s) => s.done).length}/${task.subtasks.length}',
                        style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w600),
                      ),
                    ),
                ]),
                if (cat != null || task.dueDate != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Wrap(
                      spacing: 6,
                      children: [
                        if (cat != null)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: cat.color.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '${CategoryIcons.resolve(cat.iconKey)} ${cat.name}',
                              style: TextStyle(color: cat.color, fontSize: 11, fontWeight: FontWeight.w600),
                            ),
                          ),
                        if (task.dueDate != null)
                          Text(
                            Fmt.shortDate(task.dueDate!, locale: i18n.locale.languageCode),
                            style: TextStyle(
                              color: overdue ? AppColors.danger : AppColors.textSecondary,
                              fontSize: 11,
                              fontWeight: overdue ? FontWeight.w700 : FontWeight.w500,
                            ),
                          ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          IconButton(onPressed: onEdit, icon: const Icon(Icons.edit_outlined, size: 20)),
        ],
      ),
    );
  }
}

class _TaskForm extends StatefulWidget {
  final TaskModel? existing;
  const _TaskForm({this.existing});

  @override
  State<_TaskForm> createState() => _TaskFormState();
}

class _TaskFormState extends State<_TaskForm> {
  late TextEditingController _title;
  late TextEditingController _desc;
  late TextEditingController _newSub;
  String? _categoryId;
  DateTime? _dueDate;
  TaskPriority _priority = TaskPriority.medium;
  late List<Subtask> _subtasks;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _title = TextEditingController(text: e?.title ?? '');
    _desc = TextEditingController(text: e?.description ?? '');
    _newSub = TextEditingController();
    _categoryId = e?.categoryId;
    _dueDate = e?.dueDate;
    _priority = e?.priority ?? TaskPriority.medium;
    _subtasks = e?.subtasks
            .map((s) => Subtask(title: s.title, done: s.done))
            .toList() ??
        <Subtask>[];
  }

  @override
  void dispose() {
    _title.dispose();
    _desc.dispose();
    _newSub.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final i18n = context.watch<I18n>();
    final cats = app.categoriesByScope('task');
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(widget.existing == null ? i18n.t('add_task') : i18n.t('edit'),
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          TextField(controller: _title, decoration: InputDecoration(hintText: i18n.t('task_title'))),
          const SizedBox(height: 8),
          TextField(controller: _desc, maxLines: 2, decoration: InputDecoration(hintText: i18n.t('description'))),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: () async {
                    final p = await showDatePicker(
                      context: context,
                      initialDate: _dueDate ?? DateTime.now(),
                      firstDate: DateTime(2000),
                      lastDate: DateTime(2100),
                    );
                    if (p != null) setState(() => _dueDate = p);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                    decoration: BoxDecoration(color: AppColors.muted, borderRadius: BorderRadius.circular(14)),
                    child: Row(
                      children: [
                        const Icon(Icons.event, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(_dueDate == null
                              ? i18n.t('task_due')
                              : Fmt.date(_dueDate!, locale: i18n.locale.languageCode)),
                        ),
                        if (_dueDate != null)
                          GestureDetector(
                              onTap: () => setState(() => _dueDate = null),
                              child: const Icon(Icons.close, size: 18)),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Priority
          Row(
            children: [
              for (final p in TaskPriority.values)
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: GestureDetector(
                    onTap: () => setState(() => _priority = p),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: _priority == p ? AppColors.primary : AppColors.muted,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        p == TaskPriority.high
                            ? i18n.t('priority_high')
                            : p == TaskPriority.medium
                                ? i18n.t('priority_med')
                                : i18n.t('priority_low'),
                        style: TextStyle(
                            color: _priority == p ? Colors.white : AppColors.textPrimary,
                            fontSize: 12,
                            fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          // Category picker
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final c in cats)
                ChoiceChip(
                  label: Text('${CategoryIcons.resolve(c.iconKey)} ${c.name}'),
                  selected: _categoryId == c.id,
                  onSelected: (_) => setState(() => _categoryId = _categoryId == c.id ? null : c.id),
                ),
            ],
          ),
          const SizedBox(height: 16),
          const Text('Подзадачи',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
          const SizedBox(height: 6),
          for (var i = 0; i < _subtasks.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(children: [
                Checkbox(
                  value: _subtasks[i].done,
                  onChanged: (v) =>
                      setState(() => _subtasks[i].done = v ?? false),
                ),
                Expanded(
                  child: Text(
                    _subtasks[i].title,
                    style: TextStyle(
                      decoration: _subtasks[i].done
                          ? TextDecoration.lineThrough
                          : null,
                      color: _subtasks[i].done
                          ? AppColors.textSecondary
                          : AppColors.textPrimary,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, size: 18),
                  onPressed: () =>
                      setState(() => _subtasks.removeAt(i)),
                ),
              ]),
            ),
          Row(children: [
            Expanded(
              child: TextField(
                controller: _newSub,
                decoration: const InputDecoration(
                    hintText: 'Добавить подзадачу',
                    isDense: true),
                onSubmitted: (v) {
                  if (v.trim().isEmpty) return;
                  setState(() {
                    _subtasks.add(Subtask(title: v.trim()));
                    _newSub.clear();
                  });
                },
              ),
            ),
            IconButton(
              icon: const Icon(Icons.add_circle, color: AppColors.primary),
              onPressed: () {
                if (_newSub.text.trim().isEmpty) return;
                setState(() {
                  _subtasks.add(Subtask(title: _newSub.text.trim()));
                  _newSub.clear();
                });
              },
            ),
          ]),
          const SizedBox(height: 16),
          Row(
            children: [
              if (widget.existing != null)
                Expanded(
                  child: OutlinedButton(
                    onPressed: () async {
                      await app.deleteTask(widget.existing!.id);
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
                    if (_title.text.trim().isEmpty) return;
                    final task = TaskModel(
                      id: widget.existing?.id ?? app.newId(),
                      title: _title.text.trim(),
                      description: _desc.text.trim().isEmpty ? null : _desc.text.trim(),
                      categoryId: _categoryId,
                      dueDate: _dueDate,
                      done: widget.existing?.done ?? false,
                      priority: _priority,
                      subtasks: _subtasks,
                      createdAt: widget.existing?.createdAt ?? DateTime.now(),
                      completedAt: widget.existing?.completedAt,
                    );
                    await app.upsertTask(task);
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
