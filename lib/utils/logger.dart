import 'package:flutter/foundation.dart';

class Logger {
  static void log(String message, {String? tag}) {
    final timestamp = DateTime.now().toIso8601String();
    final tagString = tag != null ? '[$tag] ' : '';
    debugPrint('$timestamp: $tagString$message');
  }

  static void info(String message, {String? tag}) {
    log('INFO: $message', tag: tag);
  }

  static void warning(String message, {String? tag}) {
    log('WARNING: $message', tag: tag);
  }

  static void error(String message,
      {Object? error, StackTrace? stackTrace, String? tag}) {
    log('ERROR: $message', tag: tag);
    if (error != null) {
      debugPrint('Error Details: $error');
    }
    if (stackTrace != null) {
      debugPrint('Stack Trace: $stackTrace');
    }
  }
}
