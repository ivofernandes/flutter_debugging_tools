import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sqflite/sqflite.dart';

part 'sqlite_browser/sqlite_browser_actions.dart';
part 'sqlite_browser/sqlite_browser_editor.dart';
part 'sqlite_browser/sqlite_browser_table_dialog.dart';
part 'sqlite_browser/sqlite_browser_dialog_widgets.dart';
part 'sqlite_browser/sqlite_browser_compact_fields.dart';
part 'sqlite_browser/sqlite_browser_row_dialog.dart';
part 'sqlite_browser/sqlite_browser_model.dart';
part 'sqlite_browser/sqlite_browser_schema.dart';
part 'sqlite_browser/sqlite_browser_values.dart';
part 'sqlite_browser/sqlite_browser_view.dart';
part 'sqlite_browser/sqlite_browser_widgets.dart';

const List<String> _sqliteTypeOptions = [
  'INTEGER',
  'TEXT',
  'REAL',
  'BLOB',
  'NUMERIC',
  'BOOLEAN',
  'DATE',
  'DATETIME',
];

/// A DB Browser for SQLite-style debug panel for apps that use `sqflite`.
///
/// Pass the app's open [Database] instance to inspect tables, columns, and
/// recent rows without requiring developers to write SQL. The panel also
/// exposes safe debug affordances for creating tables, adding rows, and editing
/// existing primary-keyed rows. The optional SQL console remains available for
/// advanced debugging.
class SQLiteBrowserPanel extends StatefulWidget {
  const SQLiteBrowserPanel({
    required this.database,
    this.compact = false,
    this.rowLimit = 50,
    this.title = 'Tables',
    this.onInsertSampleRow,
    this.onOpenDatabase,
    this.onCloseDatabase,
    this.currentDatabasePath,
    this.availableDatabasePaths = const [],
    this.onSwitchDatabaseFile,
    this.enableConsoleLogging = !kReleaseMode,
    super.key,
  });

  /// The open SQLite database to inspect.
  final Database? database;

  /// Whether the panel is rendered inside a narrow debug drawer.
  final bool compact;

  /// Maximum number of rows loaded per paginated data fetch.
  final int rowLimit;

  /// Header text for the tables card.
  final String title;

  /// Optional app-provided action for seeding a row while debugging.
  final Future<void> Function()? onInsertSampleRow;

  /// Path displayed in connection actions and used as the default path when
  /// switching database files. Falls back to [Database.path] when available.
  final String? currentDatabasePath;

  /// Optional app-provided action for opening or reopening the database.
  final Future<void> Function()? onOpenDatabase;

  /// Optional app-provided action for closing the active database connection.
  final Future<void> Function()? onCloseDatabase;

  /// Database file paths the panel can switch between without typing a path.
  final List<String> availableDatabasePaths;

  /// Optional app-provided action for pointing the app at a different database
  /// file, useful for stress-testing connection lifecycle edge cases.
  final Future<void> Function(String databasePath)? onSwitchDatabaseFile;

  /// Whether SQLite browser lifecycle events and errors should be printed to
  /// the debug console. Defaults to enabled outside release builds.
  final bool enableConsoleLogging;

  @override
  State<SQLiteBrowserPanel> createState() => _SQLiteBrowserPanelState();
}

class _SQLiteBrowserPanelState extends State<SQLiteBrowserPanel> {
  final TextEditingController queryController = TextEditingController();
  final ScrollController tableScrollController = ScrollController();
  final ScrollController columnScrollController = ScrollController();
  final ScrollController horizontalDataController = ScrollController();

  String status = 'Connect a database to inspect and edit SQLite tables.';
  List<String> tables = [];
  String? selectedTable;
  List<SQLiteColumnInfo> columns = [];
  List<Map<String, Object?>> rows = [];
  int rowCount = 0;
  int rowOffset = 0;
  String queryOutput = 'Run a SQLite query to see output.';
  bool loading = false;
  bool showSql = false;
  bool showConnectionActions = false;

  @override
  void initState() {
    super.initState();
    queryController.text = 'SELECT * FROM sqlite_master LIMIT 10;';
    WidgetsBinding.instance.addPostFrameCallback((_) => _refreshBrowser(this));
  }

  @override
  void didUpdateWidget(SQLiteBrowserPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.database != widget.database ||
        oldWidget.rowLimit != widget.rowLimit) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _refreshBrowser(this),
      );
    }
  }

  @override
  void dispose() {
    queryController.dispose();
    tableScrollController.dispose();
    columnScrollController.dispose();
    horizontalDataController.dispose();
    super.dispose();
  }

  void updatePanel(VoidCallback fn) => setState(fn);

  bool get hasConnectedDatabase => widget.database != null;

  void logDebug(String message) {
    if (!widget.enableConsoleLogging) return;
    debugPrint('[SQLiteBrowserPanel] $message');
  }

  void _clearDisconnectedBrowserState(_SQLiteBrowserPanelState state) {
    state.updatePanel(() {
      state.status = 'Connect a database to inspect and edit SQLite tables.';
      state.tables = [];
      state.selectedTable = null;
      state.columns = [];
      state.rows = [];
      state.rowCount = 0;
      state.rowOffset = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: widget.compact ? MainAxisSize.min : MainAxisSize.max,
      children: [
        _ConnectionActionsTile(
          status: status,
          loading: loading,
          hasDatabase: hasConnectedDatabase,
          databasePath: widget.currentDatabasePath ?? widget.database?.path,
          expanded: showConnectionActions,
          onExpansionChanged: (value) =>
              updatePanel(() => showConnectionActions = value),
          onRefresh: () => _refreshBrowser(this),
          onInsertSampleRow: widget.onInsertSampleRow == null
              ? null
              : () async {
                  await widget.onInsertSampleRow!();
                  await _refreshBrowser(this);
                },
          onOpenDatabase: widget.onOpenDatabase == null
              ? null
              : () async {
                  logDebug('Open database requested.');
                  await widget.onOpenDatabase!();
                  if (!mounted) return;
                  WidgetsBinding.instance.addPostFrameCallback(
                    (_) => _refreshBrowser(this),
                  );
                },
          onCloseDatabase: widget.onCloseDatabase == null
              ? null
              : () async {
                  logDebug('Close database requested.');
                  await widget.onCloseDatabase!();
                  if (!mounted) return;
                  _clearDisconnectedBrowserState(this);
                },
          availableDatabasePaths: widget.availableDatabasePaths,
          onSwitchDatabaseFile: widget.onSwitchDatabaseFile,
        ),
        const SizedBox(height: 8),
        if (widget.compact)
          _buildBrowser(this)
        else
          Expanded(child: _buildBrowser(this)),
        const SizedBox(height: 8),
        ExpansionTile(
          initiallyExpanded: showSql,
          onExpansionChanged: (value) => updatePanel(() => showSql = value),
          tilePadding: EdgeInsets.zero,
          title: const Text('Advanced SQL console'),
          subtitle: const Text(
            'Optional: use the editor above for common changes without SQL.',
          ),
          children: [
            TextField(
              controller: queryController,
              minLines: 2,
              maxLines: 5,
              decoration: const InputDecoration(
                labelText: 'Custom SQL query',
                hintText: 'SELECT * FROM my_table LIMIT 5;',
              ),
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: FilledButton(
                onPressed: loading
                    ? null
                    : () => _runQuery(this, queryController.text),
                child: const Text('Run custom query'),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: widget.compact ? 140 : 220,
              child: _DbOutput(output: queryOutput),
            ),
          ],
        ),
      ],
    );
  }
}
