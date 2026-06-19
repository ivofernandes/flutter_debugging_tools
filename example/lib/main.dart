import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_debugging_tools/flutter_debugging_tools.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  if (!kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }
  runApp(const ExampleApp());
}

enum AppMode { demo, staging, production }

enum WorkflowState { idle, loading, success, failure }

enum AppThemeMode { light, dark, system }

extension on AppMode {
  String get label => switch (this) {
    AppMode.demo => 'Demo',
    AppMode.staging => 'Staging',
    AppMode.production => 'Production',
  };
}

extension on WorkflowState {
  String get label => switch (this) {
    WorkflowState.idle => 'Idle',
    WorkflowState.loading => 'Loading',
    WorkflowState.success => 'Success',
    WorkflowState.failure => 'Failure',
  };
}

extension on AppThemeMode {
  String get label => switch (this) {
    AppThemeMode.light => 'Light',
    AppThemeMode.dark => 'Dark',
    AppThemeMode.system => 'System',
  };

  ThemeMode get themeMode => switch (this) {
    AppThemeMode.light => ThemeMode.light,
    AppThemeMode.dark => ThemeMode.dark,
    AppThemeMode.system => ThemeMode.system,
  };
}

class ExampleController extends ChangeNotifier {
  AppMode mode = AppMode.demo;
  WorkflowState workflow = WorkflowState.idle;
  AppThemeMode themeMode = AppThemeMode.dark;

  final DebugHttpClient debugHttpClient = DebugHttpClient();
  Database? _database;
  bool _databaseConnected = false;
  String? _databasePath;
  String dbStatus = 'No database checks run yet.';

  Database? get database => _databaseConnected ? _database : null;
  String? get databasePath => _databasePath;

  Future<void> initialize() async {
    final docs = await getApplicationDocumentsDirectory();
    await _writeDemoDocumentFile(docs);
    await initializeDummyDatabase();
  }

  Future<void> _writeDemoDocumentFile(Directory docs) async {
    final file = File(p.join(docs.path, 'debug_tool_notes.txt'));
    if (!await file.exists()) {
      await file.writeAsString(
        'This file was created by the example app so the debug drawer can '
        'discover documents storage without a file-system controller.',
      );
    }
  }

  Future<void> initializeDummyDatabase({String? path}) async {
    final docs = await getApplicationDocumentsDirectory();
    final dbPath =
        path ?? _databasePath ?? p.join(docs.path, 'debug_tool_demo.sqlite');
    _databasePath = dbPath;
    _database = await openDatabase(
      dbPath,
      version: 1,
      onCreate: (db, version) async => _ensureDebugSchema(db),
      onOpen: _ensureDebugSchema,
    );
    _databaseConnected = true;
    dbStatus = 'Database ready at: $dbPath';
    await runDatabaseHealthCheck();
  }

  Future<void> _ensureDebugSchema(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS debug_events(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        label TEXT NOT NULL,
        created_at TEXT NOT NULL
      )
    ''');
  }

  Future<void> openDummyDatabase() async {
    if (_databaseConnected) return;
    await _closeDetachedDatabase(_detachDatabaseHandle());
    await initializeDummyDatabase(path: _databasePath);
  }

  Future<void> closeDummyDatabase() async {
    final db = _detachDatabaseHandle();
    _databaseConnected = false;
    dbStatus = 'Database connection manually closed for debugging.';
    notifyListeners();
    await _closeDetachedDatabase(db);
  }

  Future<void> switchDummyDatabaseFile(String path) async {
    final db = _detachDatabaseHandle();
    _databaseConnected = false;
    notifyListeners();
    await _closeDetachedDatabase(db);
    await initializeDummyDatabase(path: path);
  }

  Database? _detachDatabaseHandle() {
    final db = _database;
    _database = null;
    return db;
  }

  Future<void> _closeDetachedDatabase(Database? db) async {
    if (db == null) return;
    try {
      await db.close();
    } catch (_) {
      // The lifecycle controls intentionally exercise edge cases. Ignore close
      // failures so the debug UI can still reset and reopen the connection.
    }
  }

  Future<void> insertDummyRow() async {
    final db = _database;
    if (db == null) return;
    await db.insert('debug_events', {
      'label': 'Dummy ping',
      'created_at': DateTime.now().toIso8601String(),
    });
    await runDatabaseHealthCheck();
  }

  Future<void> runDatabaseHealthCheck() async {
    final db = _database;
    if (db == null) return;
    final rows = await db.query('debug_events', orderBy: 'id DESC', limit: 5);
    dbStatus = rows.isEmpty
        ? 'Connected ✅ (table exists, no rows yet).'
        : 'Connected ✅ (${rows.length} recent rows). Latest: ${rows.first['label']} @ ${rows.first['created_at']}';
    notifyListeners();
  }

  void setMode(AppMode value) {
    mode = value;
    notifyListeners();
  }

  void setWorkflow(WorkflowState value) {
    workflow = value;
    notifyListeners();
  }

  void setThemeMode(AppThemeMode value) {
    themeMode = value;
    notifyListeners();
  }

  @override
  void dispose() {
    debugHttpClient.close();
    _database?.close();
    super.dispose();
  }
}

class ExampleApp extends StatefulWidget {
  const ExampleApp({super.key});

  @override
  State<ExampleApp> createState() => _ExampleAppState();
}

class _ExampleAppState extends State<ExampleApp> {
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();
  final ExampleController _controller = ExampleController();
  final NavigationHistoryObserver _historyObserver =
      NavigationHistoryObserver();

  @override
  void initState() {
    super.initState();
    _controller.initialize();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final themeSeed = switch (_controller.mode) {
          AppMode.demo => Colors.indigo,
          AppMode.staging => Colors.orange,
          AppMode.production => Colors.green,
        };

        final routes = {
          '/': (_) => HomeScreen(controller: _controller),
          '/files': (_) => FilesScreen(controller: _controller),
          '/network': (_) => NetworkScreen(controller: _controller),
          '/state': (_) => StateMachineScreen(controller: _controller),
          '/database': (_) => DatabaseScreen(controller: _controller),
        };

        return MaterialApp(
          navigatorKey: _navigatorKey,
          title: 'debugging_tools example',
          themeMode: _controller.themeMode.themeMode,
          theme: _buildTheme(themeSeed, Brightness.light),
          darkTheme: _buildTheme(themeSeed, Brightness.dark),
          routes: routes,
          navigatorObservers: [_historyObserver],
          builder: (context, child) => DebuggingToolsWrapper(
            showSharedPreferencesPanel: true,
            showNavigationPanel: true,
            showLocalStoragePanel: false,
            navigatorKey: _navigatorKey,
            historyObserver: _historyObserver,
            routes: routes,
            networkClient: _controller.debugHttpClient,
            showNetworkRequestPanel: true,
            showNetworkLogsPanel: true,
            extraPanels: [
              CustomConfigPanel.item(
                title: 'State Machine',
                expanded: true,
                child: StateMachineDebugPanel(controller: _controller),
              ),
            ],
            drawerHeaderText: '🐛 Debug tools playground',
            child: child,
          ),
        );
      },
    );
  }
}

ThemeData _buildTheme(Color seed, Brightness brightness) {
  return ThemeData(
    colorScheme: ColorScheme.fromSeed(seedColor: seed, brightness: brightness),
    useMaterial3: true,
  );
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key, required this.controller});

  final ExampleController controller;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Debugging Tools Playground')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Current mode: ${controller.mode.label}'),
          Text('Workflow: ${controller.workflow.label}'),
          Text('Theme: ${controller.themeMode.label}'),
          const SizedBox(height: 12),
          SegmentedButton<AppThemeMode>(
            segments: const [
              ButtonSegment(
                value: AppThemeMode.dark,
                icon: Icon(Icons.dark_mode_outlined),
                label: Text('Dark'),
              ),
              ButtonSegment(
                value: AppThemeMode.light,
                icon: Icon(Icons.light_mode_outlined),
                label: Text('Light'),
              ),
              ButtonSegment(
                value: AppThemeMode.system,
                icon: Icon(Icons.brightness_auto_outlined),
                label: Text('System'),
              ),
            ],
            selected: {controller.themeMode},
            onSelectionChanged: (selection) =>
                controller.setThemeMode(selection.first),
          ),
          const SizedBox(height: 12),
          const Text(
            'Use these screens to generate real app state. Open the debug drawer to inspect and mutate the same data.',
          ),
          const SizedBox(height: 16),
          FilledButton.tonal(
            onPressed: () => Navigator.of(context).pushNamed('/files'),
            child: const Text('Open file screen'),
          ),
          const SizedBox(height: 8),
          FilledButton.tonal(
            onPressed: () => Navigator.of(context).pushNamed('/state'),
            child: const Text('Open state machine screen'),
          ),
          const SizedBox(height: 8),
          FilledButton.tonal(
            onPressed: () => Navigator.of(context).pushNamed('/network'),
            child: const Text('Open network screen'),
          ),
          const SizedBox(height: 8),
          FilledButton.tonal(
            onPressed: () => Navigator.of(context).pushNamed('/database'),
            child: const Text('Open SQLite screen'),
          ),
        ],
      ),
    );
  }
}

class FilesScreen extends StatelessWidget {
  const FilesScreen({super.key, required this.controller});

  final ExampleController controller;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Files on device storage')),
      body: const Padding(
        padding: EdgeInsets.all(16),
        child: Text(
          'Open the debug drawer to browse the application documents directory. '
          'The DebuggingToolsWrapper discovers it automatically, so this example '
          'does not pass a FileSystemDebugController.',
        ),
      ),
    );
  }
}

class StateMachineScreen extends StatelessWidget {
  const StateMachineScreen({super.key, required this.controller});

  final ExampleController controller;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('State machine provider demo')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Current state: ${controller.workflow.label}'),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: [
                for (final state in WorkflowState.values)
                  OutlinedButton(
                    onPressed: () => controller.setWorkflow(state),
                    child: Text(state.label),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class NetworkScreen extends StatelessWidget {
  const NetworkScreen({super.key, required this.controller});

  final ExampleController controller;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Network call tester')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: NetworkRequestPanel(client: controller.debugHttpClient),
      ),
    );
  }
}

class DatabaseScreen extends StatelessWidget {
  const DatabaseScreen({super.key, required this.controller});

  final ExampleController controller;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('SQLite connection tester')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: DatabaseTesterView(controller: controller),
      ),
    );
  }
}

class StateMachineDebugPanel extends StatelessWidget {
  const StateMachineDebugPanel({super.key, required this.controller});

  final ExampleController controller;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Current: ${controller.workflow.label}'),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: [
            for (final state in WorkflowState.values)
              OutlinedButton(
                onPressed: () => controller.setWorkflow(state),
                child: Text(state.label),
              ),
          ],
        ),
      ],
    );
  }
}

class DatabaseTesterView extends StatelessWidget {
  const DatabaseTesterView({
    super.key,
    required this.controller,
    this.compact = false,
  });

  final ExampleController controller;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return SQLiteBrowserPanel(
      database: controller.database,
      compact: compact,
      currentDatabasePath: controller.databasePath,
      onInsertSampleRow: controller.insertDummyRow,
      onOpenDatabase: controller.openDummyDatabase,
      onCloseDatabase: controller.closeDummyDatabase,
      onSwitchDatabaseFile: controller.switchDummyDatabaseFile,
    );
  }
}
