import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../logging/app_log_entry.dart';
import '../logging/app_logger.dart';

class AppLogsPanel extends StatefulWidget {
  const AppLogsPanel({
    required this.logger,
    this.compact = false,
    this.initialMinimumLevel = AppLogLevel.trace,
    super.key,
  });

  final AppLogger logger;
  final bool compact;

  /// Initial minimum severity shown in the panel. Users can change this
  /// interactively with the level chips without changing the search text.
  final AppLogLevel initialMinimumLevel;

  @override
  State<AppLogsPanel> createState() => _AppLogsPanelState();
}

class _AppLogsPanelState extends State<AppLogsPanel> {
  final TextEditingController _filterController = TextEditingController();
  String _filter = '';
  late AppLogLevel _minimumLevel;

  @override
  void initState() {
    super.initState();
    _minimumLevel = widget.initialMinimumLevel;
    _filterController.addListener(() {
      setState(() => _filter = _filterController.text.trim().toLowerCase());
    });
  }

  @override
  void dispose() {
    _filterController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.logger,
      builder: (context, _) {
        final visibleLogs = _visibleLogs();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: widget.compact ? MainAxisSize.min : MainAxisSize.max,
          children: [
            Text(
              'App logs (${visibleLogs.length}/${widget.logger.entries.length})',
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _filterController,
              decoration: InputDecoration(
                labelText: 'Search logs',
                hintText: 'Filter by level, tag, message, or error',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _filterController.text.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'Clear search',
                        onPressed: _filterController.clear,
                        icon: const Icon(Icons.clear),
                      ),
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final level in AppLogLevel.values)
                  FilterChip(
                    label: Text(level.label),
                    selected: _minimumLevel == level,
                    onSelected: (_) => setState(() => _minimumLevel = level),
                    tooltip: 'Show ${level.label} and higher logs',
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.icon(
                  onPressed: visibleLogs.isEmpty
                      ? null
                      : () => _copyText(
                          context,
                          visibleLogs.map((entry) => entry.copyText).join('\n'),
                          'Visible logs copied',
                        ),
                  icon: const Icon(Icons.copy_all, size: 16),
                  label: const Text('Copy visible'),
                ),
                OutlinedButton.icon(
                  onPressed: widget.logger.entries.isEmpty
                      ? null
                      : widget.logger.clear,
                  icon: const Icon(Icons.delete_outline, size: 16),
                  label: const Text('Clear logs'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (visibleLogs.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text('No app logs match the current filter.'),
              )
            else
              SizedBox(
                height: widget.compact ? 320 : 520,
                child: ListView.separated(
                  itemCount: visibleLogs.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, index) => _LogCard(
                    entry: visibleLogs[index],
                    onCopy: () => _copyText(
                      context,
                      visibleLogs[index].copyText,
                      'Log copied',
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  List<AppLogEntry> _visibleLogs() {
    return widget.logger.entries
        .where((entry) => entry.level.isAtLeast(_minimumLevel))
        .where((entry) {
          if (_filter.isEmpty) return true;
          return entry.copyText.toLowerCase().contains(_filter);
        })
        .toList(growable: false);
  }

  void _copyText(BuildContext context, String text, String message) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

class _LogCard extends StatelessWidget {
  const _LogCard({required this.entry, required this.onCopy});

  final AppLogEntry entry;
  final VoidCallback onCopy;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SelectableText(entry.copyText),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: onCopy,
                icon: const Icon(Icons.copy, size: 16),
                label: const Text('Copy'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
