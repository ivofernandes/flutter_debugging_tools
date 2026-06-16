import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_debugging_tools/flutter_debugging_tools.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  if (!kIsWeb &&
      (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }
  runApp(const ExampleApp());
}

enum AppMode { demo, staging, production }

enum WorkflowState { idle, loading, success, failure }

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

class ExampleController extends ChangeNotifier {
  AppMode mode = AppMode.demo;
  WorkflowState workflow = WorkflowState.idle;

  FileSystemDebugController? fileSystemController;

  final DebugHttpClient debugHttpClient = DebugHttpClient();
  Database? _database;
  bool _useAlternateDatabase = false;
  String dbStatus = 'No database checks run yet.';

  bool get hasStorage => fileSystemController != null;
  String get storagePath => fileSystemController?.rootPath ?? 'Loading...';
  Database? get database => _database;

  Future<void> initialize() async {
    final docs = await getApplicationDocumentsDirectory();
    fileSystemController = FileSystemDebugController(
      rootDirectory: Directory('${docs.path}/debug_tool_files'),
    );
    await fileSystemController!.initialize();
    await initializeDummyDatabase();
  }

  Future<void> initializeDummyDatabase() async {
    final docs = await getApplicationDocumentsDirectory();
    final dbPath = p.join(
      docs.path,
      _useAlternateDatabase
          ? 'debug_tool_demo_alternate.sqlite'
          : 'debug_tool_demo.sqlite',
    );
    _database = await openDatabase(
      dbPath,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE debug_events(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            label TEXT NOT NULL,
            created_at TEXT NOT NULL
          )
        ''');
      },
    );
    dbStatus = 'Database ready at: $dbPath';
    await runDatabaseHealthCheck();
  }

  Future<void> openDummyDatabase() async {
    if (_database != null) return;
    await initializeDummyDatabase();
  }

  Future<void> closeDummyDatabase() async {
    final db = _database;
    if (db == null) return;
    await db.close();
    _database = null;
    dbStatus = 'Database connection manually closed for debugging.';
    notifyListeners();
  }

  Future<void> switchDummyDatabaseFile() async {
    final db = _database;
    if (db != null) await db.close();
    _database = null;
    _useAlternateDatabase = !_useAlternateDatabase;
    await initializeDummyDatabase();
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
    final rows = await db.query(
      'debug_events',
      orderBy: 'id DESC',
      limit: 5,
    );
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

  @override
  void dispose() {
    debugHttpClient.close();
    fileSystemController?.dispose();
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
  final NavigationHistoryObserver _historyObserver = NavigationHistoryObserver();

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
          theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(seedColor: themeSeed),
            useMaterial3: true,
          ),
          routes: routes,
          navigatorObservers: [_historyObserver],
          builder: (context, child) => DebuggingToolsWrapper(
            showSharedPreferencesPanel: true,
            showNavigationPanel: true,
            showLocalStoragePanel: false,
            navigatorKey: _navigatorKey,
            historyObserver: _historyObserver,
            routes: routes,
            fileSystemController: _controller.fileSystemController,
            networkClient: _controller.debugHttpClient,
            showNetworkRequestPanel: true,
            showNetworkLogsPanel: true,
            extraPanels: [
              CustomConfigPanel.item(
                title: 'State Machine',
                expanded: true,
                child: StateMachineDebugPanel(controller: _controller),
              ),
              CustomConfigPanel.item(
                title: 'SQLite',
                child: DatabaseDebugPanel(controller: _controller),
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
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: controller.fileSystemController == null
            ? const Center(child: CircularProgressIndicator())
            : FileSystemPanel(controller: controller.fileSystemController!),
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

class DatabaseDebugPanel extends StatelessWidget {
  const DatabaseDebugPanel({super.key, required this.controller});

  final ExampleController controller;

  @override
  Widget build(BuildContext context) {
    return DatabaseTesterView(controller: controller, compact: true);
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
      onInsertSampleRow: controller.insertDummyRow,
      onOpenDatabase: controller.openDummyDatabase,
      onCloseDatabase: controller.closeDummyDatabase,
      onSwitchDatabaseFile: controller.switchDummyDatabaseFile,
    );
  }
}
