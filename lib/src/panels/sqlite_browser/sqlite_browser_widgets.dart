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
  final Future<void> Function(String databasePath)? onSwitchDatabaseFile;

  @override
  Widget build(BuildContext context) {
    final hasLifecycleActions = onOpenDatabase != null ||
        onCloseDatabase != null ||
        onSwitchDatabaseFile != null ||
        onInsertSampleRow != null;

    return Card(
      margin: EdgeInsets.zero,
      child: ExpansionTile(
        initiallyExpanded: expanded,
        onExpansionChanged: onExpansionChanged,
        tilePadding: const EdgeInsets.symmetric(horizontal: 12),
        childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        leading: Icon(
          hasDatabase ? Icons.check_circle_outline : Icons.link_off,
          color: hasDatabase ? Colors.green : null,
        ),
        title: SelectableText(status),
        subtitle: hasLifecycleActions
            ? const Text('Tap to show SQLite connection actions.')
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
                    onPressed:
                        loading || !hasDatabase ? null : onInsertSampleRow,
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
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Text(message),
      ),
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
      child: SingleChildScrollView(
        child: SelectableText(output),
      ),
    );
  }
}
