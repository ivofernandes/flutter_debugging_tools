import 'package:flutter/material.dart';

/// A panel that shows buttons to push named routes, and supports displaying
/// the navigation history via an optional [NavigationHistoryObserver].
///
/// Pass [routes] as a map of route name → [WidgetBuilder].  A button is
/// rendered for each entry.  The host app typically passes a subset of its
/// route table so that testers can jump directly to any screen.
///
/// To also show the route stack, create a [NavigationHistoryObserver],
/// register it in `MaterialApp.navigatorObservers`, and pass the same
/// instance as [historyObserver].
class NavigationPanel extends StatefulWidget {
  const NavigationPanel({
    this.routes = const {},
    this.historyObserver,
    super.key,
  });

  /// Named routes that will become navigation buttons.
  final Map<String, WidgetBuilder> routes;

  /// Optional observer used to display the current navigation stack.
  final NavigationHistoryObserver? historyObserver;

  @override
  State<NavigationPanel> createState() => _NavigationPanelState();
}

class _NavigationPanelState extends State<NavigationPanel> {
  @override
  Widget build(BuildContext context) {
    final observer = widget.historyObserver;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (observer != null) ...[
          const Text(
            'Route stack (top → bottom)',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          _RouteStackWidget(observer: observer),
          const Divider(),
        ],
        if (widget.routes.isEmpty)
          const Text('No routes provided. Pass routes to NavigationPanel.')
        else ...[
          const Text(
            'Push route',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          ...widget.routes.entries.map(
            (entry) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () {
                    Navigator.of(context).push<void>(
                      MaterialPageRoute<void>(
                        builder: entry.value,
                        settings: RouteSettings(name: entry.key),
                      ),
                    );
                  },
                  child: Text(entry.key),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _RouteStackWidget extends StatefulWidget {
  const _RouteStackWidget({required this.observer});
  final NavigationHistoryObserver observer;

  @override
  State<_RouteStackWidget> createState() => _RouteStackWidgetState();
}

class _RouteStackWidgetState extends State<_RouteStackWidget> {
  @override
  void initState() {
    super.initState();
    widget.observer.addListener(_rebuild);
  }

  @override
  void dispose() {
    widget.observer.removeListener(_rebuild);
    super.dispose();
  }

  void _rebuild() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final history = widget.observer.history;
    if (history.isEmpty) {
      return const Text('(empty)');
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: history.reversed
          .map(
            (r) => Text(
              r.settings.name ?? '(unnamed)',
              overflow: TextOverflow.ellipsis,
            ),
          )
          .toList(),
    );
  }
}

/// A [NavigatorObserver] that tracks the route stack.
///
/// Register it in `MaterialApp.navigatorObservers` and pass the same instance
/// to [NavigationPanel.historyObserver]:
///
/// ```dart
/// final _navObserver = NavigationHistoryObserver();
///
/// MaterialApp(
///   navigatorObservers: [_navObserver],
///   builder: (context, child) => DebuggingToolsWrapper(
///     child: child,
///     showNavigationPanel: true,
///     historyObserver: _navObserver,
///   ),
/// )
/// ```
class NavigationHistoryObserver extends NavigatorObserver with ChangeNotifier {
  final List<Route<dynamic>> _history = [];

  List<Route<dynamic>> get history => List.unmodifiable(_history);

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _history.add(route);
    notifyListeners();
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _history.remove(route);
    notifyListeners();
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _history.remove(route);
    notifyListeners();
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    if (oldRoute != null) {
      final index = _history.indexOf(oldRoute);
      if (index != -1 && newRoute != null) {
        _history[index] = newRoute;
      }
    }
    notifyListeners();
  }
}
