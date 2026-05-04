/// Message extra entity for additional message data
class WKMessageExtra {
  String messageId;
  int readedAt;
  int revokedAt;
  String? extraStr;

  WKMessageExtra({
    this.messageId = '',
    this.readedAt = 0,
    this.revokedAt = 0,
    this.extraStr,
  });

  factory WKMessageExtra.fromJson(Map<String, dynamic> json) {
    return WKMessageExtra(
      messageId: json['message_id'] ?? json['messageId'] ?? '',
      readedAt: json['readed_at'] ?? json['readedAt'] ?? 0,
      revokedAt: json['revoked_at'] ?? json['revokedAt'] ?? 0,
      extraStr: json['extra_str'] ?? json['extraStr'],
    );
  }
}
