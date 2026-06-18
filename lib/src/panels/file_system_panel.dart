import 'dart:io';

import 'package:flutter/material.dart';

/// Controls a [FileSystemPanel] rooted at a directory supplied by the host app.
///
/// The controller owns the generic file-system operations that are useful in a
/// debug drawer: refresh, create, edit, rename, delete, and selection state.
/// Apps only need to provide a safe sandbox directory, for example the app
/// documents directory from `path_provider`.
class FileSystemDebugController extends ChangeNotifier {
  FileSystemDebugController({required Directory rootDirectory})
    : _rootDirectory = rootDirectory;

  Directory _rootDirectory;

  /// File extensions treated as SQLite database files by auto-configuring
  /// wrappers. Values are compared case-insensitively and may include a dot.
  static const sqliteDatabaseExtensions = <String>{'db', 'sqlite', 'sqlite3'};

  /// Directory browsed by this controller.
  Directory get rootDirectory => _rootDirectory;

  /// All discovered files, keyed by their relative path below [rootDirectory].
  final Map<String, String> files = {};

  /// All discovered directories as relative paths. The empty string is root.
  final Set<String> directories = {''};

  /// Relative file paths that look like SQLite database files.
  List<String> get sqliteDatabaseFilePaths =>
      files.keys.where(isSqliteDatabasePath).toList()
        ..sort((a, b) => basename(a).compareTo(basename(b)));

  /// Currently selected file relative path, if any.
  String? selectedFilePath;

  /// Directory currently highlighted by the file tree.
  String currentDirectoryPath = '';

  /// Whether [initialize] or [refreshFiles] completed at least once.
  bool initialized = false;

  /// Human-readable root path for display in debug UIs.
  String get rootPath => _rootDirectory.path;

  /// Directories immediately inside [currentDirectoryPath].
  List<String> get childDirectories => childDirectoriesOf(currentDirectoryPath);

  /// Files immediately inside [currentDirectoryPath].
  List<MapEntry<String, String>> get childFiles =>
      childFilesOf(currentDirectoryPath);

  /// Ensures the root exists and loads the current file tree.
  Future<void> initialize() async {
    if (!await _rootDirectory.exists()) {
      await _rootDirectory.create(recursive: true);
    }
    await refreshFiles();
  }

  /// Changes the root directory and refreshes the tree.
  Future<void> setRootDirectory(Directory rootDirectory) async {
    _rootDirectory = rootDirectory;
    selectedFilePath = null;
    currentDirectoryPath = '';
    await initialize();
  }

  /// Reloads all files and folders from disk.
  Future<void> refreshFiles() async {
    if (!await _rootDirectory.exists()) {
      await _rootDirectory.create(recursive: true);
    }

    files.clear();
    directories
      ..clear()
      ..add('');

    final entities = await _rootDirectory.list(recursive: true).toList();
    for (final entity in entities) {
      if (entity is File) {
        final relativePath = _relativePath(entity.path);
        try {
          files[relativePath] = await entity.readAsString();
        } catch (_) {
          files[relativePath] = '<binary or unreadable file>';
        }
      } else if (entity is Directory) {
        directories.add(_relativePath(entity.path));
      }
    }

    if (!directories.contains(currentDirectoryPath)) {
      currentDirectoryPath = '';
    }

    selectedFilePath = files.isEmpty
        ? null
        : (selectedFilePath ?? files.keys.first);
    if (selectedFilePath != null && !files.containsKey(selectedFilePath)) {
      selectedFilePath = files.keys.isEmpty ? null : files.keys.first;
    }
    initialized = true;
    notifyListeners();
  }

  Future<void> createFile(
    String name,
    String content, {
    String? parentDirectory,
  }) async {
    final safe = name.trim();
    if (safe.isEmpty) {
      return;
    }

    final path = _joinPath(parentDirectory ?? currentDirectoryPath, safe);
    await File(
      '${_rootDirectory.path}${Platform.pathSeparator}$path',
    ).writeAsString(content);
    selectedFilePath = path;
    await refreshFiles();
  }

  Future<void> createFolder(String name, {String? parentDirectory}) async {
    final safe = name.trim();
    if (safe.isEmpty) {
      return;
    }

    final path = _joinPath(parentDirectory ?? currentDirectoryPath, safe);
    await Directory(
      '${_rootDirectory.path}${Platform.pathSeparator}$path',
    ).create(recursive: true);
    currentDirectoryPath = path;
    await refreshFiles();
  }

  Future<void> editFile({
    required String originalPath,
    required String updatedName,
    required String content,
  }) async {
    final newName = updatedName.trim();
    if (newName.isEmpty) {
      return;
    }

    final parentDir = parentPath(originalPath);
    final updatedPath = _joinPath(parentDir, newName);
    final oldFile = File(
      '${_rootDirectory.path}${Platform.pathSeparator}$originalPath',
    );
    if (await oldFile.exists() && originalPath != updatedPath) {
      await oldFile.delete();
    }

    await File(
      '${_rootDirectory.path}${Platform.pathSeparator}$updatedPath',
    ).writeAsString(content);
    selectedFilePath = updatedPath;
    await refreshFiles();
  }

  Future<void> removeFile(String path) async {
    final target = File('${_rootDirectory.path}${Platform.pathSeparator}$path');
    if (await target.exists()) {
      await target.delete();
    }
    await refreshFiles();
  }

  Future<void> renameFolder({
    required String originalPath,
    required String updatedName,
  }) async {
    if (originalPath.isEmpty) {
      return;
    }

    final newName = updatedName.trim();
    if (newName.isEmpty) {
      return;
    }

    final parentDir = parentPath(originalPath);
    final updatedPath = _joinPath(parentDir, newName);
    final oldFolder = Directory(
      '${_rootDirectory.path}${Platform.pathSeparator}$originalPath',
    );
    if (await oldFolder.exists() && originalPath != updatedPath) {
      await oldFolder.rename(
        '${_rootDirectory.path}${Platform.pathSeparator}$updatedPath',
      );
    }

    if (currentDirectoryPath == originalPath ||
        currentDirectoryPath.startsWith(
          '$originalPath${Platform.pathSeparator}',
        )) {
      currentDirectoryPath = updatedPath;
    }
    if (selectedFilePath != null &&
        selectedFilePath!.startsWith(
          '$originalPath${Platform.pathSeparator}',
        )) {
      selectedFilePath = selectedFilePath!.replaceFirst(
        originalPath,
        updatedPath,
      );
    }

    await refreshFiles();
  }

  Future<void> removeFolder(String path) async {
    if (path.isEmpty) {
      return;
    }

    final target = Directory(
      '${_rootDirectory.path}${Platform.pathSeparator}$path',
    );
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
    currentDirectoryPath = parentPath(currentDirectoryPath);
    notifyListeners();
  }

  List<String> childDirectoriesOf(String parentPathValue) {
    return directories
        .where((path) => path.isNotEmpty && parentPath(path) == parentPathValue)
        .toList()
      ..sort((a, b) => basename(a).compareTo(basename(b)));
  }

  List<MapEntry<String, String>> childFilesOf(String parentPathValue) {
    return files.entries
        .where((entry) => parentPath(entry.key) == parentPathValue)
        .toList()
      ..sort((a, b) => basename(a.key).compareTo(basename(b.key)));
  }

  /// Returns whether [path] has a common SQLite database extension.
  static bool isSqliteDatabasePath(String path) {
    final fileName = path.split(Platform.pathSeparator).last.toLowerCase();
    final extensionIndex = fileName.lastIndexOf('.');
    if (extensionIndex == -1 || extensionIndex == fileName.length - 1) {
      return false;
    }

    final extension = fileName.substring(extensionIndex + 1);
    return sqliteDatabaseExtensions.contains(extension);
  }

  /// Converts a relative file path below [rootDirectory] to an absolute path.
  String absolutePath(String relativePath) =>
      '${_rootDirectory.path}${Platform.pathSeparator}$relativePath';

  String basename(String path) => path.split(Platform.pathSeparator).last;

  String parentPath(String path) {
    if (path.isEmpty) {
      return '';
    }
    final idx = path.lastIndexOf(Platform.pathSeparator);
    if (idx == -1) {
      return '';
    }
    return path.substring(0, idx);
  }

  String _relativePath(String absolutePath) {
    final normalizedBase = '${_rootDirectory.path}${Platform.pathSeparator}';
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
}

/// Generic debug UI for browsing and editing files under an app-owned folder.
class FileSystemPanel extends StatefulWidget {
  const FileSystemPanel({
    required this.controller,
    this.compact = false,
    this.title = 'Files',
    super.key,
  });

  final FileSystemDebugController controller;
  final bool compact;
  final String title;

  @override
  State<FileSystemPanel> createState() => _FileSystemPanelState();
}

class _FileSystemPanelState extends State<FileSystemPanel> {
  final Set<String> _expandedFolders = {''};

  FileSystemDebugController get controller => widget.controller;

  @override
  void initState() {
    super.initState();
    if (!controller.initialized) {
      controller.initialize();
    }
  }

  @override
  void didUpdateWidget(covariant FileSystemPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      _expandedFolders
        ..clear()
        ..add('');
      if (!controller.initialized) {
        controller.initialize();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final selected = controller.selectedFilePath;
        final selectedBaseName = selected == null
            ? null
            : controller.basename(selected);
        final selectedContent = selected == null
            ? null
            : controller.files[selected];

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: widget.compact ? MainAxisSize.min : MainAxisSize.max,
          children: [
            Text('Storage path: ${controller.rootPath}'),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${controller.files.length} file(s), '
                    '${controller.directories.length - 1} folder(s)',
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
              'Tap folders to expand. Tap files to preview. Long-press for actions.',
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
                        label: widget.title,
                        depth: 0,
                        expanded: true,
                        selected: controller.currentDirectoryPath.isEmpty,
                        onTap: () => controller.openDirectory(''),
                        onToggle: null,
                        onLongPress: () => _showFolderActions(context, ''),
                      ),
                      ..._buildFolderChildren(context, '', depth: 1),
                      if (controller.directories.length == 1 &&
                          controller.files.isEmpty)
                        const Padding(
                          padding: EdgeInsets.fromLTRB(44, 10, 12, 10),
                          child: Text(
                            'No files or folders yet. Long-press to add one.',
                          ),
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
                constraints: BoxConstraints(
                  maxHeight: widget.compact ? 90 : 180,
                ),
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
      },
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

  Future<void> _showFolderActions(
    BuildContext context,
    String folderPath,
  ) async {
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
                folderPath.isEmpty
                    ? widget.title
                    : controller.basename(folderPath),
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
                onTap: () =>
                    Navigator.of(context).pop(_FileTreeAction.renameFolder),
              ),
              ListTile(
                leading: const Icon(Icons.delete_outline),
                title: const Text('Delete folder'),
                textColor: Colors.red,
                iconColor: Colors.red,
                onTap: () =>
                    Navigator.of(context).pop(_FileTreeAction.deleteFolder),
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
              onTap: () =>
                  Navigator.of(context).pop(_FileTreeAction.deleteFile),
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
              Navigator.of(
                context,
              ).pop(_FileDraft(name: name, content: contentController.text));
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
                        expanded
                            ? Icons.keyboard_arrow_down
                            : Icons.chevron_right,
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
                  Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
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

class _FileDraft {
  const _FileDraft({required this.name, required this.content});

  final String name;
  final String content;
}
