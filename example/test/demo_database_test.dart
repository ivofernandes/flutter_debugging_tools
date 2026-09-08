import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:example/demo_database.dart';

void main() {
  late Database database;

  setUpAll(sqfliteFfiInit);

  setUp(() async {
    database = await databaseFactoryFfi.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(
        version: demoDatabaseVersion,
        onConfigure: configureDemoDatabase,
        onCreate: (db, version) => ensureDemoDatabaseSchema(db),
        onOpen: seedDemoDatabase,
      ),
    );
  });

  tearDown(() => database.close());

  test('creates and seeds a representative relational schema', () async {
    final objects = await database.rawQuery('''
      SELECT name, type FROM sqlite_master
      WHERE name IN ('teams', 'users', 'projects', 'tasks', 'tags',
                     'task_tags', 'project_summary')
    ''');

    expect(objects, hasLength(7));
    expect(await database.query('project_summary'), [
      containsPair('task_count', 2),
    ]);
    expect(await database.rawQuery('PRAGMA foreign_key_check'), isEmpty);
  });

  test('enforces check, unique, and foreign-key constraints', () async {
    expect(
      () => database.insert('tasks', {
        'project_id': 999999,
        'title': 'Missing project',
        'priority': 3,
      }),
      throwsA(isA<DatabaseException>()),
    );
    expect(
      () => database.insert('tasks', {
        'project_id': 1,
        'title': 'Bad priority',
        'priority': 10,
      }),
      throwsA(isA<DatabaseException>()),
    );
    expect(
      () => database.insert('tags', {
        'name': 'database',
        'color_hex': '#000000',
      }),
      throwsA(isA<DatabaseException>()),
    );
  });

  test('cascades project deletion to tasks and junction records', () async {
    final projectId = Sqflite.firstIntValue(
      await database.query('projects', columns: ['id'], limit: 1),
    )!;

    await database.delete('projects', where: 'id = ?', whereArgs: [projectId]);

    expect(await database.query('tasks'), isEmpty);
    expect(await database.query('task_tags'), isEmpty);
  });
}
