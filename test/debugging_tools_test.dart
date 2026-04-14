import 'package:debugging_tools/debugging_tools.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DebuggingDrawer', () {
    testWidgets('renders header text when provided', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            drawer: DebuggingDrawer(
              panels: const [],
              headerText: 'Test Header',
            ),
            body: const SizedBox.shrink(),
          ),
        ),
      );

      final scaffoldState = tester.state<ScaffoldState>(find.byType(Scaffold));
      scaffoldState.openDrawer();
      await tester.pumpAndSettle();

      expect(find.text('Test Header'), findsOneWidget);
    });

    testWidgets('renders panel titles as expansion panel headers', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            drawer: DebuggingDrawer(
              panels: [
                DebugPanelItem('Panel One', const Text('body one')),
                DebugPanelItem('Panel Two', const Text('body two')),
              ],
            ),
            body: const SizedBox.shrink(),
          ),
        ),
      );

      final scaffoldState = tester.state<ScaffoldState>(find.byType(Scaffold));
      scaffoldState.openDrawer();
      await tester.pumpAndSettle();

      expect(find.text('Panel One'), findsOneWidget);
      expect(find.text('Panel Two'), findsOneWidget);
    });

    testWidgets('expands panel and shows body when tapped', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            drawer: DebuggingDrawer(
              panels: [
                DebugPanelItem('My Panel', const Text('panel body content')),
              ],
            ),
            body: const SizedBox.shrink(),
          ),
        ),
      );

      final scaffoldState = tester.state<ScaffoldState>(find.byType(Scaffold));
      scaffoldState.openDrawer();
      await tester.pumpAndSettle();

      // Body not visible before expanding
      expect(find.text('panel body content'), findsNothing);

      // Tap the panel header to expand it
      await tester.tap(find.text('My Panel'));
      await tester.pumpAndSettle();

      expect(find.text('panel body content'), findsOneWidget);
    });
  });

  group('DebugPanelItem', () {
    test('defaults expanded to false', () {
      final item = DebugPanelItem('title', const SizedBox.shrink());
      expect(item.expanded, isFalse);
    });

    test('respects explicit expanded value', () {
      final item = DebugPanelItem('title', const SizedBox.shrink(), expanded: true);
      expect(item.expanded, isTrue);
    });
  });

  group('CustomConfigPanel', () {
    test('item factory creates DebugPanelItem with correct title', () {
      final item = CustomConfigPanel.item(
        title: 'Custom',
        child: const SizedBox.shrink(),
      );
      expect(item.title, 'Custom');
      expect(item.expanded, isFalse);
    });

    test('item factory respects expanded flag', () {
      final item = CustomConfigPanel.item(
        title: 'Custom',
        child: const SizedBox.shrink(),
        expanded: true,
      );
      expect(item.expanded, isTrue);
    });
  });
}
