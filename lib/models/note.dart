class ChecklistItem {
  String text;
  bool done;
  ChecklistItem({required this.text, this.done = false});

  Map<String, dynamic> toJson() => {'text': text, 'done': done};
  factory ChecklistItem.fromJson(Map j) =>
      ChecklistItem(text: j['text']?.toString() ?? '', done: j['done'] == true);
}

class NoteModel {
  final String id;
  String title;
  String body;
  String? categoryId;
  List<String> imagePaths;
  List<String> links;
  List<ChecklistItem> checklist;
  bool markdown;
  DateTime createdAt;
  DateTime updatedAt;

  NoteModel({
    required this.id,
    required this.title,
    required this.body,
    this.categoryId,
    List<String>? imagePaths,
    List<String>? links,
    List<ChecklistItem>? checklist,
    this.markdown = false,
    required this.createdAt,
    required this.updatedAt,
  })  : imagePaths = imagePaths ?? [],
        links = links ?? [],
        checklist = checklist ?? [];

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'body': body,
        'categoryId': categoryId,
        'imagePaths': imagePaths,
        'links': links,
        'checklist': checklist.map((c) => c.toJson()).toList(),
        'markdown': markdown,
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
        checklist: (j['checklist'] as List?)
                ?.whereType<Map>()
                .map(ChecklistItem.fromJson)
                .toList() ??
            [],
        markdown: j['markdown'] == true,
        createdAt: DateTime.parse(j['createdAt']),
        updatedAt: DateTime.parse(j['updatedAt']),
      );
}
