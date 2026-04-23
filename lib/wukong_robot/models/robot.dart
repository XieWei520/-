/// Represents a chat robot/bot in the system.
///
/// Robots provide automated services like GIF search, weather updates,
/// news feeds, and other programmatic interactions.
class Robot {
  /// Unique robot identifier.
  final String robotId;

  /// Robot username used for inline query lookups.
  final String username;

  /// Display name of the robot.
  final String name;

  /// Avatar image URL.
  final String? avatar;

  /// Robot description/help text.
  final String? description;

  /// Placeholder text for inline input.
  final String? placeholder;

  /// Whether inline query is enabled for this robot.
  final bool inlineOn;

  /// Current robot status from sync payload.
  final int status;

  /// Current robot version for delta sync.
  final int version;

  /// Available commands as command-description pairs.
  final List<RobotCommand> commands;

  /// Menu shortcuts exposed by the robot inside chat.
  final List<RobotMenu> menus;

  /// Whether this robot is owned by the current user.
  final bool isOwner;

  /// Whether this robot has been added to user's collection.
  final bool isAdded;

  /// Robot category (e.g., 'utility', 'entertainment', 'news').
  final String? category;

  /// Usage count or popularity metric.
  final int? usageCount;

  Robot({
    required this.robotId,
    this.username = '',
    required this.name,
    this.avatar,
    this.description,
    this.placeholder,
    this.inlineOn = false,
    this.status = 0,
    this.version = 0,
    this.commands = const [],
    this.menus = const [],
    this.isOwner = false,
    this.isAdded = false,
    this.category,
    this.usageCount,
  });

  factory Robot.fromJson(Map<String, dynamic> json) {
    return Robot(
      robotId: json['robot_id']?.toString() ?? '',
      username: json['username']?.toString() ?? '',
      name: json['name']?.toString() ?? 'Unknown Robot',
      avatar: json['avatar']?.toString(),
      description: json['description']?.toString(),
      placeholder: json['placeholder']?.toString(),
      inlineOn: json['inline_on'] == 1 || json['inline_on'] == true,
      status: json['status'] as int? ?? 0,
      version: json['version'] as int? ?? 0,
      commands: _parseCommands(json['commands']),
      menus: _parseMenus(json['menus']),
      isOwner: json['is_owner'] == true || json['isOwner'] == true,
      isAdded: json['is_added'] == true || json['isAdded'] == true,
      category: json['category']?.toString(),
      usageCount: json['usage_count'] as int? ?? json['use_count'] as int?,
    );
  }

  static List<RobotCommand> _parseCommands(dynamic commandsJson) {
    if (commandsJson == null) return const [];
    if (commandsJson is! List) return const [];

    return commandsJson
        .whereType<Map>()
        .map((cmd) => RobotCommand.fromJson(Map<String, dynamic>.from(cmd)))
        .toList();
  }

  static List<RobotMenu> _parseMenus(dynamic menusJson) {
    if (menusJson == null || menusJson is! List) {
      return const [];
    }

    return menusJson
        .whereType<Map>()
        .map((menu) => RobotMenu.fromJson(Map<String, dynamic>.from(menu)))
        .toList();
  }

  /// Returns the first command matching the given trigger.
  RobotCommand? findCommand(String trigger) {
    try {
      return commands.firstWhere((cmd) => cmd.trigger.toLowerCase() == trigger.toLowerCase());
    } catch (_) {
      return null;
    }
  }

  /// Checks if robot has a specific command.
  bool hasCommand(String trigger) {
    return commands.any((cmd) => cmd.trigger.toLowerCase() == trigger.toLowerCase());
  }

  Map<String, dynamic> toJson() {
    return {
      'robot_id': robotId,
      'username': username,
      'name': name,
      'avatar': avatar,
      'description': description,
      'placeholder': placeholder,
      'inline_on': inlineOn ? 1 : 0,
      'status': status,
      'version': version,
      'commands': commands.map((cmd) => cmd.toJson()).toList(),
      'menus': menus.map((menu) => menu.toJson()).toList(),
      'is_owner': isOwner,
      'is_added': isAdded,
      'category': category,
      'usage_count': usageCount,
    };
  }

  @override
  String toString() {
    return 'Robot(robotId: $robotId, name: $name, commands: ${commands.length})';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Robot && other.robotId == robotId;
  }

  @override
  int get hashCode => robotId.hashCode;
}

class RobotMenu {
  final String robotId;
  final String cmd;
  final String remark;
  final String type;

  const RobotMenu({
    required this.robotId,
    required this.cmd,
    required this.remark,
    required this.type,
  });

  factory RobotMenu.fromJson(Map<String, dynamic> json) {
    return RobotMenu(
      robotId: json['robot_id']?.toString() ?? '',
      cmd: json['cmd']?.toString() ?? '',
      remark: json['remark']?.toString() ?? '',
      type: json['type']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'robot_id': robotId,
      'cmd': cmd,
      'remark': remark,
      'type': type,
    };
  }
}

/// Represents a command that a robot can execute.
class RobotCommand {
  /// Command trigger word (without / prefix).
  final String trigger;

  /// Human-readable description of what the command does.
  final String description;

  /// Example usage of the command.
  final String? example;

  RobotCommand({
    required this.trigger,
    required this.description,
    this.example,
  });

  factory RobotCommand.fromJson(Map<String, dynamic> json) {
    return RobotCommand(
      trigger: json['trigger']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      example: json['example']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'trigger': trigger,
      'description': description,
      'example': example,
    };
  }

  /// Returns the full command string with / prefix.
  String get fullCommand => '/$trigger';

  @override
  String toString() {
    return 'RobotCommand(trigger: $trigger, description: $description)';
  }
}

/// Result from a robot inline query.
class RobotInlineQueryResult {
  /// Type of result (article, photo, gif, video, audio, etc.).
  final String type;

  /// Unique result identifier.
  final String id;

  /// Inline query session identifier returned by the robot service.
  final String inlineQuerySid;

  /// Title for article/photo results.
  final String? title;

  /// Description/caption for the result.
  final String? description;

  /// Thumbnail URL for visual results.
  final String? thumbnailUrl;

  /// Content URL (for media results).
  final String? contentUrl;

  /// MIME type of the content.
  final String? mimeType;

  /// Additional data specific to result type.
  final Map<String, dynamic> extraData;

  RobotInlineQueryResult({
    required this.type,
    required this.id,
    this.inlineQuerySid = '',
    this.title,
    this.description,
    this.thumbnailUrl,
    this.contentUrl,
    this.mimeType,
    this.extraData = const {},
  });

  factory RobotInlineQueryResult.fromJson(Map<String, dynamic> json) {
    return RobotInlineQueryResult(
      type: json['type']?.toString() ?? 'article',
      id: json['id']?.toString() ?? '',
      inlineQuerySid: json['inline_query_sid']?.toString() ?? '',
      title: json['title']?.toString(),
      description: json['description']?.toString(),
      thumbnailUrl: json['thumb_url']?.toString() ?? json['thumbnail_url']?.toString(),
      contentUrl: json['content_url']?.toString() ?? json['url']?.toString(),
      mimeType: json['mime_type']?.toString() ?? json['mimetype']?.toString(),
      extraData: Map<String, dynamic>.from(json['extra'] ?? {}),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'type': type,
      'id': id,
      'inline_query_sid': inlineQuerySid,
      'title': title,
      'description': description,
      'thumb_url': thumbnailUrl,
      'content_url': contentUrl,
      'mime_type': mimeType,
      'extra': extraData,
    };
  }

  /// Convenience getter for GIF results.
  bool get isGif => type.toLowerCase() == 'gif';

  /// Convenience getter for photo results.
  bool get isPhoto => type.toLowerCase() == 'photo';

  /// Convenience getter for article results.
  bool get isArticle => type.toLowerCase() == 'article';

  /// Convenience getter for video results.
  bool get isVideo => type.toLowerCase() == 'video';
}
