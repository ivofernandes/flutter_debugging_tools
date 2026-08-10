import 'package:flutter/material.dart';
import 'package:flutter_debugging_tools/flutter_debugging_tools.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('disabled simulator returns the child unchanged', (tester) async {
    const child = SizedBox(key: Key('child'), width: 40, height: 50);

    await tester.pumpWidget(
      const MaterialApp(
        home: ScreenSizeSimulator(enabled: false, child: child),
      ),
    );

    expect(find.byKey(const Key('child')), findsOneWidget);
    expect(find.text('Viewport'), findsNothing);
    expect(tester.getSize(find.byKey(const Key('child'))), const Size(40, 50));
  });

  testWidgets('preset updates constraints and MediaQuery size', (tester) async {
    Size? mediaQuerySize;
    BoxConstraints? childConstraints;
    await _pumpSimulator(
      tester,
      viewports: const [DebugViewport('Phone', Size(375, 500))],
      child: LayoutBuilder(
        builder: (context, constraints) {
          childConstraints = constraints;
          mediaQuerySize = MediaQuery.sizeOf(context);
          return const SizedBox.expand();
        },
      ),
    );

    await tester.tap(find.byTooltip('Select viewport'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Phone'));
    await tester.pumpAndSettle();

    expect(childConstraints?.biggest, const Size(375, 500));
    expect(mediaQuerySize, const Size(375, 500));
  });

  testWidgets('rotate swaps viewport width and height', (tester) async {
    await _pumpSimulator(
      tester,
      viewports: const [DebugViewport('Phone', Size(375, 500))],
    );
    await tester.tap(find.byTooltip('Select viewport'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Phone'));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Rotate viewport'));
    await tester.pump();

    expect(find.text('500 × 375'), findsOneWidget);
  });

  testWidgets('presets larger than the host are not offered', (tester) async {
    Size? mediaQuerySize;
    await _pumpSimulator(
      tester,
      hostSize: const Size(500, 600),
      child: Builder(
        builder: (context) {
          mediaQuerySize = MediaQuery.sizeOf(context);
          return const SizedBox.expand();
        },
      ),
    );

    expect(find.text('500 × 600'), findsOneWidget);
    await tester.tap(find.byTooltip('Select viewport'));
    await tester.pumpAndSettle();

    expect(mediaQuerySize, const Size(500, 600));
    expect(find.text('Tablet'), findsNothing);
    expect(find.text('Tablet landscape'), findsNothing);
  });

  testWidgets('exact dimensions update the viewport and sliders', (
    tester,
  ) async {
    Size? mediaQuerySize;
    await _pumpSimulator(
      tester,
      hostSize: const Size(500, 600),
      child: Builder(
        builder: (context) {
          mediaQuerySize = MediaQuery.sizeOf(context);
          return const SizedBox.expand();
        },
      ),
    );

    final widthField = find.widgetWithText(TextField, 'Width');
    await tester.enterText(widthField, '321');
    await tester.pump();

    expect(mediaQuerySize, const Size(321, 600));
    expect(find.text('321 × 600'), findsOneWidget);
    final widthSlider = tester.widget<Slider>(find.byType(Slider).first);
    expect(widthSlider.value, 321);

    await tester.enterText(widthField, '501');
    await tester.pump();

    expect(mediaQuerySize, const Size(321, 600));
    expect(tester.widget<Slider>(find.byType(Slider).first).value, 321);
  });
}

Future<void> _pumpSimulator(
  WidgetTester tester, {
  Widget child = const SizedBox.expand(),
  Size hostSize = const Size(1200, 1200),
  List<DebugViewport> viewports = ScreenSizeSimulator.defaultViewports,
}) {
  return tester.pumpWidget(
    MaterialApp(
      home: Center(
        child: SizedBox.fromSize(
          size: hostSize,
          child: ScreenSizeSimulator(viewports: viewports, child: child),
        ),
      ),
    ),
  );
}
