import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/category.dart';
import '../../models/note.dart';
import '../../providers/app_state.dart';
import '../../theme/app_theme.dart';
import '../../utils/format.dart';
import '../../utils/i18n.dart';
import '../../widgets/section.dart';

class NotesScreen extends StatefulWidget {
  const NotesScreen({super.key});

  @override
  State<NotesScreen> createState() => _NotesScreenState();
}

class _NotesScreenState extends State<NotesScreen> {
  String _filter = '';

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final i18n = context.watch<I18n>();
    final cats = app.categoriesByScope('note');
    final notes = app.noteAll().where((n) {
      if (_filter.isEmpty) return true;
      return n.categoryId == _filter;
    }).toList();
    return Scaffold(
      appBar: AppBar(title: Text(i18n.t('notes'))),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const NoteEditScreen(existing: null))),
        child: const Icon(Icons.add),
      ),
      body: Column(
        children: [
          if (cats.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
              child: SizedBox(
                height: 36,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(i18n.t('all')),
                        selected: _filter.isEmpty,
                        onSelected: (_) => setState(() => _filter = ''),
                      ),
                    ),
                    for (final c in cats)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text('${CategoryIcons.resolve(c.iconKey)} ${c.name}'),
                          selected: _filter == c.id,
                          onSelected: (_) => setState(() => _filter = _filter == c.id ? '' : c.id),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          Expanded(
            child: notes.isEmpty
                ? Center(
                    child: Text(i18n.t('no_notes'),
                        style: const TextStyle(color: AppColors.textSecondary)))
                : ListView(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                    children: [
                      for (final n in notes)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _NoteCard(note: n),
                        ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class _NoteCard extends StatelessWidget {
  final NoteModel note;
  const _NoteCard({required this.note});

  @override
  Widget build(BuildContext context) {
    final app = context.read<AppState>();
    final i18n = context.watch<I18n>();
    final cat = app.categoryById(note.categoryId);
    return AppCard(
      onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => NoteEditScreen(existing: note))),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (cat != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: cat.color.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text('${CategoryIcons.resolve(cat.iconKey)} ${cat.name}',
                      style: TextStyle(color: cat.color, fontSize: 11, fontWeight: FontWeight.w600)),
                ),
              const Spacer(),
              Text(Fmt.shortDate(note.updatedAt, locale: i18n.locale.languageCode),
                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 11)),
            ],
          ),
          if (note.title.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(note.title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          ],
          if (note.body.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(note.body,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: AppColors.textPrimary, fontSize: 13)),
          ],
          if (note.imagePaths.isNotEmpty) ...[
            const SizedBox(height: 8),
            SizedBox(
              height: 80,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  for (final p in note.imagePaths)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: File(p).existsSync()
                            ? Image.file(File(p), width: 80, height: 80, fit: BoxFit.cover)
                            : Container(
                                width: 80, height: 80, color: AppColors.muted,
                                child: const Icon(Icons.broken_image),
                              ),
                      ),
                    ),
                ],
              ),
            ),
          ],
          if (note.links.isNotEmpty) ...[
            const SizedBox(height: 6),
            for (final l in note.links.take(2))
              Row(
                children: [
                  Icon(Icons.link, size: 14, color: AppColors.primary),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(l,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: AppColors.primary, fontSize: 12)),
                  ),
                ],
              ),
          ],
        ],
      ),
    );
  }
}

class NoteEditScreen extends StatefulWidget {
  final NoteModel? existing;
  const NoteEditScreen({super.key, required this.existing});

  @override
  State<NoteEditScreen> createState() => _NoteEditScreenState();
}

class _NoteEditScreenState extends State<NoteEditScreen> {
  late TextEditingController _title;
  late TextEditingController _body;
  late TextEditingController _link;
  String? _categoryId;
  late List<String> _images;
  late List<String> _links;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _title = TextEditingController(text: e?.title ?? '');
    _body = TextEditingController(text: e?.body ?? '');
    _link = TextEditingController();
    _categoryId = e?.categoryId;
    _images = List.from(e?.imagePaths ?? []);
    _links = List.from(e?.links ?? []);
  }

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    _link.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    try {
      final picker = ImagePicker();
      final x = await picker.pickImage(source: ImageSource.gallery, maxWidth: 2000);
      if (x != null) setState(() => _images.add(x.path));
    } catch (e) {
      // ignore
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final i18n = context.watch<I18n>();
    final cats = app.categoriesByScope('note');

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.existing == null ? i18n.t('add_note') : i18n.t('edit')),
        actions: [
          if (widget.existing != null)
            IconButton(
              onPressed: () async {
                await app.deleteNote(widget.existing!.id);
                if (!mounted) return;
                Navigator.pop(context);
              },
              icon: const Icon(Icons.delete_outline),
            ),
          IconButton(
            onPressed: () async {
              final note = NoteModel(
                id: widget.existing?.id ?? app.newId(),
                title: _title.text.trim(),
                body: _body.text.trim(),
                categoryId: _categoryId,
                imagePaths: _images,
                links: _links,
                createdAt: widget.existing?.createdAt ?? DateTime.now(),
                updatedAt: DateTime.now(),
              );
              await app.upsertNote(note);
              if (!mounted) return;
              Navigator.pop(context);
            },
            icon: const Icon(Icons.check),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        children: [
          TextField(
            controller: _title,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
            decoration: InputDecoration(
              hintText: i18n.t('task_title'),
              filled: false,
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              hintStyle: const TextStyle(fontSize: 22, color: AppColors.textSecondary),
            ),
          ),
          // Categories
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
          const SizedBox(height: 8),
          TextField(
            controller: _body,
            decoration: InputDecoration(hintText: i18n.t('note_text')),
            maxLines: 8,
            minLines: 4,
          ),
          const SizedBox(height: 12),
          if (_images.isNotEmpty)
            SizedBox(
              height: 100,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  for (int i = 0; i < _images.length; i++)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: Stack(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: File(_images[i]).existsSync()
                                ? Image.file(File(_images[i]), width: 100, height: 100, fit: BoxFit.cover)
                                : Container(width: 100, height: 100, color: AppColors.muted, child: const Icon(Icons.broken_image)),
                          ),
                          Positioned(
                            top: 4, right: 4,
                            child: GestureDetector(
                              onTap: () => setState(() => _images.removeAt(i)),
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                                child: const Icon(Icons.close, size: 14, color: Colors.white),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _pickImage,
            icon: const Icon(Icons.image_outlined),
            label: Text(i18n.t('attach_image')),
          ),
          const SizedBox(height: 12),
          if (_links.isNotEmpty)
            for (int i = 0; i < _links.length; i++)
              ListTile(
                leading: Icon(Icons.link, color: AppColors.primary),
                title: GestureDetector(
                  onTap: () async {
                    final uri = Uri.tryParse(_links[i]);
                    if (uri != null) await launchUrl(uri, mode: LaunchMode.externalApplication);
                  },
                  child: Text(_links[i],
                      style: TextStyle(color: AppColors.primary), overflow: TextOverflow.ellipsis),
                ),
                trailing: IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => setState(() => _links.removeAt(i))),
                contentPadding: EdgeInsets.zero,
              ),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _link,
                  decoration: InputDecoration(hintText: 'https://...'),
                ),
              ),
              IconButton(
                onPressed: () {
                  if (_link.text.trim().isNotEmpty) {
                    setState(() {
                      _links.add(_link.text.trim());
                      _link.clear();
                    });
                  }
                },
                icon: const Icon(Icons.add_link),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
