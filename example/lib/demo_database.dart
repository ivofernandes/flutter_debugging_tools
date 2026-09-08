import 'package:sqflite/sqflite.dart';

const demoDatabaseVersion = 2;

/// Enables connection-level SQLite features used by the demo schema.
Future<void> configureDemoDatabase(Database db) async {
  await db.execute('PRAGMA foreign_keys = ON');
}

/// Creates a small, relational project-management database for the browser.
Future<void> ensureDemoDatabaseSchema(Database db) async {
  await db.execute('''
    CREATE TABLE IF NOT EXISTS teams(
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      name TEXT NOT NULL UNIQUE CHECK(length(trim(name)) >= 2),
      created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
    )
  ''');
  await db.execute('''
    CREATE TABLE IF NOT EXISTS users(
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      team_id INTEGER NOT NULL,
      email TEXT NOT NULL UNIQUE CHECK(email LIKE '%_@_%._%'),
      display_name TEXT NOT NULL CHECK(length(trim(display_name)) > 0),
      role TEXT NOT NULL DEFAULT 'member'
        CHECK(role IN ('owner', 'member', 'viewer')),
      is_active INTEGER NOT NULL DEFAULT 1 CHECK(is_active IN (0, 1)),
      FOREIGN KEY(team_id) REFERENCES teams(id) ON DELETE RESTRICT
    )
  ''');
  await db.execute('''
    CREATE TABLE IF NOT EXISTS projects(
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      team_id INTEGER NOT NULL,
      slug TEXT NOT NULL CHECK(length(trim(slug)) > 0),
      name TEXT NOT NULL CHECK(length(trim(name)) > 0),
      status TEXT NOT NULL DEFAULT 'active'
        CHECK(status IN ('planned', 'active', 'archived')),
      budget_cents INTEGER NOT NULL DEFAULT 0 CHECK(budget_cents >= 0),
      UNIQUE(team_id, slug),
      FOREIGN KEY(team_id) REFERENCES teams(id) ON DELETE CASCADE
    )
  ''');
  await db.execute('''
    CREATE TABLE IF NOT EXISTS tasks(
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      project_id INTEGER NOT NULL,
      assignee_id INTEGER,
      title TEXT NOT NULL CHECK(length(trim(title)) >= 3),
      status TEXT NOT NULL DEFAULT 'todo'
        CHECK(status IN ('todo', 'doing', 'blocked', 'done')),
      priority INTEGER NOT NULL DEFAULT 3 CHECK(priority BETWEEN 1 AND 5),
      estimate_hours REAL CHECK(estimate_hours IS NULL OR estimate_hours >= 0),
      due_at TEXT,
      created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
      FOREIGN KEY(project_id) REFERENCES projects(id) ON DELETE CASCADE,
      FOREIGN KEY(assignee_id) REFERENCES users(id) ON DELETE SET NULL
    )
  ''');
  await db.execute('''
    CREATE TABLE IF NOT EXISTS tags(
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      name TEXT NOT NULL UNIQUE CHECK(length(trim(name)) > 0),
      color_hex TEXT NOT NULL DEFAULT '#607D8B'
        CHECK(length(color_hex) = 7 AND substr(color_hex, 1, 1) = '#')
    )
  ''');
  await db.execute('''
    CREATE TABLE IF NOT EXISTS task_tags(
      task_id INTEGER NOT NULL,
      tag_id INTEGER NOT NULL,
      PRIMARY KEY(task_id, tag_id),
      FOREIGN KEY(task_id) REFERENCES tasks(id) ON DELETE CASCADE,
      FOREIGN KEY(tag_id) REFERENCES tags(id) ON DELETE CASCADE
    ) WITHOUT ROWID
  ''');
  await db.execute(
    'CREATE INDEX IF NOT EXISTS idx_tasks_project_status '
    'ON tasks(project_id, status)',
  );
  await db.execute(
    'CREATE INDEX IF NOT EXISTS idx_tasks_assignee ON tasks(assignee_id)',
  );
  await db.execute('''
    CREATE VIEW IF NOT EXISTS project_summary AS
    SELECT p.id, p.name, p.status, t.name AS team_name,
           COUNT(task.id) AS task_count,
           SUM(CASE WHEN task.status = 'done' THEN 1 ELSE 0 END) AS done_count
    FROM projects p
    JOIN teams t ON t.id = p.team_id
    LEFT JOIN tasks task ON task.project_id = p.id
    GROUP BY p.id, p.name, p.status, t.name
  ''');
}

/// Adds deterministic data so every relationship is visible on first launch.
Future<void> seedDemoDatabase(Database db) async {
  await db.transaction((txn) async {
    await txn.insert(
      'teams',
      {'name': 'Developer Experience'},
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
    final teamId = Sqflite.firstIntValue(
      await txn.query(
        'teams',
        columns: ['id'],
        where: 'name = ?',
        whereArgs: ['Developer Experience'],
      ),
    )!;

    for (final user in [
      {'email': 'ada@example.dev', 'display_name': 'Ada', 'role': 'owner'},
      {'email': 'linus@example.dev', 'display_name': 'Linus', 'role': 'member'},
    ]) {
      await txn.insert(
        'users',
        {'team_id': teamId, ...user},
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
    }
    await txn.insert(
      'projects',
      {
        'team_id': teamId,
        'slug': 'sqlite-browser',
        'name': 'SQLite Browser',
        'status': 'active',
        'budget_cents': 125000,
      },
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
    final projectId = Sqflite.firstIntValue(
      await txn.query(
        'projects',
        columns: ['id'],
        where: 'team_id = ? AND slug = ?',
        whereArgs: [teamId, 'sqlite-browser'],
      ),
    )!;
    final adaId = Sqflite.firstIntValue(
      await txn.query(
        'users',
        columns: ['id'],
        where: 'email = ?',
        whereArgs: ['ada@example.dev'],
      ),
    );
    if (Sqflite.firstIntValue(
          await txn.rawQuery(
            'SELECT COUNT(*) FROM tasks WHERE project_id = ?',
            [projectId],
          ),
        ) ==
        0) {
      await txn.insert('tasks', {
        'project_id': projectId,
        'assignee_id': adaId,
        'title': 'Inspect relational schema',
        'status': 'doing',
        'priority': 5,
        'estimate_hours': 3.5,
      });
      await txn.insert('tasks', {
        'project_id': projectId,
        'title': 'Verify cascade deletes',
        'status': 'todo',
        'priority': 3,
        'estimate_hours': 1,
      });
    }
    for (final tag in [
      {'name': 'database', 'color_hex': '#3F51B5'},
      {'name': 'debugging', 'color_hex': '#E91E63'},
    ]) {
      await txn.insert(
        'tags',
        tag,
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
    }
    final firstTaskId = Sqflite.firstIntValue(
      await txn.rawQuery(
        'SELECT id FROM tasks WHERE project_id = ? ORDER BY id LIMIT 1',
        [projectId],
      ),
    );
    final databaseTagId = Sqflite.firstIntValue(
      await txn.query(
        'tags',
        columns: ['id'],
        where: 'name = ?',
        whereArgs: ['database'],
      ),
    );
    if (firstTaskId != null && databaseTagId != null) {
      await txn.insert(
        'task_tags',
        {'task_id': firstTaskId, 'tag_id': databaseTagId},
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
    }
  });
}
