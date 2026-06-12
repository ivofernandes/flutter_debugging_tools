part of '../sqlite_browser_panel.dart';

class _CreateTableRequest {
  const _CreateTableRequest({
    required this.tableName,
    required this.columnDefinitions,
  });

  final String tableName;
  final String columnDefinitions;
}

class _CreateTableDialog extends StatefulWidget {
  const _CreateTableDialog();

  @override
  State<_CreateTableDialog> createState() => _CreateTableDialogState();
}

class _CreateTableDialogState extends State<_CreateTableDialog> {
  final TextEditingController _tableNameController =
      TextEditingController(text: 'debug_notes');
  final List<_CreateColumnInput> _columns = [];

  @override
  void initState() {
    super.initState();
    _columns.addAll([
      _CreateColumnInput(
        name: 'id',
        type: 'INTEGER',
        primaryKey: true,
        autoIncrement: true,
      ),
      _CreateColumnInput(name: 'label', type: 'TEXT', notNull: true),
      _CreateColumnInput(name: 'value', type: 'TEXT'),
      _CreateColumnInput(
        name: 'created_at',
        type: 'TEXT',
        defaultValue: 'CURRENT_TIMESTAMP',
      ),
    ]);
  }

  @override
  void dispose() {
    _tableNameController.dispose();
    for (final column in _columns) {
      column.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final preview = _columnDefinitions;
    final previewTableName = _tableNameController.text.trim().isEmpty
        ? 'table_name'
        : _quoteIdentifier(_tableNameController.text.trim());

    return Dialog(
      insetPadding: const EdgeInsets.all(12),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 920,
          maxHeight: MediaQuery.sizeOf(context).height * 0.86,
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
                  const Icon(Icons.table_chart_outlined, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Edit table definition',
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
                    _DialogSection(
                      title: 'Table',
                      child: TextField(
                        controller: _tableNameController,
                        autofocus: true,
                        onChanged: (_) => setState(() {}),
                        decoration: const InputDecoration(
                          labelText: 'Table name',
                          hintText: 'debug_notes',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    _DialogSection(
                      title: 'Fields',
                      trailing: Wrap(
                        spacing: 8,
                        children: [
                          OutlinedButton.icon(
                            onPressed: _addColumn,
                            icon: const Icon(Icons.add),
                            label: const Text('Add'),
                          ),
                          OutlinedButton.icon(
                            onPressed: _columns.length > 1
                                ? () => _removeColumn(_columns.length - 1)
                                : null,
                            icon: const Icon(Icons.remove),
                            label: const Text('Remove'),
                          ),
                        ],
                      ),
                      child: _FieldsGrid(
                        columns: _columns,
                        onChanged: () => setState(() {}),
                        onDelete: _removeColumn,
                        onPrimaryKeySelected: _selectPrimaryKey,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text('SQL preview', style: theme.textTheme.labelLarge),
                    const SizedBox(height: 6),
                    Container(
                      constraints: const BoxConstraints(minHeight: 128),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: theme.dividerColor),
                      ),
                      child: SelectableText(
                        'CREATE TABLE $previewTableName (\n$preview\n);',
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
                    onPressed: _canSubmit ? _submit : null,
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

  bool get _canSubmit =>
      _tableNameController.text.trim().isNotEmpty &&
      _columns.any((column) => column.name.trim().isNotEmpty);

  String get _columnDefinitions => _columns
      .where((column) => column.name.trim().isNotEmpty)
      .map((column) => column.definition)
      .join(',\n');

  void _addColumn() {
    setState(
      () => _columns.add(
        _CreateColumnInput(name: 'column_${_columns.length + 1}'),
      ),
    );
  }

  void _removeColumn(int index) {
    setState(() => _columns.removeAt(index).dispose());
  }

  void _selectPrimaryKey(int index) {
    setState(() {
      for (var i = 0; i < _columns.length; i++) {
        if (i == index) continue;
        _columns[i].primaryKey = false;
        _columns[i].autoIncrement = false;
      }
      _columns[index].primaryKey = true;
    });
  }

  void _submit() {
    final tableName = _tableNameController.text.trim();
    final columnDefinitions = _columnDefinitions;
    if (tableName.isEmpty || columnDefinitions.isEmpty) return;
    Navigator.of(context).pop(
      _CreateTableRequest(
        tableName: tableName,
        columnDefinitions: columnDefinitions,
      ),
    );
  }
}

class _CreateColumnInput {
  _CreateColumnInput({
    String name = '',
    String type = 'TEXT',
    bool primaryKey = false,
    bool autoIncrement = false,
    bool notNull = false,
    bool unique = false,
    String defaultValue = '',
    String check = '',
  })  : nameController = TextEditingController(text: name),
        defaultController = TextEditingController(text: defaultValue),
        checkController = TextEditingController(text: check),
        type = type,
        primaryKey = primaryKey,
        autoIncrement = autoIncrement,
        notNull = notNull,
        unique = unique;

  final TextEditingController nameController;
  final TextEditingController defaultController;
  final TextEditingController checkController;
  String type;
  bool primaryKey;
  bool autoIncrement;
  bool notNull;
  bool unique;

  String get name => nameController.text;

  String get definition {
    final parts = <String>[
      _quoteIdentifier(name.trim()),
      type,
      if (primaryKey) 'PRIMARY KEY',
      if (autoIncrement && type == 'INTEGER' && primaryKey) 'AUTOINCREMENT',
      if (notNull && !primaryKey) 'NOT NULL',
      if (unique && !primaryKey) 'UNIQUE',
      if (defaultController.text.trim().isNotEmpty)
        'DEFAULT ${defaultController.text.trim()}',
      if (checkController.text.trim().isNotEmpty)
        'CHECK (${checkController.text.trim()})',
    ];
    return parts.join(' ');
  }

  void dispose() {
    nameController.dispose();
    defaultController.dispose();
    checkController.dispose();
  }
}
