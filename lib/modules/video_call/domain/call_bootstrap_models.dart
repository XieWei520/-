import '../../../data/models/call.dart';

class CallSessionTicket {
  const CallSessionTicket({
    required this.token,
    required this.expiresAt,
    required this.roomId,
    required this.participant,
  });

  final String token;
  final int expiresAt;
  final String roomId;
  final String participant;

  factory CallSessionTicket.fromJson(Map<String, dynamic> json) {
    return CallSessionTicket(
      token: json['token']?.toString() ?? '',
      expiresAt: (json['expires_at'] as num?)?.toInt() ?? 0,
      roomId: json['room_id']?.toString() ?? '',
      participant: json['participant']?.toString() ?? '',
    );
  }
}

class CallJoinDescriptor {
  const CallJoinDescriptor({
    required this.controlUrl,
    required this.livekitUrl,
    required this.roomName,
  });

  final String controlUrl;
  final String livekitUrl;
  final String roomName;

  factory CallJoinDescriptor.fromJson(Map<String, dynamic> json) {
    return CallJoinDescriptor(
      controlUrl: json['control_url']?.toString() ?? '',
      livekitUrl: json['livekit_url']?.toString() ?? '',
      roomName: json['room_name']?.toString() ?? '',
    );
  }
}

class CallMediaCapabilities {
  const CallMediaCapabilities({
    required this.platform,
    required this.supportsVideo,
    required this.supportsAudio,
    required this.prefersAudio,
    required this.isSafari,
    required this.isMobileWeb,
  });

  final String platform;
  final bool supportsVideo;
  final bool supportsAudio;
  final bool prefersAudio;
  final bool isSafari;
  final bool isMobileWeb;

  factory CallMediaCapabilities.fromJson(Map<String, dynamic> json) {
    return CallMediaCapabilities(
      platform: json['platform']?.toString() ?? 'unknown',
      supportsVideo: json['supports_video'] == true,
      supportsAudio: json['supports_audio'] != false,
      prefersAudio: json['prefers_audio'] == true,
      isSafari: json['is_safari'] == true,
      isMobileWeb: json['is_mobile_web'] == true,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'platform': platform,
      'supports_video': supportsVideo,
      'supports_audio': supportsAudio,
      'prefers_audio': prefersAudio,
      'is_safari': isSafari,
      'is_mobile_web': isMobileWeb,
    };
  }
}

class CallBootstrap {
  const CallBootstrap({
    required this.room,
    required this.ticket,
    required this.join,
    required this.capabilities,
  });

  final CallRoom room;
  final CallSessionTicket ticket;
  final CallJoinDescriptor join;
  final CallMediaCapabilities capabilities;

  factory CallBootstrap.fromJson(Map<String, dynamic> json) {
    return CallBootstrap(
      room: CallRoom.fromJson(_readMap(json['room'])),
      ticket: CallSessionTicket.fromJson(_readMap(json['ticket'])),
      join: CallJoinDescriptor.fromJson(_readMap(json['join'])),
      capabilities: CallMediaCapabilities.fromJson(
        _readMap(json['capabilities']),
      ),
    );
  }

  static Map<String, dynamic> _readMap(dynamic raw) {
    if (raw is Map<String, dynamic>) {
      return raw;
    }
    if (raw is Map) {
      return Map<String, dynamic>.from(raw);
    }
    return <String, dynamic>{};
  }
}
