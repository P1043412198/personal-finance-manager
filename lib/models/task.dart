enum TaskPriority { low, medium, high }

class Subtask {
  String title;
  bool done;
  Subtask({required this.title, this.done = false});

  Map<String, dynamic> toJson() => {'title': title, 'done': done};
  factory Subtask.fromJson(Map j) =>
      Subtask(title: j['title']?.toString() ?? '', done: j['done'] == true);
}

class TaskModel {
  final String id;
  String title;
  String? description;
  String? categoryId;
  DateTime? dueDate;
  bool done;
  TaskPriority priority;
  DateTime createdAt;
  DateTime? completedAt;
  List<Subtask> subtasks;

  TaskModel({
    required this.id,
    required this.title,
    this.description,
    this.categoryId,
    this.dueDate,
    this.done = false,
    this.priority = TaskPriority.medium,
    required this.createdAt,
    this.completedAt,
    List<Subtask>? subtasks,
  }) : subtasks = subtasks ?? [];

  double get subtaskProgress {
    if (subtasks.isEmpty) return done ? 1 : 0;
    final d = subtasks.where((s) => s.done).length;
    return d / subtasks.length;
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'description': description,
        'categoryId': categoryId,
        'dueDate': dueDate?.toIso8601String(),
        'done': done,
        'priority': priority.name,
        'createdAt': createdAt.toIso8601String(),
        'completedAt': completedAt?.toIso8601String(),
        'subtasks': subtasks.map((s) => s.toJson()).toList(),
      };

  factory TaskModel.fromJson(Map j) => TaskModel(
        id: j['id'] as String,
        title: j['title'] as String,
        description: j['description'] as String?,
        categoryId: j['categoryId'] as String?,
        dueDate: j['dueDate'] != null ? DateTime.parse(j['dueDate']) : null,
        done: j['done'] as bool? ?? false,
        priority: TaskPriority.values
            .firstWhere((e) => e.name == j['priority'], orElse: () => TaskPriority.medium),
        createdAt: DateTime.parse(j['createdAt'] as String),
        completedAt:
            j['completedAt'] != null ? DateTime.parse(j['completedAt']) : null,
        subtasks: (j['subtasks'] as List?)
                ?.whereType<Map>()
                .map(Subtask.fromJson)
                .toList() ??
            [],
      );
}
