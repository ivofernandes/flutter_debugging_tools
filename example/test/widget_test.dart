import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:example/main.dart';

void main() {
  testWidgets('switches modes from home and settings', (WidgetTester tester) async {
    await tester.pumpWidget(const ExampleApp());

    expect(find.text('Current Mode: Demo'), findsOneWidget);

    await tester.tap(find.text('Staging'));
    await tester.pumpAndSettle();

    expect(find.text('Current Mode: Staging'), findsOneWidget);

    await tester.tap(find.byKey(const Key('open-settings-button')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('mode-radio-production')));
    await tester.pumpAndSettle();

    expect(find.text('Production'), findsWidgets);

    await tester.pageBack();
    await tester.pumpAndSettle();

    expect(find.text('Current Mode: Production'), findsOneWidget);
  });

  testWidgets('navigates from catalog list to item details and back home', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const ExampleApp());

    await tester.tap(find.byKey(const Key('open-catalog-button')));
    await tester.pumpAndSettle();

    expect(find.text('Catalog'), findsOneWidget);

    await tester.tap(find.byKey(const Key('catalog-item-1')));
    await tester.pumpAndSettle();

    expect(find.text('Network Logs'), findsOneWidget);
    expect(find.text('Running in Demo mode'), findsOneWidget);

    await tester.tap(find.byKey(const Key('catalog-item-back-home-button')));
    await tester.pumpAndSettle();

    expect(find.text('Debugging Tools Example'), findsOneWidget);
    expect(find.text('Current Mode: Demo'), findsOneWidget);
  });
}
