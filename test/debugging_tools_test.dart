import 'package:flutter/material.dart';
import 'package:flutter_debugging_tools/flutter_debugging_tools.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DebuggingDrawer', () {
    testWidgets('renders header text when provided', (
      WidgetTester tester,
    ) async {
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

    testWidgets('renders panel titles as expansion panel headers', (
      WidgetTester tester,
    ) async {
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

    testWidgets('expands panel and shows body when tapped', (
      WidgetTester tester,
    ) async {
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

    testWidgets('shows resize handle by default', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            drawer: DebuggingDrawer(panels: []),
            body: SizedBox.shrink(),
          ),
        ),
      );

      final scaffoldState = tester.state<ScaffoldState>(find.byType(Scaffold));
      scaffoldState.openDrawer();
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('debugging_drawer_resize_handle')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('debugging_drawer_close_button')),
        findsOneWidget,
      );
    });

    testWidgets('resizes when the resize handle is dragged', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            drawer: DebuggingDrawer(
              panels: [],
              width: 320,
              resizable: true,
            ),
            body: SizedBox.shrink(),
          ),
        ),
      );

      final scaffoldState = tester.state<ScaffoldState>(find.byType(Scaffold));
      scaffoldState.openDrawer();
      await tester.pumpAndSettle();

      await tester.drag(
        find.byKey(const Key('debugging_drawer_resize_handle')),
        const Offset(80, 0),
      );
      await tester.pumpAndSettle();

      final drawer = tester.widget<Drawer>(find.byType(Drawer));
      expect(drawer.width, 400);
    });

    testWidgets('keeps resized width after closing and reopening', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            drawer: DebuggingDrawer(
              panels: [],
              width: 320,
              resizable: true,
            ),
            body: SizedBox.shrink(),
          ),
        ),
      );

      final scaffoldState = tester.state<ScaffoldState>(find.byType(Scaffold));
      scaffoldState.openDrawer();
      await tester.pumpAndSettle();

      await tester.drag(
        find.byKey(const Key('debugging_drawer_resize_handle')),
        const Offset(80, 0),
      );
      await tester.pumpAndSettle();
      scaffoldState.closeDrawer();
      await tester.pumpAndSettle();

      scaffoldState.openDrawer();
      await tester.pumpAndSettle();

      final drawer = tester.widget<Drawer>(find.byType(Drawer));
      expect(drawer.width, 400);
    });

    testWidgets('uses fractional width when configured', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            drawer: DebuggingDrawer(
              panels: [],
              widthFactor: 1,
            ),
            body: SizedBox.shrink(),
          ),
        ),
      );

      final scaffoldState = tester.state<ScaffoldState>(find.byType(Scaffold));
      scaffoldState.openDrawer();
      await tester.pumpAndSettle();

      final drawer = tester.widget<Drawer>(find.byType(Drawer));
      expect(
        drawer.width,
        tester.view.physicalSize.width / tester.view.devicePixelRatio,
      );
    });
  });

  group('DebuggingToolsWrapper', () {
    testWidgets('renders child without debug overlay when disabled', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: DebuggingToolsWrapper(
            enabled: false,
            child: Text('app content'),
          ),
        ),
      );

      expect(find.text('app content'), findsOneWidget);
      expect(find.byType(DebuggingSettingsButton), findsNothing);
      expect(find.byType(Scaffold), findsNothing);
    });

    testWidgets('renders debug overlay when explicitly enabled', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: DebuggingToolsWrapper(
            enabled: true,
            child: Text('app content'),
          ),
        ),
      );

      expect(find.text('app content'), findsOneWidget);
      expect(find.byType(DebuggingSettingsButton), findsOneWidget);
      expect(find.byType(Scaffold), findsOneWidget);
    });
  });

  group('DebugPanelItem', () {
    test('defaults expanded to false', () {
      final item = DebugPanelItem('title', const SizedBox.shrink());
      expect(item.expanded, isFalse);
    });

    test('respects explicit expanded value', () {
      final item = DebugPanelItem(
        'title',
        const SizedBox.shrink(),
        expanded: true,
      );
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
  group('AppLogsPanel', () {
    testWidgets('filters visible logs by selected minimum level', (
      WidgetTester tester,
    ) async {
      final logger = AppLogger.detached();
      logger.debug('debug detail');
      logger.info('info detail');
      logger.warning('warning detail');

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AppLogsPanel(
              logger: logger,
              initialMinimumLevel: AppLogLevel.info,
            ),
          ),
        ),
      );

      expect(find.text('App logs (2/3)'), findsOneWidget);
      expect(find.textContaining('debug detail'), findsNothing);
      expect(find.textContaining('info detail'), findsOneWidget);
      expect(find.textContaining('warning detail'), findsOneWidget);

      await tester.tap(find.text('WARNING'));
      await tester.pumpAndSettle();

      expect(find.text('App logs (1/3)'), findsOneWidget);
      expect(find.textContaining('info detail'), findsNothing);
      expect(find.textContaining('warning detail'), findsOneWidget);
    });
  });

}
