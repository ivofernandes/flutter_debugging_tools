import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_debugging_tools/flutter_debugging_tools.dart';

void main() {
  testWidgets('pushes routes using navigatorKey when built in drawer', (
    WidgetTester tester,
  ) async {
    final navigatorKey = GlobalKey<NavigatorState>();

    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigatorKey,
        home: Builder(
          builder: (context) => Scaffold(
            drawer: Drawer(
              child: NavigationPanel(
                navigatorKey: navigatorKey,
                routes: {
                  '/next': (_) => const Scaffold(
                    body: Center(child: Text('Next Page')),
                  ),
                },
              ),
            ),
            body: Center(
              child: ElevatedButton(
                onPressed: () => Scaffold.of(context).openDrawer(),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('/next'));
    await tester.pumpAndSettle();

    expect(find.text('Next Page'), findsOneWidget);
  });
}
