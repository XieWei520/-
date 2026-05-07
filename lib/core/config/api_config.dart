import 'dart:async';

import 'app_config.dart';
import '../constants/app_constants.dart';
import '../utils/storage_utils.dart';

/// API 配置
class ApiConfig {
  ApiConfig._();

  // Application credentials
  // These can be overridden via environment variables:
  // -DWK_APP_ID=wukongchat -DWK_APP_KEY=your_key_here
  static const String appId = String.fromEnvironment(
    'WK_APP_ID',
    defaultValue: 'wukongchat',
  );
  static const String appKey = String.fromEnvironment(
    'WK_APP_KEY',
    defaultValue: '25b002c6be2d539f264c',
  );

  static const String devBaseUrl = String.fromEnvironment(
    'WK_DEV_BASE_URL',
    defaultValue: 'https://infoequity.cn',
  );
  static const String prodBaseUrl = String.fromEnvironment(
    'WK_PROD_BASE_URL',
    defaultValue: 'https://infoequity.cn',
  );

  static String get baseUrl {
    final rawRuntimeOverride = StorageUtils.getString(
      AppConstants.keyAuthLoginApiBaseUrl,
    );
    final runtimeOverride = normalizeRuntimeBaseUrlOverride(rawRuntimeOverride);
    if ((rawRuntimeOverride ?? '') != runtimeOverride) {
      _saveRuntimeBaseUrlOverride(runtimeOverride);
    }
    if (runtimeOverride.isNotEmpty) {
      return runtimeOverride;
    }
    return AppConfig.isDevelopment ? devBaseUrl : prodBaseUrl;
  }

  static const String devWsAddr = String.fromEnvironment(
    'WK_DEV_WS_ADDR',
    defaultValue: 'wss://infoequity.cn/ws',
  );
  static const String prodWsAddr = String.fromEnvironment(
    'WK_PROD_WS_ADDR',
    defaultValue: 'wss://infoequity.cn/ws',
  );

  static const String windowsDesktopTunnelBaseUrl = 'http://127.0.0.1:15001';
  static const String windowsDesktopTunnelWsAddr = '127.0.0.1:15100';
  static const String windowsDesktopTunnelMinioBaseUrl =
      'http://127.0.0.1:15002';

  static String get wsAddr {
    final resolvedBaseUrl = baseUrl;
    if (isWindowsDesktopTunnelBaseUrl(resolvedBaseUrl)) {
      return windowsDesktopTunnelWsAddr;
    }
    return AppConfig.isDevelopment ? devWsAddr : prodWsAddr;
  }

  static const String v1 = '/v1';

  static const String userLogin = '$v1/user/login';
  static const String userUsernameLogin = '$v1/user/usernamelogin';
  static const String userRegister = '$v1/user/register';
  static const String userUsernameRegister = '$v1/user/usernameregister';
  static const String userInfo = '$v1/users';
  static const String userCurrent = '$v1/user';
  static const String userMailList = '$v1/user/maillist';
  static const String userBlacklists = '$v1/user/blacklists';
  static const String userBlacklist = '$v1/user/blacklist';
  static const String userCustomerServices = '$v1/user/customerservices';
  static const String userDestroySms = '$v1/user/sms/destroy';
  static const String userChatPwd = '$v1/user/chatpwd';
  static const String apps = '$v1/apps';
  static const String openApiAuthCode = '$v1/openapi/authcode';

  static String userDestroy(String code) => '$v1/user/destroy/$code';

  static const String friends = '$v1/friend/sync';
  static const String friendRemark = '$v1/friend/remark';
  static const String friendRequest = '$v1/friend/apply';
  static const String friendRequests = '$v1/friend/apply';
  static const String friendResponse = '$v1/friend/sure';
  static const String friendRefuse = '$v1/friend/refuse';

  static const String groupCreate = '$v1/group/create';
  static const String groupMy = '$v1/group/my';
  static const String groups = '$v1/groups';
  static const String groupMembers = '/members';
  static const String groupSetting = '/setting';

  static const String messageSync = '$v1/message/sync';
  static const String messageRevoke = '$v1/message/revoke';
  static const String messageDelete = '$v1/message';
  static const String messageSearch = '$v1/message/search';
  static const String messagePinned = '$v1/message/pinned';
  static const String messagePinnedSync = '$v1/message/pinned/sync';
  static const String messagePinnedClear = '$v1/message/pinned/clear';
  static const String searchGlobal = '$v1/search/global';
  static const String conversations = '$v1/conversations';
  static const String conversationExtraSync = '$v1/conversation/extra/sync';

  static const String fileUpload = '$v1/file/upload';
  static const String fileMultipartInit = '$v1/file/multipart/init';
  static const String fileMultipartPart = '$v1/file/multipart/part';
  static const String fileMultipartParts = '$v1/file/multipart/parts';
  static const String fileMultipartComplete = '$v1/file/multipart/complete';
  static const String reportCategories = '$v1/report/categories';
  static const String reports = '$v1/reports';

  static const String smsRegisterCode = '$v1/user/sms/registercode';
  static const String smsForgetPwd = '$v1/user/sms/forgetpwd';

  static const String favorites = '$v1/extra/favorites';
  static const String favorite = '$v1/extra/favorite';

  static const String tags = '$v1/extra/tags';
  static const String tag = '$v1/extra/tag';

  static const String moments = '$v1/extra/moments';
  static const String moment = '$v1/extra/moment';

  static const String userSetting = '$v1/extra/user/setting';
  static const String userDeviceLock = '$v1/extra/user/device/lock';
  static const String userDevices = '$v1/extra/user/devices';

  static String resolveUrl(String? urlOrPath) {
    final value = urlOrPath?.trim() ?? '';
    if (value.isEmpty) {
      return '';
    }

    final lowerValue = value.toLowerCase();
    if (lowerValue.startsWith('http://') || lowerValue.startsWith('https://')) {
      return _normalizeSelfHostedAbsoluteUrl(value);
    }

    var normalized = value.replaceAll('\\', '/');
    normalized = normalized.replaceFirst(RegExp(r'^/+'), '');
    if (isWindowsDesktopTunnelBaseUrl(baseUrl)) {
      final normalizedUri = Uri.tryParse(normalized);
      final minioTunnelUrl = _resolveWindowsDesktopTunnelMinioUrl(
        normalizedUri?.path ?? normalized,
        query: normalizedUri != null && normalizedUri.hasQuery
            ? normalizedUri.query
            : null,
        fragment: normalizedUri != null && normalizedUri.hasFragment
            ? normalizedUri.fragment
            : null,
      );
      if (minioTunnelUrl.isNotEmpty) {
        return minioTunnelUrl;
      }
    }
    if (normalized.startsWith('minio/')) {
      return '$baseUrl/$normalized';
    }
    if (!normalized.startsWith('v1/')) {
      normalized = 'v1/$normalized';
    }
    return '$baseUrl/$normalized';
  }

  static String resolveMediaUrl(String? urlOrPath) {
    final value = urlOrPath?.trim() ?? '';
    if (value.isEmpty) {
      return '';
    }
    final lowerValue = value.toLowerCase();
    if (lowerValue.startsWith('http://') || lowerValue.startsWith('https://')) {
      return _normalizeSelfHostedAbsoluteUrl(value);
    }

    final normalized = value
        .replaceAll('\\', '/')
        .replaceFirst(RegExp(r'^/+'), '');
    if (_isRawObjectStorageMediaPath(normalized)) {
      if (isWindowsDesktopTunnelBaseUrl(baseUrl)) {
        return Uri.parse(
          windowsDesktopTunnelMinioBaseUrl,
        ).replace(path: '/$normalized').toString();
      }
      return '$baseUrl/minio/$normalized';
    }
    return resolveUrl(value);
  }

  static String normalizeUploadUrl(String? urlOrPath) {
    final resolved = resolveUrl(urlOrPath);
    if (resolved.isEmpty) {
      return '';
    }

    final targetUri = Uri.tryParse(resolved);
    final baseUri = Uri.tryParse(baseUrl);
    if (targetUri == null || baseUri == null) {
      return resolved;
    }

    final normalizedPath = targetUri.path.replaceFirst(RegExp(r'/+$'), '');
    if (normalizedPath != fileUpload) {
      return resolved;
    }

    if (_sameAuthority(targetUri, baseUri)) {
      return resolved;
    }

    return baseUri
        .replace(
          path: fileUpload,
          query: targetUri.hasQuery ? targetUri.query : null,
        )
        .toString();
  }

  static String normalizeRuntimeBaseUrlOverride(String? rawValue) {
    final normalized = _normalizeRuntimeBaseUrl(rawValue);
    if (!_isAllowedRuntimeBaseUrlOverride(normalized)) {
      return '';
    }
    return normalized;
  }

  static String _normalizeRuntimeBaseUrl(String? rawValue) {
    final value = rawValue?.trim() ?? '';
    if (value.isEmpty) {
      return '';
    }
    return value.replaceFirst(RegExp(r'/+$'), '');
  }

  static bool _isAllowedRuntimeBaseUrlOverride(String value) {
    if (value.isEmpty) {
      return true;
    }

    final uri = Uri.tryParse(value) ?? Uri.tryParse('//$value');
    final host = uri?.host.toLowerCase() ?? '';
    if (host.isEmpty) {
      return false;
    }

    return host == Uri.parse(prodBaseUrl).host ||
        host == Uri.parse(devBaseUrl).host ||
        host == 'localhost' ||
        host == '127.0.0.1' ||
        host == '::1' ||
        _isPrivateIPv4Host(host);
  }

  static bool _isPrivateIPv4Host(String host) {
    final parts = host.split('.');
    if (parts.length != 4) {
      return false;
    }
    final octets = <int>[];
    for (final part in parts) {
      final number = int.tryParse(part);
      if (number == null || number < 0 || number > 255) {
        return false;
      }
      octets.add(number);
    }

    return octets[0] == 10 ||
        (octets[0] == 172 && octets[1] >= 16 && octets[1] <= 31) ||
        (octets[0] == 192 && octets[1] == 168);
  }

  static void _saveRuntimeBaseUrlOverride(String value) {
    if (!StorageUtils.isInitialized) {
      return;
    }
    unawaited(
      StorageUtils.setString(AppConstants.keyAuthLoginApiBaseUrl, value),
    );
  }

  static bool isWindowsDesktopTunnelBaseUrl(String value) {
    return _normalizeRuntimeBaseUrl(value) == windowsDesktopTunnelBaseUrl;
  }

  static String _normalizeSelfHostedAbsoluteUrl(String value) {
    final targetUri = Uri.tryParse(value);
    final baseUri = Uri.tryParse(baseUrl);
    if (targetUri == null || baseUri == null) {
      return value;
    }
    if (isWindowsDesktopTunnelBaseUrl(baseUrl)) {
      final minioTunnelUrl = _resolveWindowsDesktopTunnelMinioUrl(
        targetUri.path.replaceFirst(RegExp(r'^/+'), ''),
        query: targetUri.hasQuery ? targetUri.query : null,
        fragment: targetUri.hasFragment ? targetUri.fragment : null,
      );
      if (minioTunnelUrl.isNotEmpty) {
        return minioTunnelUrl;
      }
    }
    if (_sameAuthority(targetUri, baseUri) ||
        !_shouldRewriteSelfHostedAbsoluteUrl(targetUri)) {
      return value;
    }

    return baseUri
        .replace(
          path: targetUri.path,
          query: targetUri.hasQuery ? targetUri.query : null,
          fragment: targetUri.hasFragment ? targetUri.fragment : null,
        )
        .toString();
  }

  static bool _shouldRewriteSelfHostedAbsoluteUrl(Uri uri) {
    final normalizedPath = uri.path.replaceFirst(RegExp(r'/+$'), '');
    return normalizedPath == fileUpload ||
        normalizedPath.startsWith('/minio/') ||
        normalizedPath.startsWith('/v1/file/preview') ||
        normalizedPath.startsWith('/v1/file/download');
  }

  static String _resolveWindowsDesktopTunnelMinioUrl(
    String normalizedPath, {
    String? query,
    String? fragment,
  }) {
    final path = _windowsDesktopTunnelMinioPath(normalizedPath);
    if (path.isEmpty) {
      return '';
    }
    return Uri.parse(
      windowsDesktopTunnelMinioBaseUrl,
    ).replace(path: path, query: query, fragment: fragment).toString();
  }

  static String _windowsDesktopTunnelMinioPath(String normalizedPath) {
    final value = normalizedPath
        .replaceAll('\\', '/')
        .replaceFirst(RegExp(r'^/+'), '');
    for (final prefix in <String>[
      'minio/',
      'v1/file/preview/',
      'v1/file/download/',
    ]) {
      if (value.startsWith(prefix)) {
        return '/${value.substring(prefix.length)}';
      }
    }
    return '';
  }

  static bool _isRawObjectStorageMediaPath(String normalizedPath) {
    final value = normalizedPath.trim().toLowerCase();
    if (value.isEmpty ||
        value.startsWith('v1/') ||
        value.startsWith('minio/')) {
      return false;
    }
    for (final prefix in <String>[
      'chat/',
      'common/',
      'avatar/',
      'group/',
      'moment/',
      'report/',
      'download/',
      'sticker/',
      'chatbg/',
    ]) {
      if (value.startsWith(prefix)) {
        return true;
      }
    }
    return false;
  }

  static bool _sameAuthority(Uri left, Uri right) {
    return left.scheme == right.scheme &&
        left.host == right.host &&
        _effectivePort(left) == _effectivePort(right);
  }

  static int _effectivePort(Uri uri) {
    if (uri.hasPort) {
      return uri.port;
    }
    return switch (uri.scheme) {
      'https' => 443,
      _ => 80,
    };
  }
}
