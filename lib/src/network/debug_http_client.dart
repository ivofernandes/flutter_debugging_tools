import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'network_log_entry.dart';

/// HTTP client wrapper that records requests/responses for debugging panels.
class DebugHttpClient extends http.BaseClient with ChangeNotifier {
  DebugHttpClient({http.Client? inner, this.maxEntries = 50}) : _inner = inner ?? http.Client();

  final http.Client _inner;
  final int maxEntries;
  final List<NetworkLogEntry> _entries = [];

  List<NetworkLogEntry> get entries => List.unmodifiable(_entries);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final startedAt = DateTime.now();
    try {
      final streamed = await _inner.send(request);
      final bytes = await streamed.stream.toBytes();
      final body = utf8.decode(bytes, allowMalformed: true);

      _record(
        NetworkLogEntry(
          timestamp: startedAt,
          method: request.method,
          url: request.url,
          statusCode: streamed.statusCode,
          responseSnippet: body.length > 400 ? '${body.substring(0, 400)}…' : body,
        ),
      );

      return http.StreamedResponse(
        Stream<List<int>>.fromIterable([bytes]),
        streamed.statusCode,
        contentLength: bytes.length,
        request: streamed.request,
        headers: streamed.headers,
        isRedirect: streamed.isRedirect,
        persistentConnection: streamed.persistentConnection,
        reasonPhrase: streamed.reasonPhrase,
      );
    } catch (error) {
      _record(
        NetworkLogEntry(
          timestamp: startedAt,
          method: request.method,
          url: request.url,
          errorMessage: error.toString(),
        ),
      );
      rethrow;
    }
  }

  void clear() {
    _entries.clear();
    notifyListeners();
  }

  void _record(NetworkLogEntry entry) {
    _entries.insert(0, entry);
    if (_entries.length > maxEntries) {
      _entries.removeRange(maxEntries, _entries.length);
    }
    notifyListeners();
  }

  @override
  void close() {
    _inner.close();
    super.dispose();
  }
}
