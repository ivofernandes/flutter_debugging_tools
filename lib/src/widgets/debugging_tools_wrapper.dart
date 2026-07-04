import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import '../logging/app_logger.dart';
import '../model/debug_panel_item.dart';
import '../network/debug_http_client.dart';
import '../panels/app_logs_panel.dart';
import '../panels/file_system_panel.dart';
import '../panels/local_storage_panel.dart';
import '../panels/navigation_panel.dart';
import '../panels/network_logs_panel.dart';
import '../panels/network_request_panel.dart';
import '../panels/shared_preferences_panel.dart';
import '../panels/sqlite_browser_panel.dart';
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
    this.enabled = !kReleaseMode,
    this.showSharedPreferencesPanel = true,
    this.showNavigationPanel = true,
    this.showLocalStoragePanel = true,
    this.showFileSystemPanel = true,
    this.showSQLiteBrowserPanel = true,
    this.showNetworkRequestPanel = false,
    this.showNetworkLogsPanel = false,
    this.showAppLogsPanel = false,
    this.extraPanels = const [],
    this.routes = const {},
    this.historyObserver,
    this.navigatorKey,
    this.localStorageBuilder,
    this.fileSystemController,
    this.fileSystemRootDirectoryProvider,
    this.sqliteDatabase,
    this.networkClient,
    this.appLogger,
    this.drawerHeaderText,
    super.key,
  });

  final Widget? child;

  /// Whether the debugging overlay should be mounted.
  ///
  /// Defaults to disabled in release builds and enabled otherwise. Pass `true`
  /// to intentionally expose the tools in release builds, such as when an
  /// app-level feature flag or authorized dev mode allows production
  /// diagnostics.
  final bool enabled;

  final bool showSharedPreferencesPanel;
  final bool showNavigationPanel;
  final bool showLocalStoragePanel;

  /// Shows the generic file-system browser. When [fileSystemController] is not
  /// provided, the wrapper automatically roots it at
  /// `getApplicationDocumentsDirectory()`.
  final bool showFileSystemPanel;

  /// Shows the SQLite browser when an explicit [sqliteDatabase] is provided or
  /// when the auto-configured file-system root contains a `.db`, `.sqlite`, or
  /// `.sqlite3` file.
  final bool showSQLiteBrowserPanel;

  /// Shows a generic URL caller backed by [networkClient].
  final bool showNetworkRequestPanel;

  /// Shows request logs captured by [networkClient].
  final bool showNetworkLogsPanel;

  /// Shows application logs captured by [appLogger] or [AppLogger.instance].
  final bool showAppLogsPanel;

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

  /// Optional controller for the built-in [FileSystemPanel]. If omitted, the
  /// wrapper creates one from [fileSystemRootDirectoryProvider].
  final FileSystemDebugController? fileSystemController;

  /// Root directory provider used by the automatic file-system and SQLite
  /// discovery flow. Defaults to `getApplicationDocumentsDirectory`.
  final Future<Directory> Function()? fileSystemRootDirectoryProvider;

  /// Optional database for the built-in [SQLiteBrowserPanel]. If omitted, the
  /// wrapper opens the first database-looking file found under the file-system
  /// root and lets the panel switch between discovered database files.
  final Database? sqliteDatabase;

  /// Optional client shared by [NetworkRequestPanel] and [NetworkLogsPanel].
  final DebugHttpClient? networkClient;

  /// Optional application logger shown by [AppLogsPanel].
  final AppLogger? appLogger;

  /// Optional text shown at the top of the debug drawer.
  final String? drawerHeaderText;

  @override
  State<DebuggingToolsWrapper> createState() => _DebuggingToolsWrapperState();
}

class _DebuggingToolsWrapperState extends State<DebuggingToolsWrapper> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  FileSystemDebugController? _autoFileSystemController;
  Database? _autoSqliteDatabase;
  String? _autoSqliteDatabasePath;

  FileSystemDebugController? get _effectiveFileSystemController =>
      widget.fileSystemController ?? _autoFileSystemController;

  Database? get _effectiveSqliteDatabase =>
      widget.sqliteDatabase ?? _autoSqliteDatabase;

  @override
  void initState() {
    super.initState();
    if (widget.enabled) {
      _configureAutomaticStoragePanels();
    }
  }

  @override
  void didUpdateWidget(covariant DebuggingToolsWrapper oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.enabled) {
      _autoFileSystemController?.dispose();
      _autoFileSystemController = null;
      _closeAutoSqliteDatabase(forgetPath: true);
      return;
    }

    if (oldWidget.enabled != widget.enabled ||
        oldWidget.fileSystemController != widget.fileSystemController ||
        oldWidget.fileSystemRootDirectoryProvider !=
            widget.fileSystemRootDirectoryProvider ||
        oldWidget.sqliteDatabase != widget.sqliteDatabase ||
        oldWidget.showFileSystemPanel != widget.showFileSystemPanel ||
        oldWidget.showSQLiteBrowserPanel != widget.showSQLiteBrowserPanel) {
      _configureAutomaticStoragePanels();
    }
  }

  @override
  void dispose() {
    _autoFileSystemController?.dispose();
    _closeAutoSqliteDatabase();
    super.dispose();
  }

  Future<void> _configureAutomaticStoragePanels() async {
    if (!widget.enabled ||
        (!widget.showFileSystemPanel && !widget.showSQLiteBrowserPanel)) {
      return;
    }

    var controller = widget.fileSystemController;
    if (controller == null) {
      final rootDirectoryProvider =
          widget.fileSystemRootDirectoryProvider ??
          getApplicationDocumentsDirectory;
      final root = await rootDirectoryProvider();
      if (!mounted) return;
      final existing = _autoFileSystemController;
      if (existing == null || existing.rootPath != root.path) {
        existing?.dispose();
        controller = FileSystemDebugController(rootDirectory: root);
        _autoFileSystemController = controller;
      } else {
        controller = existing;
      }
    }

    await controller.initialize();
    if (!mounted) return;
    setState(() {});

    if (widget.showSQLiteBrowserPanel && widget.sqliteDatabase == null) {
      await _openFirstDiscoveredSqliteDatabase(controller);
    }
  }

  Future<void> _openFirstDiscoveredSqliteDatabase(
    FileSystemDebugController controller,
  ) async {
    final databaseFiles = controller.sqliteDatabaseFilePaths;
    if (databaseFiles.isEmpty) {
      await _closeAutoSqliteDatabase(forgetPath: true);
      if (mounted) setState(() {});
      return;
    }

    final selectedPath = controller.absolutePath(databaseFiles.first);
    if (_autoSqliteDatabasePath == selectedPath &&
        _autoSqliteDatabase != null) {
      return;
    }
    await _switchAutoSqliteDatabase(selectedPath);
  }

  Future<void> _switchAutoSqliteDatabase(String databasePath) async {
    await _closeAutoSqliteDatabase(forgetPath: true);
    _autoSqliteDatabase = await openDatabase(
      databasePath,
      singleInstance: false,
    );
    _autoSqliteDatabasePath = databasePath;
    if (mounted) setState(() {});
  }

  Future<void> _openAutoSqliteDatabase() async {
    final discoveredPaths = _discoveredSqliteDatabasePaths();
    final databasePath =
        _autoSqliteDatabasePath ??
        (discoveredPaths.isEmpty ? null : discoveredPaths.first);
    if (databasePath == null) return;
    await _switchAutoSqliteDatabase(databasePath);
  }

  Future<void> _closeSelectedAutoSqliteDatabase() async {
    await _closeAutoSqliteDatabase();
    if (mounted) setState(() {});
  }

  Future<void> _closeAutoSqliteDatabase({bool forgetPath = false}) async {
    final database = _autoSqliteDatabase;
    _autoSqliteDatabase = null;
    if (forgetPath) {
      _autoSqliteDatabasePath = null;
    }
    await database?.close();
  }

  List<String> _discoveredSqliteDatabasePaths() {
    final controller = _effectiveFileSystemController;
    if (controller == null) return const [];
    return controller.sqliteDatabaseFilePaths
        .map(controller.absolutePath)
        .toList(growable: false);
  }

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
      if (widget.showFileSystemPanel && _effectiveFileSystemController != null)
        DebugPanelItem(
          'Files',
          FileSystemPanel(
            controller: _effectiveFileSystemController!,
            compact: true,
          ),
        ),
      if (widget.showSQLiteBrowserPanel &&
          (_effectiveSqliteDatabase != null ||
              _discoveredSqliteDatabasePaths().isNotEmpty))
        DebugPanelItem(
          'SQLite',
          SQLiteBrowserPanel(
            database: _effectiveSqliteDatabase,
            compact: true,
            currentDatabasePath:
                widget.sqliteDatabase?.path ?? _autoSqliteDatabasePath,
            availableDatabasePaths: _discoveredSqliteDatabasePaths(),
            onOpenDatabase: widget.sqliteDatabase == null
                ? _openAutoSqliteDatabase
                : null,
            onCloseDatabase: widget.sqliteDatabase == null
                ? _closeSelectedAutoSqliteDatabase
                : null,
            onSwitchDatabaseFile: widget.sqliteDatabase == null
                ? (databasePath) => _switchAutoSqliteDatabase(databasePath)
                : null,
          ),
        ),
      if (widget.showNetworkRequestPanel && widget.networkClient != null)
        DebugPanelItem(
          'Network Request',
          NetworkRequestPanel(client: widget.networkClient!, compact: true),
        ),
      if (widget.showNetworkLogsPanel && widget.networkClient != null)
        DebugPanelItem(
          'Network Logs',
          NetworkLogsPanel(client: widget.networkClient!, compact: true),
        ),
      if (widget.showAppLogsPanel)
        DebugPanelItem(
          'App Logs',
          AppLogsPanel(
            logger: widget.appLogger ?? AppLogger.instance,
            compact: true,
          ),
        ),
      ...widget.extraPanels,
    ];
  }

  ThemeData _debugToolsTheme(BuildContext context) {
    final hostTheme = Theme.of(context);
    final colorScheme = ColorScheme.fromSeed(
      seedColor: hostTheme.colorScheme.primary,
      brightness: hostTheme.brightness,
    );

    return ThemeData(
      colorScheme: colorScheme,
      useMaterial3: true,
      visualDensity: hostTheme.visualDensity,
      textTheme: hostTheme.textTheme.apply(
        bodyColor: colorScheme.onSurface,
        displayColor: colorScheme.onSurface,
      ),
      iconTheme: IconThemeData(color: colorScheme.onSurface),
      dividerColor: colorScheme.outlineVariant,
      drawerTheme: DrawerThemeData(
        backgroundColor: colorScheme.surface,
        scrimColor: Colors.black54,
      ),
      cardTheme: CardThemeData(
        color: colorScheme.surfaceContainerHigh,
        surfaceTintColor: colorScheme.surfaceTint,
      ),
      listTileTheme: ListTileThemeData(
        iconColor: colorScheme.onSurface,
        textColor: colorScheme.onSurface,
        selectedColor: colorScheme.primary,
        selectedTileColor: colorScheme.primaryContainer.withValues(alpha: 0.35),
      ),
      expansionTileTheme: ExpansionTileThemeData(
        textColor: colorScheme.onSurface,
        collapsedTextColor: colorScheme.onSurface,
        iconColor: colorScheme.onSurface,
        collapsedIconColor: colorScheme.onSurfaceVariant,
        backgroundColor: colorScheme.surfaceContainerLow,
        collapsedBackgroundColor: colorScheme.surfaceContainerLow,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) {
      return widget.child ?? const SizedBox.shrink();
    }

    return Scaffold(
      key: _scaffoldKey,
      drawer: Theme(
        data: _debugToolsTheme(context),
        child: DebuggingDrawer(
          panels: _buildPanels(),
          headerText: widget.drawerHeaderText ?? '🐛 Debug Tools',
        ),
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
