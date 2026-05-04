import 'package:dio/dio.dart';

import 'api_client.dart';

class RobotSyncTarget {
  const RobotSyncTarget({this.robotId, this.username, this.version = 0});

  final String? robotId;
  final String? username;
  final int version;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      if (robotId != null && robotId!.trim().isNotEmpty) 'robot_id': robotId,
      if (username != null && username!.trim().isNotEmpty) 'username': username,
      'version': version,
    };
  }
}

class RobotStreamStartRequest {
  const RobotStreamStartRequest({
    this.header,
    required this.clientMsgNo,
    required this.fromUid,
    required this.channelId,
    required this.channelType,
    required this.payload,
  });

  final Map<String, dynamic>? header;
  final String clientMsgNo;
  final String fromUid;
  final String channelId;
  final int channelType;
  final Object payload;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      if (header != null && header!.isNotEmpty) 'header': header,
      'client_msg_no': clientMsgNo,
      'from_uid': fromUid,
      'channel_id': channelId,
      'channel_type': channelType,
      'payload': payload,
    };
  }
}

class RobotStreamStartResponse {
  const RobotStreamStartResponse({required this.streamNo});

  final String streamNo;

  factory RobotStreamStartResponse.fromJson(Map<String, dynamic> json) {
    return RobotStreamStartResponse(
      streamNo: (json['stream_no'] ?? '').toString().trim(),
    );
  }
}

class RobotStreamEndRequest {
  const RobotStreamEndRequest({
    required this.streamNo,
    required this.channelId,
    required this.channelType,
  });

  final String streamNo;
  final String channelId;
  final int channelType;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'stream_no': streamNo,
      'channel_id': channelId,
      'channel_type': channelType,
    };
  }
}

/// Robot API client for bot synchronization and inline queries.
///
/// Handles all robot-related operations:
/// - Sync robot list from server
/// - Perform inline queries (@bot search)
/// - GIF sticker search through robots
class RobotApi {
  static final RobotApi _instance = RobotApi._();
  static RobotApi get instance => _instance;

  final ApiClient _client = ApiClient.instance;

  RobotApi._();

  /// Resolves response body to a `Map<String, dynamic>`.
  Map<String, dynamic> _resolveBody(dynamic raw) {
    if (raw is Map<String, dynamic>) {
      return raw;
    }
    if (raw is Map) {
      return Map<String, dynamic>.from(raw);
    }
    return {};
  }

  /// Resolves response data to a `List<dynamic>`.
  List<dynamic> _resolveList(dynamic raw) {
    if (raw is List) {
      return raw;
    }
    if (raw is Map && raw['data'] is List) {
      return List<dynamic>.from(raw['data'] as List);
    }
    if (raw is Map && raw['robots'] is List) {
      return List<dynamic>.from(raw['robots'] as List);
    }
    return const <dynamic>[];
  }

  /// Validates API response and throws exception on error.
  void _ensureSuccess(Response<dynamic> response, {required String fallback}) {
    final body = _resolveBody(response.data);
    final statusCode = response.statusCode ?? 200;
    final code = body['code'];
    final status = body['status'];
    final message = (body['msg'] ?? body['message'] ?? fallback).toString();

    final hasErrorCode =
        (code is num && code.toInt() != 0) ||
        (status is num && status.toInt() >= 400);

    if (statusCode >= 400 || hasErrorCode) {
      throw Exception(message);
    }
  }

  /// Synchronizes robot list with the server.
  ///
  /// [targets] - Optional robot descriptors with id/username and version.
  ///
  /// Returns a list of robot information maps containing:
  /// - robot_id: Unique robot identifier
  /// - name: Display name
  /// - avatar: Avatar URL
  /// - description: Robot description
  /// - commands: Available commands
  Future<List<Map<String, dynamic>>> syncRobots([
    List<RobotSyncTarget>? targets,
  ]) async {
    final payload = (targets ?? const <RobotSyncTarget>[])
        .map((target) => target.toJson())
        .toList(growable: false);
    final response = await _client.post('/v1/robot/sync', data: payload);
    _ensureSuccess(response, fallback: 'Failed to sync robots');

    final list = _resolveList(response.data);
    return list
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  /// Performs an inline query for a specific robot.
  ///
  /// [robotId] - The ID of the robot to query.
  /// [query] - The search query string.
  /// [channelId] - Optional channel ID for context-aware results.
  /// [offset] - Pagination offset for large result sets.
  ///
  /// Returns query results containing articles, photos, or other media.
  Future<Map<String, dynamic>> inlineQuery({
    required String robotId,
    required String query,
    String? username,
    String? channelId,
    int? channelType,
    int offset = 0,
  }) async {
    final data = <String, dynamic>{
      'robot_id': robotId,
      'query': query,
      'offset': offset,
      if (username != null && username.trim().isNotEmpty)
        'username': username.trim(),
    };

    if (channelId != null) {
      data['channel_id'] = channelId;
    }
    if (channelType != null) {
      data['channel_type'] = channelType;
    }

    final response = await _client.post('/v1/robot/inline_query', data: data);
    _ensureSuccess(response, fallback: 'Robot inline query failed');

    return _resolveBody(response.data);
  }

  /// Searches for GIF stickers using GIPHY or similar service.
  ///
  /// [query] - Search term for GIFs.
  /// [limit] - Maximum number of results (default 20).
  /// [offset] - Pagination offset.
  ///
  /// Returns a list of GIF objects with URLs and metadata.
  Future<List<Map<String, dynamic>>> searchGifs({
    required String query,
    int limit = 20,
    int offset = 0,
    String? username,
    String? channelId,
    int? channelType,
  }) async {
    // Use the GIF robot (typically 'giphy' or similar)
    final result = await inlineQuery(
      robotId: 'giphy',
      username: username,
      query: query,
      channelId: channelId,
      channelType: channelType,
      offset: offset,
    );

    final results = result['results'];
    if (results is List) {
      return results
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList();
    }

    return const <Map<String, dynamic>>[];
  }

  /// Gets detailed information about a specific robot.
  ///
  /// [robotId] - The ID of the robot to fetch details for.
  ///
  /// Returns robot detail including commands, usage instructions, and settings.
  Future<Map<String, dynamic>> getRobotDetail(String robotId) async {
    final response = await _client.get('/v1/robot/$robotId');
    _ensureSuccess(response, fallback: 'Failed to get robot detail');

    return _resolveBody(response.data);
  }

  /// Adds a robot to user's collection.
  ///
  /// [robotId] - The ID of the robot to add.
  Future<void> addRobot(String robotId) async {
    final response = await _client.post(
      '/v1/robot/add',
      data: {'robot_id': robotId},
    );
    _ensureSuccess(response, fallback: 'Failed to add robot');
  }

  /// Removes a robot from user's collection.
  ///
  /// [robotId] - The ID of the robot to remove.
  Future<void> removeRobot(String robotId) async {
    final response = await _client.post(
      '/v1/robot/remove',
      data: {'robot_id': robotId},
    );
    _ensureSuccess(response, fallback: 'Failed to remove robot');
  }

  /// Gets user's collected/favorited robots.
  ///
  /// Returns list of robots that user has added.
  Future<List<Map<String, dynamic>>> getMyRobots() async {
    final response = await _client.get('/v1/robot/my');
    _ensureSuccess(response, fallback: 'Failed to get my robots');

    final list = _resolveList(response.data);
    return list
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  Future<RobotStreamStartResponse> startStream({
    required String robotId,
    required String appKey,
    required RobotStreamStartRequest request,
  }) async {
    final response = await _client.post(
      '/v1/robots/${robotId.trim()}/${appKey.trim()}/stream/start',
      data: request.toJson(),
    );
    _ensureSuccess(response, fallback: 'Robot stream start failed');

    return RobotStreamStartResponse.fromJson(_resolveBody(response.data));
  }

  Future<void> endStream({
    required String robotId,
    required String appKey,
    required RobotStreamEndRequest request,
  }) async {
    final response = await _client.post(
      '/v1/robots/${robotId.trim()}/${appKey.trim()}/stream/end',
      data: request.toJson(),
    );
    _ensureSuccess(response, fallback: 'Robot stream end failed');
  }
}
