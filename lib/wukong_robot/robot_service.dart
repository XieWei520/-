import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:wukongimfluttersdk/type/const.dart';
import 'package:wukongimfluttersdk/wkim.dart';

import '../service/api/robot_api.dart';
import 'models/robot.dart';

/// Service for managing robot interactions and queries.
///
/// Provides high-level API for:
/// - Robot discovery and synchronization
/// - Inline queries (@bot commands)
/// - GIF search
/// - Command execution
class RobotService {
  static final RobotService _instance = RobotService._();
  static RobotService get instance => _instance;

  final RobotApi _api = RobotApi.instance;

  // Cache for synced robots
  final Map<String, Robot> _robotCache = {};
  bool _isSynced = false;
  DateTime? _lastSyncTime;

  RobotService._();

  /// Synchronizes robot list from server.
  ///
  /// Call this periodically or on app startup to ensure
  /// robot list is up to date.
  Future<List<Robot>> syncRobots({
    List<RobotSyncTarget>? targets,
    bool forceRefresh = false,
  }) async {
    final normalizedTargets = _normalizeTargets(targets);
    final hasTargets = normalizedTargets.isNotEmpty;

    // Return cached data if recently synced and not forced refresh
    if (!hasTargets && _isSynced && !forceRefresh && _lastSyncTime != null) {
      final elapsed = DateTime.now().difference(_lastSyncTime!);
      if (elapsed.inMinutes < 30) {
        debugPrint(
          '[RobotService] Returning cached robots (${_robotCache.length} robots)',
        );
        return _robotCache.values.toList();
      }
    }

    try {
      debugPrint('[RobotService] Syncing robots from server...');
      final robotData = await _api.syncRobots(normalizedTargets);

      if (!hasTargets) {
        _robotCache.clear();
      }
      for (final data in robotData) {
        final robot = Robot.fromJson(data);
        _robotCache[robot.robotId] = robot;
      }

      _isSynced = true;
      _lastSyncTime = DateTime.now();

      debugPrint('[RobotService] Synced ${_robotCache.length} robots');
      return hasTargets
          ? _resolveRobotsForTargets(normalizedTargets)
          : _robotCache.values.toList();
    } catch (e) {
      debugPrint('[RobotService] Failed to sync robots: $e');
      // Return cached data even if stale
      if (_robotCache.isNotEmpty) {
        return hasTargets
            ? _resolveRobotsForTargets(normalizedTargets)
            : _robotCache.values.toList();
      }
      rethrow;
    }
  }

  Future<List<RobotMenu>> syncConversationMenus({
    required String channelId,
    required int channelType,
    bool forceRefresh = false,
  }) async {
    final targets = await _buildConversationTargets(
      channelId: channelId,
      channelType: channelType,
    );
    if (targets.isEmpty) {
      return const <RobotMenu>[];
    }

    final robots = await syncRobots(
      targets: targets,
      forceRefresh: forceRefresh,
    );
    final menus = <RobotMenu>[];
    for (final robot in robots) {
      if (robot.status != 1 || robot.menus.isEmpty) {
        continue;
      }
      menus.addAll(robot.menus);
    }
    return List<RobotMenu>.unmodifiable(menus);
  }

  /// Performs an inline query on a specific robot.
  ///
  /// [robotId] - The robot to query.
  /// [query] - Search query string.
  /// [channelId] - Optional channel context.
  ///
  /// Returns list of results from the robot.
  Future<List<RobotInlineQueryResult>> query({
    required String robotId,
    required String query,
    String? username,
    String? channelId,
    int? channelType,
  }) async {
    try {
      final result = await _api.inlineQuery(
        robotId: robotId,
        username: username,
        query: query,
        channelId: channelId,
        channelType: channelType,
      );

      final resultsJson = result['results'] as List? ?? [];
      return resultsJson
          .whereType<Map>()
          .map(
            (item) => RobotInlineQueryResult.fromJson(
              Map<String, dynamic>.from(item),
            ),
          )
          .toList();
    } catch (e) {
      debugPrint('[RobotService] Query failed: $e');
      return const [];
    }
  }

  /// Searches for GIF stickers.
  ///
  /// [query] - Search term.
  /// [limit] - Number of results (default 20).
  ///
  /// Returns list of GIF results.
  Future<List<RobotInlineQueryResult>> searchGifs({
    required String query,
    int limit = 20,
    String? username,
    String? channelId,
    int? channelType,
  }) async {
    try {
      debugPrint('[RobotService] Searching GIFs: "$query"');
      final result = await _api.searchGifs(
        query: query,
        limit: limit,
        username: username,
        channelId: channelId,
        channelType: channelType,
      );

      return result
          .whereType<Map>()
          .map(
            (item) => RobotInlineQueryResult.fromJson(
              Map<String, dynamic>.from(item),
            ),
          )
          .toList();
    } catch (e) {
      debugPrint('[RobotService] GIF search failed: $e');
      return const [];
    }
  }

  /// Gets a specific robot by ID.
  ///
  /// Returns null if robot not found in cache.
  Robot? getRobot(String robotId) {
    return _robotCache[robotId];
  }

  /// Gets all available robots.
  List<Robot> getAllRobots() {
    return _robotCache.values.toList();
  }

  /// Adds a robot to user's collection.
  Future<void> addRobot(String robotId) async {
    await _api.addRobot(robotId);
    // Update cache
    if (_robotCache.containsKey(robotId)) {
      final robot = _robotCache[robotId]!;
      _robotCache[robotId] = Robot(
        robotId: robot.robotId,
        username: robot.username,
        name: robot.name,
        avatar: robot.avatar,
        description: robot.description,
        placeholder: robot.placeholder,
        inlineOn: robot.inlineOn,
        status: robot.status,
        version: robot.version,
        commands: robot.commands,
        menus: robot.menus,
        isOwner: robot.isOwner,
        isAdded: true,
        category: robot.category,
        usageCount: robot.usageCount,
      );
    }
  }

  /// Removes a robot from user's collection.
  Future<void> removeRobot(String robotId) async {
    await _api.removeRobot(robotId);
    // Update cache
    if (_robotCache.containsKey(robotId)) {
      final robot = _robotCache[robotId]!;
      _robotCache[robotId] = Robot(
        robotId: robot.robotId,
        username: robot.username,
        name: robot.name,
        avatar: robot.avatar,
        description: robot.description,
        placeholder: robot.placeholder,
        inlineOn: robot.inlineOn,
        status: robot.status,
        version: robot.version,
        commands: robot.commands,
        menus: robot.menus,
        isOwner: robot.isOwner,
        isAdded: false,
        category: robot.category,
        usageCount: robot.usageCount,
      );
    }
  }

  /// Checks if a robot has been added by user.
  bool isRobotAdded(String robotId) {
    final robot = _robotCache[robotId];
    return robot?.isAdded ?? false;
  }

  /// Executes a robot command.
  ///
  /// [robotId] - The robot containing the command.
  /// [command] - Command trigger (with or without / prefix).
  /// [args] - Command arguments.
  ///
  /// Returns command execution result.
  Future<Map<String, dynamic>?> executeCommand({
    required String robotId,
    required String command,
    List<String> args = const [],
  }) async {
    final robot = getRobot(robotId);
    if (robot == null) {
      debugPrint('[RobotService] Robot not found: $robotId');
      return null;
    }

    final cleanCommand = command.startsWith('/')
        ? command.substring(1)
        : command;
    final cmd = robot.findCommand(cleanCommand);
    if (cmd == null) {
      debugPrint('[RobotService] Command not found: $command');
      return null;
    }

    // Execute via inline query with command syntax
    final queryString = '/$command ${args.join(' ')}'.trim();
    final results = await query(robotId: robotId, query: queryString);

    if (results.isEmpty) {
      return null;
    }

    return {
      'success': true,
      'command': command,
      'results': results.map((r) => r.toJson()).toList(),
    };
  }

  /// Clears the robot cache.
  ///
  /// Next sync will fetch fresh data from server.
  void clearCache() {
    _robotCache.clear();
    _isSynced = false;
    _lastSyncTime = null;
    debugPrint('[RobotService] Cache cleared');
  }

  /// Gets recently used robots based on usage count.
  List<Robot> getPopularRobots({int limit = 10}) {
    final robots = _robotCache.values.toList()
      ..sort((a, b) => (b.usageCount ?? 0).compareTo(a.usageCount ?? 0));

    return robots.take(limit).toList();
  }

  /// Searches robots by name or description.
  List<Robot> searchRobots(String keyword) {
    if (keyword.trim().isEmpty) {
      return getAllRobots();
    }

    final lowerKeyword = keyword.toLowerCase();
    return _robotCache.values.where((robot) {
      return robot.name.toLowerCase().contains(lowerKeyword) ||
          (robot.description?.toLowerCase().contains(lowerKeyword) ?? false);
    }).toList();
  }

  List<RobotSyncTarget> _normalizeTargets(List<RobotSyncTarget>? targets) {
    if (targets == null || targets.isEmpty) {
      return const <RobotSyncTarget>[];
    }

    final deduped = <String, RobotSyncTarget>{};
    for (final target in targets) {
      final robotId = target.robotId?.trim();
      final username = target.username?.trim();
      final cacheKey = (robotId != null && robotId.isNotEmpty)
          ? 'id:$robotId'
          : 'username:${username ?? ''}';
      if (cacheKey.endsWith(':')) {
        continue;
      }
      final cachedVersion = robotId != null && robotId.isNotEmpty
          ? (_robotCache[robotId]?.version ?? 0)
          : 0;
      deduped[cacheKey] = RobotSyncTarget(
        robotId: robotId,
        username: username,
        version: target.version > 0 ? target.version : cachedVersion,
      );
    }
    return deduped.values.toList(growable: false);
  }

  List<Robot> _resolveRobotsForTargets(List<RobotSyncTarget> targets) {
    final robots = <Robot>[];
    for (final target in targets) {
      final robotId = target.robotId?.trim();
      if (robotId != null && robotId.isNotEmpty) {
        final robot = _robotCache[robotId];
        if (robot != null) {
          robots.add(robot);
        }
        continue;
      }
      final username = target.username?.trim();
      if (username == null || username.isEmpty) {
        continue;
      }
      for (final robot in _robotCache.values) {
        if (robot.username == username) {
          robots.add(robot);
          break;
        }
      }
    }
    return robots;
  }

  Future<List<RobotSyncTarget>> _buildConversationTargets({
    required String channelId,
    required int channelType,
  }) async {
    final robotIds = <String>{};
    final channel = await WKIM.shared.channelManager.getChannel(
      channelId,
      channelType,
    );
    if ((channel?.robot ?? 0) == 1 && channelId.trim().isNotEmpty) {
      robotIds.add(channelId.trim());
    }

    if (channelType == WKChannelType.group) {
      final members = await WKIM.shared.channelMemberManager.getMembers(
        channelId,
        channelType,
      );
      for (final member in members ?? const []) {
        final memberUid = member.memberUID.trim();
        if (member.robot == 1 &&
            member.isDeleted != 1 &&
            memberUid.isNotEmpty) {
          robotIds.add(memberUid);
        }
      }
    }

    return robotIds
        .map(
          (robotId) => RobotSyncTarget(
            robotId: robotId,
            version: _robotCache[robotId]?.version ?? 0,
          ),
        )
        .toList(growable: false);
  }
}
