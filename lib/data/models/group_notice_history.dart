class GroupNoticeHistory {
  final int id;
  final String groupNo;
  final String operatorUid;
  final String operatorName;
  final String notice;
  final String createdAt;

  const GroupNoticeHistory({
    required this.id,
    required this.groupNo,
    required this.operatorUid,
    required this.operatorName,
    required this.notice,
    required this.createdAt,
  });

  factory GroupNoticeHistory.fromJson(Map<String, dynamic> json) {
    return GroupNoticeHistory(
      id: _readInt(json['id']),
      groupNo: (json['group_no'] ?? '').toString(),
      operatorUid: (json['operator_uid'] ?? '').toString(),
      operatorName: (json['operator_name'] ?? '').toString(),
      notice: (json['notice'] ?? '').toString(),
      createdAt: (json['created_at'] ?? '').toString(),
    );
  }

  static int _readInt(dynamic value) {
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }
}
