import 'package:flutter/foundation.dart';

class AppLogger {
  const AppLogger._();

  static const bool verbose = bool.fromEnvironment('HABITO_VERBOSE_LOGS');

  static void info(String message, {Object? error, StackTrace? stackTrace}) {
    _log('INFO', message, error: error, stackTrace: stackTrace);
  }

  static void warning(String message, {Object? error, StackTrace? stackTrace}) {
    _log('WARN', message, error: error, stackTrace: stackTrace);
  }

  static void error(String message, {Object? error, StackTrace? stackTrace}) {
    _log('ERROR', message, error: error, stackTrace: stackTrace);
  }

  static void _log(
    String level,
    String message, {
    Object? error,
    StackTrace? stackTrace,
  }) {
    if (!kDebugMode && !verbose && level != 'ERROR') return;

    debugPrint('[Habito][$level] $message');
    if (error != null) debugPrint('[Habito][$level] $error');
    if (stackTrace != null && (kDebugMode || verbose)) {
      debugPrint(stackTrace.toString());
    }
  }
}
