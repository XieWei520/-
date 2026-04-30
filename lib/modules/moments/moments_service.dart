import '../../core/config/api_config.dart';
import '../../core/platform/local_image_picker.dart';
import '../../core/utils/platform_utils.dart';
import '../../service/api/collection_api.dart';

class MomentMention {
  const MomentMention({required this.uid, required this.name});

  final String uid;
  final String name;
}

class MomentPublishRequest {
  const MomentPublishRequest({
    this.content,
    this.images = const <String>[],
    this.mentions = const <String>[],
    this.location,
  });

  final String? content;
  final List<String> images;
  final List<String> mentions;
  final String? location;
}

abstract interface class MomentsComposeService {
  Future<Moment> publish(MomentPublishRequest request);
}

class Moment {
  const Moment({
    required this.id,
    required this.uid,
    required this.username,
    this.avatar,
    this.content,
    this.location,
    this.mentions = const <String>[],
    this.images = const <String>[],
    this.likeCount = 0,
    this.commentCount = 0,
    this.isLiked = false,
    required this.createdAt,
    this.comments = const <MomentComment>[],
    this.likes = const <MomentLike>[],
  });

  final String id;
  final String uid;
  final String username;
  final String? avatar;
  final String? content;
  final String? location;
  final List<String> mentions;
  final List<String> images;
  final int likeCount;
  final int commentCount;
  final bool isLiked;
  final int createdAt;
  final List<MomentComment> comments;
  final List<MomentLike> likes;

  factory Moment.fromPayload(Map<String, dynamic> json) {
    final author = _asMap(json['author']);
    return Moment(
      id: _stringValue(json['id']),
      uid: _stringValue(author['uid'] ?? json['uid']),
      username: _stringValue(
        author['name'] ?? json['username'] ?? json['author_name'],
      ),
      avatar: _resolvedMediaUrl(author['avatar'] ?? json['avatar']),
      content: _nullableString(json['content']),
      location: _nullableString(json['location']),
      mentions: _resolveMentions(json['mentions']),
      images: _resolveImages(json['images']),
      likeCount: _intValue(json['like_count']),
      commentCount: _intValue(json['comment_count']),
      isLiked: _boolValue(json['is_liked']),
      createdAt: _timestampSeconds(json['created_at']),
      comments: _asList(json['comments'])
          .map((item) => MomentComment.fromPayload(_asMap(item)))
          .toList(growable: false),
      likes: _asList(json['likes'])
          .map((item) => MomentLike.fromPayload(_asMap(item)))
          .toList(growable: false),
    );
  }

  Moment copyWith({List<MomentComment>? comments}) {
    return Moment(
      id: id,
      uid: uid,
      username: username,
      avatar: avatar,
      content: content,
      location: location,
      mentions: mentions,
      images: images,
      likeCount: likeCount,
      commentCount: commentCount,
      isLiked: isLiked,
      createdAt: createdAt,
      comments: comments ?? this.comments,
      likes: likes,
    );
  }
}

class MomentComment {
  const MomentComment({
    required this.id,
    required this.uid,
    required this.username,
    this.avatar,
    required this.content,
    this.replyUid,
    this.replyUsername,
    required this.createdAt,
  });

  final String id;
  final String uid;
  final String username;
  final String? avatar;
  final String content;
  final String? replyUid;
  final String? replyUsername;
  final int createdAt;

  factory MomentComment.fromPayload(Map<String, dynamic> json) {
    return MomentComment(
      id: _stringValue(json['id']),
      uid: _stringValue(json['uid']),
      username: _stringValue(
        json['author_name'] ?? json['username'] ?? json['user_name'],
      ),
      avatar: _resolvedMediaUrl(json['avatar']),
      content: _stringValue(json['content']),
      replyUid: _nullableString(json['reply_to_uid'] ?? json['reply_uid']),
      replyUsername: _nullableString(
        json['reply_to_name'] ?? json['reply_username'],
      ),
      createdAt: _timestampSeconds(json['created_at']),
    );
  }
}

class MomentLike {
  const MomentLike({required this.uid, required this.username, this.avatar});

  final String uid;
  final String username;
  final String? avatar;

  factory MomentLike.fromPayload(Map<String, dynamic> json) {
    return MomentLike(
      uid: _stringValue(json['uid']),
      username: _stringValue(
        json['name'] ?? json['username'] ?? json['user_name'],
      ),
      avatar: _resolvedMediaUrl(json['avatar']),
    );
  }
}

class MomentsService implements MomentsComposeService {
  MomentsService._({MomentsApi? momentsApi})
    : _momentsApi = momentsApi ?? MomentsApi.instance;

  static final MomentsService _instance = MomentsService._();
  static MomentsService get instance => _instance;

  static const int _detailLookupPageSize = 50;
  final MomentsApi _momentsApi;

  Future<List<Moment>> getMoments({int page = 1, int pageSize = 20}) async {
    final payloads = await _momentsApi.getList(page: page, pageSize: pageSize);
    return payloads
        .map((item) => Moment.fromPayload(item))
        .toList(growable: false);
  }

  Future<Moment> getMomentDetail(String momentId) async {
    final moment = await _findMomentById(momentId);
    if (moment == null) {
      throw StateError('Moment not found: $momentId');
    }

    final comments = await _momentsApi.getComments(
      momentId,
      pageSize: moment.commentCount > 20 ? moment.commentCount : 20,
    );
    final mappedComments = comments
        .map((item) => MomentComment.fromPayload(item))
        .toList(growable: false);
    return moment.copyWith(comments: mappedComments);
  }

  Future<Moment> publishMoment({
    String? content,
    List<String>? images,
    List<String> mentions = const <String>[],
    String? location,
  }) async {
    final momentId = await _momentsApi.publish(
      content: content,
      images: images,
      mentions: mentions,
      location: location,
    );

    try {
      return await getMomentDetail(momentId);
    } catch (_) {
      return Moment(
        id: momentId,
        uid: '',
        username: '',
        content: content,
        location: location,
        mentions: mentions,
        createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      );
    }
  }

  @override
  Future<Moment> publish(MomentPublishRequest request) {
    return publishMoment(
      content: request.content,
      images: request.images,
      mentions: request.mentions,
      location: request.location,
    );
  }

  Future<void> deleteMoment(String momentId) {
    return _momentsApi.delete(momentId);
  }

  Future<void> likeMoment(String momentId) {
    return _momentsApi.like(momentId);
  }

  Future<void> unlikeMoment(String momentId) {
    return _momentsApi.unlike(momentId);
  }

  Future<MomentComment> commentMoment({
    required String momentId,
    required String content,
    String? replyUid,
    String? replyUsername,
  }) async {
    final commentId = await _momentsApi.comment(
      momentId: momentId,
      content: content,
      replyTo: replyUid,
    );
    return MomentComment(
      id: commentId,
      uid: '',
      username: '',
      content: content,
      replyUid: replyUid,
      replyUsername: replyUsername,
      createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
    );
  }

  Future<void> deleteComment(String momentId, String commentId) {
    return _momentsApi.deleteComment(momentId: momentId, commentId: commentId);
  }

  Future<List<Moment>> getMomentsWithMedia() async {
    final moments = await getMoments();
    return moments
        .where((moment) => moment.images.isNotEmpty)
        .toList(growable: false);
  }

  Future<List<String>> pickImages({int maxImages = 9}) async {
    return pickMultipleLocalImagePaths(
      limit: maxImages,
      maxWidth: 1920,
      maxHeight: 1920,
      imageQuality: 85,
    );
  }

  Future<String?> takePhoto() async {
    if (PlatformUtils.isDesktop) {
      throw UnsupportedError(
        '${PlatformUtils.platformName} 桌面端暂不支持直接拍照，请从相册选择图片',
      );
    }

    return pickSingleLocalImagePath(
      source: LocalImagePickSource.camera,
      maxWidth: 1920,
      maxHeight: 1920,
      imageQuality: 85,
      useDesktopFilePickerForGallery: false,
    );
  }

  Future<Moment?> _findMomentById(String momentId) async {
    final seenMomentIds = <String>{};

    for (var page = 1; ; page++) {
      final moments = await getMoments(
        page: page,
        pageSize: _detailLookupPageSize,
      );
      if (moments.isEmpty) {
        break;
      }

      var discoveredNewMoment = false;
      for (final moment in moments) {
        if (moment.id == momentId) {
          return moment;
        }
        if (seenMomentIds.add(moment.id)) {
          discoveredNewMoment = true;
        }
      }
      if (!discoveredNewMoment || moments.length < _detailLookupPageSize) {
        break;
      }
    }
    return null;
  }
}

Map<String, dynamic> _asMap(dynamic value) {
  if (value is Map<String, dynamic>) {
    return value;
  }
  if (value is Map) {
    return Map<String, dynamic>.from(value);
  }
  return <String, dynamic>{};
}

List<dynamic> _asList(dynamic value) {
  if (value is List) {
    return value;
  }
  return const <dynamic>[];
}

String _stringValue(dynamic value) {
  if (value == null) {
    return '';
  }
  return value.toString();
}

String? _nullableString(dynamic value) {
  final resolved = _stringValue(value).trim();
  return resolved.isEmpty ? null : resolved;
}

int _intValue(dynamic value) {
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  return int.tryParse(_stringValue(value)) ?? 0;
}

bool _boolValue(dynamic value) {
  if (value is bool) {
    return value;
  }
  final normalized = _stringValue(value).trim().toLowerCase();
  return normalized == 'true' || normalized == '1';
}

int _timestampSeconds(dynamic value) {
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }

  final raw = _stringValue(value).trim();
  if (raw.isEmpty) {
    return 0;
  }

  final numeric = int.tryParse(raw);
  if (numeric != null) {
    return numeric;
  }

  final parsed = DateTime.tryParse(raw);
  if (parsed != null) {
    return parsed.millisecondsSinceEpoch ~/ 1000;
  }
  return 0;
}

String? _resolvedMediaUrl(dynamic value) {
  final raw = _nullableString(value);
  if (raw == null) {
    return null;
  }
  final resolved = ApiConfig.resolveMediaUrl(raw);
  return resolved.isEmpty ? null : resolved;
}

List<String> _resolveImages(dynamic value) {
  return _asList(value)
      .map((item) {
        if (item is Map) {
          return _resolvedMediaUrl(item['url']);
        }
        return _resolvedMediaUrl(item);
      })
      .whereType<String>()
      .where((item) => item.isNotEmpty)
      .toList(growable: false);
}

List<String> _resolveMentions(dynamic value) {
  return _asList(value)
      .map((item) => _nullableString(item))
      .whereType<String>()
      .where((item) => item.isNotEmpty)
      .toList(growable: false);
}
