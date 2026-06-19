part of '../sqlite_browser_panel.dart';

Future<void> _showCreateTableDialog(_SQLiteBrowserPanelState state) async {
  final db = state.widget.database;
  if (db == null || state.loading) return;

  final request = await showDialog<_CreateTableRequest>(
    context: state.context,
    builder: (context) => const _CreateTableDialog(),
  );

  if (request == null) return;
  await _createTable(state, request.tableName, request.columnDefinitions);
}

Future<void> _createTable(
  _SQLiteBrowserPanelState state,
  String tableName,
  String columnDefinitions,
) async {
  final db = state.widget.database;
  if (db == null || state.loading) return;

  state.updatePanel(() => state.loading = true);
  try {
    await db.execute(
      'CREATE TABLE ${_quoteIdentifier(tableName)} ($columnDefinitions)',
    );
    if (!state.mounted) return;
    state.selectedTable = tableName;
    _showSnack(state, 'Created table $tableName.');
  } catch (error) {
    if (!state.mounted) return;
    _showSnack(state, 'Could not create table: $error');
  } finally {
    if (state.mounted) state.updatePanel(() => state.loading = false);
  }
  await _refreshBrowser(state);
}

Future<void> _showAddRowDialog(_SQLiteBrowserPanelState state) async {
  final tableName = state.selectedTable;
  if (tableName == null || state.columns.isEmpty || state.loading) return;

  final values = await showDialog<Map<String, Object?>>(
    context: state.context,
    builder: (context) => _RowValuesDialog(
      title: 'Add row to $tableName',
      columns: state.columns,
      actionLabel: 'Add row',
      fieldValueFor: (_) => '',
      skipColumn: (column) => false,
      readOnlyColumn: (_) => false,
      helperTextFor: _columnHelperText,
      includeValue: (column, text) =>
          text.trim().isNotEmpty || _requiresExplicitInsertValue(column),
    ),
  );

  if (values != null) await _insertRow(state, tableName, values);
}

Future<void> _insertRow(
  _SQLiteBrowserPanelState state,
  String tableName,
  Map<String, Object?> values,
) async {
  final db = state.widget.database;
  if (db == null || state.loading) return;

  state.updatePanel(() => state.loading = true);
  try {
    final id = values.isEmpty
        ? await db.rawInsert(
            'INSERT INTO ${_quoteIdentifier(tableName)} DEFAULT VALUES',
          )
        : await db.insert(tableName, values);
    if (!state.mounted) return;
    _showSnack(state, 'Inserted row $id into $tableName.');
  } catch (error) {
    if (!state.mounted) return;
    _showSnack(state, 'Could not add row: $error');
  } finally {
    if (state.mounted) state.updatePanel(() => state.loading = false);
  }
  await _browseTable(state, tableName);
}

Future<void> _showEditRowDialog(
  _SQLiteBrowserPanelState state,
  Map<String, Object?> row,
) async {
  final tableName = state.selectedTable;
  if (tableName == null || state.columns.isEmpty || state.loading) return;

  final primaryKeyColumn = _primaryKeyColumn(state.columns);
  if (primaryKeyColumn == null || row[primaryKeyColumn.name] == null) {
    _showSnack(
      state,
      'Rows without a primary key cannot be edited from the grid.',
    );
    return;
  }

  final values = await showDialog<Map<String, Object?>>(
    context: state.context,
    builder: (context) => _RowValuesDialog(
      title: 'Edit row in $tableName',
      columns: state.columns,
      actionLabel: 'Save changes',
      fieldValueFor: (column) => _editFieldValue(row[column.name]),
      skipColumn: (column) => column.name == primaryKeyColumn.name,
      readOnlyColumn: (column) => column.name == primaryKeyColumn.name,
      helperTextFor: (column) => column.name == primaryKeyColumn.name
          ? 'Primary key used to find this row'
          : _columnHelperText(column),
      includeValue: (_, _) => true,
    ),
  );

  if (values != null) {
    await _updateRow(
      state,
      tableName,
      primaryKeyColumn.name,
      row[primaryKeyColumn.name],
      values,
    );
  }
}
