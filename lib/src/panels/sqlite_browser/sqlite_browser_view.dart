part of '../sqlite_browser_panel.dart';

Widget _buildBrowser(_SQLiteBrowserPanelState state) {
  return Card.outlined(
    margin: EdgeInsets.zero,
    child: Column(
      mainAxisSize: state.widget.compact ? MainAxisSize.min : MainAxisSize.max,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _PaneHeader(
          icon: Icons.table_chart_outlined,
          label: state.widget.title,
          addTooltip: 'Create table',
          onAdd: state.loading || !state.hasConnectedDatabase
              ? null
              : () => _showCreateTableDialog(state),
        ),
        if (state.widget.compact)
          _buildBrowserBody(state)
        else
          Expanded(child: _buildBrowserBody(state)),
      ],
    ),
  );
}

Widget _buildBrowserBody(_SQLiteBrowserPanelState state) {
  if (state.widget.compact) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildTableList(state),
        const Divider(height: 1),
        if (state.selectedTable == null)
          _EmptyDatabaseSelection(connected: state.hasConnectedDatabase)
        else ...[
          _buildColumnList(state),
          const Divider(height: 1),
          _buildBrowseDataGrid(state),
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
        Expanded(
          child: _EmptyDatabaseSelection(connected: state.hasConnectedDatabase),
        )
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
    children: [_buildTableListContent(state)],
  );
}

Widget _buildTableListContent(_SQLiteBrowserPanelState state) {
  if (state.tables.isEmpty) {
    final message = state.hasConnectedDatabase
        ? 'No app tables found.'
        : 'Database is closed. Open a database to inspect tables.';
    if (state.widget.compact) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Center(child: Text(message)),
      );
    }

    return Expanded(child: Center(child: Text(message)));
  }

  if (state.widget.compact) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final table in state.tables) _buildTableTile(state, table),
      ],
    );
  }

  return Expanded(
    child: Scrollbar(
      controller: state.tableScrollController,
      child: ListView.builder(
        controller: state.tableScrollController,
        itemCount: state.tables.length,
        itemBuilder: (context, index) =>
            _buildTableTile(state, state.tables[index]),
      ),
    ),
  );
}

Widget _buildTableTile(_SQLiteBrowserPanelState state, String table) {
  final context = state.context;
  final colors = Theme.of(context).colorScheme;
  final selected = table == state.selectedTable;
  final contentColor = selected ? colors.primary : colors.onSurface;

  return ListTile(
    dense: true,
    selected: selected,
    iconColor: contentColor,
    textColor: contentColor,
    selectedColor: colors.primary,
    selectedTileColor: colors.primaryContainer.withValues(alpha: 0.35),
    leading: const Icon(Icons.grid_on, size: 18),
    title: Text(table),
    trailing: selected ? const Icon(Icons.chevron_right) : null,
    onTap: () => _browseTable(state, table),
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
      _buildColumnListContent(state),
    ],
  );
}

Widget _buildColumnListContent(_SQLiteBrowserPanelState state) {
  if (state.columns.isEmpty) {
    if (state.widget.compact) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Center(child: Text('No columns found.')),
      );
    }

    return const Expanded(child: Center(child: Text('No columns found.')));
  }

  if (state.widget.compact) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [for (final column in state.columns) _buildColumnTile(column)],
    );
  }

  return Expanded(
    child: Scrollbar(
      controller: state.columnScrollController,
      child: ListView.builder(
        controller: state.columnScrollController,
        itemCount: state.columns.length,
        itemBuilder: (context, index) => _buildColumnTile(state.columns[index]),
      ),
    ),
  );
}

Widget _buildColumnTile(SQLiteColumnInfo column) {
  return Builder(
    builder: (context) {
      final colors = Theme.of(context).colorScheme;
      return ListTile(
        dense: true,
        iconColor: colors.onSurface,
        textColor: colors.onSurface,
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
          style: TextStyle(color: colors.onSurfaceVariant),
        ),
      );
    },
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
      if (state.widget.compact)
        state.columns.isEmpty
            ? const Padding(
                padding: EdgeInsets.all(16),
                child: Center(child: Text('Select a table to edit rows.')),
              )
            : _buildDataRows(state)
      else
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

  final table = state.selectedTable;
  if (table == null) {
    return const Center(child: Text('Select a table to edit rows.'));
  }

  final pageSize = _dataPageSize(state);
  final firstRow = state.rowOffset + 1;
  final lastRow = state.rowOffset + state.rows.length;
  final canGoBack = state.rowOffset > 0 && !state.loading;
  final canGoForward = lastRow < state.rowCount && !state.loading;

  return Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Scrollbar(
        controller: state.horizontalDataController,
        child: SingleChildScrollView(
          controller: state.horizontalDataController,
          scrollDirection: Axis.horizontal,
          child: DataTable(
            headingRowHeight: 36,
            dataRowMinHeight: 36,
            dataRowMaxHeight: 56,
            columns: [
              for (final column in state.columns)
                DataColumn(label: Text(column.name)),
            ],
            rows: [for (final row in state.rows) _buildDataRow(state, row)],
          ),
        ),
      ),
      const Divider(height: 1),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          alignment: WrapAlignment.end,
          children: [
            Text('Rows $firstRow–$lastRow of ${state.rowCount}'),
            OutlinedButton.icon(
              onPressed: canGoBack
                  ? () => _browseTable(
                      state,
                      table,
                      offset: (state.rowOffset - pageSize)
                          .clamp(0, state.rowCount)
                          .toInt(),
                    )
                  : null,
              icon: const Icon(Icons.chevron_left),
              label: const Text('Previous'),
            ),
            OutlinedButton.icon(
              onPressed: canGoForward
                  ? () => _browseTable(
                      state,
                      table,
                      offset: state.rowOffset + pageSize,
                    )
                  : null,
              icon: const Icon(Icons.chevron_right),
              label: const Text('Next'),
            ),
          ],
        ),
      ),
    ],
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
            child: SelectableText(_formatCell(row[column.name]), maxLines: 2),
          ),
          onTap: () => _showEditRowDialog(state, row),
        ),
    ],
  );
}
