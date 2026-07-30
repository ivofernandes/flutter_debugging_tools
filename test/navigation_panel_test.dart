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
                  '/next': (_) =>
                      const Scaffold(body: Center(child: Text('Next Page'))),
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

  testWidgets('shows named routes as a navigation tree', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: NavigationPanel(
            routes: {
              '/': (_) => const SizedBox.shrink(),
              '/settings': (_) => const SizedBox.shrink(),
              '/settings/profile': (_) => const SizedBox.shrink(),
              '/settings/security': (_) => const SizedBox.shrink(),
              '/orders/detail': (_) => const SizedBox.shrink(),
            },
          ),
        ),
      ),
    );

    expect(find.text('Navigation tree'), findsOneWidget);
    expect(find.text('/'), findsNWidgets(2));
    expect(find.text('/settings'), findsNWidgets(2));
    expect(find.text('/settings/profile'), findsNWidgets(2));
    expect(find.text('/settings/security'), findsNWidgets(2));
    expect(find.text('/orders'), findsOneWidget);
    expect(find.text('/orders/detail'), findsNWidgets(2));
  });

  testWidgets('navigates when a route in the navigation tree is tapped', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: NavigationPanel(
            routes: {
              '/next': (_) =>
                  const Scaffold(body: Center(child: Text('Next Page'))),
            },
          ),
        ),
      ),
    );

    await tester.tap(find.bySemanticsLabel('Navigate to /next'));
    await tester.pumpAndSettle();

    expect(find.text('Next Page'), findsOneWidget);
  });

  testWidgets('shows the live navigation stack before the route tree', (
    WidgetTester tester,
  ) async {
    final observer = NavigationHistoryObserver();
    final navigatorKey = GlobalKey<NavigatorState>();

    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigatorKey,
        navigatorObservers: [observer],
        routes: {
          '/': (_) => Scaffold(
            body: NavigationPanel(
              historyObserver: observer,
              navigatorKey: navigatorKey,
              routes: {'/details': (_) => const Text('Details')},
            ),
          ),
          '/details': (_) => const Scaffold(body: Text('Details')),
        },
      ),
    );

    expect(find.text('Navigation stack'), findsOneWidget);
    expect(find.text('CURRENT'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('Navigation stack')).dy,
      lessThan(tester.getTopLeft(find.text('Navigation tree')).dy),
    );

    final detailsRoute = MaterialPageRoute<void>(
      settings: const RouteSettings(name: '/details'),
      builder: (_) => const SizedBox.shrink(),
    );
    observer.didPush(detailsRoute, observer.history.last);
    await tester.pump();

    expect(find.text('/details'), findsNWidgets(2));
    expect(find.text('CURRENT'), findsOneWidget);

    observer.didPop(detailsRoute, observer.history.first);
    detailsRoute.dispose();
    await tester.pump();

    navigatorKey.currentState!.pushNamed('/details');
    await tester.pumpAndSettle();
    navigatorKey.currentState!.pop();
    await tester.pumpAndSettle();

    expect(observer.history, hasLength(1));
    expect(observer.history.single.settings.name, '/');
  });
}
