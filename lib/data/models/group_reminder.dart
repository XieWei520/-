class GroupReminderStatus {
  static const int pending = 0;
  static const int completed = 1;
}

class GroupReminderType {
  static const int todo = 3;
}

class GroupReminderAssignee {
  final String uid;
  final String name;
  final bool done;
  final String? doneAt;

  const GroupReminderAssignee({
    required this.uid,
    required this.name,
    required this.done,
    this.doneAt,
  });

  factory GroupReminderAssignee.fromJson(Map<String, dynamic> json) {
    return GroupReminderAssignee(
      uid: (json['uid'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      done: _readBool(json['done']),
      doneAt: _readString(json['done_at']),
    );
  }
}

class GroupReminder {
  final int id;
  final String groupNo;
  final String title;
  final String content;
  final String creatorUid;
  final String creatorName;
  final int remindAt;
  final int triggeredAt;
  final int completedAt;
  final int status;
  final bool triggered;
  final bool allDone;
  final bool done;
  final bool overdue;
  final int totalCount;
  final int doneCount;
  final List<GroupReminderAssignee> assignees;
  final String? createdAt;
  final String? updatedAt;

  const GroupReminder({
    required this.id,
    required this.groupNo,
    required this.title,
    required this.content,
    required this.creatorUid,
    required this.creatorName,
    required this.remindAt,
    required this.triggeredAt,
    required this.completedAt,
    required this.status,
    required this.triggered,
    required this.allDone,
    required this.done,
    required this.overdue,
    required this.totalCount,
    required this.doneCount,
    required this.assignees,
    this.createdAt,
    this.updatedAt,
  });

  bool get isCompleted => status == GroupReminderStatus.completed || allDone;

  bool get isPending => !isCompleted;

  bool get isScheduled => !triggered && isPending;

  bool get isInProgress => triggered && isPending;

  bool get isEditable => isPending && !triggered && triggeredAt <= 0;

  Set<String> get assigneeUids => assignees
      .map((item) => item.uid.trim())
      .where((item) => item.isNotEmpty)
      .toSet();

  bool canManage(String uid) {
    final normalizedUid = uid.trim();
    if (normalizedUid.isEmpty) {
      return false;
    }
    return isEditable && creatorUid.trim() == normalizedUid;
  }

  factory GroupReminder.fromJson(Map<String, dynamic> json) {
    final rawAssignees = json['assignees'];
    final assignees = rawAssignees is List
        ? rawAssignees
              .whereType<Map>()
              .map(
                (item) => GroupReminderAssignee.fromJson(
                  Map<String, dynamic>.from(item),
                ),
              )
              .toList()
        : const <GroupReminderAssignee>[];

    return GroupReminder(
      id: _readInt(json['id']),
      groupNo: (json['group_no'] ?? '').toString(),
      title: (json['title'] ?? '').toString(),
      content: (json['content'] ?? '').toString(),
      creatorUid: (json['creator_uid'] ?? '').toString(),
      creatorName: (json['creator_name'] ?? '').toString(),
      remindAt: _readInt(json['remind_at']),
      triggeredAt: _readInt(json['triggered_at']),
      completedAt: _readInt(json['completed_at']),
      status: _readInt(json['status']),
      triggered: _readBool(json['triggered']),
      allDone: _readBool(json['all_done']),
      done: _readBool(json['done']),
      overdue: _readBool(json['overdue']),
      totalCount: _readInt(json['total_count']),
      doneCount: _readInt(json['done_count']),
      assignees: assignees,
      createdAt: _readString(json['created_at']),
      updatedAt: _readString(json['updated_at']),
    );
  }
}

class GroupReminderPayload {
  final int reminderId;
  final String groupNo;
  final String title;
  final String content;
  final String creatorUid;
  final String creatorName;
  final int remindAt;
  final List<String> assigneeUids;

  const GroupReminderPayload({
    required this.reminderId,
    required this.groupNo,
    required this.title,
    required this.content,
    required this.creatorUid,
    required this.creatorName,
    required this.remindAt,
    required this.assigneeUids,
  });

  static GroupReminderPayload? fromReminderData(dynamic data) {
    if (data is! Map) {
      return null;
    }
    final json = Map<String, dynamic>.from(data);
    if ((json['kind'] ?? '').toString() != 'group_reminder') {
      return null;
    }
    final rawAssignees = json['assignee_uids'];
    final assigneeUids = rawAssignees is List
        ? rawAssignees
              .map((item) => item.toString().trim())
              .where((item) => item.isNotEmpty)
              .toList()
        : const <String>[];

    return GroupReminderPayload(
      reminderId: _readInt(json['group_reminder_id']),
      groupNo: (json['group_no'] ?? '').toString(),
      title: (json['title'] ?? '').toString(),
      content: (json['content'] ?? '').toString(),
      creatorUid: (json['creator_uid'] ?? '').toString(),
      creatorName: (json['creator_name'] ?? '').toString(),
      remindAt: _readInt(json['remind_at']),
      assigneeUids: assigneeUids,
    );
  }
}

int _readInt(dynamic value) {
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

bool _readBool(dynamic value) {
  if (value is bool) {
    return value;
  }
  if (value is num) {
    return value.toInt() == 1;
  }
  final normalized = value?.toString().trim().toLowerCase() ?? '';
  return normalized == '1' || normalized == 'true';
}

String? _readString(dynamic value) {
  final resolved = value?.toString().trim() ?? '';
  if (resolved.isEmpty) {
    return null;
  }
  return resolved;
}
