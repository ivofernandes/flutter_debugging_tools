part of '../sqlite_browser_panel.dart';

Future<void> _showAddColumnDialog(_SQLiteBrowserPanelState state) async {
  final tableName = state.selectedTable;
  final db = state.widget.database;
  if (db == null || tableName == null || state.loading) return;

  final nameController = TextEditingController();
  final typeController = TextEditingController(text: 'TEXT');
  final constraintsController = TextEditingController();

  final confirmed = await showDialog<bool>(
    context: state.context,
    builder: (context) => AlertDialog(
      title: Text('Add column to $tableName'),
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
                  labelText: 'Column name',
                  hintText: 'notes',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: typeController,
                decoration: const InputDecoration(
                  labelText: 'Type',
                  hintText: 'TEXT, INTEGER, REAL, BLOB',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: constraintsController,
                decoration: const InputDecoration(
                  labelText: 'Optional constraints',
                  hintText: 'DEFAULT 0, NOT NULL DEFAULT ""',
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
          child: const Text('Add column'),
        ),
      ],
    ),
  );

  final columnName = nameController.text.trim();
  final columnType = typeController.text.trim();
  final constraints = constraintsController.text.trim();
  nameController.dispose();
  typeController.dispose();
  constraintsController.dispose();

  if (confirmed != true || columnName.isEmpty) return;
  await _addColumn(state, tableName, columnName, columnType, constraints);
}

Future<void> _addColumn(
  _SQLiteBrowserPanelState state,
  String tableName,
  String columnName,
  String columnType,
  String constraints,
) async {
  final db = state.widget.database;
  if (db == null || state.loading) return;

  final definition = [
    _quoteIdentifier(columnName),
    if (columnType.isNotEmpty) columnType,
    if (constraints.isNotEmpty) constraints,
  ].join(' ');

  state.updatePanel(() => state.loading = true);
  try {
    await db.execute(
      'ALTER TABLE ${_quoteIdentifier(tableName)} ADD COLUMN $definition',
    );
    if (!state.mounted) return;
    _showSnack(state, 'Added column $columnName to $tableName.');
  } catch (error) {
    if (!state.mounted) return;
    _showSnack(state, 'Could not add column: $error');
  } finally {
    if (state.mounted) state.updatePanel(() => state.loading = false);
  }
  await _browseTable(state, tableName);
}
