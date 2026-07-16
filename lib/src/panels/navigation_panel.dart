import 'package:flutter/material.dart';

/// A panel that shows the named route tree, route push buttons, and supports
/// displaying the navigation history via an optional
/// [NavigationHistoryObserver].
///
/// Pass [routes] as a map of route name → [WidgetBuilder]. A button is
/// rendered for each entry. The host app typically passes a subset of its
/// route table so that testers can jump directly to any screen.
///
/// When this panel is rendered from a [Drawer], route pushes need a navigator
/// obtained from [navigatorKey], because the drawer context is not a descendant
/// of the app's [Navigator].
///
/// To also show the route stack, create a [NavigationHistoryObserver],
/// register it in `MaterialApp.navigatorObservers`, and pass the same
/// instance as [historyObserver].
class NavigationPanel extends StatefulWidget {
  const NavigationPanel({
    this.routes = const {},
    this.historyObserver,
    this.navigatorKey,
    super.key,
  });

  /// Named routes that will become navigation buttons.
  final Map<String, WidgetBuilder> routes;

  /// Optional observer used to display the current navigation stack.
  final NavigationHistoryObserver? historyObserver;

  /// Optional navigator key used for route pushes when this panel is rendered
  /// outside of the app's Navigator subtree (for example inside a Drawer).
  final GlobalKey<NavigatorState>? navigatorKey;

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
            'Navigation tree',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          _RouteTreeWidget(routes: widget.routes.keys),
          const Divider(),
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
                    final navigator =
                        widget.navigatorKey?.currentState ??
                        Navigator.maybeOf(context);
                    if (navigator == null) {
                      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
                        const SnackBar(
                          content: Text(
                            'No Navigator found. Pass navigatorKey to DebuggingToolsWrapper.',
                          ),
                        ),
                      );
                      return;
                    }

                    navigator.push<void>(
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

class _RouteTreeWidget extends StatelessWidget {
  const _RouteTreeWidget({required this.routes});

  final Iterable<String> routes;

  @override
  Widget build(BuildContext context) {
    final root = _RouteTreeNode(label: '/');
    for (final route in routes) {
      root.addRoute(route);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: _buildRows(context, root, depth: 0),
    );
  }

  List<Widget> _buildRows(
    BuildContext context,
    _RouteTreeNode node, {
    required int depth,
  }) {
    final textTheme = Theme.of(context).textTheme;
    final children = <Widget>[
      Padding(
        padding: EdgeInsets.only(left: depth * 16),
        child: Row(
          children: [
            Icon(
              node.children.isEmpty
                  ? Icons.radio_button_unchecked
                  : Icons.account_tree,
              size: 16,
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                node.label,
                overflow: TextOverflow.ellipsis,
                style: node.isRoute
                    ? textTheme.bodyMedium
                    : textTheme.bodySmall,
              ),
            ),
          ],
        ),
      ),
    ];

    for (final child in node.sortedChildren) {
      children.addAll(_buildRows(context, child, depth: depth + 1));
    }
    return children;
  }
}

class _RouteTreeNode {
  _RouteTreeNode({required this.label});

  final String label;
  final Map<String, _RouteTreeNode> children = {};
  bool isRoute = false;

  List<_RouteTreeNode> get sortedChildren {
    final values = children.values.toList();
    values.sort((a, b) => a.label.compareTo(b.label));
    return values;
  }

  void addRoute(String route) {
    if (route == '/') {
      isRoute = true;
      return;
    }

    final normalized = route.startsWith('/') ? route.substring(1) : route;
    final segments = normalized
        .split('/')
        .where((segment) => segment.isNotEmpty);
    var current = this;
    var path = '';
    for (final segment in segments) {
      path = '$path/$segment';
      current = current.children.putIfAbsent(
        path,
        () => _RouteTreeNode(label: path),
      );
    }
    current.isRoute = true;
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
