import 'package:wukongimfluttersdk/model/wk_message_content.dart';
import 'package:wukongimfluttersdk/type/const.dart';
import 'package:wukongimfluttersdk/wkim.dart';

import '../../data/models/wk_custom_content.dart';
import '../../data/models/wk_robot_card_content.dart';
import '../../wukong_base/msg/msg_content_type.dart';

typedef ImMessageContentFactory = WKMessageContent Function(dynamic data);

abstract interface class ImMessageContentRegistrar {
  void register(int contentType, ImMessageContentFactory factory);
}

class WkImMessageContentRegistrar implements ImMessageContentRegistrar {
  const WkImMessageContentRegistrar();

  @override
  void register(int contentType, ImMessageContentFactory factory) {
    WKIM.shared.messageManager.registerMsgContent(contentType, factory);
  }
}

class ImMessageContentRegistry {
  const ImMessageContentRegistry({
    this.registrar = const WkImMessageContentRegistrar(),
  });

  final ImMessageContentRegistrar registrar;

  void registerDefaults() {
    registrar.register(
      WkMessageContentType.location,
      (data) => WKLocationContent().decodeJson(_asMap(data)),
    );
    registrar.register(
      WkMessageContentType.file,
      (data) => WKFileContent().decodeJson(_asMap(data)),
    );
    registrar.register(
      WkMessageContentType.card,
      (data) => WKCardContent('', '').decodeJson(_asMap(data)),
    );
    registrar.register(
      MsgContentType.robotCard,
      (data) => WKRobotCardContent().decodeJson(_asMap(data)),
    );
  }

  Map<String, dynamic> _asMap(dynamic raw) {
    if (raw is Map<String, dynamic>) {
      return raw;
    }
    if (raw is Map) {
      return Map<String, dynamic>.from(raw);
    }
    return <String, dynamic>{};
  }
}
