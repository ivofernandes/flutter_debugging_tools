import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_debugging_tools/flutter_debugging_tools.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

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
    expect(find.text('/'), findsOneWidget);
    expect(find.text('/settings'), findsOneWidget);
    expect(find.text('/settings/profile'), findsOneWidget);
    expect(find.text('/settings/security'), findsOneWidget);
    expect(find.text('/orders'), findsOneWidget);
    expect(find.text('/orders/detail'), findsOneWidget);
    expect(find.text('Push route'), findsNothing);
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

  testWidgets('wrapper restores the default before the drawer is opened', (
    WidgetTester tester,
  ) async {
    const preferenceKey = 'test.wrapper.default.route';
    SharedPreferences.setMockInitialValues({preferenceKey: '/next'});
    final observer = NavigationHistoryObserver();
    final navigatorKey = GlobalKey<NavigatorState>();

    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigatorKey,
        navigatorObservers: [observer],
        builder: (context, child) => DebuggingToolsWrapper(
          navigatorKey: navigatorKey,
          historyObserver: observer,
          navigationDefaultRoutePreferenceKey: preferenceKey,
          routes: {
            '/next': (_) => const Scaffold(body: Text('Startup Default')),
          },
          showSharedPreferencesPanel: false,
          showLocalStoragePanel: false,
          showFileSystemPanel: false,
          showAssetBundlePanel: false,
          showSQLiteBrowserPanel: false,
          showScreenSizeSimulator: false,
          child: child,
        ),
        home: const Scaffold(body: Text('Initial Page')),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Startup Default'), findsOneWidget);
    expect(observer.history, hasLength(2));
  });

  testWidgets('lets the user select and clear a default route', (
    WidgetTester tester,
  ) async {
    const preferenceKey = 'test.default.route';
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: NavigationPanel(
            defaultRoutePreferenceKey: preferenceKey,
            routes: {'/next': (_) => const SizedBox.shrink()},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Set default route'));
    await tester.pump();
    expect(
      find.text('Tap a route in the tree to make it the default.'),
      findsOneWidget,
    );

    await tester.tap(find.bySemanticsLabel('Set /next as default route'));
    await tester.pumpAndSettle();
    expect(find.text('Default: /next'), findsOneWidget);
    expect(
      (await SharedPreferences.getInstance()).getString(preferenceKey),
      '/next',
    );

    await tester.tap(find.byTooltip('Clear default route'));
    await tester.pumpAndSettle();
    expect(find.text('Default: /next'), findsNothing);
    expect(
      (await SharedPreferences.getInstance()).getString(preferenceKey),
      isNull,
    );
  });
}
