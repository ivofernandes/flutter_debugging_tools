part of '../sqlite_browser_panel.dart';

Future<void> _showCreateTableDialog(_SQLiteBrowserPanelState state) async {
  final db = state.widget.database;
  if (db == null || state.loading) return;

  final nameController = TextEditingController(text: 'debug_notes');
  final columnsController = TextEditingController(
    text: 'id INTEGER PRIMARY KEY AUTOINCREMENT,\n'
        'label TEXT NOT NULL,\n'
        'value TEXT,\n'
        'created_at TEXT DEFAULT CURRENT_TIMESTAMP',
  );

  final confirmed = await showDialog<bool>(
    context: state.context,
    builder: (context) => AlertDialog(
      title: const Text('Create SQLite table'),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'Table name',
                  hintText: 'debug_notes',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: columnsController,
                minLines: 5,
                maxLines: 9,
                decoration: const InputDecoration(
                  labelText: 'Column definitions',
                  helperText: 'Everything between CREATE TABLE name (...)',
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Create table'),
        ),
      ],
    ),
  );

  final tableName = nameController.text.trim();
  final columnDefinitions = columnsController.text.trim();
  nameController.dispose();
  columnsController.dispose();

  if (confirmed != true || tableName.isEmpty || columnDefinitions.isEmpty) {
    return;
  }

  await _createTable(state, tableName, columnDefinitions);
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

  final controllers = {
    for (final column in state.columns) column.name: TextEditingController(),
  };

  final confirmed = await showDialog<bool>(
    context: state.context,
    builder: (context) => AlertDialog(
      title: Text('Add row to $tableName'),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final column in state.columns) ...[
                TextField(
                  controller: controllers[column.name],
                  decoration: InputDecoration(
                    labelText: column.name,
                    helperText: _columnHelperText(column),
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Add row'),
        ),
      ],
    ),
  );

  final values = <String, Object?>{};
  for (final column in state.columns) {
    final text = controllers[column.name]!.text;
    if (text.trim().isEmpty && !_requiresExplicitInsertValue(column)) {
      continue;
    }
    values[column.name] = _parseSqlValue(text, column);
  }
  for (final controller in controllers.values) {
    controller.dispose();
  }

  if (confirmed == true) await _insertRow(state, tableName, values);
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
    _showSnack(state, 'Rows without a primary key cannot be edited from the grid.');
    return;
  }

  final controllers = {
    for (final column in state.columns)
      column.name: TextEditingController(
        text: _editFieldValue(row[column.name]),
      ),
  };

  final confirmed = await showDialog<bool>(
    context: state.context,
    builder: (context) => AlertDialog(
      title: Text('Edit row in $tableName'),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final column in state.columns) ...[
                TextField(
                  controller: controllers[column.name],
                  readOnly: column.name == primaryKeyColumn.name,
                  decoration: InputDecoration(
                    labelText: column.name,
                    helperText: column.name == primaryKeyColumn.name
                        ? 'Primary key used to find this row'
                        : _columnHelperText(column),
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Save changes'),
        ),
      ],
    ),
  );

  final values = <String, Object?>{};
  for (final column in state.columns) {
    if (column.name == primaryKeyColumn.name) continue;
    values[column.name] = _parseSqlValue(controllers[column.name]!.text, column);
  }
  for (final controller in controllers.values) {
    controller.dispose();
  }

  if (confirmed == true) {
    await _updateRow(
      state,
      tableName,
      primaryKeyColumn.name,
      row[primaryKeyColumn.name],
      values,
    );
  }
}
