import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../network/debug_http_client.dart';

/// Generic URL caller for debug drawers.
///
/// Pass the same [DebugHttpClient] to [NetworkLogsPanel] to inspect generated
/// request logs and copy cURL commands.
class NetworkRequestPanel extends StatefulWidget {
  const NetworkRequestPanel({
    required this.client,
    this.initialUrl = 'https://api.ipify.org?format=json',
    this.quickActions = const [
      NetworkQuickAction(
        label: 'Get public IP',
        url: 'https://api.ipify.org?format=json',
      ),
    ],
    this.compact = false,
    super.key,
  });

  final DebugHttpClient client;
  final String initialUrl;
  final List<NetworkQuickAction> quickActions;
  final bool compact;

  @override
  State<NetworkRequestPanel> createState() => _NetworkRequestPanelState();
}

class NetworkQuickAction {
  const NetworkQuickAction({required this.label, required this.url});

  final String label;
  final String url;
}

class _NetworkRequestPanelState extends State<NetworkRequestPanel> {
  late final TextEditingController _urlController;
  String _output = 'No request performed yet.';
  NetworkRequestState _state = NetworkRequestState.idle;

  @override
  void initState() {
    super.initState();
    _urlController = TextEditingController(text: widget.initialUrl);
  }

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  Future<void> _fetchUrl({String? customUrl}) async {
    final rawUrl = (customUrl ?? _urlController.text).trim();
    if (rawUrl.isEmpty) {
      return;
    }

    _urlController.text = rawUrl;
    setState(() {
      _state = NetworkRequestState.loading;
      _output = 'Calling $rawUrl ...';
    });

    try {
      final response = await widget.client.get(Uri.parse(rawUrl));
      if (!mounted) return;
      setState(() {
        _state = NetworkRequestState.success;
        _output = _formatResponse(response);
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _state = NetworkRequestState.failure;
        _output = 'Request failed: $error';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final outputView = SingleChildScrollView(child: SelectableText(_output));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: widget.compact ? MainAxisSize.min : MainAxisSize.max,
      children: [
        TextField(
          controller: _urlController,
          decoration: const InputDecoration(
            labelText: 'URL',
            hintText: 'https://api.ipify.org?format=json',
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: [
            FilledButton(
              onPressed: _state == NetworkRequestState.loading
                  ? null
                  : () => _fetchUrl(),
              child: const Text('Call URL'),
            ),
            for (final action in widget.quickActions)
              OutlinedButton(
                onPressed: _state == NetworkRequestState.loading
                    ? null
                    : () => _fetchUrl(customUrl: action.url),
                child: Text(action.label),
              ),
          ],
        ),
        const SizedBox(height: 8),
        Text('Request state: ${_state.label}'),
        const SizedBox(height: 8),
        if (widget.compact)
          SizedBox(height: 180, child: outputView)
        else
          Expanded(child: outputView),
      ],
    );
  }

  String _formatResponse(http.Response response) {
    final body = response.body.length > 400
        ? '${response.body.substring(0, 400)}...'
        : response.body;

    try {
      final decoded = jsonDecode(body);
      final pretty = const JsonEncoder.withIndent('  ').convert(decoded);
      return 'HTTP ${response.statusCode}\n$pretty';
    } catch (_) {
      return 'HTTP ${response.statusCode}\n$body';
    }
  }
}

enum NetworkRequestState { idle, loading, success, failure }

extension on NetworkRequestState {
  String get label => switch (this) {
    NetworkRequestState.idle => 'Idle',
    NetworkRequestState.loading => 'Loading',
    NetworkRequestState.success => 'Success',
    NetworkRequestState.failure => 'Failure',
  };
}
