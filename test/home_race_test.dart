import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:klasc/main.dart';
import 'package:klasc/store.dart';

class PendingStore implements ItemRepository {
  final reads = <Completer<List<SavedItem>>>[];
  @override
  bool get isCloud => false;
  @override
  Future<List<SavedItem>> all() {
    final request = Completer<List<SavedItem>>();
    reads.add(request);
    return request.future;
  }

  @override
  Future<int> save(
          {int? id,
          required ItemType type,
          required String title,
          required String content,
          required List<String> tags,
          Uint8List? image}) async =>
      throw UnimplementedError();
  @override
  Future<void> archive(int id, bool value) async => throw UnimplementedError();
  @override
  Future<void> delete(int id) async => throw UnimplementedError();
}

SavedItem note(String title) => SavedItem(
    id: 1,
    type: ItemType.note,
    title: title,
    content: 'Test content',
    tags: [],
    created: DateTime.utc(2026),
    updated: DateTime.utc(2026),
    archived: false);

void main() {
  testWidgets(
      'a slow older refresh cannot replace newer data or surface an old error',
      (tester) async {
    final store = PendingStore();
    await tester.pumpWidget(KlascApp(store: store));
    store.reads.single.complete([]);
    await tester.pumpAndSettle();
    final refresh = tester
        .widget<RefreshIndicator>(find.byType(RefreshIndicator))
        .onRefresh;
    final older = refresh(), newer = refresh();
    store.reads[2].complete([note('Newest idea')]);
    await newer;
    await tester.pumpAndSettle();
    store.reads[1].complete([note('Old result')]);
    await older;
    await tester.pumpAndSettle();
    expect(find.text('Newest idea'), findsOneWidget);
    expect(find.text('Old result'), findsNothing);
    final oldFailure = refresh(), fresh = refresh();
    store.reads[4].complete([note('Still newest')]);
    await fresh;
    store.reads[3].completeError(StateError('An old failed request'));
    await oldFailure;
    await tester.pumpAndSettle();
    expect(find.text('Still newest'), findsOneWidget);
    expect(find.text('An old failed request'), findsNothing);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
      'finishing an inbox load after leaving the screen does not update disposed state',
      (tester) async {
    final store = PendingStore();
    await tester.pumpWidget(KlascApp(store: store));
    await tester.pumpWidget(const SizedBox());
    store.reads.single.complete([note('Late idea')]);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
