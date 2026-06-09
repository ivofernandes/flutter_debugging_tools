import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';

/// Schema metadata for a SQLite table column.
class SQLiteColumnInfo {
  const SQLiteColumnInfo({
    required this.name,
    required this.type,
    required this.notNull,
    required this.primaryKeyPosition,
    this.defaultValue,
  });

  factory SQLiteColumnInfo.fromPragmaRow(Map<String, Object?> row) {
    return SQLiteColumnInfo(
      name: '${row['name']}',
      type: '${row['type']}',
      notNull: row['notnull'] == 1,
      primaryKeyPosition: (row['pk'] as int?) ?? 0,
      defaultValue: row['dflt_value'],
    );
  }

  final String name;
  final String type;
  final bool notNull;
  final int primaryKeyPosition;
  final Object? defaultValue;

  String get badges {
    final values = <String>[];
    if (primaryKeyPosition > 0) values.add('PK');
    if (notNull) values.add('NOT NULL');
    if (defaultValue != null) values.add('DEFAULT $defaultValue');
    return values.join(' · ');
  }
}

/// A DB Browser for SQLite-style debug panel for apps that use `sqflite`.
///
/// Pass the app's open [Database] instance to inspect tables, columns, and
/// recent rows without requiring developers to write SQL. The optional SQL
/// console remains available for advanced debugging.
class SQLiteBrowserPanel extends StatefulWidget {
  const SQLiteBrowserPanel({
    required this.database,
    this.compact = false,
    this.rowLimit = 50,
    this.title = 'SQLite Browser',
    this.onInsertSampleRow,
    super.key,
  });

  /// The open SQLite database to inspect.
  final Database? database;

  /// Whether the panel is rendered inside a narrow debug drawer.
  final bool compact;

  /// Maximum number of rows loaded when browsing a table.
  final int rowLimit;

  /// Header text for the browser card.
  final String title;

  /// Optional app-provided action for seeding a row while debugging.
  final Future<void> Function()? onInsertSampleRow;

  @override
  State<SQLiteBrowserPanel> createState() => _SQLiteBrowserPanelState();
}

class _SQLiteBrowserPanelState extends State<SQLiteBrowserPanel> {
  final TextEditingController _queryController = TextEditingController();
  final ScrollController _tableScrollController = ScrollController();
  final ScrollController _columnScrollController = ScrollController();
  final ScrollController _horizontalDataController = ScrollController();
  final ScrollController _verticalDataController = ScrollController();

  String _status = 'Connect a database to browse SQLite tables.';
  List<String> _tables = [];
  String? _selectedTable;
  List<SQLiteColumnInfo> _columns = [];
  List<Map<String, Object?>> _rows = [];
  int _rowCount = 0;
  String _queryOutput = 'Run a SQLite query to see output.';
  bool _loading = false;
  bool _showSql = false;

  @override
  void initState() {
    super.initState();
    _queryController.text = 'SELECT * FROM sqlite_master LIMIT 10;';
    WidgetsBinding.instance.addPostFrameCallback((_) => _refreshBrowser());
  }

  @override
  void didUpdateWidget(SQLiteBrowserPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.database != widget.database ||
        oldWidget.rowLimit != widget.rowLimit) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _refreshBrowser());
    }
  }

  @override
  void dispose() {
    _queryController.dispose();
    _tableScrollController.dispose();
    _columnScrollController.dispose();
    _horizontalDataController.dispose();
    _verticalDataController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: widget.compact ? MainAxisSize.min : MainAxisSize.max,
      children: [
        _DatabaseToolbar(
          loading: _loading,
          onRefresh: _refreshBrowser,
          onInsertSampleRow: widget.onInsertSampleRow == null
              ? null
              : () async {
                  await widget.onInsertSampleRow!();
                  await _refreshBrowser();
                },
        ),
        const SizedBox(height: 8),
        Text(_status),
        const SizedBox(height: 8),
        if (widget.compact)
          SizedBox(height: 430, child: _buildBrowser())
        else
          Expanded(child: _buildBrowser()),
        const SizedBox(height: 8),
        ExpansionTile(
          initiallyExpanded: _showSql,
          onExpansionChanged: (value) => setState(() => _showSql = value),
          tilePadding: EdgeInsets.zero,
          title: const Text('Advanced SQL console'),
          subtitle: const Text(
            'Optional: browse tables above without writing SQL.',
          ),
          children: [
            TextField(
              controller: _queryController,
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
                onPressed:
                    _loading ? null : () => _runQuery(_queryController.text),
                child: const Text('Run custom query'),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: widget.compact ? 140 : 220,
              child: _DbOutput(output: _queryOutput),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildBrowser() {
    return Card.outlined(
      margin: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(12),
              ),
            ),
            child: Text(
              widget.title,
              style: Theme.of(context).textTheme.titleSmall,
            ),
          ),
          Expanded(
            child: widget.compact
                ? Column(
                    children: [
                      SizedBox(height: 126, child: _buildTableList()),
                      const Divider(height: 1),
                      if (_selectedTable == null)
                        const Expanded(child: _EmptyDatabaseSelection())
                      else ...[
                        SizedBox(height: 126, child: _buildColumnList()),
                        const Divider(height: 1),
                        Expanded(child: _buildBrowseDataGrid()),
                      ],
                    ],
                  )
                : Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SizedBox(width: 220, child: _buildTableList()),
                      const VerticalDivider(width: 1),
                      if (_selectedTable == null)
                        const Expanded(child: _EmptyDatabaseSelection())
                      else ...[
                        SizedBox(width: 280, child: _buildColumnList()),
                        const VerticalDivider(width: 1),
                        Expanded(child: _buildBrowseDataGrid()),
                      ],
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildTableList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _PaneHeader(icon: Icons.table_chart_outlined, label: 'Tables'),
        Expanded(
          child: _tables.isEmpty
              ? const Center(child: Text('No user tables found.'))
              : Scrollbar(
                  controller: _tableScrollController,
                  child: ListView.builder(
                    controller: _tableScrollController,
                    itemCount: _tables.length,
                    itemBuilder: (context, index) {
                      final table = _tables[index];
                      return ListTile(
                        dense: true,
                        selected: table == _selectedTable,
                        leading: const Icon(Icons.grid_on, size: 18),
                        title: Text(table),
                        trailing: table == _selectedTable
                            ? const Icon(Icons.chevron_right)
                            : null,
                        onTap: () => _browseTable(table),
                      );
                    },
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildColumnList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _PaneHeader(icon: Icons.view_column_outlined, label: 'Columns'),
        Expanded(
          child: _columns.isEmpty
              ? const Center(child: Text('No columns found.'))
              : Scrollbar(
                  controller: _columnScrollController,
                  child: ListView.builder(
                    controller: _columnScrollController,
                    itemCount: _columns.length,
                    itemBuilder: (context, index) {
                      final column = _columns[index];
                      return ListTile(
                        dense: true,
                        leading: Icon(
                          column.primaryKeyPosition > 0
                              ? Icons.key
                              : Icons.notes,
                          size: 18,
                        ),
                        title: Text(column.name),
                        subtitle: Text(
                          [
                            if (column.type.isNotEmpty) column.type,
                            if (column.badges.isNotEmpty) column.badges,
                          ].join(' · '),
                        ),
                      );
                    },
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildBrowseDataGrid() {
    final table = _selectedTable ?? 'table';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _PaneHeader(
          icon: Icons.dataset_outlined,
          label: 'Browse Data · $table ($_rowCount rows)',
        ),
        Expanded(
          child: _columns.isEmpty
              ? const Center(child: Text('Select a table to browse rows.'))
              : _rows.isEmpty
                  ? const Center(child: Text('No rows found for this table.'))
                  : Scrollbar(
                      controller: _horizontalDataController,
                      notificationPredicate: (notification) {
                        return notification.depth == 1;
                      },
                      child: SingleChildScrollView(
                        controller: _horizontalDataController,
                        scrollDirection: Axis.horizontal,
                        child: Scrollbar(
                          controller: _verticalDataController,
                          child: SingleChildScrollView(
                            controller: _verticalDataController,
                            child: DataTable(
                              headingRowHeight: 36,
                              dataRowMinHeight: 36,
                              dataRowMaxHeight: 56,
                              columns: [
                                for (final column in _columns)
                                  DataColumn(label: Text(column.name)),
                              ],
                              rows: [
                                for (final row in _rows)
                                  DataRow(
                                    cells: [
                                      for (final column in _columns)
                                        DataCell(
                                          ConstrainedBox(
                                            constraints: const BoxConstraints(
                                              maxWidth: 220,
                                            ),
                                            child: SelectableText(
                                              _formatCell(row[column.name]),
                                              maxLines: 2,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
        ),
      ],
    );
  }

  Future<void> _refreshBrowser() async {
    final db = widget.database;
    if (!mounted || _loading) return;

    if (db == null) {
      setState(() {
        _status = 'Connect a database to browse SQLite tables.';
        _tables = [];
        _selectedTable = null;
        _columns = [];
        _rows = [];
        _rowCount = 0;
      });
      return;
    }

    setState(() => _loading = true);
    try {
      final rows = await db.rawQuery(
        "SELECT name FROM sqlite_master "
        "WHERE type='table' AND name NOT LIKE 'sqlite_%' "
        'ORDER BY name;',
      );
      final tables = rows.map((row) => '${row['name']}').toList();
      final selectedTable = tables.contains(_selectedTable)
          ? _selectedTable
          : (tables.isEmpty ? null : tables.first);

      if (!mounted) return;
      setState(() {
        _tables = tables;
        _selectedTable = selectedTable;
        _status = 'Connected ✅ (${tables.length} table(s))';
      });

      if (selectedTable == null) {
        setState(() {
          _columns = [];
          _rows = [];
          _rowCount = 0;
        });
      } else {
        await _browseTable(selectedTable, showLoading: false);
      }
    } catch (error) {
      if (!mounted) return;
      setState(() => _status = 'SQLite browser refresh failed: $error');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _browseTable(String tableName, {bool showLoading = true}) async {
    final db = widget.database;
    if (db == null || tableName.trim().isEmpty || !mounted) return;

    if (showLoading) setState(() => _loading = true);
    try {
      final columnRows = await db.rawQuery(
        'PRAGMA table_info(${_quoteIdentifier(tableName)})',
      );
      final columns = columnRows.map(SQLiteColumnInfo.fromPragmaRow).toList();

      final countRows = await db.rawQuery(
        'SELECT COUNT(*) AS count FROM ${_quoteIdentifier(tableName)}',
      );
      final rowCount = (countRows.first['count'] as int?) ?? 0;

      String? primaryKeyColumn;
      for (final column in columns) {
        if (column.primaryKeyPosition > 0) {
          primaryKeyColumn = column.name;
          break;
        }
      }
      final rows = await db.query(
        tableName,
        orderBy: primaryKeyColumn == null
            ? null
            : '${_quoteIdentifier(primaryKeyColumn)} DESC',
        limit: widget.rowLimit,
      );

      if (!mounted) return;
      setState(() {
        _selectedTable = tableName;
        _columns = columns;
        _rows = rows;
        _rowCount = rowCount;
        _queryController.text =
            'SELECT * FROM ${_quoteIdentifier(tableName)} LIMIT ${widget.rowLimit};';
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _status = 'Could not browse $tableName: $error');
    } finally {
      if (showLoading && mounted) setState(() => _loading = false);
    }
  }

  Future<void> _runQuery(String query) async {
    final db = widget.database;
    final trimmed = query.trim();
    if (db == null || trimmed.isEmpty || _loading) return;

    setState(() => _loading = true);
    try {
      final keyword = trimmed.split(RegExp(r'\s+')).first.toUpperCase();
      if (keyword == 'SELECT' || keyword == 'PRAGMA' || keyword == 'WITH') {
        final rows = await db.rawQuery(trimmed);
        _queryOutput = const JsonEncoder.withIndent('  ').convert(rows);
      } else if (keyword == 'INSERT') {
        final id = await db.rawInsert(trimmed);
        _queryOutput = 'Statement executed. Inserted row id: $id';
      } else {
        final changed = await db.rawUpdate(trimmed);
        _queryOutput = 'Statement executed. Changed rows: $changed';
      }
      if (mounted) setState(() => _loading = false);
      await _refreshBrowser();
    } catch (error) {
      if (!mounted) return;
      setState(() => _queryOutput = 'Query failed: $error');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _quoteIdentifier(String value) {
    return '"${value.replaceAll('"', '""')}"';
  }

  String _formatCell(Object? value) {
    if (value == null) return 'NULL';
    if (value is List<int>) return '<${value.length} bytes>';
    return '$value';
  }
}

class _DatabaseToolbar extends StatelessWidget {
  const _DatabaseToolbar({
    required this.loading,
    required this.onRefresh,
    this.onInsertSampleRow,
  });

  final bool loading;
  final VoidCallback onRefresh;
  final Future<void> Function()? onInsertSampleRow;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        FilledButton.icon(
          onPressed: loading ? null : onRefresh,
          icon: const Icon(Icons.refresh),
          label: const Text('Refresh browser'),
        ),
        if (onInsertSampleRow != null)
          OutlinedButton.icon(
            onPressed: loading ? null : onInsertSampleRow,
            icon: const Icon(Icons.add),
            label: const Text('Insert sample row'),
          ),
      ],
    );
  }
}

class _PaneHeader extends StatelessWidget {
  const _PaneHeader({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      child: Row(
        children: [
          Icon(icon, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: Theme.of(context).textTheme.labelLarge,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyDatabaseSelection extends StatelessWidget {
  const _EmptyDatabaseSelection();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Text('Select a table to inspect its columns and browse rows.'),
      ),
    );
  }
}

class _DbOutput extends StatelessWidget {
  const _DbOutput({required this.output});

  final String output;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      color: Colors.black12,
      child: SingleChildScrollView(
        child: SelectableText(output),
      ),
    );
  }
}
