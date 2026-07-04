/// Severity labels supported by [AppLogEntry] and [AppLogger].
enum AppLogLevel {
  trace,
  debug,
  info,
  warning,
  error;

  String get label => name.toUpperCase();
}

/// A single application log record displayed by the app logs panel.
class AppLogEntry {
  const AppLogEntry({
    required this.timestamp,
    required this.level,
    required this.message,
    this.tags = const [],
    this.error,
    this.stackTrace,
  });

  final DateTime timestamp;
  final AppLogLevel level;
  final String message;
  final List<String> tags;
  final Object? error;
  final StackTrace? stackTrace;

  /// Timestamped, grep-friendly single-line representation.
  String get formattedLine {
    final tagText = tags.isEmpty ? '' : ' ${tags.join('.')}';
    final errorText = error == null ? '' : ' | error=$error';
    return '[${timestamp.toUtc().toIso8601String()}] '
        '${level.label}$tagText $message$errorText';
  }

  /// Full text including stack trace, suitable for copy/paste.
  String get copyText {
    final stack = stackTrace;
    if (stack == null) return formattedLine;
    return '$formattedLine\n$stack';
  }
}
