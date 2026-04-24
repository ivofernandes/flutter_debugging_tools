import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../network/debug_http_client.dart';

class NetworkLogsPanel extends StatefulWidget {
  const NetworkLogsPanel({
    required this.client,
    this.compact = false,
    super.key,
  });

  final DebugHttpClient client;
  final bool compact;

  @override
  State<NetworkLogsPanel> createState() => _NetworkLogsPanelState();
}

class _NetworkLogsPanelState extends State<NetworkLogsPanel> {
  double _visibleCount = 8;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.client,
      builder: (context, _) {
        final visibleCount = _visibleCount.round();
        final logs = widget.client.entries.take(visibleCount).toList();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: widget.compact ? MainAxisSize.min : MainAxisSize.max,
          children: [
            Text('Recent request logs (${logs.length}/${widget.client.entries.length})'),
            const SizedBox(height: 8),
            Text('Visible logs: $visibleCount'),
            Slider(
              value: _visibleCount,
              min: 1,
              max: 20,
              divisions: 19,
              label: visibleCount.toString(),
              onChanged: (value) => setState(() => _visibleCount = value),
            ),
            if (logs.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text('No network requests recorded yet.'),
              )
            else
              SizedBox(
                height: widget.compact ? 260 : 420,
                child: ListView.separated(
                  itemCount: logs.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final log = logs[index];
                    return Card(
                      margin: EdgeInsets.zero,
                      child: Padding(
                        padding: const EdgeInsets.all(8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(log.summary),
                            const SizedBox(height: 6),
                            SelectableText(log.curlCommand),
                            const SizedBox(height: 6),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                TextButton(
                                  onPressed: widget.client.clear,
                                  child: const Text('Clear'),
                                ),
                                TextButton.icon(
                                  onPressed: () {
                                    Clipboard.setData(ClipboardData(text: log.curlCommand));
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('cURL copied')),
                                    );
                                  },
                                  icon: const Icon(Icons.copy, size: 16),
                                  label: const Text('Copy cURL'),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
          ],
        );
      },
    );
  }
}
