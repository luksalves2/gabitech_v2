import 'dart:developer' as developer;
import 'package:flutter/foundation.dart';

/// Centralized error reporting hook.
/// Today: logs to console; tomorrow: plug Sentry/Crashlytics here.
class ErrorReporter {
  const ErrorReporter._();

  static void report(Object error, StackTrace? stack) {
    if (kDebugMode) {
      debugPrint('❗️[Error] $error');
      if (stack != null) debugPrint(stack.toString());
    } else {
      developer.log(
        error.toString(),
        name: 'AppError',
        error: error,
        stackTrace: stack,
      );
    }
    // TODO: integrate Sentry/Crashlytics here.
  }
}
