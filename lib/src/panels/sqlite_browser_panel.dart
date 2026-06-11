import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';

part 'sqlite_browser/sqlite_browser_actions.dart';
part 'sqlite_browser/sqlite_browser_editor.dart';
part 'sqlite_browser/sqlite_browser_model.dart';
part 'sqlite_browser/sqlite_browser_schema.dart';
part 'sqlite_browser/sqlite_browser_values.dart';
part 'sqlite_browser/sqlite_browser_view.dart';
part 'sqlite_browser/sqlite_browser_widgets.dart';

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
    super.key,
  });

  /// The open SQLite database to inspect.
  final Database? database;

  /// Whether the panel is rendered inside a narrow debug drawer.
  final bool compact;

  /// Maximum number of rows loaded when browsing a table.
  final int rowLimit;

  /// Header text for the tables card.
  final String title;

  /// Optional app-provided action for seeding a row while debugging.
  final Future<void> Function()? onInsertSampleRow;

  @override
  State<SQLiteBrowserPanel> createState() => _SQLiteBrowserPanelState();
}

class _SQLiteBrowserPanelState extends State<SQLiteBrowserPanel> {
  final TextEditingController queryController = TextEditingController();
  final ScrollController tableScrollController = ScrollController();
  final ScrollController columnScrollController = ScrollController();
  final ScrollController horizontalDataController = ScrollController();
  final ScrollController verticalDataController = ScrollController();

  String status = 'Connect a database to inspect and edit SQLite tables.';
  List<String> tables = [];
  String? selectedTable;
  List<SQLiteColumnInfo> columns = [];
  List<Map<String, Object?>> rows = [];
  int rowCount = 0;
  String queryOutput = 'Run a SQLite query to see output.';
  bool loading = false;
  bool showSql = false;

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
      WidgetsBinding.instance.addPostFrameCallback((_) => _refreshBrowser(this));
    }
  }

  @override
  void dispose() {
    queryController.dispose();
    tableScrollController.dispose();
    columnScrollController.dispose();
    horizontalDataController.dispose();
    verticalDataController.dispose();
    super.dispose();
  }

  void updatePanel(VoidCallback fn) => setState(fn);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: widget.compact ? MainAxisSize.min : MainAxisSize.max,
      children: [
        _DatabaseToolbar(
          loading: loading,
          hasDatabase: widget.database != null,
          onRefresh: () => _refreshBrowser(this),
          onInsertSampleRow: widget.onInsertSampleRow == null
              ? null
              : () async {
                  await widget.onInsertSampleRow!();
                  await _refreshBrowser(this);
                },
        ),
        const SizedBox(height: 8),
        Text(status),
        const SizedBox(height: 8),
        if (widget.compact)
          SizedBox(height: 600, child: _buildBrowser(this))
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
