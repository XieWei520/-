# Architecture Mainline Realignment Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the first authoritative Flutter mainline architecture layer by introducing a startup pipeline, a unified HTTP client, a router-based app shell, and a push-to-chat navigation bridge while preserving the current login, home, and chat entry flows.

**Architecture:** This plan does not attempt a full package split in one move. It creates the new top-level architecture skeleton inside `lib/app`, `lib/wk_foundation`, and `lib/wk_im_core` entry points, then bridges existing production pages into that shell. The result is a working Android-aligned mainline that later parity plans can extend without adding more logic to legacy duplicate paths.

**Tech Stack:** Flutter, flutter_riverpod, go_router, dio, flutter_test, sqflite_common_ffi, existing WKIM SDK, PowerShell, SSH remote debugging

---

**Workspace Note:** This working copy does not currently contain `.git` metadata. The `git add` and `git commit` commands below are the correct checkpoint commands for the canonical repository checkout. In this local copy, record the same checkpoints together with verification output until the repository is initialized.

## Scope Boundary

This plan only implements `Phase 1: New Mainline Architecture` from [2026-04-03-complete-feature-alignment-design.md](C:/Users/COLORFUL/Desktop/WuKongIM/wukong_im_app/docs/superpowers/specs/2026-04-03-complete-feature-alignment-design.md).

In scope:

- startup pipeline
- foundation runtime and logging skeleton
- unified HTTP client and failure model
- router-driven app shell
- auth-aware route resolution
- push-opened-to-chat navigation bridge
- compatibility wrappers for the two existing `ApiClient` entry points

Out of scope for this plan:

- endpoint slot rebuild
- login feature completeness
- home/contacts behavioral parity work
- chat action completeness
- group/search/push-vendor/call feature completion

## File Structure

### New Files

- `lib/app/app.dart`
  - Owns `MaterialApp.router`, reads the router provider, and keeps push routing plus call coordinator startup in one place.
- `lib/app/bootstrap/app_startup.dart`
  - Defines ordered startup steps and the startup runner used before `runApp`.
- `lib/app/navigation/app_route_location.dart`
  - Centralizes route paths and chat route encoding.
- `lib/app/navigation/app_route_resolver.dart`
  - Pure auth-aware redirect rules for the router.
- `lib/app/navigation/app_router.dart`
  - Builds the `GoRouter` instance that bridges login, home, and chat pages.
- `lib/app/navigation/app_router_refresh_notifier.dart`
  - Refreshes router redirects when auth state changes.
- `lib/app/navigation/app_push_route_bridge.dart`
  - Converts opened push events into chat route intents.
- `lib/wk_foundation/runtime/app_environment.dart`
  - Encodes platform/runtime facts used during startup.
- `lib/wk_foundation/logging/app_logger.dart`
  - Provides tagged logging with child scopes.
- `lib/wk_foundation/errors/app_failure.dart`
  - Normalizes request failures into a stable app error model.
- `lib/wk_foundation/net/wk_http_client.dart`
  - Becomes the canonical Dio-backed HTTP client.
- `test/app/bootstrap/app_startup_test.dart`
  - Verifies startup step ordering, caching, and failure behavior.
- `test/app/navigation/app_router_test.dart`
  - Verifies route encoding and auth-aware redirect logic.
- `test/app/navigation/app_push_route_bridge_test.dart`
  - Verifies push events become chat intents only when actionable.
- `test/wk_foundation/net/wk_http_client_test.dart`
  - Verifies signed header composition and failure mapping.

### Existing Files To Modify

- `pubspec.yaml`
  - Add `go_router`.
- `lib/main.dart`
  - Replace the ad hoc startup and `MaterialApp` bootstrap with the new startup runner and routed app shell.
- `lib/service/api/api_client.dart`
  - Convert to a compatibility wrapper over `WkHttpClient`.
- `lib/wukong_base/net/api_client.dart`
  - Convert to a compatibility wrapper over `WkHttpClient`.
- `test/modules/shell/main_pages_compile_test.dart`
  - Include the new `WuKongApp` shell in compile coverage.

## Remote Debugging Requirement

This plan keeps server-assisted validation explicit.

- SSH entry: `ssh root@103.207.68.33`
- Use remote verification when startup behavior, push routing, or runtime integration differs from local expectations.
- Minimum server checks:
  - `docker ps`
  - `docker logs --tail 200 fullstack-tangsengdaodaoserver-1`
  - `tail -n 200 /data/fullstack/wukongimdata/logs/error.log`

## Verification Commands Used Throughout

- `dart analyze lib/main.dart lib/app lib/wk_foundation lib/service/api lib/wukong_base/net`
- `flutter test test/app/bootstrap/app_startup_test.dart`
- `flutter test test/wk_foundation/net/wk_http_client_test.dart`
- `flutter test test/app/navigation/app_router_test.dart test/app/navigation/app_push_route_bridge_test.dart`
- `flutter test test/modules/shell/main_pages_compile_test.dart`

### Task 1: Create Foundation Runtime And Startup Pipeline

**Files:**
- Create: `lib/wk_foundation/runtime/app_environment.dart`
- Create: `lib/wk_foundation/logging/app_logger.dart`
- Create: `lib/app/bootstrap/app_startup.dart`
- Test: `test/app/bootstrap/app_startup_test.dart`

- [ ] **Step 1: Write the failing startup and environment tests**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:wukong_im_app/app/bootstrap/app_startup.dart';
import 'package:wukong_im_app/wk_foundation/logging/app_logger.dart';
import 'package:wukong_im_app/wk_foundation/runtime/app_environment.dart';

void main() {
  test('startup runner executes steps once and in order', () async {
    final events = <String>[];
    final runner = AppStartupRunner(
      logger: const AppLogger('startup'),
      steps: <AppStartupStep>[
        AppStartupStep('storage', () async => events.add('storage')),
        AppStartupStep('push', () async => events.add('push')),
      ],
    );

    await runner.ensureStarted();
    await runner.ensureStarted();

    expect(events, <String>['storage', 'push']);
  });

  test('startup runner stops at the first failing step', () async {
    final runner = AppStartupRunner(
      logger: const AppLogger('startup'),
      steps: <AppStartupStep>[
        AppStartupStep('storage', () async {}),
        AppStartupStep('broken', () async {
          throw StateError('boom');
        }),
        AppStartupStep('never', () async {
          throw StateError('should not run');
        }),
      ],
    );

    expect(runner.ensureStarted(), throwsA(isA<StateError>()));
  });

  test('desktop environments opt into sqflite ffi while mobile does not', () {
    const windows = AppEnvironment(platform: AppPlatform.windows, isWeb: false);
    const android = AppEnvironment(platform: AppPlatform.android, isWeb: false);
    const web = AppEnvironment(platform: AppPlatform.web, isWeb: true);

    expect(windows.usesSqfliteFfi, isTrue);
    expect(android.usesSqfliteFfi, isFalse);
    expect(web.usesSqfliteFfi, isFalse);
  });
}
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `flutter test test/app/bootstrap/app_startup_test.dart`
Expected: FAIL with missing `AppStartupRunner`, `AppStartupStep`, or `AppEnvironment`

- [ ] **Step 3: Implement the runtime environment and scoped logger**

```dart
// lib/wk_foundation/runtime/app_environment.dart
import 'package:flutter/foundation.dart';

enum AppPlatform {
  android,
  ios,
  web,
  windows,
  linux,
  macos,
  unknown,
}

@immutable
class AppEnvironment {
  const AppEnvironment({
    required this.platform,
    required this.isWeb,
  });

  final AppPlatform platform;
  final bool isWeb;

  bool get usesSqfliteFfi {
    if (isWeb) {
      return false;
    }
    return platform == AppPlatform.windows ||
        platform == AppPlatform.linux ||
        platform == AppPlatform.macos;
  }

  static AppEnvironment detect() {
    if (kIsWeb) {
      return const AppEnvironment(platform: AppPlatform.web, isWeb: true);
    }

    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return const AppEnvironment(platform: AppPlatform.android, isWeb: false);
      case TargetPlatform.iOS:
        return const AppEnvironment(platform: AppPlatform.ios, isWeb: false);
      case TargetPlatform.windows:
        return const AppEnvironment(platform: AppPlatform.windows, isWeb: false);
      case TargetPlatform.linux:
        return const AppEnvironment(platform: AppPlatform.linux, isWeb: false);
      case TargetPlatform.macOS:
        return const AppEnvironment(platform: AppPlatform.macos, isWeb: false);
      case TargetPlatform.fuchsia:
        return const AppEnvironment(platform: AppPlatform.unknown, isWeb: false);
    }
  }
}
```

```dart
// lib/wk_foundation/logging/app_logger.dart
import 'package:flutter/foundation.dart';

@immutable
class AppLogger {
  const AppLogger(this.scope);

  final String scope;

  AppLogger child(String name) => AppLogger('$scope/$name');

  void info(String message) {
    debugPrint('[$scope] $message');
  }

  void error(String message, Object error) {
    debugPrint('[$scope] $message -> $error');
  }
}
```

- [ ] **Step 4: Implement the startup runner**

```dart
// lib/app/bootstrap/app_startup.dart
import '../../wk_foundation/logging/app_logger.dart';

typedef StartupCallback = Future<void> Function();

class AppStartupStep {
  const AppStartupStep(this.label, this.run);

  final String label;
  final StartupCallback run;
}

class AppStartupRunner {
  AppStartupRunner({
    required List<AppStartupStep> steps,
    required AppLogger logger,
  }) : _steps = List<AppStartupStep>.unmodifiable(steps),
       _logger = logger;

  final List<AppStartupStep> _steps;
  final AppLogger _logger;
  Future<void>? _inFlight;
  bool _completed = false;

  Future<void> ensureStarted() {
    if (_completed) {
      return Future<void>.value();
    }
    final inFlight = _inFlight;
    if (inFlight != null) {
      return inFlight;
    }

    final future = _run();
    _inFlight = future;
    return future;
  }

  Future<void> _run() async {
    try {
      for (final step in _steps) {
        _logger.info('startup:${step.label}');
        await step.run();
      }
      _completed = true;
    } catch (error) {
      _logger.error('startup failed', error);
      rethrow;
    } finally {
      _inFlight = null;
    }
  }
}
```

- [ ] **Step 5: Run the startup tests again**

Run: `flutter test test/app/bootstrap/app_startup_test.dart`
Expected: PASS with 3 tests green

- [ ] **Step 6: Checkpoint**

```bash
git add lib/wk_foundation/runtime/app_environment.dart lib/wk_foundation/logging/app_logger.dart lib/app/bootstrap/app_startup.dart test/app/bootstrap/app_startup_test.dart
git commit -m "refactor: add foundation startup pipeline"
```

### Task 2: Introduce The Canonical HTTP Client And Compatibility Wrappers

**Files:**
- Create: `lib/wk_foundation/errors/app_failure.dart`
- Create: `lib/wk_foundation/net/wk_http_client.dart`
- Modify: `lib/service/api/api_client.dart`
- Modify: `lib/wukong_base/net/api_client.dart`
- Test: `test/wk_foundation/net/wk_http_client_test.dart`

- [ ] **Step 1: Write the failing network and failure tests**

```dart
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wukong_im_app/wk_foundation/errors/app_failure.dart';
import 'package:wukong_im_app/wk_foundation/net/wk_http_client.dart';

void main() {
  test('signed headers include auth and device identity when provided', () {
    final client = WkHttpClient(
      now: () => DateTime.fromMillisecondsSinceEpoch(123456),
      nonceFactory: (_) => 'nonce-fixed',
    );

    final headers = client.buildSignedHeaders(
      data: const <String, dynamic>{'hello': 'world'},
      token: 'token-1',
      deviceId: 'device-1',
      deviceSessionId: 'session-1',
    );

    expect(headers['token'], 'token-1');
    expect(headers['X-Device-ID'], 'device-1');
    expect(headers['X-Device-Session-ID'], 'session-1');
    expect(headers['timestamp'], '123456');
    expect(headers['noncestr'], 'nonce-fixed');
    expect(headers['appid'], isNotEmpty);
    expect(headers['sign'], isNotEmpty);
  });

  test('failure mapper preserves server failures', () {
    final request = RequestOptions(path: '/messages');
    final response = Response<void>(requestOptions: request, statusCode: 502);
    final exception = DioException(
      requestOptions: request,
      response: response,
      type: DioExceptionType.badResponse,
    );

    final failure = AppFailure.fromDio(exception);

    expect(failure.kind, AppFailureKind.server);
    expect(failure.statusCode, 502);
  });
}
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `flutter test test/wk_foundation/net/wk_http_client_test.dart`
Expected: FAIL with missing `WkHttpClient` or `AppFailure`

- [ ] **Step 3: Implement the canonical failure model and HTTP client**

```dart
// lib/wk_foundation/errors/app_failure.dart
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

enum AppFailureKind {
  unauthorized,
  timeout,
  network,
  server,
  unknown,
}

@immutable
class AppFailure implements Exception {
  const AppFailure({
    required this.kind,
    required this.message,
    this.statusCode,
  });

  final AppFailureKind kind;
  final String message;
  final int? statusCode;

  factory AppFailure.fromDio(DioException exception) {
    final statusCode = exception.response?.statusCode;

    switch (exception.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return AppFailure(
          kind: AppFailureKind.timeout,
          message: exception.message ?? 'Request timed out',
          statusCode: statusCode,
        );
      case DioExceptionType.connectionError:
        return AppFailure(
          kind: AppFailureKind.network,
          message: exception.message ?? 'Network connection failed',
          statusCode: statusCode,
        );
      case DioExceptionType.badResponse:
        if (statusCode == 401) {
          return const AppFailure(
            kind: AppFailureKind.unauthorized,
            message: 'Unauthorized',
            statusCode: 401,
          );
        }
        return AppFailure(
          kind: AppFailureKind.server,
          message: exception.message ?? 'Server error',
          statusCode: statusCode,
        );
      default:
        return AppFailure(
          kind: AppFailureKind.unknown,
          message: exception.message ?? 'Unknown request failure',
          statusCode: statusCode,
        );
    }
  }
}
```

```dart
// lib/wk_foundation/net/wk_http_client.dart
import 'dart:convert';

import 'package:crypto/crypto.dart' as crypto_lib;
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../core/config/api_config.dart';
import '../../core/utils/storage_utils.dart';
import '../errors/app_failure.dart';

typedef WkNow = DateTime Function();
typedef WkNonceFactory = String Function(int length);

class WkHttpClient {
  WkHttpClient({
    Dio? dio,
    WkNow? now,
    WkNonceFactory? nonceFactory,
  }) : _dio = dio,
       _now = now ?? DateTime.now,
       _nonceFactory = nonceFactory ?? _defaultNonceFactory;

  static final WkHttpClient instance = WkHttpClient();

  Dio? _dio;
  final WkNow _now;
  final WkNonceFactory _nonceFactory;

  Dio get dio => _dio ??= _createDio();

  void warmUp() {
    dio;
  }

  @visibleForTesting
  Map<String, String> buildSignedHeaders({
    Object? data,
    String? token,
    String? deviceId,
    String? deviceSessionId,
  }) {
    final timestamp = _now().millisecondsSinceEpoch.toString();
    final nonce = _nonceFactory(16);
    final encoded = data == null
        ? ''
        : data is String
        ? data
        : jsonEncode(data);
    final signSource = '$encoded$nonce$timestamp${ApiConfig.appKey}';
    final sign = crypto_lib.md5.convert(utf8.encode(signSource)).toString();

    return <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      'appid': ApiConfig.appId,
      'timestamp': timestamp,
      'noncestr': nonce,
      'sign': sign,
      if ((token ?? '').isNotEmpty) 'token': token!,
      if ((deviceId ?? '').isNotEmpty) 'X-Device-ID': deviceId!,
      if ((deviceSessionId ?? '').isNotEmpty)
        'X-Device-Session-ID': deviceSessionId!,
    };
  }

  Dio _createDio() {
    final client = Dio(
      BaseOptions(
        baseUrl: ApiConfig.baseUrl,
        connectTimeout: const Duration(seconds: 30),
        receiveTimeout: const Duration(seconds: 30),
        sendTimeout: const Duration(seconds: 30),
        receiveDataWhenStatusError: true,
        validateStatus: (_) => true,
      ),
    );

    client.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          options.headers.addAll(
            buildSignedHeaders(
              data: options.data,
              token: StorageUtils.getToken(),
              deviceId: StorageUtils.getDeviceId(),
              deviceSessionId: StorageUtils.getDeviceSessionId(),
            ),
          );
          handler.next(options);
        },
        onResponse: (response, handler) async {
          if (response.statusCode == 401) {
            await StorageUtils.logout();
          }
          handler.next(response);
        },
        onError: (error, handler) {
          handler.next(
            DioException(
              requestOptions: error.requestOptions,
              response: error.response,
              error: AppFailure.fromDio(error),
              type: error.type,
              message: error.message,
            ),
          );
        },
      ),
    );

    return client;
  }

  Future<Response<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) {
    return dio.get<T>(path, queryParameters: queryParameters, options: options);
  }

  Future<Response<T>> post<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) {
    return dio.post<T>(
      path,
      data: data,
      queryParameters: queryParameters,
      options: options,
    );
  }

  Future<Response<T>> put<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) {
    return dio.put<T>(
      path,
      data: data,
      queryParameters: queryParameters,
      options: options,
    );
  }

  Future<Response<T>> delete<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) {
    return dio.delete<T>(
      path,
      data: data,
      queryParameters: queryParameters,
      options: options,
    );
  }

  Future<Response<T>> uploadFile<T>(
    String path,
    String filePath, {
    String name = 'file',
    Map<String, dynamic>? data,
    void Function(int, int)? onSendProgress,
  }) async {
    final formData = FormData.fromMap({
      ...?data,
      name: await MultipartFile.fromFile(filePath),
    });

    return dio.post<T>(
      path,
      data: formData,
      onSendProgress: onSendProgress,
      options: Options(contentType: 'multipart/form-data'),
    );
  }

  Future<Response<dynamic>> downloadFile(
    String path,
    String savePath, {
    void Function(int, int)? onReceiveProgress,
    CancelToken? cancelToken,
  }) {
    return dio.download(
      path,
      savePath,
      onReceiveProgress: onReceiveProgress,
      cancelToken: cancelToken,
    );
  }

  void setToken(String token) {
    dio.options.headers['token'] = token;
  }

  void clearToken() {
    dio.options.headers.remove('token');
  }

  static String _defaultNonceFactory(int length) {
    const chars =
        'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';
    final millis = DateTime.now().millisecondsSinceEpoch;
    return List<String>.generate(
      length,
      (index) => chars[(millis + index * 17) % chars.length],
    ).join();
  }
}
```

- [ ] **Step 4: Replace both legacy API clients with compatibility wrappers**

```dart
// lib/service/api/api_client.dart
import 'package:dio/dio.dart';

import '../../wk_foundation/net/wk_http_client.dart';

class ApiClient {
  ApiClient._();

  static final ApiClient _instance = ApiClient._();
  static ApiClient get instance => _instance;

  final WkHttpClient _client = WkHttpClient.instance;

  Dio get dio => _client.dio;

  Future<Response<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) {
    return _client.get<T>(
      path,
      queryParameters: queryParameters,
      options: options,
    );
  }

  Future<Response<T>> post<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) {
    return _client.post<T>(
      path,
      data: data,
      queryParameters: queryParameters,
      options: options,
    );
  }

  Future<Response<T>> put<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) {
    return _client.put<T>(
      path,
      data: data,
      queryParameters: queryParameters,
      options: options,
    );
  }

  Future<Response<T>> delete<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) {
    return _client.delete<T>(
      path,
      data: data,
      queryParameters: queryParameters,
      options: options,
    );
  }

  Future<Response<T>> uploadFile<T>(
    String path,
    String filePath, {
    String name = 'file',
    Map<String, dynamic>? data,
    void Function(int, int)? onSendProgress,
  }) {
    return _client.uploadFile<T>(
      path,
      filePath,
      name: name,
      data: data,
      onSendProgress: onSendProgress,
    );
  }

  void setToken(String token) => _client.setToken(token);

  void clearToken() => _client.clearToken();
}
```

```dart
// lib/wukong_base/net/api_client.dart
import 'package:dio/dio.dart';

import '../../wk_foundation/net/wk_http_client.dart';

class ApiClient {
  ApiClient._();

  static final ApiClient _instance = ApiClient._();
  static ApiClient get instance => _instance;

  final WkHttpClient _client = WkHttpClient.instance;

  Dio get dio => _client.dio;

  Future<Response<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
  }) {
    return _client.get<T>(
      path,
      queryParameters: queryParameters,
      options: options,
    );
  }

  Future<Response<T>> post<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
  }) {
    return _client.post<T>(
      path,
      data: data,
      queryParameters: queryParameters,
      options: options,
    );
  }

  Future<Response<T>> put<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
  }) {
    return _client.put<T>(
      path,
      data: data,
      queryParameters: queryParameters,
      options: options,
    );
  }

  Future<Response<T>> delete<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
  }) {
    return _client.delete<T>(
      path,
      data: data,
      queryParameters: queryParameters,
      options: options,
    );
  }

  Future<Response<T>> uploadFile<T>(
    String path, {
    required String filePath,
    required String fileKey,
    Map<String, dynamic>? data,
    void Function(int, int)? onSendProgress,
    CancelToken? cancelToken,
  }) {
    return _client.uploadFile<T>(
      path,
      filePath,
      name: fileKey,
      data: data,
      onSendProgress: onSendProgress,
    );
  }

  Future<Response<dynamic>> downloadFile(
    String url,
    String savePath, {
    void Function(int, int)? onReceiveProgress,
    CancelToken? cancelToken,
  }) {
    return _client.downloadFile(
      url,
      savePath,
      onReceiveProgress: onReceiveProgress,
      cancelToken: cancelToken,
    );
  }
}
```

- [ ] **Step 5: Run analysis and the network tests**

Run: `dart analyze lib/wk_foundation lib/service/api/api_client.dart lib/wukong_base/net/api_client.dart`
Expected: PASS with no analyzer errors

Run: `flutter test test/wk_foundation/net/wk_http_client_test.dart`
Expected: PASS with 2 tests green

- [ ] **Step 6: Checkpoint**

```bash
git add lib/wk_foundation/errors/app_failure.dart lib/wk_foundation/net/wk_http_client.dart lib/service/api/api_client.dart lib/wukong_base/net/api_client.dart test/wk_foundation/net/wk_http_client_test.dart
git commit -m "refactor: unify flutter api client entry points"
```

### Task 3: Add The Router Mainline And Auth Redirect Rules

**Files:**
- Modify: `pubspec.yaml`
- Create: `lib/app/navigation/app_route_location.dart`
- Create: `lib/app/navigation/app_route_resolver.dart`
- Create: `lib/app/navigation/app_router_refresh_notifier.dart`
- Create: `lib/app/navigation/app_router.dart`
- Test: `test/app/navigation/app_router_test.dart`

- [ ] **Step 1: Add the router dependency**

Run: `flutter pub add go_router`
Expected: `pubspec.yaml` updated and `.dart_tool/package_config.json` regenerated

- [ ] **Step 2: Write the failing router tests**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:wukong_im_app/app/navigation/app_route_location.dart';
import 'package:wukong_im_app/app/navigation/app_route_resolver.dart';
import 'package:wukong_im_app/data/providers/auth_provider.dart';

void main() {
  test('logged out users are redirected to login', () {
    final resolver = AppRouteResolver();
    final auth = AuthState(isLoggedIn: false, isLoading: false);

    expect(
      resolver.redirectFor(authState: auth, location: AppRouteLocation.home),
      AppRouteLocation.login,
    );
  });

  test('logged in users are redirected away from login', () {
    final resolver = AppRouteResolver();
    final auth = AuthState(isLoggedIn: true, isLoading: false);

    expect(
      resolver.redirectFor(authState: auth, location: AppRouteLocation.login),
      AppRouteLocation.home,
    );
  });

  test('chat route encodes id and query name', () {
    expect(
      AppRouteLocation.chat(
        channelType: 1,
        channelId: 'alice/42',
        channelName: 'Alice Smith',
      ),
      '/chat/1/alice%2F42?name=Alice%20Smith',
    );
  });
}
```

- [ ] **Step 3: Run the tests to verify they fail**

Run: `flutter test test/app/navigation/app_router_test.dart`
Expected: FAIL with missing route classes or resolver implementation

- [ ] **Step 4: Implement route locations, redirect rules, router refresh, and the `GoRouter` provider**

```dart
// lib/app/navigation/app_route_location.dart
class AppRouteLocation {
  static const String root = '/';
  static const String boot = '/boot';
  static const String login = '/login';
  static const String home = '/home';

  static String chat({
    required int channelType,
    required String channelId,
    String? channelName,
  }) {
    final encodedId = Uri.encodeComponent(channelId);
    final encodedName = channelName == null
        ? ''
        : '?name=${Uri.encodeQueryComponent(channelName)}';
    return '/chat/$channelType/$encodedId$encodedName';
  }
}
```

```dart
// lib/app/navigation/app_route_resolver.dart
import '../../data/providers/auth_provider.dart';
import 'app_route_location.dart';

class AppRouteResolver {
  String? redirectFor({
    required AuthState authState,
    required String location,
  }) {
    final atBoot = location == AppRouteLocation.boot;
    final atLogin = location == AppRouteLocation.login;

    if (authState.isLoading) {
      return atBoot ? null : AppRouteLocation.boot;
    }

    if (!authState.isLoggedIn) {
      return atLogin ? null : AppRouteLocation.login;
    }

    if (location == AppRouteLocation.root || atBoot || atLogin) {
      return AppRouteLocation.home;
    }

    return null;
  }
}
```

```dart
// lib/app/navigation/app_router_refresh_notifier.dart
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers/auth_provider.dart';

class AppRouterRefreshNotifier extends ChangeNotifier {
  void refresh() => notifyListeners();
}

final appRouterRefreshNotifierProvider = Provider<AppRouterRefreshNotifier>((ref) {
  final notifier = AppRouterRefreshNotifier();
  ref.listen<AuthState>(authProvider, (_, __) => notifier.refresh());
  ref.onDispose(notifier.dispose);
  return notifier;
});
```

```dart
// lib/app/navigation/app_router.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/providers/auth_provider.dart';
import '../../modules/auth/login_page.dart';
import '../../modules/chat/chat_page.dart';
import '../../modules/conversation/main_page.dart';
import 'app_route_location.dart';
import 'app_route_resolver.dart';
import 'app_router_refresh_notifier.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  final refresh = ref.watch(appRouterRefreshNotifierProvider);
  final resolver = AppRouteResolver();

  return GoRouter(
    initialLocation: AppRouteLocation.boot,
    refreshListenable: refresh,
    redirect: (_, state) {
      return resolver.redirectFor(
        authState: ref.read(authProvider),
        location: state.matchedLocation,
      );
    },
    routes: <RouteBase>[
      GoRoute(
        path: AppRouteLocation.boot,
        builder: (_, __) => const Scaffold(
          body: Center(child: CircularProgressIndicator()),
        ),
      ),
      GoRoute(
        path: AppRouteLocation.login,
        builder: (_, __) => const LoginPage(),
      ),
      GoRoute(
        path: AppRouteLocation.home,
        builder: (_, __) => const MainPage(),
      ),
      GoRoute(
        path: '/chat/:channelType/:channelId',
        name: 'chat',
        builder: (_, state) {
          final channelType = int.parse(state.pathParameters['channelType']!);
          final channelId = Uri.decodeComponent(state.pathParameters['channelId']!);
          final channelName = state.uri.queryParameters['name'] ?? channelId;
          return ChatPage(
            channelId: channelId,
            channelType: channelType,
            channelName: channelName,
          );
        },
      ),
    ],
  );
});
```

- [ ] **Step 5: Run router tests and analysis**

Run: `dart analyze lib/app/navigation`
Expected: PASS with no analyzer errors

Run: `flutter test test/app/navigation/app_router_test.dart`
Expected: PASS with 3 tests green

- [ ] **Step 6: Checkpoint**

```bash
git add pubspec.yaml lib/app/navigation/app_route_location.dart lib/app/navigation/app_route_resolver.dart lib/app/navigation/app_router_refresh_notifier.dart lib/app/navigation/app_router.dart test/app/navigation/app_router_test.dart
git commit -m "refactor: add router mainline shell"
```

### Task 4: Integrate The Routed App Shell Into The Entry Point

**Files:**
- Create: `lib/app/navigation/app_push_route_bridge.dart`
- Create: `lib/app/app.dart`
- Modify: `lib/main.dart`
- Modify: `test/modules/shell/main_pages_compile_test.dart`
- Test: `test/app/navigation/app_push_route_bridge_test.dart`

- [ ] **Step 1: Write the failing push-route bridge test**

```dart
import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:wukong_im_app/app/navigation/app_push_route_bridge.dart';
import 'package:wukong_im_app/wukong_push/models/push_models.dart';

void main() {
  test('push route bridge opens chat for actionable opened events only', () async {
    final controller = StreamController<PushMessageEvent>.broadcast();
    final opened = <AppChatRouteIntent>[];
    final bridge = AppPushRouteBridge(
      messageEvents: controller.stream,
      isLoggedIn: () => true,
      onOpenChat: opened.add,
    );

    bridge.start();

    controller.add(
      PushMessageEvent(
        payload: PushPayload(
          raw: const <String, dynamic>{},
          channelId: 'alice',
          channelType: 1,
          title: 'Alice',
        ),
        data: const <String, dynamic>{},
        trigger: PushMessageTrigger.tap,
      ),
    );

    controller.add(
      PushMessageEvent(
        payload: PushPayload(
          raw: const <String, dynamic>{},
          channelId: 'ignored',
          channelType: 1,
        ),
        data: const <String, dynamic>{},
        trigger: PushMessageTrigger.foreground,
      ),
    );

    await Future<void>.delayed(Duration.zero);

    expect(opened, hasLength(1));
    expect(opened.single.channelId, 'alice');
    expect(opened.single.location, '/chat/1/alice?name=Alice');

    await bridge.dispose();
    await controller.close();
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/app/navigation/app_push_route_bridge_test.dart`
Expected: FAIL with missing `AppPushRouteBridge` or `AppChatRouteIntent`

- [ ] **Step 3: Implement the push route bridge, the routed app shell, and the new entry point**

```dart
// lib/app/navigation/app_push_route_bridge.dart
import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../wukong_push/models/push_models.dart';
import 'app_route_location.dart';

@immutable
class AppChatRouteIntent {
  const AppChatRouteIntent({
    required this.channelId,
    required this.channelType,
    required this.channelName,
  });

  final String channelId;
  final int channelType;
  final String channelName;

  String get location => AppRouteLocation.chat(
    channelType: channelType,
    channelId: channelId,
    channelName: channelName,
  );
}

typedef OpenChatRoute = void Function(AppChatRouteIntent intent);

class AppPushRouteBridge {
  AppPushRouteBridge({
    required Stream<PushMessageEvent> messageEvents,
    required bool Function() isLoggedIn,
    required OpenChatRoute onOpenChat,
  }) : _messageEvents = messageEvents,
       _isLoggedIn = isLoggedIn,
       _onOpenChat = onOpenChat;

  final Stream<PushMessageEvent> _messageEvents;
  final bool Function() _isLoggedIn;
  final OpenChatRoute _onOpenChat;

  StreamSubscription<PushMessageEvent>? _subscription;

  void start() {
    _subscription ??= _messageEvents.listen(_handleEvent);
  }

  void _handleEvent(PushMessageEvent event) {
    if (!event.openedFromNotification || !_isLoggedIn()) {
      return;
    }
    if (!event.payload.hasConversationTarget) {
      return;
    }
    _onOpenChat(
      AppChatRouteIntent(
        channelId: event.payload.channelId!,
        channelType: event.payload.channelType!,
        channelName:
            event.payload.title?.trim().isNotEmpty == true
                ? event.payload.title!
                : event.payload.body?.trim().isNotEmpty == true
                ? event.payload.body!
                : event.payload.channelId!,
      ),
    );
  }

  Future<void> dispose() async {
    await _subscription?.cancel();
    _subscription = null;
  }
}
```

```dart
// lib/app/app.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/providers/auth_provider.dart';
import '../modules/video_call/call_coordinator.dart';
import '../widgets/wk_theme.dart';
import '../wukong_push/push_service.dart';
import 'navigation/app_push_route_bridge.dart';
import 'navigation/app_router.dart';

class WuKongApp extends ConsumerStatefulWidget {
  const WuKongApp({super.key});

  @override
  ConsumerState<WuKongApp> createState() => _WuKongAppState();
}

class _WuKongAppState extends ConsumerState<WuKongApp> {
  AppPushRouteBridge? _pushBridge;

  @override
  void initState() {
    super.initState();
    _pushBridge = AppPushRouteBridge(
      messageEvents: PushService.instance.messageEvents,
      isLoggedIn: () => ref.read(authProvider).isLoggedIn,
      onOpenChat: (intent) {
        ref.read(appRouterProvider).push(intent.location);
      },
    )..start();
  }

  @override
  void dispose() {
    _pushBridge?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(appRouterProvider);
    final auth = ref.watch(authProvider);

    if (auth.isLoggedIn) {
      CallCoordinator.instance.start(router.routerDelegate.navigatorKey);
    } else {
      CallCoordinator.instance.stop();
    }

    return MaterialApp.router(
      title: 'WuKongIM',
      debugShowCheckedModeBanner: false,
      theme: WKTheme.themeData,
      routerConfig: router,
    );
  }
}
```

```dart
// lib/main.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'app/app.dart';
import 'app/bootstrap/app_startup.dart';
import 'core/utils/storage_utils.dart';
import 'wk_foundation/logging/app_logger.dart';
import 'wk_foundation/net/wk_http_client.dart';
import 'wk_foundation/runtime/app_environment.dart';
import 'wukong_base/msg/draft_manager.dart';
import 'wukong_push/push_exports.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final environment = AppEnvironment.detect();
  if (environment.usesSqfliteFfi) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }

  final startup = AppStartupRunner(
    logger: const AppLogger('startup'),
    steps: <AppStartupStep>[
      AppStartupStep('storage', StorageUtils.init),
      AppStartupStep(
        'drafts',
        () => DraftManager().loadAllDrafts(syncRemote: false),
      ),
      AppStartupStep('network', () async => WkHttpClient.instance.warmUp()),
      AppStartupStep('push', () => PushService.instance.ensureInitialized()),
    ],
  );

  await startup.ensureStarted();

  runApp(const ProviderScope(child: WuKongApp()));
}
```

```dart
// test/modules/shell/main_pages_compile_test.dart
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:wukong_im_app/app/app.dart';
import 'package:wukong_im_app/modules/contacts/contacts_page.dart';
import 'package:wukong_im_app/modules/conversation/conversation_list_page.dart';
import 'package:wukong_im_app/modules/conversation/main_page.dart';
import 'package:wukong_im_app/modules/home/home_shell_page.dart';
import 'package:wukong_im_app/modules/user/user_page.dart';

void main() {
  test('main shell pages compile', () {
    expect(const WuKongApp(), isA<Widget>());
    expect(const MainPage(), isA<Widget>());
    expect(const HomeShellPage(), isA<Widget>());
    expect(const ConversationListPage(), isA<Widget>());
    expect(const ContactsPage(), isA<Widget>());
    expect(const UserPage(), isA<Widget>());
    expect(const NewFriendsPage(), isA<Widget>());
  });
}
```

- [ ] **Step 4: Run analysis and the integration-facing tests**

Run: `dart analyze lib/main.dart lib/app`
Expected: PASS with no analyzer errors

Run: `flutter test test/app/navigation/app_push_route_bridge_test.dart test/modules/shell/main_pages_compile_test.dart`
Expected: PASS with push bridge behavior covered and compile shell coverage green

- [ ] **Step 5: Verify the deployed backend is healthy before accepting startup and push-route integration**

Run: `ssh root@103.207.68.33 "docker ps --format '{{.Names}}' && docker logs --tail 200 fullstack-tangsengdaodaoserver-1"`
Expected: container list includes the IM backend containers and server logs do not show startup-time authentication or routing-correlated crashes

- [ ] **Step 6: Checkpoint**

```bash
git add lib/app/navigation/app_push_route_bridge.dart lib/app/app.dart lib/main.dart test/app/navigation/app_push_route_bridge_test.dart test/modules/shell/main_pages_compile_test.dart
git commit -m "refactor: switch app entrypoint to routed shell"
```

## Self-Review Checklist

- Spec coverage:
  - `Phase 1: New Mainline Architecture` is fully covered by Tasks 1-4.
  - Startup backbone is covered by Task 1.
  - Unified network and failure model is covered by Task 2.
  - Unified routing shell is covered by Task 3.
  - New app shell plus push-open routing integration is covered by Task 4.
- Placeholder scan:
  - No placeholder markers remain.
  - Every code-changing step includes concrete code or an exact command.
- Type consistency:
  - `AppStartupRunner`, `AppRouteLocation`, `AppRouteResolver`, `WkHttpClient`, `AppPushRouteBridge`, and `WuKongApp` use one stable naming scheme throughout the plan.

## Expected Outcome

After this plan is implemented:

- the app boots through an ordered startup pipeline
- one canonical HTTP client backs both current API entry points
- auth redirects and main navigation flow through `GoRouter`
- push-opened chat navigation follows the routed mainline instead of ad hoc `Navigator.push`
- future parity work can attach to the new app shell instead of extending duplicate legacy entry points
