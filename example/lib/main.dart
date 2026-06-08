import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_debugging_tools/flutter_debugging_tools.dart';
import 'package:http/http.dart' as http;
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
  final List<String> visitedRoutes = ['/'];

  Directory? _storageDir;
  final Map<String, String> files = {};
  final Set<String> directories = {};
  String? selectedFilePath;
  String currentDirectoryPath = '';

  String endpoint = 'https://api.ipify.org?format=json';
  String networkOutput = 'No request performed yet.';
  final DebugHttpClient debugHttpClient = DebugHttpClient();
  bool _routeNotificationScheduled = false;
  Database? _database;
  String dbStatus = 'No database checks run yet.';
  List<String> dbTables = [];
  String dbQueryOutput = 'Run a SQLite query to see output.';

  bool get hasStorage => _storageDir != null;
  String get storagePath => _storageDir?.path ?? 'Loading...';

  Future<void> initialize() async {
    final docs = await getApplicationDocumentsDirectory();
    _storageDir = Directory('${docs.path}/debug_tool_files');
    if (!await _storageDir!.exists()) {
      await _storageDir!.create(recursive: true);
    }
    await refreshFiles();
    await initializeDummyDatabase();
  }

  Future<void> initializeDummyDatabase() async {
    final docs = await getApplicationDocumentsDirectory();
    final dbPath = p.join(docs.path, 'debug_tool_demo.sqlite');
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
    await refreshTables();
    await runQuery('SELECT * FROM debug_events ORDER BY id DESC LIMIT 5;');
    notifyListeners();
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

  Future<void> refreshTables() async {
    final db = _database;
    if (db == null) return;
    final rows = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%' ORDER BY name;",
    );
    dbTables = rows.map((row) => '${row['name']}').toList();
    notifyListeners();
  }

  Future<void> runQuery(String query) async {
    final db = _database;
    final trimmed = query.trim();
    if (db == null || trimmed.isEmpty) return;

    try {
      if (trimmed.toUpperCase().startsWith('SELECT')) {
        final rows = await db.rawQuery(trimmed);
        dbQueryOutput = const JsonEncoder.withIndent('  ').convert(rows);
      } else {
        final changed = await db.rawUpdate(trimmed);
        dbQueryOutput = 'Statement executed. Changed rows: $changed';
      }
      await refreshTables();
      await runDatabaseHealthCheck();
    } catch (error) {
      dbQueryOutput = 'Query failed: $error';
      notifyListeners();
    }
  }

  Future<void> runDefaultInsert() {
    return runQuery(
      "INSERT INTO debug_events(label, created_at) VALUES('Quick test insert', '${DateTime.now().toIso8601String()}');",
    );
  }

  Future<void> runDefaultSelect() {
    return runQuery('SELECT * FROM debug_events ORDER BY id DESC LIMIT 10;');
  }

  void trackRoute(String routeName) {
    visitedRoutes.add(routeName);
    if (_routeNotificationScheduled) {
      return;
    }

    _routeNotificationScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _routeNotificationScheduled = false;
      notifyListeners();
    });
  }

  void setMode(AppMode value) {
    mode = value;
    notifyListeners();
  }

  Future<void> refreshFiles() async {
    if (_storageDir == null) {
      return;
    }

    files.clear();
    directories
      ..clear()
      ..add('');
    final entities = await _storageDir!.list(recursive: true).toList();

    for (final entity in entities) {
      if (entity is File) {
        final relativePath = _relativePath(entity.path);
        files[relativePath] = await entity.readAsString();
      } else if (entity is Directory) {
        directories.add(_relativePath(entity.path));
      }
    }

    if (!directories.contains(currentDirectoryPath)) {
      currentDirectoryPath = '';
    }

    selectedFilePath = files.isEmpty ? null : (selectedFilePath ?? files.keys.first);
    if (selectedFilePath != null && !files.containsKey(selectedFilePath)) {
      selectedFilePath = files.keys.isEmpty ? null : files.keys.first;
    }
    notifyListeners();
  }

  Future<void> createFile(
    String name,
    String content, {
    String? parentDirectory,
  }) async {
    final safe = name.trim();
    if (safe.isEmpty || _storageDir == null) {
      return;
    }

    final path = _joinPath(parentDirectory ?? currentDirectoryPath, safe);
    await File('${_storageDir!.path}/$path').writeAsString(content);
    selectedFilePath = path;
    await refreshFiles();
  }

  Future<void> createFolder(String name, {String? parentDirectory}) async {
    final safe = name.trim();
    if (safe.isEmpty || _storageDir == null) {
      return;
    }

    final path = _joinPath(parentDirectory ?? currentDirectoryPath, safe);
    await Directory('${_storageDir!.path}/$path').create(recursive: true);
    currentDirectoryPath = path;
    await refreshFiles();
  }

  Future<void> editFile({
    required String originalPath,
    required String updatedName,
    required String content,
  }) async {
    if (_storageDir == null) {
      return;
    }

    final newName = updatedName.trim();
    if (newName.isEmpty) {
      return;
    }

    final parentDir = _parentPath(originalPath);
    final updatedPath = _joinPath(parentDir, newName);
    final oldFile = File('${_storageDir!.path}/$originalPath');
    if (await oldFile.exists() && originalPath != updatedPath) {
      await oldFile.delete();
    }

    await File('${_storageDir!.path}/$updatedPath').writeAsString(content);
    selectedFilePath = updatedPath;
    await refreshFiles();
  }

  Future<void> removeFile(String path) async {
    if (_storageDir == null) {
      return;
    }

    final target = File('${_storageDir!.path}/$path');
    if (await target.exists()) {
      await target.delete();
    }
    await refreshFiles();
  }

  Future<void> renameFolder({
    required String originalPath,
    required String updatedName,
  }) async {
    if (_storageDir == null || originalPath.isEmpty) {
      return;
    }

    final newName = updatedName.trim();
    if (newName.isEmpty) {
      return;
    }

    final parentDir = _parentPath(originalPath);
    final updatedPath = _joinPath(parentDir, newName);
    final oldFolder = Directory('${_storageDir!.path}/$originalPath');
    if (await oldFolder.exists() && originalPath != updatedPath) {
      await oldFolder.rename('${_storageDir!.path}/$updatedPath');
    }

    if (currentDirectoryPath == originalPath ||
        currentDirectoryPath.startsWith('$originalPath${Platform.pathSeparator}')) {
      currentDirectoryPath = updatedPath;
    }
    if (selectedFilePath != null &&
        selectedFilePath!.startsWith('$originalPath${Platform.pathSeparator}')) {
      selectedFilePath = selectedFilePath!.replaceFirst(originalPath, updatedPath);
    }

    await refreshFiles();
  }

  Future<void> removeFolder(String path) async {
    if (_storageDir == null || path.isEmpty) {
      return;
    }

    final target = Directory('${_storageDir!.path}/$path');
    if (await target.exists()) {
      await target.delete(recursive: true);
    }

    if (currentDirectoryPath == path ||
        currentDirectoryPath.startsWith('$path${Platform.pathSeparator}')) {
      currentDirectoryPath = '';
    }
    if (selectedFilePath != null &&
        selectedFilePath!.startsWith('$path${Platform.pathSeparator}')) {
      selectedFilePath = null;
    }

    await refreshFiles();
  }

  void setSelectedFile(String? value) {
    selectedFilePath = value;
    notifyListeners();
  }

  void openDirectory(String path) {
    currentDirectoryPath = path;
    notifyListeners();
  }

  void goToParentDirectory() {
    if (currentDirectoryPath.isEmpty) {
      return;
    }
    currentDirectoryPath = _parentPath(currentDirectoryPath);
    notifyListeners();
  }

  List<String> get childDirectories => childDirectoriesOf(currentDirectoryPath);

  List<MapEntry<String, String>> get childFiles =>
      childFilesOf(currentDirectoryPath);

  List<String> childDirectoriesOf(String parentPath) {
    return directories
        .where((path) => path.isNotEmpty && _parentPath(path) == parentPath)
        .toList()
      ..sort((a, b) => basename(a).compareTo(basename(b)));
  }

  List<MapEntry<String, String>> childFilesOf(String parentPath) {
    final items = files.entries
        .where((entry) => _parentPath(entry.key) == parentPath)
        .toList()
      ..sort((a, b) => basename(a.key).compareTo(basename(b.key)));
    return items;
  }

  void setWorkflow(WorkflowState value) {
    workflow = value;
    notifyListeners();
  }

  Future<void> fetchUrl({String? customUrl}) async {
    final rawUrl = (customUrl ?? endpoint).trim();
    if (rawUrl.isEmpty) {
      return;
    }

    endpoint = rawUrl;
    workflow = WorkflowState.loading;
    networkOutput = 'Calling $rawUrl ...';
    notifyListeners();

    try {
      final uri = Uri.parse(rawUrl);
      final response = await debugHttpClient.get(uri);
      workflow = WorkflowState.success;
      networkOutput = _formatResponse(response);
    } catch (error) {
      workflow = WorkflowState.failure;
      networkOutput = 'Request failed: $error';
    }

    notifyListeners();
  }

  Future<void> fetchPublicIp() {
    return fetchUrl(customUrl: 'https://api.ipify.org?format=json');
  }

  String _relativePath(String absolutePath) {
    final base = _storageDir!.path;
    final normalizedBase = '$base${Platform.pathSeparator}';
    if (absolutePath.startsWith(normalizedBase)) {
      return absolutePath.substring(normalizedBase.length);
    }
    return absolutePath;
  }

  String _joinPath(String left, String right) {
    if (left.isEmpty) {
      return right;
    }
    return '$left${Platform.pathSeparator}$right';
  }

  String _parentPath(String path) {
    if (path.isEmpty) {
      return '';
    }
    final idx = path.lastIndexOf(Platform.pathSeparator);
    if (idx == -1) {
      return '';
    }
    return path.substring(0, idx);
  }

  String basename(String path) => path.split(Platform.pathSeparator).last;

  String _formatResponse(http.Response response) {
    final body = response.body.length > 400
        ? '${response.body.substring(0, 400)}...'
        : response.body;

    try {
      final decoded = jsonDecode(body);
      final pretty = const JsonEncoder.withIndent('  ').convert(decoded);
      return 'HTTP ${response.statusCode}\n$pretty';
    } catch (_) {
      return 'HTTP ${response.statusCode}\n$body';
    }
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

        return MaterialApp(
          navigatorKey: _navigatorKey,
          title: 'debugging_tools example',
          theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(seedColor: themeSeed),
            useMaterial3: true,
          ),
          routes: {
            '/': (_) => HomeScreen(controller: _controller),
            '/files': (_) => FilesScreen(controller: _controller),
            '/network': (_) => NetworkScreen(controller: _controller),
            '/state': (_) => StateMachineScreen(controller: _controller),
            '/database': (_) => DatabaseScreen(controller: _controller),
          },
          navigatorObservers: [
            _RouteTracker(onVisited: _controller.trackRoute),
          ],
          builder: (context, child) => DebuggingToolsWrapper(
            showSharedPreferencesPanel: true,
            showNavigationPanel: true,
            showLocalStoragePanel: true,
            navigatorKey: _navigatorKey,
            routes: {
              '/': (_) => HomeScreen(controller: _controller),
              '/files': (_) => FilesScreen(controller: _controller),
              '/network': (_) => NetworkScreen(controller: _controller),
              '/state': (_) => StateMachineScreen(controller: _controller),
              '/database': (_) => DatabaseScreen(controller: _controller),
            },
            localStorageBuilder: (_) => FileDebugPanel(controller: _controller),
            extraPanels: [
              CustomConfigPanel.item(
                title: 'State Machine',
                expanded: true,
                child: StateMachineDebugPanel(controller: _controller),
              ),
              CustomConfigPanel.item(
                title: 'Network',
                child: NetworkDebugPanel(controller: _controller),
              ),
              CustomConfigPanel.item(
                title: 'SQLite Health',
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

class _RouteTracker extends NavigatorObserver {
  _RouteTracker({required this.onVisited});

  final ValueChanged<String> onVisited;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    final name = route.settings.name;
    if (name != null) {
      onVisited(name);
    }
    super.didPush(route, previousRoute);
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
        child: FileEditorView(controller: controller),
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
        child: NetworkEditorView(controller: controller),
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

class FileDebugPanel extends StatelessWidget {
  const FileDebugPanel({super.key, required this.controller});

  final ExampleController controller;

  @override
  Widget build(BuildContext context) {
    return FileEditorView(controller: controller, compact: true);
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

class NetworkDebugPanel extends StatelessWidget {
  const NetworkDebugPanel({super.key, required this.controller});

  final ExampleController controller;

  @override
  Widget build(BuildContext context) {
    return NetworkLogsPanel(client: controller.debugHttpClient, compact: true);
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

class FileEditorView extends StatefulWidget {
  const FileEditorView({
    super.key,
    required this.controller,
    this.compact = false,
  });

  final ExampleController controller;
  final bool compact;

  @override
  State<FileEditorView> createState() => _FileEditorViewState();
}

class _FileEditorViewState extends State<FileEditorView> {
  final Set<String> _expandedFolders = {''};

  ExampleController get controller => widget.controller;

  @override
  void didUpdateWidget(covariant FileEditorView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      _expandedFolders
        ..clear()
        ..add('');
    }
  }

  @override
  Widget build(BuildContext context) {
    final selected = controller.selectedFilePath;
    final selectedBaseName = selected == null
        ? null
        : controller.basename(selected);
    final selectedContent = selected == null ? null : controller.files[selected];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: widget.compact ? MainAxisSize.min : MainAxisSize.max,
      children: [
        Text('Storage path: ${controller.storagePath}'),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: Text(
                '${controller.files.length} file(s), ${controller.directories.length - 1} folder(s)',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
            IconButton(
              onPressed: controller.refreshFiles,
              tooltip: 'Refresh file tree',
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          'Tap folders to expand. Tap files to preview. Long-press anywhere in the tree for actions.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 8),
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onLongPress: () => _showFolderActions(context, ''),
          child: Container(
            width: double.infinity,
            constraints: BoxConstraints(
              minHeight: widget.compact ? 160 : 260,
              maxHeight: widget.compact ? 220 : 360,
            ),
            decoration: BoxDecoration(
              border: Border.all(color: Theme.of(context).dividerColor),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Scrollbar(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 6),
                children: [
                  _FolderTreeRow(
                    label: 'Files',
                    depth: 0,
                    expanded: true,
                    selected: controller.currentDirectoryPath.isEmpty,
                    onTap: () => controller.openDirectory(''),
                    onToggle: null,
                    onLongPress: () => _showFolderActions(context, ''),
                  ),
                  ..._buildFolderChildren(context, '', depth: 1),
                  if (controller.directories.length == 1 && controller.files.isEmpty)
                    const Padding(
                      padding: EdgeInsets.fromLTRB(44, 10, 12, 10),
                      child: Text('No files or folders yet. Long-press to add one.'),
                    ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text('Selected file: ${selectedBaseName ?? 'none'}'),
        if (selectedContent != null) ...[
          const SizedBox(height: 6),
          Container(
            width: double.infinity,
            constraints: BoxConstraints(maxHeight: widget.compact ? 90 : 180),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(8),
            ),
            child: SingleChildScrollView(
              child: SelectableText(selectedContent),
            ),
          ),
        ],
      ],
    );
  }

  List<Widget> _buildFolderChildren(
    BuildContext context,
    String folderPath, {
    required int depth,
  }) {
    final children = <Widget>[];
    for (final childFolder in controller.childDirectoriesOf(folderPath)) {
      final isExpanded = _expandedFolders.contains(childFolder);
      children.add(
        _FolderTreeRow(
          label: controller.basename(childFolder),
          depth: depth,
          expanded: isExpanded,
          selected: controller.currentDirectoryPath == childFolder,
          onTap: () {
            controller.openDirectory(childFolder);
            setState(() {
              if (isExpanded) {
                _expandedFolders.remove(childFolder);
              } else {
                _expandedFolders.add(childFolder);
              }
            });
          },
          onToggle: () {
            setState(() {
              if (isExpanded) {
                _expandedFolders.remove(childFolder);
              } else {
                _expandedFolders.add(childFolder);
              }
            });
          },
          onLongPress: () => _showFolderActions(context, childFolder),
        ),
      );
      if (isExpanded) {
        children.addAll(
          _buildFolderChildren(context, childFolder, depth: depth + 1),
        );
      }
    }

    for (final entry in controller.childFilesOf(folderPath)) {
      children.add(
        _FileTreeRow(
          label: controller.basename(entry.key),
          preview: entry.value,
          depth: depth,
          selected: entry.key == controller.selectedFilePath,
          onTap: () => controller.setSelectedFile(entry.key),
          onLongPress: () => _showFileActions(context, entry.key),
        ),
      );
    }
    return children;
  }

  Future<void> _showFolderActions(BuildContext context, String folderPath) async {
    controller.openDirectory(folderPath);
    final action = await showModalBottomSheet<_FileTreeAction>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.folder_outlined),
              title: Text(
                folderPath.isEmpty ? 'Files' : controller.basename(folderPath),
              ),
              subtitle: Text(folderPath.isEmpty ? 'Root folder' : folderPath),
            ),
            ListTile(
              leading: const Icon(Icons.note_add_outlined),
              title: const Text('New file here'),
              onTap: () => Navigator.of(context).pop(_FileTreeAction.newFile),
            ),
            ListTile(
              leading: const Icon(Icons.create_new_folder_outlined),
              title: const Text('New folder here'),
              onTap: () => Navigator.of(context).pop(_FileTreeAction.newFolder),
            ),
            if (folderPath.isNotEmpty) ...[
              ListTile(
                leading: const Icon(Icons.drive_file_rename_outline),
                title: const Text('Rename folder'),
                onTap: () => Navigator.of(context).pop(
                  _FileTreeAction.renameFolder,
                ),
              ),
              ListTile(
                leading: const Icon(Icons.delete_outline),
                title: const Text('Delete folder'),
                textColor: Colors.red,
                iconColor: Colors.red,
                onTap: () => Navigator.of(context).pop(
                  _FileTreeAction.deleteFolder,
                ),
              ),
            ],
          ],
        ),
      ),
    );

    if (!context.mounted || action == null) return;
    switch (action) {
      case _FileTreeAction.newFile:
        final draft = await _showFileDialog(context);
        if (draft != null) {
          await controller.createFile(
            draft.name,
            draft.content,
            parentDirectory: folderPath,
          );
          _expandedFolders.add(folderPath);
        }
        break;
      case _FileTreeAction.newFolder:
        final folderName = await _showNameDialog(
          context,
          title: 'Create folder',
          label: 'Folder name',
        );
        if (folderName != null) {
          await controller.createFolder(
            folderName,
            parentDirectory: folderPath,
          );
          _expandedFolders.add(folderPath);
        }
        break;
      case _FileTreeAction.renameFolder:
        final updatedName = await _showNameDialog(
          context,
          title: 'Rename folder',
          label: 'Folder name',
          initialName: controller.basename(folderPath),
        );
        if (updatedName != null) {
          await controller.renameFolder(
            originalPath: folderPath,
            updatedName: updatedName,
          );
        }
        break;
      case _FileTreeAction.deleteFolder:
        await controller.removeFolder(folderPath);
        break;
      case _FileTreeAction.editFile:
      case _FileTreeAction.deleteFile:
        break;
    }
    if (mounted) setState(() {});
  }

  Future<void> _showFileActions(BuildContext context, String path) async {
    controller.setSelectedFile(path);
    final action = await showModalBottomSheet<_FileTreeAction>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.description_outlined),
              title: Text(controller.basename(path)),
              subtitle: Text(path),
            ),
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text('Edit file'),
              onTap: () => Navigator.of(context).pop(_FileTreeAction.editFile),
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline),
              title: const Text('Delete file'),
              textColor: Colors.red,
              iconColor: Colors.red,
              onTap: () => Navigator.of(context).pop(_FileTreeAction.deleteFile),
            ),
          ],
        ),
      ),
    );

    if (!context.mounted || action == null) return;
    switch (action) {
      case _FileTreeAction.editFile:
        final draft = await _showFileDialog(
          context,
          initialName: controller.basename(path),
          initialContent: controller.files[path] ?? '',
        );
        if (draft != null) {
          await controller.editFile(
            originalPath: path,
            updatedName: draft.name,
            content: draft.content,
          );
        }
        break;
      case _FileTreeAction.deleteFile:
        await controller.removeFile(path);
        break;
      case _FileTreeAction.newFile:
      case _FileTreeAction.newFolder:
      case _FileTreeAction.renameFolder:
      case _FileTreeAction.deleteFolder:
        break;
    }
    if (mounted) setState(() {});
  }

  Future<_FileDraft?> _showFileDialog(
    BuildContext context, {
    String? initialName,
    String? initialContent,
  }) {
    final nameController = TextEditingController(text: initialName ?? '');
    final contentController = TextEditingController(text: initialContent ?? '');

    return showDialog<_FileDraft>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(initialName == null ? 'Create file' : 'Edit file'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: 'Name'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: contentController,
              minLines: 2,
              maxLines: 5,
              decoration: const InputDecoration(labelText: 'Content'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final name = nameController.text.trim();
              if (name.isEmpty) {
                return;
              }
              Navigator.of(context).pop(
                _FileDraft(name: name, content: contentController.text),
              );
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<String?> _showNameDialog(
    BuildContext context, {
    required String title,
    required String label,
    String? initialName,
  }) {
    final nameController = TextEditingController(text: initialName ?? '');

    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: nameController,
          autofocus: true,
          decoration: InputDecoration(labelText: label),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final name = nameController.text.trim();
              if (name.isEmpty) {
                return;
              }
              Navigator.of(context).pop(name);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}

class _FolderTreeRow extends StatelessWidget {
  const _FolderTreeRow({
    required this.label,
    required this.depth,
    required this.expanded,
    required this.selected,
    required this.onTap,
    required this.onLongPress,
    this.onToggle,
  });

  final String label;
  final int depth;
  final bool expanded;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final VoidCallback? onToggle;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Container(
        color: selected
            ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.10)
            : null,
        padding: EdgeInsets.only(
          left: 8.0 + depth * 18,
          right: 8,
          top: 2,
          bottom: 2,
        ),
        child: Row(
          children: [
            SizedBox(
              width: 28,
              height: 28,
              child: onToggle == null
                  ? const Icon(Icons.keyboard_arrow_down, size: 18)
                  : IconButton(
                      onPressed: onToggle,
                      icon: Icon(
                        expanded ? Icons.keyboard_arrow_down : Icons.chevron_right,
                        size: 18,
                      ),
                      padding: EdgeInsets.zero,
                      visualDensity: VisualDensity.compact,
                    ),
            ),
            Icon(
              expanded ? Icons.folder_open_outlined : Icons.folder_outlined,
              size: 20,
              color: Colors.amber.shade700,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FileTreeRow extends StatelessWidget {
  const _FileTreeRow({
    required this.label,
    required this.preview,
    required this.depth,
    required this.selected,
    required this.onTap,
    required this.onLongPress,
  });

  final String label;
  final String preview;
  final int depth;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Container(
        color: selected
            ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.10)
            : null,
        padding: EdgeInsets.only(
          left: 36.0 + depth * 18,
          right: 8,
          top: 4,
          bottom: 4,
        ),
        child: Row(
          children: [
            const Icon(Icons.description_outlined, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (preview.isNotEmpty)
                    Text(
                      preview,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

enum _FileTreeAction {
  newFile,
  newFolder,
  renameFolder,
  deleteFolder,
  editFile,
  deleteFile,
}

class NetworkEditorView extends StatefulWidget {
  const NetworkEditorView({
    super.key,
    required this.controller,
    this.compact = false,
  });

  final ExampleController controller;
  final bool compact;

  @override
  State<NetworkEditorView> createState() => _NetworkEditorViewState();
}

class _NetworkEditorViewState extends State<NetworkEditorView> {
  late final TextEditingController _urlController;

  @override
  void initState() {
    super.initState();
    _urlController = TextEditingController(text: widget.controller.endpoint);
  }

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final outputView = SingleChildScrollView(
      child: SelectableText(controller.networkOutput),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: widget.compact ? MainAxisSize.min : MainAxisSize.max,
      children: [
        TextField(
          controller: _urlController,
          decoration: const InputDecoration(
            labelText: 'URL',
            hintText: 'https://api.ipify.org?format=json',
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: [
            FilledButton(
              onPressed: () => controller.fetchUrl(customUrl: _urlController.text),
              child: const Text('Call URL'),
            ),
            OutlinedButton(
              onPressed: () {
                _urlController.text = 'https://api.ipify.org?format=json';
                controller.fetchPublicIp();
              },
              child: const Text('Get public IP'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text('Workflow state: ${controller.workflow.label}'),
        const SizedBox(height: 8),
        if (widget.compact)
          SizedBox(
            height: 180,
            child: outputView,
          )
        else
          Expanded(
            child: outputView,
          ),
      ],
    );
  }
}

class DatabaseTesterView extends StatefulWidget {
  const DatabaseTesterView({
    super.key,
    required this.controller,
    this.compact = false,
  });

  final ExampleController controller;
  final bool compact;

  @override
  State<DatabaseTesterView> createState() => _DatabaseTesterViewState();
}

class _DatabaseTesterViewState extends State<DatabaseTesterView> {
  late final TextEditingController _queryController;

  @override
  void initState() {
    super.initState();
    _queryController = TextEditingController(
      text: 'SELECT * FROM debug_events ORDER BY id DESC LIMIT 10;',
    );
  }

  @override
  void dispose() {
    _queryController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(controller.dbStatus),
        const SizedBox(height: 8),
        Text('Tables: ${controller.dbTables.isEmpty ? 'none' : controller.dbTables.join(', ')}'),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            FilledButton(
              onPressed: controller.runDatabaseHealthCheck,
              child: const Text('Run connection check'),
            ),
            OutlinedButton(
              onPressed: controller.refreshTables,
              child: const Text('Refresh tables'),
            ),
            OutlinedButton(
              onPressed: controller.runDefaultInsert,
              child: const Text('Quick test insert'),
            ),
            OutlinedButton(
              onPressed: controller.runDefaultSelect,
              child: const Text('Quick test select'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _queryController,
          minLines: 2,
          maxLines: 5,
          decoration: const InputDecoration(
            labelText: 'Custom SQL query',
            hintText: 'SELECT * FROM debug_events LIMIT 5;',
          ),
        ),
        const SizedBox(height: 8),
        FilledButton(
          onPressed: () => controller.runQuery(_queryController.text),
          child: const Text('Run custom query'),
        ),
        const SizedBox(height: 8),
        if (widget.compact)
          SizedBox(
            height: 180,
            child: _DbOutput(output: controller.dbQueryOutput),
          )
        else
          Expanded(
            child: _DbOutput(output: controller.dbQueryOutput),
          ),
      ],
    );
  }
}

class _DbOutput extends StatelessWidget {
  const _DbOutput({required this.output});

  final String output;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      color: Colors.black.withValues(alpha: 0.04),
      child: SingleChildScrollView(
        child: SelectableText(output),
            ),
      );
  }
}

class _FileDraft {
  const _FileDraft({required this.name, required this.content});

  final String name;
  final String content;
}
