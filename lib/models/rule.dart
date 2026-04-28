class CategoryRule {
  final String id;
  String matchShop;
  String matchComment;
  String categoryId;

  CategoryRule({
    required this.id,
    this.matchShop = '',
    this.matchComment = '',
    required this.categoryId,
  });

  bool matches(String? shop, String? comment) {
    final s = (shop ?? '').toLowerCase();
    final c = (comment ?? '').toLowerCase();
    if (matchShop.isNotEmpty && s.contains(matchShop.toLowerCase())) return true;
    if (matchComment.isNotEmpty && c.contains(matchComment.toLowerCase())) return true;
    return false;
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'matchShop': matchShop,
        'matchComment': matchComment,
        'categoryId': categoryId,
      };

  factory CategoryRule.fromJson(Map j) => CategoryRule(
        id: j['id'] as String,
        matchShop: j['matchShop'] as String? ?? '',
        matchComment: j['matchComment'] as String? ?? '',
        categoryId: j['categoryId'] as String,
      );
}
