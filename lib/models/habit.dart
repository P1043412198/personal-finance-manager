enum HabitKind { good, bad }

class HabitModel {
  final String id;
  String name;
  HabitKind kind;
  String? categoryId;
  String iconKey;
  int colorValue;
  double savePerDay;
  DateTime createdAt;

  HabitModel({
    required this.id,
    required this.name,
    required this.kind,
    this.categoryId,
    this.iconKey = 'sport',
    this.colorValue = 0xFF2E7D32,
    this.savePerDay = 0,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'kind': kind.name,
        'categoryId': categoryId,
        'iconKey': iconKey,
        'colorValue': colorValue,
        'savePerDay': savePerDay,
        'createdAt': createdAt.toIso8601String(),
      };

  factory HabitModel.fromJson(Map j) => HabitModel(
        id: j['id'] as String,
        name: j['name'] as String,
        kind: HabitKind.values
            .firstWhere((e) => e.name == j['kind'], orElse: () => HabitKind.good),
        categoryId: j['categoryId'] as String?,
        iconKey: j['iconKey'] as String? ?? 'sport',
        colorValue: (j['colorValue'] as num?)?.toInt() ?? 0xFF2E7D32,
        savePerDay: (j['savePerDay'] as num?)?.toDouble() ?? 0,
        createdAt: DateTime.parse(j['createdAt']),
      );
}

class HabitLog {
  final String habitId;
  /// yyyy-MM-dd
  final String dayKey;

  HabitLog(this.habitId, this.dayKey);

  String get id => '${habitId}_$dayKey';
}
