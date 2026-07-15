import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

  group('AssetBundlePanel', () {
    testWidgets('lists assets from the manifest and previews text assets', (
      WidgetTester tester,
    ) async {
      final bundle = _FakeAssetBundle({
        'AssetManifest.json': '{"assets/config.json":["assets/config.json"],'
                '"images/logo.png":["images/logo.png"]}'
            .codeUnits,
        'assets/config.json': '{"api":"local"}'.codeUnits,
        'images/logo.png': _transparentPngBytes,
      });

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: AssetBundlePanel(bundle: bundle)),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('2/2 asset(s)'), findsOneWidget);
      expect(find.text('assets/config.json'), findsOneWidget);
      expect(find.text('images/logo.png'), findsOneWidget);

      await tester.tap(find.text('assets/config.json'));
      await tester.pumpAndSettle();

      expect(find.text('Selected asset: assets/config.json'), findsOneWidget);
      expect(find.text('{"api":"local"}'), findsOneWidget);
    });

    testWidgets('renders image assets as image previews', (
      WidgetTester tester,
    ) async {
      final bundle = _FakeAssetBundle({
        'AssetManifest.json': '{"images/logo.png":["images/logo.png"]}'
            .codeUnits,
        'images/logo.png': _transparentPngBytes,
      });

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: AssetBundlePanel(bundle: bundle)),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('images/logo.png'));
      await tester.pumpAndSettle();

      expect(find.text('Selected asset: images/logo.png'), findsOneWidget);
      expect(
        find.byKey(const Key('asset_bundle_image_preview')),
        findsOneWidget,
      );
      expect(find.text('<binary asset preview unavailable>'), findsNothing);
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

class _FakeAssetBundle extends CachingAssetBundle {
  _FakeAssetBundle(this.assets);

  final Map<String, List<int>> assets;

  @override
  Future<ByteData> load(String key) async {
    final value = assets[key];
    if (value == null) {
      throw FlutterError('Asset not found: $key');
    }
    final bytes = Uint8List.fromList(value);
    return ByteData.sublistView(bytes);
  }
}

const List<int> _transparentPngBytes = [
  0x89,
  0x50,
  0x4e,
  0x47,
  0x0d,
  0x0a,
  0x1a,
  0x0a,
  0x00,
  0x00,
  0x00,
  0x0d,
  0x49,
  0x48,
  0x44,
  0x52,
  0x00,
  0x00,
  0x00,
  0x01,
  0x00,
  0x00,
  0x00,
  0x01,
  0x08,
  0x06,
  0x00,
  0x00,
  0x00,
  0x1f,
  0x15,
  0xc4,
  0x89,
  0x00,
  0x00,
  0x00,
  0x0d,
  0x49,
  0x44,
  0x41,
  0x54,
  0x78,
  0x9c,
  0x63,
  0x00,
  0x01,
  0x00,
  0x00,
  0x05,
  0x00,
  0x01,
  0x0d,
  0x0a,
  0x2d,
  0xb4,
  0x00,
  0x00,
  0x00,
  0x00,
  0x49,
  0x45,
  0x4e,
  0x44,
  0xae,
  0x42,
  0x60,
  0x82,
];
