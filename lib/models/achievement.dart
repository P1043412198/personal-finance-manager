class AchievementModel {
  final String id;
  final String key;
  final String iconKey;
  final DateTime unlockedAt;

  AchievementModel({
    required this.id,
    required this.key,
    required this.iconKey,
    required this.unlockedAt,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'key': key,
        'iconKey': iconKey,
        'unlockedAt': unlockedAt.toIso8601String(),
      };

  factory AchievementModel.fromJson(Map j) => AchievementModel(
        id: j['id'] as String,
        key: j['key'] as String,
        iconKey: j['iconKey'] as String,
        unlockedAt: DateTime.parse(j['unlockedAt'] as String),
      );
}

class AchievementCatalog {
  static const items = [
    ('first_tx', '💰'),
    ('first_task', '✅'),
    ('first_habit', '🌱'),
    ('first_goal', '🎯'),
    ('first_note', '📝'),
    ('first_budget', '📊'),
    ('first_wallet', '👛'),
    ('week_streak', '🔥'),
    ('month_streak', '🌟'),
    ('hundred_tx', '💯'),
    ('saver', '🏆'),
    ('budget_keeper', '🛡️'),
  ];
}
