import 'dart:convert';

import 'package:crypto/crypto.dart' as crypto_lib;
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../core/config/api_config.dart';
import '../../core/utils/storage_utils.dart';
import '../errors/app_failure.dart';
import '../logging/app_logger.dart';
import 'wk_http_client_proxy_stub.dart'
    if (dart.library.io) 'wk_http_client_proxy_io.dart';

typedef WkNow = DateTime Function();
typedef WkNonceFactory = String Function(int length);

class WkHttpClient {
  WkHttpClient({Dio? dio, WkNow? now, WkNonceFactory? nonceFactory})
    : _dio = dio,
      _now = now ?? DateTime.now,
      _nonceFactory = nonceFactory ?? _defaultNonceFactory;

  static final WkHttpClient instance = WkHttpClient();
  static const AppLogger _authLogger = AppLogger('http/auth');

  Dio? _dio;
  final WkNow _now;
  final WkNonceFactory _nonceFactory;

  Dio get dio => _dio ??= _createDio();

  void warmUp() {
    syncBaseUrlWithConfig();
  }

  void syncBaseUrlWithConfig() {
    final client = dio;
    final resolvedBaseUrl = ApiConfig.baseUrl;
    if (client.options.baseUrl == resolvedBaseUrl) {
      return;
    }
    client.options.baseUrl = resolvedBaseUrl;
    configureNativeProxyBypass(client, baseUrl: resolvedBaseUrl);
  }

  @visibleForTesting
  Map<String, String> buildSignedHeaders({
    Object? data,
    String? token,
    String? deviceId,
    String? deviceSessionId,
    bool includeJsonContentType = true,
  }) {
    final timestamp = _now().millisecondsSinceEpoch.toString();
    final nonce = _nonceFactory(16);
    final encoded = _encodeDataForSign(data);
    final signSource = '$encoded$nonce$timestamp${ApiConfig.appKey}';
    final sign = crypto_lib.md5.convert(utf8.encode(signSource)).toString();

    return <String, String>{
      if (includeJsonContentType) 'Content-Type': 'application/json',
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
    configureNativeProxyBypass(client, baseUrl: ApiConfig.baseUrl);

    client.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          final hasMultipartData =
              options.data is FormData ||
              (options.contentType ?? '').contains('multipart/form-data');
          options.headers.addAll(
            buildSignedHeaders(
              data: options.data,
              token: StorageUtils.getToken(),
              deviceId: StorageUtils.getDeviceId(),
              deviceSessionId: StorageUtils.getDeviceSessionId(),
              includeJsonContentType: !hasMultipartData,
            ),
          );
          if (_shouldLogAuthRequest(options)) {
            _authLogger.info('request ${options.method} ${options.uri}');
          }
          handler.next(options);
        },
        onResponse: (response, handler) async {
          final statusCode = response.statusCode ?? 0;
          if (_shouldLogAuthRequest(response.requestOptions)) {
            _authLogger.info(
              'response ${response.requestOptions.method} ${response.requestOptions.uri} status=$statusCode',
            );
          }
          if (statusCode >= 400) {
            if (statusCode == 401) {
              await StorageUtils.logout();
              clearToken();
            }
            handler.reject(
              _mapToFailure(
                DioException(
                  requestOptions: response.requestOptions,
                  response: response,
                  type: DioExceptionType.badResponse,
                  message: 'Request failed with status code: $statusCode',
                ),
              ),
            );
            return;
          }
          handler.next(response);
        },
        onError: (error, handler) {
          if (_shouldLogAuthRequest(error.requestOptions)) {
            _authLogger.error(
              'request failed ${error.requestOptions.method} ${error.requestOptions.uri} status=${error.response?.statusCode ?? 'n/a'}',
              error.error ?? error,
              error.stackTrace,
            );
          }
          handler.next(_mapToFailure(error));
        },
      ),
    );

    return client;
  }

  Future<Response<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
  }) {
    return dio.get<T>(
      path,
      queryParameters: queryParameters,
      options: options,
      cancelToken: cancelToken,
    );
  }

  Future<Response<T>> post<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
  }) {
    return dio.post<T>(
      path,
      data: data,
      queryParameters: queryParameters,
      options: options,
      cancelToken: cancelToken,
    );
  }

  Future<Response<T>> put<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
  }) {
    return dio.put<T>(
      path,
      data: data,
      queryParameters: queryParameters,
      options: options,
      cancelToken: cancelToken,
    );
  }

  Future<Response<T>> delete<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
  }) {
    return dio.delete<T>(
      path,
      data: data,
      queryParameters: queryParameters,
      options: options,
      cancelToken: cancelToken,
    );
  }

  Future<Response<T>> uploadFile<T>(
    String path,
    String filePath, {
    String name = 'file',
    Map<String, dynamic>? data,
    void Function(int, int)? onSendProgress,
    CancelToken? cancelToken,
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
      cancelToken: cancelToken,
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

  DioException _mapToFailure(DioException error) {
    if (error.error is AppFailure) {
      return error;
    }

    return DioException(
      requestOptions: error.requestOptions,
      response: error.response,
      error: AppFailure.fromDio(error),
      type: error.type,
      message: error.message,
    );
  }

  static String _encodeDataForSign(Object? data) {
    if (data == null || data is FormData) {
      return '';
    }
    if (data is String) {
      return data;
    }
    if (data is Map || data is List || data is num || data is bool) {
      return jsonEncode(data);
    }
    try {
      return jsonEncode(data);
    } catch (_) {
      return '';
    }
  }

  static bool _shouldLogAuthRequest(RequestOptions options) {
    final path = options.uri.path.toLowerCase();
    return path.startsWith('/v1/user/');
  }
}
