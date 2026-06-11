part of '../sqlite_browser_panel.dart';

Widget _buildBrowser(_SQLiteBrowserPanelState state) {
  return Card.outlined(
    margin: EdgeInsets.zero,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _PaneHeader(
          icon: Icons.table_chart_outlined,
          label: state.widget.title,
          addTooltip: 'Create table',
          onAdd: state.loading || state.widget.database == null
              ? null
              : () => _showCreateTableDialog(state),
        ),
        Expanded(child: _buildBrowserBody(state)),
      ],
    ),
  );
}

Widget _buildBrowserBody(_SQLiteBrowserPanelState state) {
  if (state.widget.compact) {
    return Column(
      children: [
        SizedBox(height: 112, child: _buildTableList(state)),
        const Divider(height: 1),
        if (state.selectedTable == null)
          const Expanded(child: _EmptyDatabaseSelection())
        else ...[
          SizedBox(height: 150, child: _buildColumnList(state)),
          const Divider(height: 1),
          Expanded(child: _buildBrowseDataGrid(state)),
        ],
      ],
    );
  }

  return Row(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      SizedBox(width: 220, child: _buildTableList(state)),
      const VerticalDivider(width: 1),
      if (state.selectedTable == null)
        const Expanded(child: _EmptyDatabaseSelection())
      else ...[
        SizedBox(width: 280, child: _buildColumnList(state)),
        const VerticalDivider(width: 1),
        Expanded(child: _buildBrowseDataGrid(state)),
      ],
    ],
  );
}

Widget _buildTableList(_SQLiteBrowserPanelState state) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Expanded(
        child: state.tables.isEmpty
            ? const Center(child: Text('No user tables found.'))
            : Scrollbar(
                controller: state.tableScrollController,
                child: ListView.builder(
                  controller: state.tableScrollController,
                  itemCount: state.tables.length,
                  itemBuilder: (context, index) {
                    final table = state.tables[index];
                    return ListTile(
                      dense: true,
                      selected: table == state.selectedTable,
                      leading: const Icon(Icons.grid_on, size: 18),
                      title: Text(table),
                      trailing: table == state.selectedTable
                          ? const Icon(Icons.chevron_right)
                          : null,
                      onTap: () => _browseTable(state, table),
                    );
                  },
                ),
              ),
      ),
    ],
  );
}

Widget _buildColumnList(_SQLiteBrowserPanelState state) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _PaneHeader(
        icon: Icons.view_column_outlined,
        label: 'Columns',
        addTooltip: 'Add column',
        onAdd: state.loading || state.selectedTable == null
            ? null
            : () => _showAddColumnDialog(state),
      ),
      Expanded(
        child: state.columns.isEmpty
            ? const Center(child: Text('No columns found.'))
            : Scrollbar(
                controller: state.columnScrollController,
                child: ListView.builder(
                  controller: state.columnScrollController,
                  itemCount: state.columns.length,
                  itemBuilder: (context, index) {
                    final column = state.columns[index];
                    return ListTile(
                      dense: true,
                      leading: Icon(
                        column.primaryKeyPosition > 0 ? Icons.key : Icons.notes,
                        size: 18,
                      ),
                      title: Text(column.name),
                      subtitle: Text(
                        [
                          if (column.type.isNotEmpty) column.type,
                          if (column.badges.isNotEmpty) column.badges,
                        ].join(' · '),
                      ),
                    );
                  },
                ),
              ),
      ),
    ],
  );
}

Widget _buildBrowseDataGrid(_SQLiteBrowserPanelState state) {
  final table = state.selectedTable ?? 'table';

  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _PaneHeader(
        icon: Icons.dataset_outlined,
        label: 'Data · $table (${state.rowCount} rows)',
        addTooltip: 'Add row',
        onAdd: state.loading || state.columns.isEmpty
            ? null
            : () => _showAddRowDialog(state),
      ),
      Expanded(
        child: state.columns.isEmpty
            ? const Center(child: Text('Select a table to edit rows.'))
            : _buildDataRows(state),
      ),
    ],
  );
}

Widget _buildDataRows(_SQLiteBrowserPanelState state) {
  if (state.rows.isEmpty) {
    return const Center(child: Text('No rows yet. Add the first row.'));
  }

  return Scrollbar(
    controller: state.horizontalDataController,
    notificationPredicate: (notification) => notification.depth == 1,
    child: SingleChildScrollView(
      controller: state.horizontalDataController,
      scrollDirection: Axis.horizontal,
      child: Scrollbar(
        controller: state.verticalDataController,
        child: SingleChildScrollView(
          controller: state.verticalDataController,
          child: DataTable(
            headingRowHeight: 36,
            dataRowMinHeight: 36,
            dataRowMaxHeight: 56,
            columns: [
              for (final column in state.columns)
                DataColumn(label: Text(column.name)),
            ],
            rows: [
              for (final row in state.rows) _buildDataRow(state, row),
            ],
          ),
        ),
      ),
    ),
  );
}

DataRow _buildDataRow(
  _SQLiteBrowserPanelState state,
  Map<String, Object?> row,
) {
  return DataRow(
    onLongPress: () => _showEditRowDialog(state, row),
    cells: [
      for (final column in state.columns)
        DataCell(
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 220),
            child: SelectableText(
              _formatCell(row[column.name]),
              maxLines: 2,
            ),
          ),
          onTap: () => _showEditRowDialog(state, row),
        ),
    ],
  );
}
