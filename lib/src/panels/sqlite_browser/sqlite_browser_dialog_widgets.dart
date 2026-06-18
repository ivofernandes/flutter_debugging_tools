part of '../sqlite_browser_panel.dart';

class _DialogSection extends StatelessWidget {
  const _DialogSection({
    required this.title,
    required this.child,
    this.trailing,
  });

  final String title;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: theme.dividerColor),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final titleWidget = Text(
                title,
                style: theme.textTheme.titleSmall,
                overflow: TextOverflow.ellipsis,
              );
              final trailingWidget = trailing;
              if (trailingWidget == null) return titleWidget;
              if (constraints.maxWidth < 430) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    titleWidget,
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: trailingWidget,
                      ),
                    ),
                  ],
                );
              }
              return Row(
                children: [
                  Expanded(child: titleWidget),
                  trailingWidget,
                ],
              );
            },
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}

class _FieldsGrid extends StatelessWidget {
  const _FieldsGrid({
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
    final theme = Theme.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 640) {
          return _CompactFieldsList(
            columns: columns,
            onChanged: onChanged,
            onDelete: onDelete,
            onPrimaryKeySelected: onPrimaryKeySelected,
          );
        }
        return Container(
          decoration: BoxDecoration(
            border: Border.all(color: theme.dividerColor),
          ),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              headingRowHeight: 36,
              dataRowMinHeight: 48,
              dataRowMaxHeight: 56,
              horizontalMargin: 8,
              columnSpacing: 10,
              columns: const [
                DataColumn(label: SizedBox(width: 180, child: Text('Name'))),
                DataColumn(label: SizedBox(width: 126, child: Text('Type'))),
                DataColumn(label: Text('NN')),
                DataColumn(label: Text('PK')),
                DataColumn(label: Text('AI')),
                DataColumn(label: Text('U')),
                DataColumn(label: SizedBox(width: 160, child: Text('Default'))),
                DataColumn(label: SizedBox(width: 150, child: Text('Check'))),
                DataColumn(label: SizedBox(width: 40, child: Text(''))),
              ],
              rows: [
                for (var i = 0; i < columns.length; i++)
                  DataRow(
                    cells: [
                      DataCell(
                        SizedBox(
                          width: 180,
                          child: TextField(
                            controller: columns[i].nameController,
                            onChanged: (_) => onChanged(),
                            decoration: const InputDecoration(
                              isDense: true,
                              border: InputBorder.none,
                              hintText: 'column_name',
                            ),
                          ),
                        ),
                      ),
                      DataCell(
                        SizedBox(
                          width: 126,
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: columns[i].type,
                              isExpanded: true,
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
                                columns[i].type = value;
                                if (value != 'INTEGER') {
                                  columns[i].autoIncrement = false;
                                }
                                onChanged();
                              },
                            ),
                          ),
                        ),
                      ),
                      DataCell(
                        Checkbox(
                          value: columns[i].notNull,
                          onChanged: columns[i].primaryKey
                              ? null
                              : (value) {
                                  columns[i].notNull = value ?? false;
                                  onChanged();
                                },
                        ),
                      ),
                      DataCell(
                        Checkbox(
                          value: columns[i].primaryKey,
                          onChanged: (value) {
                            if (value ?? false) {
                              onPrimaryKeySelected(i);
                            } else {
                              columns[i].primaryKey = false;
                              columns[i].autoIncrement = false;
                              onChanged();
                            }
                          },
                        ),
                      ),
                      DataCell(
                        Checkbox(
                          value: columns[i].autoIncrement,
                          onChanged:
                              columns[i].type == 'INTEGER' &&
                                  columns[i].primaryKey
                              ? (value) {
                                  columns[i].autoIncrement = value ?? false;
                                  onChanged();
                                }
                              : null,
                        ),
                      ),
                      DataCell(
                        Checkbox(
                          value: columns[i].unique,
                          onChanged: columns[i].primaryKey
                              ? null
                              : (value) {
                                  columns[i].unique = value ?? false;
                                  onChanged();
                                },
                        ),
                      ),
                      DataCell(
                        SizedBox(
                          width: 160,
                          child: TextField(
                            controller: columns[i].defaultController,
                            onChanged: (_) => onChanged(),
                            decoration: const InputDecoration(
                              isDense: true,
                              border: InputBorder.none,
                              hintText: 'NULL / 0 / CURRENT_TIMESTAMP',
                            ),
                          ),
                        ),
                      ),
                      DataCell(
                        SizedBox(
                          width: 150,
                          child: TextField(
                            controller: columns[i].checkController,
                            onChanged: (_) => onChanged(),
                            decoration: const InputDecoration(
                              isDense: true,
                              border: InputBorder.none,
                              hintText: 'value > 0',
                            ),
                          ),
                        ),
                      ),
                      DataCell(
                        IconButton(
                          tooltip: 'Remove column',
                          visualDensity: VisualDensity.compact,
                          onPressed: columns.length > 1
                              ? () => onDelete(i)
                              : null,
                          icon: const Icon(Icons.delete_outline),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
