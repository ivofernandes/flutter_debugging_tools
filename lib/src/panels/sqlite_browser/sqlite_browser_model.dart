part of '../sqlite_browser_panel.dart';

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
