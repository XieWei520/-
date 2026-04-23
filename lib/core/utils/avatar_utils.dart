import '../config/api_config.dart';

String? resolveAvatarUrl(String? rawAvatar) {
  final avatar = rawAvatar?.trim() ?? '';
  if (avatar.isEmpty) {
    return null;
  }
  return ApiConfig.resolveMediaUrl(avatar);
}

String? buildUserAvatarUrl(String? uid, {String? cacheKey}) {
  final normalizedUid = uid?.trim() ?? '';
  if (normalizedUid.isEmpty) {
    return null;
  }

  final normalizedCacheKey = cacheKey?.trim() ?? '';
  final path = normalizedCacheKey.isEmpty
      ? 'users/$normalizedUid/avatar'
      : 'users/$normalizedUid/avatar?v=${Uri.encodeQueryComponent(normalizedCacheKey)}';
  return ApiConfig.resolveMediaUrl(path);
}

String? resolveUserAvatarUrl(
  String? rawAvatar,
  String? uid, {
  String? cacheKey,
}) {
  return resolveAvatarUrl(rawAvatar) ??
      buildUserAvatarUrl(uid, cacheKey: cacheKey);
}
