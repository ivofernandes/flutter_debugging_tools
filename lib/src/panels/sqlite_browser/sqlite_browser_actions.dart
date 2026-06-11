part of '../sqlite_browser_panel.dart';

Future<void> _refreshBrowser(_SQLiteBrowserPanelState state) async {
  final db = state.widget.database;
  if (!state.mounted || state.loading) return;

  if (db == null) {
    state.updatePanel(() {
      state.status = 'Connect a database to inspect and edit SQLite tables.';
      state.tables = [];
      state.selectedTable = null;
      state.columns = [];
      state.rows = [];
      state.rowCount = 0;
    });
    return;
  }

  state.updatePanel(() => state.loading = true);
  try {
    final rows = await db.rawQuery(
      "SELECT name FROM sqlite_master "
      "WHERE type='table' AND name NOT LIKE 'sqlite_%' "
      'ORDER BY name;',
    );
    final tables = rows.map((row) => '${row['name']}').toList();
    final selectedTable = tables.contains(state.selectedTable)
        ? state.selectedTable
        : (tables.isEmpty ? null : tables.first);

    if (!state.mounted) return;
    state.updatePanel(() {
      state.tables = tables;
      state.selectedTable = selectedTable;
      state.status = 'Connected ✅ (${tables.length} table(s))';
    });

    if (selectedTable == null) {
      state.updatePanel(() {
        state.columns = [];
        state.rows = [];
        state.rowCount = 0;
      });
    } else {
      await _browseTable(state, selectedTable, showLoading: false);
    }
  } catch (error) {
    if (!state.mounted) return;
    state.updatePanel(() => state.status = 'SQLite browser refresh failed: $error');
  } finally {
    if (state.mounted) state.updatePanel(() => state.loading = false);
  }
}

Future<void> _browseTable(
  _SQLiteBrowserPanelState state,
  String tableName, {
  bool showLoading = true,
}) async {
  final db = state.widget.database;
  if (db == null || tableName.trim().isEmpty || !state.mounted) return;

  if (showLoading) state.updatePanel(() => state.loading = true);
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
      limit: state.widget.rowLimit,
    );

    if (!state.mounted) return;
    state.updatePanel(() {
      state.selectedTable = tableName;
      state.columns = columns;
      state.rows = rows;
      state.rowCount = rowCount;
      state.queryController.text =
          'SELECT * FROM ${_quoteIdentifier(tableName)} '
          'LIMIT ${state.widget.rowLimit};';
    });
  } catch (error) {
    if (!state.mounted) return;
    state.updatePanel(() => state.status = 'Could not browse $tableName: $error');
  } finally {
    if (showLoading && state.mounted) {
      state.updatePanel(() => state.loading = false);
    }
  }
}

Future<void> _runQuery(_SQLiteBrowserPanelState state, String query) async {
  final db = state.widget.database;
  final trimmed = query.trim();
  if (db == null || trimmed.isEmpty || state.loading) return;

  state.updatePanel(() => state.loading = true);
  try {
    final keyword = trimmed.split(RegExp(r'\s+')).first.toUpperCase();
    if (keyword == 'SELECT' || keyword == 'PRAGMA' || keyword == 'WITH') {
      final rows = await db.rawQuery(trimmed);
      state.queryOutput = const JsonEncoder.withIndent('  ').convert(rows);
    } else if (keyword == 'INSERT') {
      final id = await db.rawInsert(trimmed);
      state.queryOutput = 'Statement executed. Inserted row id: $id';
    } else {
      final changed = await db.rawUpdate(trimmed);
      state.queryOutput = 'Statement executed. Changed rows: $changed';
    }
    if (state.mounted) state.updatePanel(() => state.loading = false);
    await _refreshBrowser(state);
  } catch (error) {
    if (!state.mounted) return;
    state.updatePanel(() => state.queryOutput = 'Query failed: $error');
  } finally {
    if (state.mounted) state.updatePanel(() => state.loading = false);
  }
}
