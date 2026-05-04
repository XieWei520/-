import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wukong_im_app/service/api/login_bridge_api.dart';
import 'package:wukong_im_app/wukong_login/pc_login_service.dart';

void main() {
  test('requestPCLoginQRCode delegates to LoginBridgeApi.getLoginUuid', () async {
    final service = PCLoginService(
      requestLoginUuid: () async => const LoginUuidResult(
        uuid: 'uuid-1',
        qrcode: 'https://example.com/qr/uuid-1',
      ),
      pollLoginStatus: (_) async => const LoginStatusResult(
        status: 'authed',
        authCode: 'auth-1',
      ),
      loadDevices: () async => const <LoginBridgeDeviceRecord>[
        LoginBridgeDeviceRecord(
          id: 1,
          deviceId: 'desktop-1',
          deviceName: 'MacBook Pro (local)',
          deviceModel: 'macOS',
          lastLogin: '2026-04-08 10:00',
          self: true,
        ),
      ],
      deleteDevice: (_) async {},
      quitPcWeb: () async {},
      pollInterval: const Duration(milliseconds: 1),
    );

    final scene = await service.requestPCLoginQRCode();
    final sessions = await service.getSessions();

    expect(scene, 'uuid-1');
    expect(sessions.single.deviceId, 'desktop-1');
    expect(sessions.single.deviceType, 'macOS');
  });

  test('logoutAllSessions and logoutSession delegate to bridge callbacks', () async {
    final calls = <String>[];
    final service = PCLoginService(
      requestLoginUuid: () async => const LoginUuidResult(
        uuid: 'uuid-1',
        qrcode: 'https://example.com/qr/uuid-1',
      ),
      pollLoginStatus: (_) async => const LoginStatusResult(status: 'waitScan'),
      loadDevices: () async => const <LoginBridgeDeviceRecord>[],
      deleteDevice: (deviceId) async => calls.add('delete:$deviceId'),
      quitPcWeb: () async => calls.add('quit-all'),
    );

    await service.logoutSession('desktop-9');
    await service.logoutAllSessions();

    expect(calls, <String>['delete:desktop-9', 'quit-all']);
  });

  test(
    'startPollingLoginStatus avoids overlap, ignores transient poll errors, and stops after success',
    () {
      fakeAsync((async) {
        final firstPoll = Completer<LoginStatusResult>();
        var pollCalls = 0;
        var inFlight = 0;
        var maxInFlight = 0;
        var callbackCalls = 0;
        String? callbackAuthCode;

        final service = PCLoginService(
          requestLoginUuid: () async => const LoginUuidResult(
            uuid: 'uuid-1',
            qrcode: 'https://example.com/qr/uuid-1',
          ),
          pollLoginStatus: (_) async {
            pollCalls += 1;
            inFlight += 1;
            if (inFlight > maxInFlight) {
              maxInFlight = inFlight;
            }

            try {
              if (pollCalls == 1) {
                return firstPoll.future;
              }
              if (pollCalls == 2) {
                throw StateError('temporary poll failure');
              }
              return const LoginStatusResult(status: 'authed', authCode: 'auth-2');
            } finally {
              inFlight -= 1;
            }
          },
          loadDevices: () async => const <LoginBridgeDeviceRecord>[],
          deleteDevice: (_) async {},
          quitPcWeb: () async {},
          pollInterval: const Duration(milliseconds: 1),
        );
        service.onLoginStatusChanged = (success, authCode) {
          if (!success) {
            return;
          }
          callbackCalls += 1;
          callbackAuthCode = authCode;
        };

        service.startPollingLoginStatus('scene-1');
        async.elapse(const Duration(milliseconds: 1));
        async.flushMicrotasks();

        async.elapse(const Duration(milliseconds: 5));
        async.flushMicrotasks();
        expect(maxInFlight, 1);

        firstPoll.complete(const LoginStatusResult(status: 'waitScan'));
        async.flushMicrotasks();

        async.elapse(const Duration(milliseconds: 1));
        async.flushMicrotasks();
        async.elapse(const Duration(milliseconds: 1));
        async.flushMicrotasks();

        expect(callbackCalls, 1);
        expect(callbackAuthCode, 'auth-2');

        final callsAfterSuccess = pollCalls;
        async.elapse(const Duration(milliseconds: 5));
        async.flushMicrotasks();
        expect(pollCalls, callsAfterSuccess);

        service.stopPollingLoginStatus();
      });
    },
  );

  test(
    'stale poll response from old cycle is ignored after stop and restart',
    () {
      fakeAsync((async) {
        final oldCyclePoll = Completer<LoginStatusResult>();
        final callbackAuthCodes = <String?>[];
        var pollCalls = 0;

        final service = PCLoginService(
          requestLoginUuid: () async => const LoginUuidResult(
            uuid: 'uuid-1',
            qrcode: 'https://example.com/qr/uuid-1',
          ),
          pollLoginStatus: (_) async {
            pollCalls += 1;
            if (pollCalls == 1) {
              return oldCyclePoll.future;
            }
            if (pollCalls == 2) {
              return const LoginStatusResult(status: 'authed', authCode: 'auth-new');
            }
            return const LoginStatusResult(status: 'waitScan');
          },
          loadDevices: () async => const <LoginBridgeDeviceRecord>[],
          deleteDevice: (_) async {},
          quitPcWeb: () async {},
          pollInterval: const Duration(milliseconds: 1),
        );
        service.onLoginStatusChanged = (success, authCode) {
          if (success) {
            callbackAuthCodes.add(authCode);
          }
        };

        service.startPollingLoginStatus('scene-old');
        async.elapse(const Duration(milliseconds: 1));
        async.flushMicrotasks();
        expect(pollCalls, 1);

        service.stopPollingLoginStatus();
        service.startPollingLoginStatus('scene-new');
        async.elapse(const Duration(milliseconds: 1));
        async.flushMicrotasks();
        expect(callbackAuthCodes, <String?>['auth-new']);

        oldCyclePoll.complete(
          const LoginStatusResult(status: 'authed', authCode: 'auth-old'),
        );
        async.flushMicrotasks();

        expect(callbackAuthCodes, <String?>['auth-new']);

        service.stopPollingLoginStatus();
      });
    },
  );
}
