part of '../sqlite_browser_panel.dart';

Future<void> _showAddColumnDialog(_SQLiteBrowserPanelState state) async {
  final tableName = state.selectedTable;
  final db = state.widget.database;
  if (db == null || tableName == null || state.loading) return;

  final request = await showDialog<_AddColumnRequest>(
    context: state.context,
    builder: (context) => _AddColumnDialog(tableName: tableName),
  );

  if (request == null) return;
  await _addColumn(
    state,
    tableName,
    request.columnName,
    request.columnType,
    request.constraints,
  );
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

class _AddColumnRequest {
  const _AddColumnRequest({
    required this.columnName,
    required this.columnType,
    required this.constraints,
  });

  final String columnName;
  final String columnType;
  final String constraints;
}

class _AddColumnDialog extends StatefulWidget {
  const _AddColumnDialog({required this.tableName});

  final String tableName;

  @override
  State<_AddColumnDialog> createState() => _AddColumnDialogState();
}

class _AddColumnDialogState extends State<_AddColumnDialog> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _defaultController = TextEditingController();
  final TextEditingController _checkController = TextEditingController();
  String _type = 'TEXT';
  bool _notNull = false;
  bool _unique = false;

  @override
  void dispose() {
    _nameController.dispose();
    _defaultController.dispose();
    _checkController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final columnName = _nameController.text.trim().isEmpty
        ? 'new_column'
        : _quoteIdentifier(_nameController.text.trim());
    final preview = [
      'ALTER TABLE ${_quoteIdentifier(widget.tableName)} ADD COLUMN',
      columnName,
      _type,
      if (_notNull) 'NOT NULL',
      if (_unique) 'UNIQUE',
      if (_defaultController.text.trim().isNotEmpty)
        'DEFAULT ${_defaultController.text.trim()}',
      if (_checkController.text.trim().isNotEmpty)
        'CHECK (${_checkController.text.trim()})',
    ].join(' ');

    return Dialog(
      insetPadding: const EdgeInsets.all(12),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 640,
          maxHeight: MediaQuery.sizeOf(context).height * 0.82,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              color: theme.colorScheme.surfaceContainerHighest,
              child: Row(
                children: [
                  const Icon(Icons.view_column_outlined, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Add column to ${widget.tableName}',
                      style: theme.textTheme.titleMedium,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Close',
                    visualDensity: VisualDensity.compact,
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextField(
                      controller: _nameController,
                      autofocus: true,
                      onChanged: (_) => setState(() {}),
                      decoration: const InputDecoration(
                        labelText: 'Column name',
                        hintText: 'notes',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: _type,
                      decoration: const InputDecoration(
                        labelText: 'Type',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      items: _sqliteTypeOptions
                          .map(
                            (type) => DropdownMenuItem(
                              value: type,
                              child: Text(type.toLowerCase()),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        if (value == null) return;
                        setState(() => _type = value);
                      },
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        FilterChip(
                          label: const Text('NOT NULL'),
                          selected: _notNull,
                          onSelected: (value) =>
                              setState(() => _notNull = value),
                        ),
                        FilterChip(
                          label: const Text('UNIQUE'),
                          selected: _unique,
                          onSelected: (value) =>
                              setState(() => _unique = value),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _defaultController,
                      onChanged: (_) => setState(() {}),
                      decoration: const InputDecoration(
                        labelText: 'Default value',
                        hintText: "'text', 0, CURRENT_TIMESTAMP",
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _checkController,
                      onChanged: (_) => setState(() {}),
                      decoration: const InputDecoration(
                        labelText: 'Check constraint',
                        hintText: 'value > 0',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text('SQL preview', style: theme.textTheme.labelLarge),
                    const SizedBox(height: 6),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: theme.dividerColor),
                      ),
                      child: SelectableText(
                        '$preview;',
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontFamily: 'monospace',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: _nameController.text.trim().isEmpty
                        ? null
                        : _submit,
                    child: const Text('OK'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _submit() {
    final constraints = [
      if (_notNull) 'NOT NULL',
      if (_unique) 'UNIQUE',
      if (_defaultController.text.trim().isNotEmpty)
        'DEFAULT ${_defaultController.text.trim()}',
      if (_checkController.text.trim().isNotEmpty)
        'CHECK (${_checkController.text.trim()})',
    ].join(' ');
    Navigator.of(context).pop(
      _AddColumnRequest(
        columnName: _nameController.text.trim(),
        columnType: _type,
        constraints: constraints,
      ),
    );
  }
}
