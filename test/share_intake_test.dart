import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:klasc/main.dart';
import 'package:klasc/share_intake.dart';
import 'package:klasc/store.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('standalone URLs and Chrome title plus URL become links', () {
    final url = SharedDraft.fromShare(' https://example.com/article ');
    expect(url.type, ItemType.link);
    expect(url.title, '');
    final chrome =
        SharedDraft.fromShare('Useful article\nhttps://example.com/read');
    expect(chrome.type, ItemType.link);
    expect(chrome.title, 'Useful article');
    expect(chrome.content, 'https://example.com/read');
    final prose = SharedDraft.fromShare('Read https://example.com later');
    expect(prose.type, ItemType.note);
    expect(prose.content, 'Read https://example.com later');
  });
  test('cold start native share is consumed once; warm shares remain queued',
      () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(
        ShareIntake.channel,
        (call) async => [
              {'text': 'https://example.com', 'subject': 'An article'},
              {'text': 'Second startup share'}
            ]);
    addTearDown(
        () => messenger.setMockMethodCallHandler(ShareIntake.channel, null));
    final intake = ShareIntake();
    await intake.initialize();
    expect(intake.take()!.title, 'An article');
    expect(intake.take()!.content, 'Second startup share');
    expect(intake.take(), isNull);
    await messenger.handlePlatformMessage(
        'klasc/share',
        const StandardMethodCodec().encodeMethodCall(
            const MethodCall('received', {'text': 'Warm shared note'})),
        (_) {});
    expect(intake.take()!.content, 'Warm shared note');
    intake.receive({'text': '   '});
    expect(intake.hasPending, isFalse);
  });
  testWidgets(
      'shared URL opens prefilled editor, remains unsaved, and can be tagged and saved',
      (tester) async {
    sqfliteFfiInit();
    final store = await ItemStore.open(
        factory: databaseFactoryFfiNoIsolate, path: inMemoryDatabasePath);
    addTearDown(store.db.close);
    await tester.pumpWidget(KlascApp(store: store));
    await tester.pumpAndSettle();
    shareIntake.receive(
        {'text': 'https://example.com/article', 'subject': 'Chrome article'});
    await tester.pumpAndSettle();
    expect(find.byType(Editor), findsOneWidget);
    expect((await store.all()), isEmpty);
    expect(
        tester
            .widget<TextFormField>(find.byType(TextFormField).at(0))
            .controller!
            .text,
        'Chrome article');
    expect(
        tester
            .widget<TextFormField>(find.byType(TextFormField).at(1))
            .controller!
            .text,
        'https://example.com/article');
    await tester.enterText(find.byType(TextFormField).at(2), 'reading');
    await tester.scrollUntilVisible(find.text('Save item'), 250,
        scrollable: find.byType(Scrollable).first);
    await tester.tap(find.text('Save item'));
    await tester.pumpAndSettle();
    final saved = (await store.all()).single;
    expect(saved.type, ItemType.link);
    expect(saved.tags, ['reading']);
  });
  testWidgets('a second share waits until the current draft is closed',
      (tester) async {
    sqfliteFfiInit();
    final store = await ItemStore.open(
        factory: databaseFactoryFfiNoIsolate, path: inMemoryDatabasePath);
    addTearDown(store.db.close);
    await tester.pumpWidget(KlascApp(store: store));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save ideas'));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.byType(TextFormField).at(0), 'Draft in progress');
    shareIntake.receive({'text': 'A separate shared note'});
    await tester.pumpAndSettle();
    expect(
        tester
            .widget<TextFormField>(find.byType(TextFormField).at(0))
            .controller!
            .text,
        'Draft in progress');
    expect(shareIntake.hasPending, isTrue);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.byType(Editor), findsOneWidget);
    expect(
        tester
            .widget<TextFormField>(find.byType(TextFormField).at(1))
            .controller!
            .text,
        'A separate shared note');
    expect(shareIntake.hasPending, isFalse);
    expect(await store.all(), isEmpty);
    await tester.pageBack();
    await tester.pumpAndSettle();
  });
  test(
      'shared content is never silently truncated and malformed subjects are ignored',
      () {
    final intake = ShareIntake();
    final longText = 'Long note ' * 6000;
    intake.receive({'text': longText, 'subject': 42});
    final draft = intake.take()!;
    expect(draft.content, longText);
    expect(draft.title, '');
    expect(draft.type, ItemType.note);
  });
}
