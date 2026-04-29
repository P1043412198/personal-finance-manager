class GoalModel {
  final String id;
  String name;
  double target;
  double current;
  DateTime? deadline;
  String iconKey;
  int colorValue;
  DateTime createdAt;
  int sortIndex;

  GoalModel({
    required this.id,
    required this.name,
    required this.target,
    this.current = 0,
    this.deadline,
    this.iconKey = 'savings',
    this.colorValue = 0xFF2E7D32,
    required this.createdAt,
    this.sortIndex = 0,
  });

  double get progress => target == 0 ? 0 : (current / target).clamp(0.0, 1.0);

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'target': target,
        'current': current,
        'deadline': deadline?.toIso8601String(),
        'iconKey': iconKey,
        'colorValue': colorValue,
        'createdAt': createdAt.toIso8601String(),
        'sortIndex': sortIndex,
      };

  factory GoalModel.fromJson(Map j) => GoalModel(
        id: j['id'] as String,
        name: j['name'] as String,
        target: (j['target'] as num).toDouble(),
        current: (j['current'] as num?)?.toDouble() ?? 0,
        deadline: j['deadline'] != null ? DateTime.parse(j['deadline']) : null,
        iconKey: j['iconKey'] as String? ?? 'savings',
        colorValue: (j['colorValue'] as num?)?.toInt() ?? 0xFF2E7D32,
        createdAt: DateTime.parse(j['createdAt']),
        sortIndex: (j['sortIndex'] as num?)?.toInt() ?? 0,
      );
}
