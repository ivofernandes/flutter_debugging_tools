import 'dart:collection';
import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';

import 'app_log_entry.dart';

/// In-memory application logger that notifies listeners as entries change.
///
/// Use [AppLogger()] or [appLogger] for the shared singleton:
///
/// ```dart
/// AppLogger().info('Opened settings');
/// appLogger.error('Failed to save', error, stackTrace);
/// ```
class AppLogger extends ChangeNotifier {
  factory AppLogger() => instance;

  AppLogger._internal({this.maxEntries = 500, this.consoleSplitLength = 1000});

  /// Creates an isolated logger when a screen, test, or package integration
  /// should not write to the shared singleton.
  AppLogger.detached({this.maxEntries = 500, this.consoleSplitLength = 1000});

  /// Shared logger for apps that do not need to manage their own instance.
  static final AppLogger instance = AppLogger._internal();

  final int maxEntries;
  final int consoleSplitLength;
  final List<AppLogEntry> _entries = [];

  UnmodifiableListView<AppLogEntry> get entries =>
      UnmodifiableListView(_entries);

  String get copyText => entries.map((entry) => entry.copyText).join('\n');

  AppLogEntry trace(dynamic event, {List<String> tags = const []}) => log(
        AppLogLevel.trace,
        event,
        tags: tags,
      );

  AppLogEntry debug(dynamic event, {List<String> tags = const []}) => log(
        AppLogLevel.debug,
        event,
        tags: tags,
      );

  AppLogEntry info(dynamic event, {List<String> tags = const []}) => log(
        AppLogLevel.info,
        event,
        tags: tags,
      );

  AppLogEntry warning(dynamic event, {List<String> tags = const []}) => log(
        AppLogLevel.warning,
        event,
        tags: tags,
      );

  AppLogEntry error(
    dynamic event, [
    Object? error,
    StackTrace? stackTrace,
  ]) =>
      log(
        AppLogLevel.error,
        event,
        error: error,
        stackTrace: stackTrace,
      );

  AppLogEntry log(
    AppLogLevel level,
    dynamic event, {
    List<String> tags = const [],
    Object? error,
    StackTrace? stackTrace,
    DateTime? timestamp,
  }) {
    final entry = AppLogEntry(
      timestamp: timestamp ?? DateTime.now().toUtc(),
      level: level,
      message: '$event',
      tags: List.unmodifiable(tags),
      error: error,
      stackTrace: stackTrace,
    );
    _entries.insert(0, entry);
    if (_entries.length > maxEntries) {
      _entries.removeRange(maxEntries, _entries.length);
    }
    _writeConsole(entry);
    notifyListeners();
    return entry;
  }

  void clear() {
    if (_entries.isEmpty) return;
    _entries.clear();
    notifyListeners();
  }

  void _writeConsole(AppLogEntry entry) {
    developer.log(
      entry.formattedLine,
      name: 'AppLogger',
      level: _developerLevel(entry.level),
      error: entry.error,
      stackTrace: entry.stackTrace,
    );

    if (!kDebugMode) return;
    for (final line in _splitLines(entry.copyText)) {
      debugPrint(line);
    }
  }

  Iterable<String> _splitLines(String text) sync* {
    for (final line in text.split('\n')) {
      if (line.length <= consoleSplitLength) {
        yield line;
        continue;
      }
      for (var start = 0; start < line.length; start += consoleSplitLength) {
        final end = start + consoleSplitLength < line.length
            ? start + consoleSplitLength
            : line.length;
        yield line.substring(start, end);
      }
    }
  }

  int _developerLevel(AppLogLevel level) => switch (level) {
        AppLogLevel.trace => 500,
        AppLogLevel.debug => 700,
        AppLogLevel.info => 800,
        AppLogLevel.warning => 900,
        AppLogLevel.error => 1000,
      };
}

/// Convenient top-level handle for the shared application logger.
final appLogger = AppLogger();
