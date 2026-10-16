import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:klasc/main.dart';
import 'package:klasc/store.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
      'Android: create, validate, search, edit, archive, restore and reopen',
      (tester) async {
    final store = await ItemStore.open(path: 'klasc_device_test.db');
    // Only clear this dedicated test database, never the user's library.
    await store.db.delete('items');
    await tester.pumpWidget(KlascApp(store: store));
    await tester.pumpAndSettle();

    Future<void> saveForm() async {
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(find.text('Save item'), 250,
          scrollable: find.byType(Scrollable).first);
      await tester.tap(find.text('Save item'));
      await tester.pumpAndSettle();
    }

    await tester.tap(find.text('Save ideas'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).at(0), 'Emulator note');
    await tester.enterText(
        find.byType(TextFormField).at(1), 'Books for winter');
    await tester.enterText(
        find.byType(TextFormField).at(2), 'Books, ideas, books');
    await saveForm();
    var items = await store.all();
    expect(items.single.tags, ['books', 'ideas']);
    final noteId = items.single.id;
    final created = items.single.created;

    await tester.enterText(find.byType(TextField).first, 'missing');
    await tester.pumpAndSettle();
    expect(find.text('No matching items'), findsOneWidget);
    await tester.enterText(find.byType(TextField).first, 'winter');
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Emulator note'), 200,
        scrollable: find.byType(Scrollable).first);
    await tester.tap(find.text('Emulator note'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Edit item'));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.byType(TextFormField).at(0), 'Updated emulator note');
    await saveForm();
    expect(find.text('Updated emulator note'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Archive item'), 250,
        scrollable: find.byType(Scrollable).first);
    await tester.tap(find.text('Archive item'));
    await tester.pumpAndSettle();
    expect((await store.all()).single.archived, true);
    await tester.tap(find.text('Archive'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Updated emulator note'), 250,
        scrollable: find.byType(Scrollable).first);
    await tester.tap(find.text('Updated emulator note'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Restore to inbox'), 250,
        scrollable: find.byType(Scrollable).first);
    await tester.tap(find.text('Restore to inbox'));
    await tester.pumpAndSettle();
    expect((await store.all()).single.archived, false);

    await tester.tap(find.text('Inbox'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save ideas'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Link'));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.byType(TextFormField).at(0), 'Flutter documentation');
    await tester.enterText(find.byType(TextFormField).at(1), 'bad-url');
    await saveForm();
    expect(await store.all(), hasLength(1));
    await tester.scrollUntilVisible(find.byType(TextFormField).at(1), -250,
        scrollable: find.byType(Scrollable).first);
    await tester.enterText(
        find.byType(TextFormField).at(1), 'https://flutter.dev');
    await saveForm();
    expect(await store.all(), hasLength(2));

    await tester.pumpWidget(const SizedBox.shrink());
    await store.db.close();
    final reopened = await ItemStore.open(path: 'klasc_device_test.db');
    items = await reopened.all();
    expect(items, hasLength(2));
    final note = items.firstWhere((i) => i.id == noteId);
    expect(note.title, 'Updated emulator note');
    expect(note.created, created);
    expect(note.archived, false);
    await tester.pumpWidget(KlascApp(store: reopened));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
