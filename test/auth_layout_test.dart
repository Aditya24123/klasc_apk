import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:klasc/cloud_gate.dart';
import 'package:klasc/design.dart';

void main() {
  testWidgets('welcome and sign-up fit a small phone with large text',
      (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(
        theme: klascTheme(),
        home: const MediaQuery(
            data: MediaQueryData(
                size: Size(320, 568), textScaler: TextScaler.linear(1.8)),
            child: AuthScreen(cloudReady: false))));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Create account'), 250,
        scrollable: find.byType(Scrollable).first);
    await tester.tap(find.text('Create account'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Use this device only'), 250,
        scrollable: find.byType(Scrollable).first);
    expect(tester.takeException(), isNull);
  });
}
