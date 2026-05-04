import '../core/config/api_config.dart';
import '../service/api/api_client.dart';

class ScanServiceResult {
  final String forward;
  final String type;
  final Map<String, dynamic> data;
  final String rawContent;

  const ScanServiceResult({
    required this.forward,
    required this.type,
    required this.data,
    required this.rawContent,
  });

  factory ScanServiceResult.fromJson(
    Map<String, dynamic> json,
    String rawContent,
  ) {
    return ScanServiceResult(
      forward: (json['forward'] ?? '').toString(),
      type: (json['type'] ?? '').toString(),
      data: json['data'] is Map
          ? Map<String, dynamic>.from(json['data'] as Map)
          : <String, dynamic>{},
      rawContent: rawContent,
    );
  }

  factory ScanServiceResult.rawText(String content) {
    final trimmed = content.trim();
    final uri = Uri.tryParse(trimmed);
    final isLink =
        uri != null &&
        uri.hasScheme &&
        (uri.scheme == 'http' || uri.scheme == 'https');

    return ScanServiceResult(
      forward: isLink ? 'external' : 'text',
      type: isLink ? 'webview' : 'text',
      data: isLink ? {'url': trimmed} : <String, dynamic>{},
      rawContent: trimmed,
    );
  }

  String? get groupId => (data['group_no'] ?? data['groupId'])?.toString();
  String? get uid => data['uid']?.toString();
  String? get url => data['url']?.toString();
  String? get authCode => (data['auth_code'] ?? data['authcode'])?.toString();
  String? get pubKey => data['pub_key']?.toString();
  String? get vercode => data['vercode']?.toString();

  Uri? get _parsedWebviewUri {
    if (type != 'webview') {
      return null;
    }
    final candidate = (url ?? rawContent).trim();
    if (candidate.isEmpty) {
      return null;
    }
    return Uri.tryParse(candidate);
  }

  bool get isInternalJoinGroupUrl {
    final uri = _parsedWebviewUri;
    if (uri == null) {
      return false;
    }
    if (!_isInternalHost(uri)) {
      return false;
    }
    final segments = uri.pathSegments.where((segment) => segment.isNotEmpty);
    if (segments.isEmpty) {
      return false;
    }
    return segments.last.toLowerCase() == 'join_group.html';
  }

  String? get joinGroupNo {
    if (!isInternalJoinGroupUrl) {
      return null;
    }
    final fromQuery = _parsedWebviewUri?.queryParameters['group_no']?.trim();
    if (fromQuery != null && fromQuery.isNotEmpty) {
      return fromQuery;
    }
    return groupId?.trim().isNotEmpty == true ? groupId?.trim() : null;
  }

  String? get joinGroupAuthCode {
    if (!isInternalJoinGroupUrl) {
      return null;
    }
    final fromQuery = _parsedWebviewUri?.queryParameters['auth_code']?.trim();
    if (fromQuery != null && fromQuery.isNotEmpty) {
      return fromQuery;
    }
    final normalizedAuthCode = authCode?.trim();
    if (normalizedAuthCode == null || normalizedAuthCode.isEmpty) {
      return null;
    }
    return normalizedAuthCode;
  }

  bool _isInternalHost(Uri uri) {
    final baseUri = Uri.parse(ApiConfig.baseUrl);
    final isHttp = uri.scheme == 'http' || uri.scheme == 'https';
    return isHttp &&
        uri.host.toLowerCase() == baseUri.host.toLowerCase() &&
        uri.port == baseUri.port;
  }
}

class ScanService {
  static final ScanService _instance = ScanService._();
  static ScanService get instance => _instance;
  ScanService._();

  final ApiClient _client = ApiClient.instance;

  Future<ScanServiceResult> processScanResult(String content) async {
    final normalized = content.trim();
    if (normalized.isEmpty) {
      throw Exception('二维码内容不能为空');
    }

    final internalUrl = _resolveInternalScanUrl(normalized);
    if (internalUrl == null) {
      return ScanServiceResult.rawText(normalized);
    }

    final response = await _client.get(internalUrl.toString());
    final statusCode = response.statusCode ?? 200;
    final body = response.data is Map
        ? Map<String, dynamic>.from(response.data as Map)
        : <String, dynamic>{};
    final code = body['code'];
    final status = body['status'];
    final hasApiError =
        (code is num && code.toInt() != 0) ||
        (status is num && status.toInt() >= 400);
    if (statusCode >= 400 || hasApiError) {
      final message = (body['msg'] ?? body['message'] ?? '二维码解析失败').toString();
      throw Exception(message);
    }

    return ScanServiceResult.fromJson(body, normalized);
  }

  Uri? _resolveInternalScanUrl(String content) {
    final uri = Uri.tryParse(content);
    if (uri == null) {
      return null;
    }

    if (!uri.hasScheme) {
      final relativeUri = Uri.parse(content);
      if (relativeUri.pathSegments.length >= 3 &&
          relativeUri.pathSegments[0] == 'v1' &&
          relativeUri.pathSegments[1] == 'qrcode') {
        final baseUri = Uri.parse(ApiConfig.baseUrl);
        return baseUri.resolveUri(relativeUri);
      }
      return null;
    }

    if (!_isInternalHost(uri)) {
      return null;
    }

    if (uri.pathSegments.length >= 3 &&
        uri.pathSegments[0] == 'v1' &&
        uri.pathSegments[1] == 'qrcode') {
      return uri;
    }

    return null;
  }

  bool _isInternalHost(Uri uri) {
    final baseUri = Uri.parse(ApiConfig.baseUrl);
    final isHttp = uri.scheme == 'http' || uri.scheme == 'https';
    return isHttp &&
        uri.host.toLowerCase() == baseUri.host.toLowerCase() &&
        uri.port == baseUri.port;
  }
}
