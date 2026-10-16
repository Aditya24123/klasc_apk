import 'dart:convert';
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

enum ItemType { note, link, snippet, image }

class SavedItem {
  final int id;
  final ItemType type;
  final String title, content;
  final List<String> tags;
  final DateTime created, updated;
  final bool archived;
  final Uint8List? image;
  SavedItem({
    required this.id,
    required this.type,
    required this.title,
    required this.content,
    required this.tags,
    required this.created,
    required this.updated,
    required this.archived,
    this.image,
  });
  String get label => 'Item $id';
  factory SavedItem.fromMap(Map<String, Object?> row) => SavedItem(
        id: row['id'] as int,
        type: ItemType.values.byName(row['type'] as String),
        title: row['title'] as String,
        content: row['content'] as String,
        tags: (jsonDecode(row['tags'] as String) as List).cast<String>(),
        created: DateTime.parse(row['created'] as String),
        updated: DateTime.parse(row['updated'] as String),
        archived: row['archived'] == 1,
        image: row['image'] as Uint8List?,
      );
}

List<String> parseTags(String input) => input
    .split(',')
    .map((tag) => tag.trim().toLowerCase())
    .where((tag) => tag.isNotEmpty)
    .toSet()
    .toList();

Uri? webUrl(String input) {
  final uri = Uri.tryParse(input.trim());
  if (uri == null ||
      !['http', 'https'].contains(uri.scheme) ||
      uri.host.isEmpty ||
      input.trim().contains(RegExp(r'\s'))) {
    return null;
  }
  return uri;
}

List<SavedItem> filterItems(
  List<SavedItem> items, {
  bool archived = false,
  String query = '',
  ItemType? type,
  String? tag,
}) {
  final terms = query.trim().toLowerCase().split(RegExp(r'\s+'));
  return items.where((item) {
    final searchable =
        '${item.label} ${item.title} ${item.content} ${item.tags.join(' ')}'
            .toLowerCase();
    return item.archived == archived &&
        (type == null || item.type == type) &&
        (tag == null || item.tags.contains(tag)) &&
        terms.every(searchable.contains);
  }).toList();
}

abstract interface class ItemRepository {
  bool get isCloud;
  Future<List<SavedItem>> all();
  Future<int> save(
      {int? id,
      required ItemType type,
      required String title,
      required String content,
      required List<String> tags,
      Uint8List? image});
  Future<void> archive(int id, bool value);
  Future<void> delete(int id);
}

class ItemStore implements ItemRepository {
  @override
  bool get isCloud => false;
  final Database db;
  ItemStore(this.db);
  static Future<ItemStore> open({
    DatabaseFactory? factory,
    String? path,
  }) async {
    final engine = factory ?? databaseFactory;
    final location =
        path ?? p.join(await engine.getDatabasesPath(), 'klasc.db');
    final db = await engine.openDatabase(
      location,
      options: OpenDatabaseOptions(
        version: 1,
        onCreate: (db, _) async {
          await db.execute('''CREATE TABLE items (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          type TEXT NOT NULL, title TEXT NOT NULL, content TEXT NOT NULL,
          tags TEXT NOT NULL, created TEXT NOT NULL, updated TEXT NOT NULL,
          archived INTEGER NOT NULL DEFAULT 0, image BLOB)''');
        },
      ),
    );
    return ItemStore(db);
  }

  @override
  Future<List<SavedItem>> all() async => (await db.query(
        'items',
        orderBy: 'updated DESC, id DESC',
      ))
          .map(SavedItem.fromMap)
          .toList();
  @override
  Future<int> save({
    int? id,
    required ItemType type,
    required String title,
    required String content,
    required List<String> tags,
    Uint8List? image,
  }) async {
    if (title.trim().isEmpty) throw ArgumentError('Add a title.');
    if (title.trim().length > 120) {
      throw ArgumentError('Keep titles under 120 characters.');
    }
    if (type == ItemType.link && webUrl(content) == null) {
      throw ArgumentError('Use a full http:// or https:// link.');
    }
    if (type == ItemType.image && (image == null || image.isEmpty)) {
      throw ArgumentError('Choose an image.');
    }
    if (type == ItemType.image && image!.length > 10 * 1024 * 1024) {
      throw ArgumentError('Choose an image smaller than 10 MB.');
    }
    if ((type == ItemType.note || type == ItemType.snippet) &&
        content.trim().isEmpty) {
      throw ArgumentError('Add some content.');
    }
    final now = DateTime.now().toUtc().toIso8601String();
    final values = <String, Object?>{
      'type': type.name,
      'title': title.trim(),
      'content': type == ItemType.snippet ? content : content.trim(),
      'tags': jsonEncode(parseTags(tags.join(','))),
      'updated': now,
      'image': type == ItemType.image ? image : null,
    };
    if (id == null) {
      values['created'] = now;
      return db.insert('items', values);
    }
    final count = await db.update(
      'items',
      values,
      where: 'id = ?',
      whereArgs: [id],
    );
    if (count != 1) throw StateError('This item no longer exists.');
    return id;
  }

  @override
  Future<void> archive(int id, bool value) async {
    final count = await db.update(
      'items',
      {
        'archived': value ? 1 : 0,
        'updated': DateTime.now().toUtc().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [id],
    );
    if (count != 1) throw StateError('This item no longer exists.');
  }

  @override
  Future<void> delete(int id) async {
    final count = await db.delete('items', where: 'id = ?', whereArgs: [id]);
    if (count != 1) throw StateError('This item no longer exists.');
  }
}
