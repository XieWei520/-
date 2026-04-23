/// Message model for chat
class WKMessage {
  String clientMsgNo;     // Client message ID
  String? messageID;      // Server message ID
  int messageSeq;        // Message sequence
  String fromUID;         // Sender UID
  String toUID;          // Receiver UID (or channel ID for groups)
  int channelType;       // 1: personal, 2: group
  String channelID;      // Channel ID
  int contentType;       // Message content type
  String content;        // Message content
  String? reply;         // Reply to message ID
  int status;            // 0: sending, 1: sent, 2: delivered, 3: read
  int isDeleted;         // Is deleted
  int isRevoked;        // Is revoked
  String? revokeTime;   // Revoke timestamp
  int createdAt;        // Created timestamp
  int updatedAt;        // Updated timestamp
  
  // Extra fields (from SDK or local)
  Map<String, dynamic>? extra;
  String? fromName;
  String? fromAvatar;
  String? toName;
  String? toAvatar;
  
  // UI specific
  bool isMe;            // Is sent by current user
  bool isVoicePlaying;   // Is voice message playing
  
  WKMessage({
    this.clientMsgNo = '',
    this.messageID,
    this.messageSeq = 0,
    this.fromUID = '',
    this.toUID = '',
    this.channelType = 1,
    this.channelID = '',
    this.contentType = 1,
    this.content = '',
    this.reply,
    this.status = 0,
    this.isDeleted = 0,
    this.isRevoked = 0,
    this.revokeTime,
    this.createdAt = 0,
    this.updatedAt = 0,
    this.extra,
    this.fromName,
    this.fromAvatar,
    this.toName,
    this.toAvatar,
    this.isMe = false,
    this.isVoicePlaying = false,
  });

  factory WKMessage.fromJson(Map<String, dynamic> json) {
    return WKMessage(
      clientMsgNo: json['client_msg_no'] ?? json['clientMsgNo'] ?? '',
      messageID: json['message_id'] ?? json['messageID'],
      messageSeq: json['message_seq'] ?? json['messageSeq'] ?? 0,
      fromUID: json['from_uid'] ?? json['fromUID'] ?? '',
      toUID: json['to_uid'] ?? json['toUID'] ?? '',
      channelType: json['channel_type'] ?? json['channelType'] ?? 1,
      channelID: json['channel_id'] ?? json['channelID'] ?? '',
      contentType: json['content_type'] ?? json['contentType'] ?? 1,
      content: json['content'] ?? '',
      reply: json['reply'],
      status: json['status'] ?? 0,
      isDeleted: json['is_deleted'] ?? json['isDeleted'] ?? 0,
      isRevoked: json['is_revoked'] ?? json['isRevoked'] ?? 0,
      revokeTime: json['revoke_time'] ?? json['revokeTime'],
      createdAt: json['created_at'] ?? json['createdAt'] ?? 0,
      updatedAt: json['updated_at'] ?? json['updatedAt'] ?? 0,
      extra: json['extra'],
      fromName: json['from_name'] ?? json['fromName'],
      fromAvatar: json['from_avatar'] ?? json['fromAvatar'],
      toName: json['to_name'] ?? json['toName'],
      toAvatar: json['to_avatar'] ?? json['toAvatar'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'client_msg_no': clientMsgNo,
      'message_id': messageID,
      'message_seq': messageSeq,
      'from_uid': fromUID,
      'to_uid': toUID,
      'channel_type': channelType,
      'channel_id': channelID,
      'content_type': contentType,
      'content': content,
      'reply': reply,
      'status': status,
      'is_deleted': isDeleted,
      'is_revoked': isRevoked,
      'revoke_time': revokeTime,
      'created_at': createdAt,
      'updated_at': updatedAt,
      'extra': extra,
      'from_name': fromName,
      'from_avatar': fromAvatar,
      'to_name': toName,
      'to_avatar': toAvatar,
    };
  }
  
  WKMessage copyWith({
    String? clientMsgNo,
    String? messageID,
    int? messageSeq,
    String? fromUID,
    String? toUID,
    int? channelType,
    String? channelID,
    int? contentType,
    String? content,
    String? reply,
    int? status,
    int? isDeleted,
    int? isRevoked,
    String? revokeTime,
    int? createdAt,
    int? updatedAt,
    Map<String, dynamic>? extra,
    String? fromName,
    String? fromAvatar,
    String? toName,
    String? toAvatar,
    bool? isMe,
    bool? isVoicePlaying,
  }) {
    return WKMessage(
      clientMsgNo: clientMsgNo ?? this.clientMsgNo,
      messageID: messageID ?? this.messageID,
      messageSeq: messageSeq ?? this.messageSeq,
      fromUID: fromUID ?? this.fromUID,
      toUID: toUID ?? this.toUID,
      channelType: channelType ?? this.channelType,
      channelID: channelID ?? this.channelID,
      contentType: contentType ?? this.contentType,
      content: content ?? this.content,
      reply: reply ?? this.reply,
      status: status ?? this.status,
      isDeleted: isDeleted ?? this.isDeleted,
      isRevoked: isRevoked ?? this.isRevoked,
      revokeTime: revokeTime ?? this.revokeTime,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      extra: extra ?? this.extra,
      fromName: fromName ?? this.fromName,
      fromAvatar: fromAvatar ?? this.fromAvatar,
      toName: toName ?? this.toName,
      toAvatar: toAvatar ?? this.toAvatar,
      isMe: isMe ?? this.isMe,
      isVoicePlaying: isVoicePlaying ?? this.isVoicePlaying,
    );
  }
}

/// Text message content
class WKTextContent {
  String text;
  
  WKTextContent({required this.text});
  
  factory WKTextContent.fromJson(Map<String, dynamic> json) {
    return WKTextContent(
      text: json['text'] ?? '',
    );
  }
  
  Map<String, dynamic> toJson() => {'text': text};
}

/// Image message content
class WKImageContent {
  String? url;          // Remote URL
  String? localPath;    // Local file path
  String? thumbnail;    // Thumbnail URL
  int width;
  int height;
  int size;             // File size in bytes
  
  WKImageContent({
    this.url,
    this.localPath,
    this.thumbnail,
    this.width = 0,
    this.height = 0,
    this.size = 0,
  });
  
  factory WKImageContent.fromJson(Map<String, dynamic> json) {
    return WKImageContent(
      url: json['url'],
      localPath: json['localPath'],
      thumbnail: json['thumbnail'],
      width: json['width'] ?? 0,
      height: json['height'] ?? 0,
      size: json['size'] ?? 0,
    );
  }
  
  Map<String, dynamic> toJson() => {
    'url': url,
    'localPath': localPath,
    'thumbnail': thumbnail,
    'width': width,
    'height': height,
    'size': size,
  };
}

/// Voice message content
class WKVoiceContent {
  String? url;          // Remote URL
  String? localPath;    // Local file path
  int duration;         // Duration in seconds
  int size;             // File size in bytes
  String? wavUrl;       // WAV format URL
  String? aacUrl;       // AAC format URL
  
  WKVoiceContent({
    this.url,
    this.localPath,
    this.duration = 0,
    this.size = 0,
    this.wavUrl,
    this.aacUrl,
  });
  
  factory WKVoiceContent.fromJson(Map<String, dynamic> json) {
    return WKVoiceContent(
      url: json['url'],
      localPath: json['localPath'],
      duration: json['duration'] ?? 0,
      size: json['size'] ?? 0,
      wavUrl: json['wavUrl'],
      aacUrl: json['aacUrl'],
    );
  }
  
  Map<String, dynamic> toJson() => {
    'url': url,
    'localPath': localPath,
    'duration': duration,
    'size': size,
    'wavUrl': wavUrl,
    'aacUrl': aacUrl,
  };
}

/// Video message content
class WKVideoContent {
  String? url;          // Remote URL
  String? localPath;    // Local file path
  String? coverUrl;     // Cover/thumbnail URL
  int width;
  int height;
  int duration;         // Duration in seconds
  int size;             // File size in bytes
  
  WKVideoContent({
    this.url,
    this.localPath,
    this.coverUrl,
    this.width = 0,
    this.height = 0,
    this.duration = 0,
    this.size = 0,
  });
  
  factory WKVideoContent.fromJson(Map<String, dynamic> json) {
    return WKVideoContent(
      url: json['url'],
      localPath: json['localPath'],
      coverUrl: json['coverUrl'],
      width: json['width'] ?? 0,
      height: json['height'] ?? 0,
      duration: json['duration'] ?? 0,
      size: json['size'] ?? 0,
    );
  }
  
  Map<String, dynamic> toJson() => {
    'url': url,
    'localPath': localPath,
    'coverUrl': coverUrl,
    'width': width,
    'height': height,
    'duration': duration,
    'size': size,
  };
}

/// File message content
class WKFileContent {
  String? url;          // Remote URL
  String? localPath;    // Local file path
  String fileName;      // File name
  String? fileExtension; // File extension
  int size;             // File size in bytes
  
  WKFileContent({
    this.url,
    this.localPath,
    this.fileName = '',
    this.fileExtension,
    this.size = 0,
  });
  
  factory WKFileContent.fromJson(Map<String, dynamic> json) {
    return WKFileContent(
      url: json['url'],
      localPath: json['localPath'],
      fileName: json['fileName'] ?? json['file_name'] ?? '',
      fileExtension: json['fileExtension'] ?? json['file_extension'],
      size: json['size'] ?? 0,
    );
  }
  
  Map<String, dynamic> toJson() => {
    'url': url,
    'localPath': localPath,
    'fileName': fileName,
    'fileExtension': fileExtension,
    'size': size,
  };
}

/// Location message content
class WKLocationContent {
  double latitude;
  double longitude;
  String? title;       // Location title/name
  String? address;     // Address string
  String? snapshot;    // Map snapshot URL
  
  WKLocationContent({
    this.latitude = 0,
    this.longitude = 0,
    this.title,
    this.address,
    this.snapshot,
  });
  
  factory WKLocationContent.fromJson(Map<String, dynamic> json) {
    return WKLocationContent(
      latitude: (json['latitude'] ?? 0).toDouble(),
      longitude: (json['longitude'] ?? 0).toDouble(),
      title: json['title'],
      address: json['address'],
      snapshot: json['snapshot'],
    );
  }
  
  Map<String, dynamic> toJson() => {
    'latitude': latitude,
    'longitude': longitude,
    'title': title,
    'address': address,
    'snapshot': snapshot,
  };
}

/// Card message content (business card)
class WKCardContent {
  String uid;          // User ID
  String name;         // User name
  String? avatar;      // User avatar
  
  WKCardContent({
    this.uid = '',
    this.name = '',
    this.avatar,
  });
  
  factory WKCardContent.fromJson(Map<String, dynamic> json) {
    return WKCardContent(
      uid: json['uid'] ?? '',
      name: json['name'] ?? '',
      avatar: json['avatar'],
    );
  }
  
  Map<String, dynamic> toJson() => {
    'uid': uid,
    'name': name,
    'avatar': avatar,
  };
}
