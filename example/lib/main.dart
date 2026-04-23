import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_debugging_tools/flutter_debugging_tools.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

void main() {
  runApp(const ExampleApp());
}

enum AppMode { demo, staging, production }

enum WorkflowState { idle, loading, success, failure }

enum FileOperation { appendDots, trimLength, addToNumber }

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

extension on FileOperation {
  String get label => switch (this) {
    FileOperation.appendDots => 'Append dots',
    FileOperation.trimLength => 'Trim length',
    FileOperation.addToNumber => 'Add to number',
  };
}

class ExampleController extends ChangeNotifier {
  AppMode mode = AppMode.demo;
  WorkflowState workflow = WorkflowState.idle;
  final List<String> visitedRoutes = ['/'];

  Directory? _storageDir;
  final Map<String, String> files = {};
  String? selectedFileName;
  double operationValue = 3;

  String endpoint = 'https://api.ipify.org?format=json';
  String networkOutput = 'No request performed yet.';

  bool get hasStorage => _storageDir != null;
  String get storagePath => _storageDir?.path ?? 'Loading...';

  Future<void> initialize() async {
    final docs = await getApplicationDocumentsDirectory();
    _storageDir = Directory('${docs.path}/debug_tool_files');
    if (!await _storageDir!.exists()) {
      await _storageDir!.create(recursive: true);
    }
    await refreshFiles();
  }

  void trackRoute(String routeName) {
    visitedRoutes.add(routeName);
    notifyListeners();
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
    final entities = await _storageDir!
        .list()
        .where((entity) => entity is File)
        .cast<File>()
        .toList();

    for (final file in entities) {
      files[_nameFromPath(file.path)] = await file.readAsString();
    }

    selectedFileName = files.isEmpty ? null : (selectedFileName ?? files.keys.first);
    if (selectedFileName != null && !files.containsKey(selectedFileName)) {
      selectedFileName = files.keys.isEmpty ? null : files.keys.first;
    }
    notifyListeners();
  }

  Future<void> createFile(String name, String content) async {
    final safe = name.trim();
    if (safe.isEmpty || _storageDir == null) {
      return;
    }

    await File('${_storageDir!.path}/$safe').writeAsString(content);
    selectedFileName = safe;
    await refreshFiles();
  }

  Future<void> editFile({
    required String originalName,
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

    final oldFile = File('${_storageDir!.path}/$originalName');
    if (await oldFile.exists() && originalName != newName) {
      await oldFile.delete();
    }

    await File('${_storageDir!.path}/$newName').writeAsString(content);
    selectedFileName = newName;
    await refreshFiles();
  }

  Future<void> removeFile(String name) async {
    if (_storageDir == null) {
      return;
    }

    final target = File('${_storageDir!.path}/$name');
    if (await target.exists()) {
      await target.delete();
    }
    await refreshFiles();
  }

  void setSelectedFile(String? value) {
    selectedFileName = value;
    notifyListeners();
  }

  void setOperationValue(double value) {
    operationValue = value;
    notifyListeners();
  }

  Future<void> applyOperation(FileOperation operation) async {
    final name = selectedFileName;
    final dir = _storageDir;
    if (name == null || dir == null) {
      return;
    }

    final file = File('${dir.path}/$name');
    if (!await file.exists()) {
      return;
    }

    final original = await file.readAsString();
    final amount = operationValue.round();
    String updated = original;

    switch (operation) {
      case FileOperation.appendDots:
        updated = '$original${'.' * amount}';
      case FileOperation.trimLength:
        updated = original.substring(0, math.min(original.length, amount));
      case FileOperation.addToNumber:
        final number = int.tryParse(original.trim());
        if (number == null) {
          networkOutput = 'Cannot add to number: "$name" content is not an integer.';
          notifyListeners();
          return;
        }
        updated = (number + amount).toString();
    }

    await file.writeAsString(updated);
    await refreshFiles();
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
      final response = await http.get(uri);
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

  String _nameFromPath(String path) => path.split(Platform.pathSeparator).last;

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
    return NetworkEditorView(controller: controller, compact: true);
  }
}

class FileEditorView extends StatelessWidget {
  const FileEditorView({
    super.key,
    required this.controller,
    this.compact = false,
  });

  final ExampleController controller;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final entries = controller.files.entries.toList()..sort((a, b) => a.key.compareTo(b.key));
    final selected = controller.selectedFileName;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Storage path: ${controller.storagePath}'),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            FilledButton.icon(
              onPressed: () async {
                final draft = await _showFileDialog(context);
                if (draft != null) {
                  await controller.createFile(draft.name, draft.content);
                }
              },
              icon: const Icon(Icons.add),
              label: const Text('Create file'),
            ),
            OutlinedButton(
              onPressed: controller.selectedFileName == null
                  ? null
                  : () async {
                      final name = controller.selectedFileName!;
                      final draft = await _showFileDialog(
                        context,
                        initialName: name,
                        initialContent: controller.files[name] ?? '',
                      );
                      if (draft != null) {
                        await controller.editFile(
                          originalName: name,
                          updatedName: draft.name,
                          content: draft.content,
                        );
                      }
                    },
              child: const Text('Edit selected'),
            ),
            OutlinedButton(
              onPressed: controller.selectedFileName == null
                  ? null
                  : () => controller.removeFile(controller.selectedFileName!),
              child: const Text('Delete selected'),
            ),
            OutlinedButton(
              onPressed: controller.refreshFiles,
              child: const Text('Refresh'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (!compact) const Text('Tap a file to select it:'),
        if (entries.isEmpty)
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: Text('No files yet.'),
          )
        else
          SizedBox(
            height: compact ? 140 : 220,
            child: ListView(
              children: [
                for (final entry in entries)
                  ListTile(
                    dense: true,
                    selected: entry.key == selected,
                    title: Text(entry.key),
                    subtitle: Text(
                      entry.value,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    onTap: () => controller.setSelectedFile(entry.key),
                  ),
              ],
            ),
          ),
        const SizedBox(height: 8),
        const Text('Operation slider:'),
        Slider(
          value: controller.operationValue,
          min: 1,
          max: 12,
          divisions: 11,
          label: controller.operationValue.round().toString(),
          onChanged: controller.setOperationValue,
        ),
        Wrap(
          spacing: 8,
          children: [
            for (final operation in FileOperation.values)
              OutlinedButton(
                onPressed: selected == null
                    ? null
                    : () => controller.applyOperation(operation),
                child: Text(operation.label),
              ),
          ],
        ),
      ],
    );
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
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
        Expanded(
          child: SingleChildScrollView(
            child: SelectableText(controller.networkOutput),
          ),
        ),
      ],
    );
  }
}

class _FileDraft {
  const _FileDraft({required this.name, required this.content});

  final String name;
  final String content;
}
