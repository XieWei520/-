import 'dart:io';

import 'package:dio/dio.dart';
import 'package:dio/io.dart';

import '../../core/config/api_config.dart';

HttpClient createNativeProxyAwareHttpClient({
  String? baseUrl,
  Duration idleTimeout = const Duration(seconds: 3),
}) {
  final client = HttpClient()..idleTimeout = idleTimeout;
  client.findProxy = createNativeProxyResolver(baseUrl: baseUrl);
  return client;
}

String Function(Uri) createNativeProxyResolver({String? baseUrl}) {
  final apiBaseUri = Uri.parse(baseUrl ?? ApiConfig.baseUrl);
  return (uri) {
    return resolveNativeProxyForUri(apiBaseUri: apiBaseUri, requestUri: uri);
  };
}

bool shouldBypassNativeProxyForUri({
  required Uri apiBaseUri,
  required Uri requestUri,
}) {
  return requestUri.host == apiBaseUri.host &&
      _resolvePort(requestUri) == _resolvePort(apiBaseUri);
}

String resolveNativeProxyForUri({
  required Uri apiBaseUri,
  required Uri requestUri,
}) {
  if (shouldBypassNativeProxyForUri(
    apiBaseUri: apiBaseUri,
    requestUri: requestUri,
  )) {
    return 'DIRECT';
  }
  return HttpClient.findProxyFromEnvironment(requestUri);
}

void configureNativeProxyBypass(Dio dio, {String? baseUrl}) {
  final adapter = dio.httpClientAdapter;
  if (adapter is! IOHttpClientAdapter) {
    return;
  }

  adapter.createHttpClient = () {
    return createNativeProxyAwareHttpClient(baseUrl: baseUrl);
  };
}

int _resolvePort(Uri uri) {
  if (uri.hasPort && uri.port != 0) {
    return uri.port;
  }

  switch (uri.scheme) {
    case 'https':
    case 'wss':
      return 443;
    case 'http':
    case 'ws':
    default:
      return 80;
  }
}
