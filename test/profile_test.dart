import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:klasc/design.dart';
import 'package:klasc/profile.dart';

void main() {
  testWidgets('username validates and saves a trimmed custom name',
      (tester) async {
    String? saved;
    await tester.pumpWidget(MaterialApp(
        theme: klascTheme(),
        home: Scaffold(
            body: ProfileDialog(
                initialName: '',
                save: (name) async {
                  saved = name;
                }))));
    await tester.tap(find.text('Save username'));
    await tester.pumpAndSettle();
    expect(find.text('Choose a username.'), findsOneWidget);
    expect(saved, isNull);
    await tester.enterText(find.byType(TextFormField), '  Aditya  ');
    await tester.tap(find.text('Save username'));
    await tester.pumpAndSettle();
    expect(saved, 'Aditya');
  });

  testWidgets('profile failure retains the name and allows retry',
      (tester) async {
    var attempts = 0;
    await tester.pumpWidget(MaterialApp(
        theme: klascTheme(),
        home: Scaffold(
            body: ProfileDialog(
                initialName: 'Aditya',
                save: (name) async {
                  attempts++;
                  throw StateError('Connection unavailable. Try again.');
                }))));
    await tester.enterText(find.byType(TextFormField), 'My ideas');
    await tester.tap(find.text('Save username'));
    await tester.pumpAndSettle();
    expect(find.text('My ideas'), findsOneWidget);
    expect(find.textContaining('Connection unavailable'), findsOneWidget);
    await tester.tap(find.text('Save username'));
    await tester.pumpAndSettle();
    expect(attempts, 2);
  });
}
