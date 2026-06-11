part of '../sqlite_browser_panel.dart';

Future<void> _updateRow(
  _SQLiteBrowserPanelState state,
  String tableName,
  String primaryKeyColumn,
  Object? primaryKeyValue,
  Map<String, Object?> values,
) async {
  final db = state.widget.database;
  if (db == null || state.loading || values.isEmpty) return;

  state.updatePanel(() => state.loading = true);
  try {
    final changed = await db.update(
      tableName,
      values,
      where: '${_quoteIdentifier(primaryKeyColumn)} = ?',
      whereArgs: [primaryKeyValue],
    );
    if (!state.mounted) return;
    _showSnack(state, 'Saved $changed row(s) in $tableName.');
  } catch (error) {
    if (!state.mounted) return;
    _showSnack(state, 'Could not edit row: $error');
  } finally {
    if (state.mounted) state.updatePanel(() => state.loading = false);
  }
  await _browseTable(state, tableName);
}

SQLiteColumnInfo? _primaryKeyColumn(List<SQLiteColumnInfo> columns) {
  for (final column in columns) {
    if (column.primaryKeyPosition > 0) return column;
  }
  return null;
}

bool _requiresExplicitInsertValue(SQLiteColumnInfo column) {
  if (column.notNull && column.defaultValue == null) return true;
  return false;
}

String _columnHelperText(SQLiteColumnInfo column) {
  final details = [
    if (column.type.isNotEmpty) column.type,
    if (column.badges.isNotEmpty) column.badges,
    'Leave blank for NULL/default. Type NULL for explicit NULL.',
  ];
  return details.join(' · ');
}

Object? _parseSqlValue(String text, SQLiteColumnInfo column) {
  final trimmed = text.trim();
  if (trimmed.isEmpty || trimmed.toUpperCase() == 'NULL') return null;

  final type = column.type.toUpperCase();
  if (type.contains('INT')) return int.tryParse(trimmed) ?? trimmed;
  if (type.contains('REAL') ||
      type.contains('FLOA') ||
      type.contains('DOUB')) {
    return double.tryParse(trimmed) ?? trimmed;
  }
  return text;
}

String _editFieldValue(Object? value) {
  if (value == null) return '';
  if (value is List<int>) return base64Encode(value);
  return '$value';
}

void _showSnack(_SQLiteBrowserPanelState state, String message) {
  if (!state.mounted) return;
  ScaffoldMessenger.of(state.context).showSnackBar(
    SnackBar(content: Text(message)),
  );
}

String _quoteIdentifier(String value) {
  return '"${value.replaceAll('"', '""')}"';
}

String _formatCell(Object? value) {
  if (value == null) return 'NULL';
  if (value is List<int>) return '<${value.length} bytes>';
  return '$value';
}
