import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:klasc/store.dart';

void main() {
  sqfliteFfiInit();
  late Directory directory;
  late ItemStore store;
  late String path;
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('klasc_test_');
    path = '${directory.path}/library.db';
    store = await ItemStore.open(factory: databaseFactoryFfi, path: path);
  });
  tearDown(() async {
    await store.db.close();
    await directory.delete(recursive: true);
  });

  test(
    'save, tag, search, edit, archive, restore, reopen, and delete',
    () async {
      final id = await store.save(
        type: ItemType.note,
        title: ' Reading list ',
        content: 'Books for winter',
        tags: parseTags('Books, ideas, books, ,'),
      );
      expect(id, 1);
      final linkId = await store.save(
        type: ItemType.link,
        title: 'Flutter',
        content: 'https://flutter.dev',
        tags: ['learning'],
      );
      var items = await store.all();
      final original = items.firstWhere((i) => i.id == id);
      expect(original.label, 'Item 1');
      expect(original.title, 'Reading list');
      expect(original.tags, ['books', 'ideas']);
      expect(filterItems(items, query: 'WINTER books').single.id, id);
      expect(filterItems(items, type: ItemType.link).single.id, linkId);
      expect(filterItems(items, tag: 'learning').single.id, linkId);
      await store.save(
        id: id,
        type: ItemType.note,
        title: 'Updated list',
        content: 'Books for summer',
        tags: ['books'],
      );
      await store.archive(id, true);
      items = await store.all();
      expect(filterItems(items).length, 1);
      expect(filterItems(items, archived: true).single.id, id);
      expect(items.firstWhere((i) => i.id == id).created, original.created);
      await store.archive(id, false);
      await store.db.close();
      store = await ItemStore.open(factory: databaseFactoryFfi, path: path);
      items = await store.all();
      expect(items.length, 2);
      expect(filterItems(items, query: 'summer').single.title, 'Updated list');
      await store.delete(id);
      final nextId = await store.save(
        type: ItemType.snippet,
        title: 'Command',
        content: 'flutter run',
        tags: [],
      );
      expect(nextId, 3); // Deleted identifiers are never reused.
    },
  );

  test('image bytes survive closing the database', () async {
    final bytes = Uint8List.fromList([1, 2, 3, 4]);
    await store.save(
      type: ItemType.image,
      title: 'Reference',
      content: '',
      tags: [],
      image: bytes,
    );
    await store.db.close();
    store = await ItemStore.open(factory: databaseFactoryFfi, path: path);
    expect((await store.all()).single.image, bytes);
  });

  test('invalid and empty input does not create records', () async {
    for (final url in [
      'javascript:alert(1)',
      'flutter.dev',
      'https://',
      'https://a b.com',
    ]) {
      expect(webUrl(url), isNull);
      await expectLater(
        store.save(type: ItemType.link, title: 'Link', content: url, tags: []),
        throwsArgumentError,
      );
    }
    await expectLater(
      store.save(type: ItemType.note, title: ' ', content: 'Text', tags: []),
      throwsArgumentError,
    );
    await expectLater(
      store.save(type: ItemType.note, title: 'Title', content: ' ', tags: []),
      throwsArgumentError,
    );
    await expectLater(
      store.save(type: ItemType.image, title: 'Photo', content: '', tags: []),
      throwsArgumentError,
    );
    expect(await store.all(), isEmpty);
    expect(webUrl('https://example.com/path?q=hello'), isNotNull);
  });

  test('snippet spacing and normalized tags survive storage', () async {
    const code = '  print("hello");\n';
    await store.save(
      type: ItemType.snippet,
      title: 'Code',
      content: code,
      tags: [' Dart ', 'dart', '', 'CODE'],
    );
    final item = (await store.all()).single;
    expect(item.content, code);
    expect(item.tags, ['dart', 'code']);
    expect(webUrl('  https://example.com  '), isNotNull);
  });

  test('missing records cannot silently update or archive', () async {
    await expectLater(
      store.save(
        id: 99,
        type: ItemType.note,
        title: 'Missing',
        content: 'Text',
        tags: [],
      ),
      throwsStateError,
    );
    await expectLater(store.archive(99, true), throwsStateError);
    await expectLater(store.delete(99), throwsStateError);
  });
}
