class NoteModel {
  final String id;
  String title;
  String body;
  String? categoryId;
  List<String> imagePaths;
  List<String> links;
  DateTime createdAt;
  DateTime updatedAt;

  NoteModel({
    required this.id,
    required this.title,
    required this.body,
    this.categoryId,
    List<String>? imagePaths,
    List<String>? links,
    required this.createdAt,
    required this.updatedAt,
  })  : imagePaths = imagePaths ?? [],
        links = links ?? [];

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'body': body,
        'categoryId': categoryId,
        'imagePaths': imagePaths,
        'links': links,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory NoteModel.fromJson(Map j) => NoteModel(
        id: j['id'] as String,
        title: j['title'] as String,
        body: j['body'] as String,
        categoryId: j['categoryId'] as String?,
        imagePaths: (j['imagePaths'] as List?)?.map((e) => e.toString()).toList() ?? [],
        links: (j['links'] as List?)?.map((e) => e.toString()).toList() ?? [],
        createdAt: DateTime.parse(j['createdAt']),
        updatedAt: DateTime.parse(j['updatedAt']),
      );
}
