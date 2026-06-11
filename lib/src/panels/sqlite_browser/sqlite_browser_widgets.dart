part of '../sqlite_browser_panel.dart';

class _DatabaseToolbar extends StatelessWidget {
  const _DatabaseToolbar({
    required this.loading,
    required this.hasDatabase,
    required this.onRefresh,
    this.onInsertSampleRow,
  });

  final bool loading;
  final bool hasDatabase;
  final VoidCallback onRefresh;
  final Future<void> Function()? onInsertSampleRow;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        FilledButton.icon(
          onPressed: loading || !hasDatabase ? null : onRefresh,
          icon: const Icon(Icons.refresh),
          label: const Text('Refresh SQLite'),
        ),
        if (onInsertSampleRow != null)
          OutlinedButton.icon(
            onPressed: loading || !hasDatabase ? null : onInsertSampleRow,
            icon: const Icon(Icons.science_outlined),
            label: const Text('Insert sample row'),
          ),
      ],
    );
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
  const _EmptyDatabaseSelection();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Text('Select a table to inspect its columns and edit rows.'),
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
