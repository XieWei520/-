import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('IMService delegates SDK callback binding to an extracted service', () {
    final source = File('lib/service/im/im_service.dart').readAsStringSync();

    expect(
      source,
      isNot(contains('addOnSyncConversationListener')),
      reason: 'Conversation sync callback wiring belongs outside IMService.',
    );
    expect(
      source,
      isNot(contains('addOnSyncChannelMsgListener')),
      reason: 'Channel sync callback wiring belongs outside IMService.',
    );
    expect(
      source,
      isNot(contains('addOnUploadAttachmentListener')),
      reason: 'Attachment upload callback wiring belongs outside IMService.',
    );
    expect(
      source,
      isNot(contains('addOnCmdListener')),
      reason: 'Command callback wiring belongs outside IMService.',
    );
    expect(
      source,
      isNot(contains('registerMsgContent')),
      reason: 'Message content registration belongs outside IMService.',
    );
  });
}
