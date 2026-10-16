import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:klasc/main.dart';
import 'package:klasc/store.dart';

void main() {
  sqfliteFfiInit();
  late ItemStore store;
  setUp(() async {
    store = await ItemStore.open(
      factory: databaseFactoryFfiNoIsolate,
      path: inMemoryDatabasePath,
    );
  });
  tearDown(() async => store.db.close());

  testWidgets('create, search, edit, archive and restore through the screens', (
    tester,
  ) async {
    await tester.pumpWidget(KlascApp(store: store));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save ideas'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).at(0), 'Reading list');
    await tester.enterText(
      find.byType(TextFormField).at(1),
      'Books for winter',
    );
    await tester.enterText(
      find.byType(TextFormField).at(2),
      'Books, ideas, books',
    );
    await tester.scrollUntilVisible(find.text('Save item'), 250,
        scrollable: find.byType(Scrollable).first);
    await tester.tap(find.text('Save item'));
    await tester.pumpAndSettle();
    expect(find.text('Reading list'), findsOneWidget);
    expect(find.byTooltip('Refresh library'), findsNothing);
    expect(find.byType(FilterChip), findsNothing);
    expect(find.text('1 item'), findsNothing);
    expect(find.text('Item 1'), findsNothing);
    await tester.enterText(find.byType(TextField).first, 'missing');
    await tester.pumpAndSettle();
    expect(find.text('No matching items'), findsOneWidget);
    await tester.enterText(find.byType(TextField).first, 'winter');
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Reading list'));
    await tester.tap(find.text('Reading list'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Edit item'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).at(0), 'Winter reading');
    await tester.scrollUntilVisible(find.text('Save item'), 250,
        scrollable: find.byType(Scrollable).first);
    await tester.tap(find.text('Save item'));
    await tester.pumpAndSettle();
    expect(find.text('Winter reading'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Archive item'), 250,
        scrollable: find.byType(Scrollable).first);
    await tester.tap(find.text('Archive item'));
    await tester.pumpAndSettle();
    expect((await store.all()).single.archived, isTrue);
    await tester.tap(find.text('Archive'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Winter reading'));
    await tester.tap(find.text('Winter reading'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Restore to inbox'), 250,
        scrollable: find.byType(Scrollable).first);
    await tester.tap(find.text('Restore to inbox'));
    await tester.pumpAndSettle();
    expect((await store.all()).single.archived, isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets('small screen and large text keep the inbox scrollable', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(
            size: Size(320, 568),
            textScaler: TextScaler.linear(1.8),
          ),
          child: Home(store: store),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -400));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('search text survives scrolling the header away', (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    for (var index = 0; index < 15; index++) {
      await store.save(
          type: ItemType.note,
          title: 'Test note $index',
          content: 'Testing search persistence',
          tags: ['testing']);
    }
    await tester.pumpWidget(KlascApp(store: store));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'testing');
    await tester.pumpAndSettle();
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -1200));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(CustomScrollView), const Offset(0, 1600));
    await tester.pumpAndSettle();
    expect(
        tester.widget<TextField>(find.byType(TextField).first).controller!.text,
        'testing');
    expect(tester.takeException(), isNull);
  });
}
