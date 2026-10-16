import 'dart:async';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:klasc/design.dart';
import 'package:klasc/image_data.dart';
import 'package:klasc/public_share.dart';

const token =
    'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
Map<String, dynamic> idea(String title) => {
      'type': 'note',
      'title': title,
      'content': 'A readable shared idea.',
      'imageData': null
    };
Widget page(
        {required Future<Map<String, dynamic>?> Function(String) loader,
        String value = token}) =>
    MaterialApp(
        theme: klascTheme(),
        home: PublicItemPage(token: value, loader: loader));

void main() {
  test('malformed stored images cannot break decoding', () {
    expect(decodeImageData('not base64%%%'), isNull);
    expect(decodeImageData(''), isNull);
    expect(decodeImageData(42), isNull);
    expect(decodeImageData('aGVsbG8='), [104, 101, 108, 108, 111]);
  });
  testWidgets(
      'corrupt image falls back while title and content stay readable and accessible',
      (tester) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(page(
        loader: (_) async => {
              ...idea('Readable title'),
              'type': 'image',
              'imageData': 'broken%%%'
            }));
    await tester.pumpAndSettle();
    expect(find.text('Image unavailable'), findsOneWidget);
    expect(find.bySemanticsLabel('Readable title'), findsOneWidget);
    expect(find.bySemanticsLabel('A readable shared idea.'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    semantics.dispose();
  });
  testWidgets('revocation clears content and stops automatic polling',
      (tester) async {
    var available = true, calls = 0;
    await tester.pumpWidget(page(loader: (_) async {
      calls++;
      return available ? idea('Visible initially') : null;
    }));
    await tester.pumpAndSettle();
    expect(find.text('Visible initially'), findsOneWidget);
    available = false;
    await tester.pump(const Duration(seconds: 30));
    await tester.pumpAndSettle();
    expect(find.text('This link is unavailable'), findsOneWidget);
    expect(find.text('Visible initially'), findsNothing);
    await tester.pump(const Duration(seconds: 30));
    expect(calls, 2);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('network failure offers a working retry and clears old content',
      (tester) async {
    var offline = false;
    await tester.pumpWidget(page(loader: (_) async {
      if (offline) {
        throw FirebaseException(plugin: 'cloud_firestore', code: 'unavailable');
      }
      return idea('Online idea');
    }));
    await tester.pumpAndSettle();
    offline = true;
    await tester.pump(const Duration(seconds: 30));
    await tester.pumpAndSettle();
    expect(find.text('Could not load this idea'), findsOneWidget);
    expect(find.text('Online idea'), findsNothing);
    offline = false;
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();
    expect(find.text('Online idea'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('changing token discards a late response for the previous token',
      (tester) async {
    final oldRequest = Completer<Map<String, dynamic>?>();
    Future<Map<String, dynamic>?> loader(String value) async =>
        value == token ? await oldRequest.future : idea('New public item');
    await tester.pumpWidget(page(loader: loader));
    await tester.pump();
    await tester.pumpWidget(page(loader: loader, value: 'b' * 64));
    await tester.pumpAndSettle();
    expect(find.text('New public item'), findsOneWidget);
    oldRequest.complete(idea('Stale response'));
    await tester.pumpAndSettle();
    expect(find.text('Stale response'), findsNothing);
    expect(find.text('New public item'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('malformed token is unavailable without making a backend request',
      (tester) async {
    var calls = 0;
    await tester.pumpWidget(page(
        value: '1',
        loader: (_) async {
          calls++;
          return idea('Never requested');
        }));
    await tester.pumpAndSettle();
    expect(find.text('This link is unavailable'), findsOneWidget);
    expect(calls, 0);
    await tester.pumpWidget(const SizedBox());
  });
}
