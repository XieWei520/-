import 'package:flutter_test/flutter_test.dart';
import 'package:wukong_im_app/modules/chat/chat_conversation_extra_gateway.dart';
import 'package:wukong_im_app/modules/chat/chat_conversation_restore_service.dart';
import 'package:wukong_im_app/modules/chat/chat_viewport_models.dart';
import 'package:wukongimfluttersdk/entity/conversation.dart';
import 'package:wukongimfluttersdk/type/const.dart';

void main() {
  test('resolveRestoreAnchor returns null when gateway load fails', () async {
    final service = ChatConversationRestoreService();
    final gateway = _ThrowingConversationExtraGateway();

    final anchor = await service.resolveRestoreAnchor(
      gateway: gateway,
      channelId: 'u_failure',
      channelType: WKChannelType.personal,
    );

    expect(anchor, isNull);
    expect(service.browseTo, 0);
  });

  test('resolveRestoreAnchor records browseTo and converts keep seq', () async {
    final service = ChatConversationRestoreService();
    final gateway = _FakeConversationExtraGateway(
      loadedExtra: WKConversationMsgExtra()
        ..browseTo = 21
        ..keepMessageSeq = 7
        ..keepOffsetY = 88,
    );

    final anchor = await service.resolveRestoreAnchor(
      gateway: gateway,
      channelId: 'u_restore',
      channelType: WKChannelType.personal,
    );

    expect(service.browseTo, 21);
    expect(anchor, isNotNull);
    expect(anchor!.aroundOrderSeq, 7000);
    expect(anchor.keepOffsetY, 88);
    expect(anchor.browseTo, 21);
  });

  test(
    'persist saves max browseTo with latest viewport and only once',
    () async {
      final service = ChatConversationRestoreService();
      final gateway = _FakeConversationExtraGateway();

      service
        ..recordRestoredBrowseTo(40)
        ..recordViewportSnapshot(
          const ChatViewportPersistenceSnapshot(
            keepMessageSeq: 11,
            keepOffsetY: 120,
            maxVisibleMessageSeq: 35,
          ),
        );

      await service.persist(
        gateway: gateway,
        channelId: 'u_persist',
        channelType: WKChannelType.personal,
        draft: 'draft text',
      );
      await service.persist(
        gateway: gateway,
        channelId: 'u_persist',
        channelType: WKChannelType.personal,
        draft: 'second draft',
      );

      expect(gateway.saveCalls, hasLength(1));
      expect(gateway.saveCalls.single.browseTo, 40);
      expect(gateway.saveCalls.single.keepMessageSeq, 11);
      expect(gateway.saveCalls.single.keepOffsetY, 120);
      expect(gateway.saveCalls.single.draft, 'draft text');
    },
  );

  test('persist skips empty snapshot without draft', () async {
    final service = ChatConversationRestoreService();
    final gateway = _FakeConversationExtraGateway();

    await service.persist(
      gateway: gateway,
      channelId: 'u_empty',
      channelType: WKChannelType.personal,
      draft: '',
    );

    expect(service.hasPersisted, isFalse);
    expect(gateway.saveCalls, isEmpty);
  });

  test('recordViewportSnapshot advances browseTo for newer visible seq', () {
    final service = ChatConversationRestoreService()..recordRestoredBrowseTo(8);

    service.recordViewportSnapshot(
      const ChatViewportPersistenceSnapshot(maxVisibleMessageSeq: 12),
    );

    expect(service.browseTo, 12);
  });
}

class _FakeConversationExtraGateway implements ChatConversationExtraGateway {
  _FakeConversationExtraGateway({this.loadedExtra});

  final WKConversationMsgExtra? loadedExtra;
  final List<_SavedConversationExtra> saveCalls = <_SavedConversationExtra>[];

  @override
  Future<WKConversationMsgExtra?> load({
    required String channelId,
    required int channelType,
  }) async {
    return loadedExtra;
  }

  @override
  Future<void> save({
    required String channelId,
    required int channelType,
    required int browseTo,
    required int keepMessageSeq,
    required int keepOffsetY,
    required String draft,
  }) async {
    saveCalls.add(
      _SavedConversationExtra(
        browseTo: browseTo,
        keepMessageSeq: keepMessageSeq,
        keepOffsetY: keepOffsetY,
        draft: draft,
      ),
    );
  }
}

class _ThrowingConversationExtraGateway
    implements ChatConversationExtraGateway {
  @override
  Future<WKConversationMsgExtra?> load({
    required String channelId,
    required int channelType,
  }) async {
    throw StateError('offline');
  }

  @override
  Future<void> save({
    required String channelId,
    required int channelType,
    required int browseTo,
    required int keepMessageSeq,
    required int keepOffsetY,
    required String draft,
  }) async {
    throw StateError('offline');
  }
}

class _SavedConversationExtra {
  const _SavedConversationExtra({
    required this.browseTo,
    required this.keepMessageSeq,
    required this.keepOffsetY,
    required this.draft,
  });

  final int browseTo;
  final int keepMessageSeq;
  final int keepOffsetY;
  final String draft;
}
