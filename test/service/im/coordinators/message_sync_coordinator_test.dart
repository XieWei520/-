import 'package:flutter_test/flutter_test.dart';
import 'package:wukong_im_app/service/im/coordinators/message_sync_coordinator.dart';

void main() {
  group('MessageSyncCoordinator', () {
    test('uses highest offline command message_seq for ack', () {
      const coordinator = MessageSyncCoordinator();

      expect(
        coordinator.resolveOfflineCommandAckSequence(<dynamic>[
          <String, dynamic>{'message_seq': 11},
          <String, dynamic>{'message_seq': '27'},
          <String, dynamic>{'message_seq': 19},
        ]),
        27,
      );
    });

    test('builds stable message-extra sync keys by channel', () {
      const coordinator = MessageSyncCoordinator();

      expect(coordinator.messageExtraSyncKey(' ch1 ', 1), 'ch1:1');
      expect(coordinator.messageExtraSyncKey('', 1), isEmpty);
    });
  });
}
