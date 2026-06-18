part of '../sqlite_browser_panel.dart';

class _ConnectionActionsTile extends StatelessWidget {
  const _ConnectionActionsTile({
    required this.status,
    required this.loading,
    required this.hasDatabase,
    required this.expanded,
    required this.onExpansionChanged,
    required this.onRefresh,
    this.databasePath,
    this.onInsertSampleRow,
    this.onOpenDatabase,
    this.onCloseDatabase,
    this.availableDatabasePaths = const [],
    this.onSwitchDatabaseFile,
  });

  final String status;
  final bool loading;
  final bool hasDatabase;
  final bool expanded;
  final ValueChanged<bool> onExpansionChanged;
  final VoidCallback onRefresh;
  final String? databasePath;
  final Future<void> Function()? onInsertSampleRow;
  final Future<void> Function()? onOpenDatabase;
  final Future<void> Function()? onCloseDatabase;
  final List<String> availableDatabasePaths;
  final Future<void> Function(String databasePath)? onSwitchDatabaseFile;

  @override
  Widget build(BuildContext context) {
    final hasLifecycleActions =
        onOpenDatabase != null ||
        onCloseDatabase != null ||
        onSwitchDatabaseFile != null ||
        onInsertSampleRow != null;

    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Card(
      margin: EdgeInsets.zero,
      color: colors.surfaceContainerHigh,
      child: ExpansionTile(
        initiallyExpanded: expanded,
        onExpansionChanged: onExpansionChanged,
        tilePadding: const EdgeInsets.symmetric(horizontal: 12),
        childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        leading: Icon(
          hasDatabase ? Icons.check_circle_outline : Icons.link_off,
          color: hasDatabase ? Colors.green : null,
        ),
        title: SelectableText(
          status,
          style: textTheme.titleSmall?.copyWith(color: colors.onSurface),
        ),
        subtitle: hasLifecycleActions
            ? Text(
                'Tap to show SQLite connection actions.',
                style: textTheme.bodySmall?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              )
            : null,
        children: [
          if (databasePath != null && databasePath!.trim().isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: SelectableText(
                  'File: $databasePath',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ),
          Align(
            alignment: Alignment.centerLeft,
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                FilledButton.icon(
                  onPressed: loading || !hasDatabase ? null : onRefresh,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Refresh SQLite'),
                ),
                OutlinedButton.icon(
                  onPressed: () async {
                    await Clipboard.setData(ClipboardData(text: status));
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('SQLite status copied.')),
                    );
                  },
                  icon: const Icon(Icons.copy),
                  label: const Text('Copy status'),
                ),
                if (onInsertSampleRow != null)
                  OutlinedButton.icon(
                    onPressed: loading || !hasDatabase
                        ? null
                        : onInsertSampleRow,
                    icon: const Icon(Icons.science_outlined),
                    label: const Text('Insert sample row'),
                  ),
                if (onOpenDatabase != null)
                  OutlinedButton.icon(
                    onPressed: loading || hasDatabase ? null : onOpenDatabase,
                    icon: const Icon(Icons.power_settings_new),
                    label: const Text('Open database'),
                  ),
                if (onCloseDatabase != null)
                  OutlinedButton.icon(
                    onPressed: loading || !hasDatabase ? null : onCloseDatabase,
                    icon: const Icon(Icons.close),
                    label: const Text('Close database'),
                  ),
                if (onSwitchDatabaseFile != null)
                  OutlinedButton.icon(
                    onPressed: loading
                        ? null
                        : () => _showDatabasePathDialog(context),
                    icon: const Icon(Icons.drive_file_rename_outline),
                    label: const Text('Change DB file'),
                  ),
              ],
            ),
          ),
          if (onSwitchDatabaseFile != null && availableDatabasePaths.isNotEmpty)
            _DetectedDatabasePicker(
              availableDatabasePaths: availableDatabasePaths,
              currentDatabasePath: databasePath,
              loading: loading,
              onSwitchDatabaseFile: onSwitchDatabaseFile!,
            ),
        ],
      ),
    );
  }

  Future<void> _showDatabasePathDialog(BuildContext context) async {
    var pathValue = databasePath ?? '';
    final selectedPath = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Change database file'),
        content: TextFormField(
          initialValue: pathValue,
          autofocus: true,
          onChanged: (value) => pathValue = value,
          decoration: const InputDecoration(
            labelText: 'SQLite file path',
            hintText: '/path/to/debug.sqlite',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(pathValue.trim()),
            child: const Text('Open file'),
          ),
        ],
      ),
    );

    if (selectedPath == null || selectedPath.isEmpty) return;
    await onSwitchDatabaseFile?.call(selectedPath);
  }
}

class _DetectedDatabasePicker extends StatelessWidget {
  const _DetectedDatabasePicker({
    required this.availableDatabasePaths,
    required this.loading,
    required this.onSwitchDatabaseFile,
    this.currentDatabasePath,
  });

  final List<String> availableDatabasePaths;
  final String? currentDatabasePath;
  final bool loading;
  final Future<void> Function(String databasePath) onSwitchDatabaseFile;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Detected SQLite databases',
            style: textTheme.labelLarge?.copyWith(color: colors.onSurface),
          ),
          const SizedBox(height: 8),
          for (final path in availableDatabasePaths) ...[
            _DetectedDatabaseTile(
              path: path,
              selected: path == currentDatabasePath,
              loading: loading,
              onTap: () => onSwitchDatabaseFile(path),
            ),
            const SizedBox(height: 8),
          ],
          Text(
            'Files ending in .db, .sqlite, or .sqlite3.',
            style: textTheme.bodySmall?.copyWith(
              color: colors.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _DetectedDatabaseTile extends StatelessWidget {
  const _DetectedDatabaseTile({
    required this.path,
    required this.selected,
    required this.loading,
    required this.onTap,
  });

  final String path;
  final bool selected;
  final bool loading;
  final Future<void> Function() onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final titleColor = selected ? colors.onPrimaryContainer : colors.onSurface;
    final subtitleColor = selected
        ? colors.onPrimaryContainer.withOpacity(0.82)
        : colors.onSurfaceVariant;

    return Material(
      color: selected
          ? colors.primaryContainer
          : colors.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: loading || selected ? null : onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              Icon(
                selected ? Icons.check_circle : Icons.storage_outlined,
                color: selected ? colors.primary : colors.onSurfaceVariant,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _databaseFileName(path),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: titleColor,
                        fontWeight: selected ? FontWeight.w700 : null,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _databaseParentPath(path),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(
                        context,
                      ).textTheme.bodySmall?.copyWith(color: subtitleColor),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.chevron_right,
                color: selected ? colors.primary : colors.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _databaseFileName(String path) {
  final parts = path.split(RegExp(r'[/\\]'));
  return parts.isEmpty ? path : parts.last;
}

String _databaseParentPath(String path) {
  final fileName = _databaseFileName(path);
  final parent = path.substring(0, path.length - fileName.length);
  if (parent.isEmpty) return path;
  return parent.endsWith('/') || parent.endsWith('\\')
      ? parent.substring(0, parent.length - 1)
      : parent;
}

class _PaneHeader extends StatelessWidget {
  const _PaneHeader({
    required this.icon,
    required this.label,
    this.onAdd,
    this.addTooltip,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onAdd;
  final String? addTooltip;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      child: Row(
        children: [
          Icon(icon, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: Theme.of(context).textTheme.labelLarge,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (onAdd != null)
            IconButton(
              tooltip: addTooltip,
              visualDensity: VisualDensity.compact,
              onPressed: onAdd,
              icon: const Icon(Icons.add),
            ),
        ],
      ),
    );
  }
}

class _EmptyDatabaseSelection extends StatelessWidget {
  const _EmptyDatabaseSelection({required this.connected});

  final bool connected;

  @override
  Widget build(BuildContext context) {
    final message = connected
        ? 'Select a table to inspect its columns and edit rows.'
        : 'Open a database to inspect its columns and rows.';
    return Center(
      child: Padding(padding: const EdgeInsets.all(16), child: Text(message)),
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
      color: Colors.black12,
      child: SingleChildScrollView(child: SelectableText(output)),
    );
  }
}
