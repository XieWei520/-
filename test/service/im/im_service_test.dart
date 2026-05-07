import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:wukong_im_app/modules/conversation/conversation_activity_registry.dart';
import 'package:wukong_im_app/data/models/wk_custom_content.dart';
import 'package:wukong_im_app/service/api/im_route_info.dart';
import 'package:wukong_im_app/service/im/im_service.dart';
import 'package:wukongimfluttersdk/entity/cmd.dart';
import 'package:wukongimfluttersdk/entity/conversation.dart';
import 'package:wukongimfluttersdk/type/const.dart';
import 'package:wukongimfluttersdk/wkim.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    ConversationActivityRegistry.instance.clearAll();
  });

  tearDown(() {
    ConversationActivityRegistry.instance.clearAll();
  });

  test('builds session gateway uri without introducing port zero', () {
    final uri = buildSessionGatewayUri(
      baseUrl: 'https://infoequity.cn',
      deviceSessionId: 'device_session_01',
      lastAckedSeq: 0,
    );

    expect(uri.toString(), isNot(contains(':0/')));
    expect(
      uri.toString(),
      'wss://infoequity.cn/v1/realtime/session/events/ws?device_session_id=device_session_01&last_acked_seq=0',
    );
  });

  test('selectImConnectAddr uses preferred_addr then transport fallbacks', () {
    final route = ImRouteInfo(
      tcpAddr: 'infoequity.cn:5100',
      wsAddr: 'ws://infoequity.cn:5200',
      wssAddr: 'wss://infoequity.cn/ws',
      preferredTransport: 'wss',
      preferredAddr: 'wss://infoequity.cn/ws',
    );

    expect(
      selectImConnectAddr(route, fallbackAddr: 'fallback.example:5100'),
      'wss://infoequity.cn/ws',
    );

    final invalidPreferred = ImRouteInfo(
      tcpAddr: 'infoequity.cn:5100',
      wsAddr: 'ws://infoequity.cn:5200',
      wssAddr: 'wss://infoequity.cn/ws',
      preferredTransport: 'wss',
      preferredAddr: 'https://infoequity.cn/ws',
    );

    expect(
      selectImConnectAddr(
        invalidPreferred,
        fallbackAddr: 'fallback.example:5100',
      ),
      'wss://infoequity.cn/ws',
    );
  });

  test('selectImConnectAddr keeps explicit local fallback override first', () {
    final route = ImRouteInfo(
      tcpAddr: 'infoequity.cn:5100',
      wsAddr: 'ws://infoequity.cn:5200',
      wssAddr: 'wss://infoequity.cn/ws',
      preferredTransport: 'wss',
      preferredAddr: 'wss://infoequity.cn/ws',
    );

    expect(
      selectImConnectAddr(route, fallbackAddr: '127.0.0.1:15100'),
      '127.0.0.1:15100',
    );
  });

  test('resolves IM init credentials with separate HTTP and IM tokens', () {
    final credentials = resolveStoredImInitCredentials(
      uid: 'u_self',
      apiToken: 'http_token_01',
      imToken: 'im_token_01',
      deviceSessionId: 'device_session_01',
    );

    expect(credentials, isNotNull);
    expect(credentials!.uid, 'u_self');
    expect(credentials.apiToken, 'http_token_01');
    expect(credentials.imToken, 'im_token_01');
    expect(credentials.deviceSessionId, 'device_session_01');
  });

  test(
    'does not reuse initialized IM session when realtime runtime is degraded',
    () {
      expect(
        shouldReuseInitializedImSession(
          initializedUid: 'u_self',
          initializedToken: 'token_01',
          initializedDeviceSessionId: 'device_session_01',
          uid: 'u_self',
          token: 'token_01',
          deviceSessionId: 'device_session_01',
          connectionStatus: WKConnectStatus.syncCompleted,
          sessionRuntimeRunning: false,
        ),
        isFalse,
      );

      expect(
        shouldReuseInitializedImSession(
          initializedUid: 'u_self',
          initializedToken: 'token_01',
          initializedDeviceSessionId: 'device_session_01',
          uid: 'u_self',
          token: 'token_01',
          deviceSessionId: 'device_session_01',
          connectionStatus: WKConnectStatus.syncCompleted,
          sessionRuntimeRunning: true,
        ),
        isTrue,
      );
    },
  );

  group('startSessionRuntimeForInit', () {
    test('returns true when native session runtime starts', () async {
      final started = await startSessionRuntimeForInit(start: () async {});

      expect(started, isTrue);
    });

    test('returns false when native session runtime throws', () async {
      Object? capturedError;

      final started = await startSessionRuntimeForInit(
        start: () async => throw StateError('handshake failed'),
        onError: (error, stackTrace) {
          capturedError = error;
        },
      );

      expect(started, isFalse);
      expect(capturedError, isA<StateError>());
    });

    test('returns false when native session runtime stalls', () async {
      final started = await startSessionRuntimeForInit(
        start: () => Completer<void>().future,
        timeout: const Duration(milliseconds: 20),
      );

      expect(started, isFalse);
    });
  });

  group('resolveImCommandSideEffects', () {
    test('friendAccept refreshes friends and friend requests', () {
      expect(
        resolveImCommandSideEffects(' friendAccept '),
        equals(<IMCommandSideEffect>{
          IMCommandSideEffect.refreshFriendList,
          IMCommandSideEffect.refreshFriendRequests,
        }),
      );
    });

    test('friendRequest refreshes friend requests only', () {
      expect(
        resolveImCommandSideEffects('friendRequest'),
        equals(<IMCommandSideEffect>{
          IMCommandSideEffect.refreshFriendRequests,
        }),
      );
    });

    test('unrelated commands do not trigger contact refresh side effects', () {
      expect(resolveImCommandSideEffects('wk_typing'), isEmpty);
    });

    test('vip_expired does not introduce extra side effects', () {
      expect(resolveImCommandSideEffects('vip_expired'), isEmpty);
    });

    test(
      'wk_sync_message_extra maps to Android message extra sync side effect',
      () {
        final sideEffectNames = resolveImCommandSideEffects(
          'wk_sync_message_extra',
        ).map((effect) => effect.name);

        expect(sideEffectNames, contains('syncMessageExtra'));
      },
    );

    test(
      'syncPinnedMessage maps to Android message extra sync side effect',
      () {
        final sideEffectNames = resolveImCommandSideEffects(
          'syncPinnedMessage',
        ).map((effect) => effect.name);

        expect(sideEffectNames, contains('syncMessageExtra'));
      },
    );

    test('syncMessageExtra maps to message extra sync side effect', () {
      final sideEffectNames = resolveImCommandSideEffects(
        'syncMessageExtra',
      ).map((effect) => effect.name);

      expect(sideEffectNames, contains('syncMessageExtra'));
    });

    test('messageRevoke maps to message extra sync side effect', () {
      final sideEffectNames = resolveImCommandSideEffects(
        'messageRevoke',
      ).map((effect) => effect.name);

      expect(sideEffectNames, contains('syncMessageExtra'));
    });

    test(
      'wk_sync_conversation_extra maps to Android conversation extra sync side effect',
      () {
        final sideEffectNames = resolveImCommandSideEffects(
          'wk_sync_conversation_extra',
        ).map((effect) => effect.name);

        expect(sideEffectNames, contains('syncConversationExtra'));
      },
    );
  });

  group('normalizeFileAttachmentMetadata', () {
    test(
      'fills missing file metadata from the local path and inferred size',
      () {
        final content = WKFileContent()..localPath = 'C:/tmp/spec.final.pdf';

        normalizeFileAttachmentMetadata(
          content,
          localPath: content.localPath,
          inferredSize: 4096,
        );

        expect(content.name, 'spec.final.pdf');
        expect(content.size, 4096);
        expect(content.suffix, 'pdf');
      },
    );

    test('keeps existing metadata when the message already defines it', () {
      final content = WKFileContent()
        ..localPath = 'C:/tmp/spec.final.pdf'
        ..name = 'custom.doc'
        ..size = 1024
        ..suffix = 'doc';

      normalizeFileAttachmentMetadata(
        content,
        localPath: content.localPath,
        inferredSize: 4096,
      );

      expect(content.name, 'custom.doc');
      expect(content.size, 1024);
      expect(content.suffix, 'doc');
    });

    test('sanitizes unsafe file metadata before upload', () {
      final content = WKFileContent()
        ..localPath = ' C:/tmp/report.final.PDF '
        ..name = r'..\..\report.final.PDF'
        ..size = -9;

      normalizeFileAttachmentMetadata(content, localPath: content.localPath);

      expect(content.name, 'report.final.PDF');
      expect(content.size, 0);
      expect(content.suffix, 'pdf');
    });
  });

  group('Task 2 parity hooks', () {
    test('background keepalive matches Android calling exception', () {
      final dynamic service = IMService();
      addTearDown(() => service.dispose());

      expect(
        service.shouldKeepConnectionInBackground(
          hasActiveCallOrPendingSetup: false,
        ),
        isFalse,
      );
      expect(
        service.shouldKeepConnectionInBackground(
          hasActiveCallOrPendingSetup: true,
        ),
        isTrue,
      );
    });

    test(
      'windows desktop notification mode keeps realtime connected in background',
      () {
        expect(
          shouldDisconnectForBackgroundLifecycle(
            isWeb: false,
            hasActiveCallOrPendingSetup: false,
            keepRealtimeForDesktopNotifications: true,
          ),
          isFalse,
        );

        expect(
          shouldDisconnectForBackgroundLifecycle(
            isWeb: false,
            hasActiveCallOrPendingSetup: false,
          ),
          isTrue,
        );
      },
    );

    test(
      'recovered channel_status restores current calls and clears stale ones',
      () {
        final dynamic service = IMService();
        addTearDown(() => service.dispose());
        final registry = ConversationActivityRegistry.instance;

        registry.setCallingState('stale_group', WKChannelType.group, true);
        final restoredKeys =
            service.applyRecoveredCallingStates(<WKChannelState>[
                  WKChannelState()
                    ..channelID = 'group_01'
                    ..channelType = WKChannelType.group
                    ..calling = 1,
                ])
                as Set<String>;

        expect(restoredKeys, {
          ConversationActivityRegistry.conversationKey(
            'group_01',
            WKChannelType.group,
          ),
        });
        expect(
          registry.getState('group_01', WKChannelType.group).isCalling,
          isTrue,
        );
        expect(
          registry.getState('stale_group', WKChannelType.group).isCalling,
          isFalse,
        );
      },
    );
  });

  group('Task 3 parity hooks', () {
    test(
      'cmd manager preserves channel target for top-level syncMessageExtra payloads',
      () {
        WKCMD? captured;
        const listenerKey = 'test_sync_message_extra_channel_target';
        WKIM.shared.cmdManager.addOnCmdListener(listenerKey, (cmd) {
          captured = cmd;
        });
        addTearDown(() {
          WKIM.shared.cmdManager.removeCmdListener(listenerKey);
        });

        WKIM.shared.cmdManager.handleCMD(<String, dynamic>{
          'cmd': 'syncMessageExtra',
          'channel_id': 'e572e880870a46ca8305a368740067ed',
          'channel_type': WKChannelType.personal,
        });

        expect(captured, isNotNull);
        expect(captured!.param, isA<Map>());
        final param = Map<String, dynamic>.from(captured!.param as Map);
        expect(param['channel_id'], 'e572e880870a46ca8305a368740067ed');
        expect(param['channel_type'], WKChannelType.personal);
      },
    );

    test('offline cmd ack sequence uses the highest synced message_seq', () {
      final dynamic service = IMService();
      addTearDown(() => service.dispose());

      final ackSeq =
          service.resolveOfflineCommandAckSequence(<dynamic>[
                <String, dynamic>{'message_seq': 11},
                <String, dynamic>{'message_seq': 27},
                <String, dynamic>{'message_seq': 19},
              ])
              as int;

      expect(ackSeq, 27);
    });

    test('vip_expired command triggers registered handler', () {
      final dynamic service = IMService();
      addTearDown(() => service.dispose());
      var triggerCount = 0;

      service.registerVipExpiredHandler(
        key: 'auth_notifier',
        handler: () {
          triggerCount += 1;
        },
      );

      final cmd = WKCMD()..cmd = ' vip_expired ';
      service.handleCmdForTesting(cmd);

      expect(triggerCount, 1);
    });

    test('vip_expired command does not trigger handler after unregister', () {
      final dynamic service = IMService();
      addTearDown(() => service.dispose());
      var triggerCount = 0;

      service.registerVipExpiredHandler(
        key: 'auth_notifier',
        handler: () {
          triggerCount += 1;
        },
      );
      service.unregisterVipExpiredHandler('auth_notifier');

      final cmd = WKCMD()..cmd = 'vip_expired';
      service.handleCmdForTesting(cmd);

      expect(triggerCount, 0);
    });
  });
}
