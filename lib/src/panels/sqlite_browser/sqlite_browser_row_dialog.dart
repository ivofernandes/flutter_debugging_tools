part of '../sqlite_browser_panel.dart';

class _RowValuesDialog extends StatefulWidget {
  const _RowValuesDialog({
    required this.title,
    required this.columns,
    required this.actionLabel,
    required this.fieldValueFor,
    required this.skipColumn,
    required this.readOnlyColumn,
    required this.helperTextFor,
    required this.includeValue,
  });

  final String title;
  final List<SQLiteColumnInfo> columns;
  final String actionLabel;
  final String Function(SQLiteColumnInfo column) fieldValueFor;
  final bool Function(SQLiteColumnInfo column) skipColumn;
  final bool Function(SQLiteColumnInfo column) readOnlyColumn;
  final String Function(SQLiteColumnInfo column) helperTextFor;
  final bool Function(SQLiteColumnInfo column, String text) includeValue;

  @override
  State<_RowValuesDialog> createState() => _RowValuesDialogState();
}

class _RowValuesDialogState extends State<_RowValuesDialog> {
  late final Map<String, TextEditingController> _controllers;

  @override
  void initState() {
    super.initState();
    _controllers = {
      for (final column in widget.columns)
        column.name: TextEditingController(text: widget.fieldValueFor(column)),
    };
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final column in widget.columns) ...[
                TextField(
                  controller: _controllers[column.name],
                  readOnly: widget.readOnlyColumn(column),
                  decoration: InputDecoration(
                    labelText: column.name,
                    helperText: widget.helperTextFor(column),
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
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _submit,
          child: Text(widget.actionLabel),
        ),
      ],
    );
  }

  void _submit() {
    final values = <String, Object?>{};
    for (final column in widget.columns) {
      if (widget.skipColumn(column)) continue;
      final text = _controllers[column.name]!.text;
      if (!widget.includeValue(column, text)) continue;
      values[column.name] = _parseSqlValue(text, column);
    }
    Navigator.of(context).pop(values);
  }
}
