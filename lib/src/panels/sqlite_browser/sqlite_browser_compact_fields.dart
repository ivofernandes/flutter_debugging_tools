part of '../sqlite_browser_panel.dart';

class _CompactFieldsList extends StatelessWidget {
  const _CompactFieldsList({
    required this.columns,
    required this.onChanged,
    required this.onDelete,
    required this.onPrimaryKeySelected,
  });

  final List<_CreateColumnInput> columns;
  final VoidCallback onChanged;
  final void Function(int index) onDelete;
  final void Function(int index) onPrimaryKeySelected;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var i = 0; i < columns.length; i++) ...[
          _CompactFieldCard(
            index: i,
            column: columns[i],
            canDelete: columns.length > 1,
            onChanged: onChanged,
            onDelete: () => onDelete(i),
            onPrimaryKeySelected: () => onPrimaryKeySelected(i),
          ),
          if (i != columns.length - 1) const SizedBox(height: 10),
        ],
      ],
    );
  }
}

class _CompactFieldCard extends StatelessWidget {
  const _CompactFieldCard({
    required this.index,
    required this.column,
    required this.canDelete,
    required this.onChanged,
    required this.onDelete,
    required this.onPrimaryKeySelected,
  });

  final int index;
  final _CreateColumnInput column;
  final bool canDelete;
  final VoidCallback onChanged;
  final VoidCallback onDelete;
  final VoidCallback onPrimaryKeySelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        border: Border.all(color: theme.dividerColor),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Field ${index + 1}',
                  style: theme.textTheme.labelLarge,
                ),
              ),
              IconButton(
                tooltip: 'Remove field',
                visualDensity: VisualDensity.compact,
                onPressed: canDelete ? onDelete : null,
                icon: const Icon(Icons.delete_outline),
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            controller: column.nameController,
            onChanged: (_) => onChanged(),
            decoration: const InputDecoration(
              labelText: 'Name',
              hintText: 'column_name',
              border: OutlineInputBorder(),
              isDense: true,
            ),
          ),
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(
            initialValue: column.type,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Type',
              border: OutlineInputBorder(),
              isDense: true,
            ),
            items: _sqliteTypeOptions
                .map(
                  (type) => DropdownMenuItem(
                    value: type,
                    child: Text(type.toLowerCase()),
                  ),
                )
                .toList(),
            onChanged: (value) {
              if (value == null) return;
              column.type = value;
              if (value != 'INTEGER') column.autoIncrement = false;
              onChanged();
            },
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _FieldOptionChip(
                label: 'NN',
                tooltip: 'NOT NULL',
                selected: column.notNull,
                onSelected: column.primaryKey
                    ? null
                    : (value) {
                        column.notNull = value;
                        onChanged();
                      },
              ),
              _FieldOptionChip(
                label: 'PK',
                tooltip: 'PRIMARY KEY',
                selected: column.primaryKey,
                onSelected: (value) {
                  if (value) {
                    onPrimaryKeySelected();
                  } else {
                    column.primaryKey = false;
                    column.autoIncrement = false;
                    onChanged();
                  }
                },
              ),
              _FieldOptionChip(
                label: 'AI',
                tooltip: 'AUTOINCREMENT',
                selected: column.autoIncrement,
                onSelected: column.type == 'INTEGER' && column.primaryKey
                    ? (value) {
                        column.autoIncrement = value;
                        onChanged();
                      }
                    : null,
              ),
              _FieldOptionChip(
                label: 'U',
                tooltip: 'UNIQUE',
                selected: column.unique,
                onSelected: column.primaryKey
                    ? null
                    : (value) {
                        column.unique = value;
                        onChanged();
                      },
              ),
            ],
          ),
          const SizedBox(height: 10),
          TextField(
            controller: column.defaultController,
            onChanged: (_) => onChanged(),
            decoration: const InputDecoration(
              labelText: 'Default',
              hintText: 'NULL / 0 / CURRENT_TIMESTAMP',
              border: OutlineInputBorder(),
              isDense: true,
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: column.checkController,
            onChanged: (_) => onChanged(),
            decoration: const InputDecoration(
              labelText: 'Check',
              hintText: 'value > 0',
              border: OutlineInputBorder(),
              isDense: true,
            ),
          ),
        ],
      ),
    );
  }
}

class _FieldOptionChip extends StatelessWidget {
  const _FieldOptionChip({
    required this.label,
    required this.tooltip,
    required this.selected,
    required this.onSelected,
  });

  final String label;
  final String tooltip;
  final bool selected;
  final ValueChanged<bool>? onSelected;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: FilterChip(
        label: Text(label),
        selected: selected,
        onSelected: onSelected,
      ),
    );
  }
}
