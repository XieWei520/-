import 'package:flutter/foundation.dart';

@immutable
class AppLogger {
  const AppLogger(this.scope);

  final String scope;

  AppLogger child(String name) => AppLogger('$scope/$name');

  void info(String message) {
    debugPrint('[$scope] $message');
  }

  void error(String message, Object error, [StackTrace? stackTrace]) {
    debugPrint('[$scope] $message -> $error');
    if (stackTrace != null) {
      debugPrint('[$scope] StackTrace: $stackTrace');
    }
  }
}
