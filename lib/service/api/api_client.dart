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
    return _client.post<T>(
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
    return _client.put<T>(
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
    return _client.delete<T>(
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
  }) {
    return _client.uploadFile<T>(
      path,
      filePath,
      name: name,
      data: data,
      onSendProgress: onSendProgress,
      cancelToken: cancelToken,
    );
  }

  void setToken(String token) => _client.setToken(token);

  void clearToken() => _client.clearToken();
}
