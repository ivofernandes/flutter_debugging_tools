import 'package:flutter/material.dart';

import '../model/debug_panel_item.dart';
import '../panels/local_storage_panel.dart';
import '../panels/navigation_panel.dart';
import '../panels/shared_preferences_panel.dart';
import 'debugging_drawer.dart';
import 'debugging_settings_button.dart';

/// A convenience widget that wires up the full debugging overlay in one place.
///
/// Intended to be used in the `builder` callback of [MaterialApp]:
///
/// ```dart
/// MaterialApp(
///   builder: (context, child) => DebuggingToolsWrapper(
///     child: child,
///   ),
/// )
/// ```
///
/// All built-in panels (shared preferences, local storage, navigation) are
/// enabled by default. Pass `false` for any flag to disable them.
///
/// Custom panels can be provided via [extraPanels]; they are appended after
/// the built-in panels.
///
/// [routes] is forwarded to [NavigationPanel] so route-push buttons appear.
///
/// [historyObserver] is forwarded to [NavigationPanel] to show the live route
/// stack.  Register the same instance in `MaterialApp.navigatorObservers`:
///
/// ```dart
/// final _navObserver = NavigationHistoryObserver();
/// final _navigatorKey = GlobalKey<NavigatorState>();
///
/// MaterialApp(
///   navigatorKey: _navigatorKey,
///   navigatorObservers: [_navObserver],
///   builder: (context, child) => DebuggingToolsWrapper(
///     child: child,
///     historyObserver: _navObserver,
///     navigatorKey: _navigatorKey,
///   ),
/// )
/// ```
///
/// [localStorageBuilder] is forwarded to [LocalStoragePanel] so the host app
/// can inject its own storage inspection widget.
class DebuggingToolsWrapper extends StatefulWidget {
  const DebuggingToolsWrapper({
    required this.child,
    this.showSharedPreferencesPanel = true,
    this.showNavigationPanel = true,
    this.showLocalStoragePanel = true,
    this.extraPanels = const [],
    this.routes = const {},
    this.historyObserver,
    this.navigatorKey,
    this.localStorageBuilder,
    this.drawerHeaderText,
    super.key,
  });

  final Widget? child;
  final bool showSharedPreferencesPanel;
  final bool showNavigationPanel;
  final bool showLocalStoragePanel;

  /// Additional custom panels appended after the built-in ones.
  final List<DebugPanelItem> extraPanels;

  /// Named routes forwarded to [NavigationPanel].
  final Map<String, WidgetBuilder> routes;

  /// Optional observer forwarded to [NavigationPanel] for live route-stack display.
  final NavigationHistoryObserver? historyObserver;

  /// Optional navigator key used by [NavigationPanel] for route pushes.
  final GlobalKey<NavigatorState>? navigatorKey;

  /// Optional builder forwarded to [LocalStoragePanel].
  final WidgetBuilder? localStorageBuilder;

  /// Optional text shown at the top of the debug drawer.
  final String? drawerHeaderText;

  @override
  State<DebuggingToolsWrapper> createState() => _DebuggingToolsWrapperState();
}

class _DebuggingToolsWrapperState extends State<DebuggingToolsWrapper> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  List<DebugPanelItem> _buildPanels() {
    return [
      if (widget.showSharedPreferencesPanel)
        DebugPanelItem(
          'Shared Preferences',
          SharedPreferencesPanel(navigatorKey: widget.navigatorKey),
          expanded: true,
        ),
      if (widget.showNavigationPanel)
        DebugPanelItem(
          'Navigation',
          NavigationPanel(
            routes: widget.routes,
            historyObserver: widget.historyObserver,
            navigatorKey: widget.navigatorKey,
          ),
        ),
      if (widget.showLocalStoragePanel)
        DebugPanelItem(
          'Local Storage',
          LocalStoragePanel(customBuilder: widget.localStorageBuilder),
        ),
      ...widget.extraPanels,
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      drawer: DebuggingDrawer(
        panels: _buildPanels(),
        headerText: widget.drawerHeaderText ?? '🐛 Debug Tools',
      ),
      body: Stack(
        children: [
          widget.child ?? const SizedBox.shrink(),
          DebuggingSettingsButton(scaffoldKey: _scaffoldKey),
        ],
      ),
    );
  }
}
