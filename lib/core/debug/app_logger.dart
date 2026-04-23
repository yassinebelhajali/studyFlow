import 'package:flutter/foundation.dart';

/// Lightweight structured logger. All output is suppressed in release builds.
///
/// Usage:
///   AppLogger.info('ChatController', 'restore complete', data: {'messages': 12});
///   AppLogger.error('HttpClient', 'stream failed', error: e, stackTrace: st);
abstract final class AppLogger {
  static void debug(String tag, String message, {Object? data}) {
    if (!kDebugMode) return;
    _print('DEBUG', tag, message, data: data);
  }

  static void info(String tag, String message, {Object? data}) {
    if (!kDebugMode) return;
    _print('INFO ', tag, message, data: data);
  }

  static void warn(String tag, String message, {Object? data}) {
    _print('WARN ', tag, message, data: data);
  }

  static void error(
    String tag,
    String message, {
    Object? data,
    Object? error,
    StackTrace? stackTrace,
  }) {
    _print('ERROR', tag, message, data: data);
    if (error != null) {
      debugPrint('       error : $error');
    }
    if (stackTrace != null && kDebugMode) {
      debugPrint('       stack : $stackTrace');
    }
  }

  static void _print(String level, String tag, String message, {Object? data}) {
    final ts = DateTime.now().toIso8601String().substring(11, 23);
    final suffix = data != null ? ' | $data' : '';
    debugPrint('$ts [$level] [$tag] $message$suffix');
  }
}
