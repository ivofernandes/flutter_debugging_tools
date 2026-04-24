class NetworkLogEntry {
  const NetworkLogEntry({
    required this.timestamp,
    required this.method,
    required this.url,
    this.statusCode,
    this.responseSnippet,
    this.errorMessage,
  });

  final DateTime timestamp;
  final String method;
  final Uri url;
  final int? statusCode;
  final String? responseSnippet;
  final String? errorMessage;

  String get curlCommand => "curl -X $method '${url.toString()}'";

  String get summary {
    final time =
        '${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}:${timestamp.second.toString().padLeft(2, '0')}';
    if (errorMessage != null) {
      return '[$time] FAILED • $method $url\n$errorMessage';
    }

    final headline = responseSnippet?.split('\n').first ?? '';
    return '[$time] HTTP ${statusCode ?? '-'} • $method $url\n$headline';
  }
}
