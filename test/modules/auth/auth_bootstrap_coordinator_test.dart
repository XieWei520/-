import 'package:flutter_test/flutter_test.dart';
import 'package:wukong_im_app/data/models/user.dart';
import 'package:wukong_im_app/modules/auth/coordinators/auth_bootstrap_coordinator.dart';
import 'package:wukong_im_app/modules/auth/domain/auth_flow_models.dart';

void main() {
  test(
    'auth stages include login verification but exclude task5 view states',
    () {
      final stageNames = AuthStage.values.map((stage) => stage.name).toSet();
      expect(stageNames.contains('awaitingLoginVerification'), isTrue);
      expect(stageNames.contains('loadingExternalLoginConfirmation'), isFalse);
      expect(stageNames.contains('managingDeviceSessions'), isFalse);
    },
  );

  test('bootstrap completes a normal login into authenticatedReady', () async {
    final calls = <String>[];
    final coordinator = AuthBootstrapCoordinator(
      persistSession: ({required uid, required token, required imToken}) async {
        calls.add('persist:$uid:$token:$imToken');
      },
      rollbackSession: () async {
        calls.add('rollback');
      },
      bindDeviceIdentity: ({required uid, required token}) async {
        calls.add('bind:$uid');
      },
      loadCurrentUser: () async {
        calls.add('load-user');
        return UserInfo(
          uid: 'u100',
          token: 't100',
          name: 'Wukong',
          avatar: 'avatar.png',
        );
      },
      initializeAuthenticatedRuntime: (user) async {
        calls.add('init-runtime:${user.uid}');
      },
      registerPush: () async => calls.add('push'),
      syncDrafts: () async => calls.add('drafts'),
    );

    final result = await coordinator.bootstrap(
      AuthCredentialResult.success(
        uid: 'u100',
        token: 't100',
        imToken: 'im100',
        user: UserInfo(uid: 'u100', token: 't100'),
      ),
    );

    expect(result.stage, AuthStage.authenticatedReady);
    expect(result.user?.uid, 'u100');
    expect(calls, <String>[
      'persist:u100:t100:im100',
      'bind:u100',
      'load-user',
      'init-runtime:u100',
      'push',
      'drafts',
    ]);
  });

  test(
    'bootstrap persists authenticated login preferences after success',
    () async {
      final calls = <String>[];
      final coordinator = AuthBootstrapCoordinator(
        persistSession:
            ({required uid, required token, required imToken}) async {
              calls.add('persist:$uid:$token:$imToken');
            },
        rollbackSession: () async {
          calls.add('rollback');
        },
        bindDeviceIdentity: ({required uid, required token}) async {
          calls.add('bind:$uid');
        },
        loadCurrentUser: () async {
          calls.add('load-user');
          return UserInfo(
            uid: 'u200',
            token: 't200',
            name: 'Test 4',
            avatar: 'avatar.png',
            phone: '19212455074',
            zone: '0086',
          );
        },
        initializeAuthenticatedRuntime: (user) async {
          calls.add('init-runtime:${user.uid}');
        },
        registerPush: () async => calls.add('push'),
        syncDrafts: () async => calls.add('drafts'),
        persistLoginPreferences: (user) async {
          calls.add('prefs:${user.phone}:${user.zone}');
        },
      );

      await coordinator.bootstrap(
        AuthCredentialResult.success(
          uid: 'u200',
          token: 't200',
          imToken: 'im200',
          user: UserInfo(uid: 'u200', token: 't200'),
        ),
      );

      expect(calls, <String>[
        'persist:u200:t200:im200',
        'bind:u200',
        'load-user',
        'init-runtime:u200',
        'push',
        'drafts',
        'prefs:19212455074:0086',
      ]);
    },
  );

  test(
    'bootstrap redirects to profile completion when required fields are missing',
    () async {
      final coordinator = AuthBootstrapCoordinator(
        persistSession:
            ({required uid, required token, required imToken}) async {},
        rollbackSession: () async {},
        bindDeviceIdentity: ({required uid, required token}) async {},
        loadCurrentUser: () async =>
            UserInfo(uid: 'u101', token: 't101', name: '', avatar: ''),
        initializeAuthenticatedRuntime: (_) async {},
        registerPush: () async {},
        syncDrafts: () async {},
      );

      final result = await coordinator.bootstrap(
        AuthCredentialResult.success(
          uid: 'u101',
          token: 't101',
          imToken: 'im101',
          user: UserInfo(uid: 'u101', token: 't101'),
        ),
      );

      expect(result.stage, AuthStage.awaitingProfileCompletion);
      expect(result.requiresProfileCompletion, isTrue);
    },
  );

  test('bootstrap rejects unsuccessful credential results', () async {
    final calls = <String>[];
    final coordinator = AuthBootstrapCoordinator(
      persistSession: ({required uid, required token, required imToken}) async {
        calls.add('persist');
      },
      rollbackSession: () async {
        calls.add('rollback');
      },
      bindDeviceIdentity: ({required uid, required token}) async {
        calls.add('bind');
      },
      loadCurrentUser: () async => UserInfo(uid: 'u'),
      initializeAuthenticatedRuntime: (_) async {
        calls.add('init-runtime');
      },
      registerPush: () async {
        calls.add('push');
      },
      syncDrafts: () async {
        calls.add('drafts');
      },
    );

    await expectLater(
      () => coordinator.bootstrap(const AuthCredentialResult.failure('nope')),
      throwsA(isA<StateError>()),
    );
    expect(calls, isEmpty);
  });

  test('bootstrap rejects blank uid or token', () async {
    final calls = <String>[];
    final coordinator = AuthBootstrapCoordinator(
      persistSession: ({required uid, required token, required imToken}) async {
        calls.add('persist');
      },
      rollbackSession: () async {
        calls.add('rollback');
      },
      bindDeviceIdentity: ({required uid, required token}) async {
        calls.add('bind');
      },
      loadCurrentUser: () async => UserInfo(uid: 'u'),
      initializeAuthenticatedRuntime: (_) async {
        calls.add('init-runtime');
      },
      registerPush: () async {
        calls.add('push');
      },
      syncDrafts: () async {
        calls.add('drafts');
      },
    );

    await expectLater(
      () => coordinator.bootstrap(
        AuthCredentialResult.success(
          uid: '  ',
          token: '',
          user: UserInfo(uid: 'u100', token: 't100'),
        ),
      ),
      throwsA(isA<StateError>()),
    );
    expect(calls, isEmpty);
  });

  test(
    'bootstrap rolls back persisted session when mid-bootstrap step fails',
    () async {
      final calls = <String>[];
      final coordinator = AuthBootstrapCoordinator(
        persistSession:
            ({required uid, required token, required imToken}) async {
              calls.add('persist:$uid:$token:$imToken');
            },
        rollbackSession: () async {
          calls.add('rollback');
        },
        bindDeviceIdentity: ({required uid, required token}) async {
          calls.add('bind:$uid');
        },
        loadCurrentUser: () async {
          calls.add('load-user');
          return UserInfo(
            uid: 'remote',
            token: 'remote-token',
            name: 'Wu',
            avatar: 'a.png',
          );
        },
        initializeAuthenticatedRuntime: (user) async {
          calls.add('init-runtime:${user.uid}:${user.token}');
        },
        registerPush: () async {
          calls.add('push');
          throw StateError('push registration failed');
        },
        syncDrafts: () async {
          calls.add('drafts');
        },
      );

      await expectLater(
        () => coordinator.bootstrap(
          AuthCredentialResult.success(
            uid: 'u500',
            token: 't500',
            imToken: 'im500',
            user: UserInfo(uid: 'u500', token: 't500'),
          ),
        ),
        throwsA(isA<StateError>()),
      );

      expect(calls, <String>[
        'persist:u500:t500:im500',
        'bind:u500',
        'load-user',
        'init-runtime:u500:t500',
        'push',
        'rollback',
      ]);
    },
  );

  test(
    'rollback can restore previous session snapshot when persistence fails early',
    () async {
      final calls = <String>[];
      var storageUid = 'old-user';
      var storageToken = 'old-token';
      var storageImToken = 'old-im-token';
      String? snapshotUid;
      String? snapshotToken;
      String? snapshotImToken;
      final coordinator = AuthBootstrapCoordinator(
        persistSession:
            ({required uid, required token, required imToken}) async {
              snapshotUid = storageUid;
              snapshotToken = storageToken;
              snapshotImToken = storageImToken;
              storageUid = uid;
              storageToken = token;
              storageImToken = imToken;
              throw StateError('persist failed');
            },
        rollbackSession: () async {
          calls.add('rollback');
          storageUid = snapshotUid ?? '';
          storageToken = snapshotToken ?? '';
          storageImToken = snapshotImToken ?? '';
        },
        bindDeviceIdentity: ({required uid, required token}) async {
          calls.add('bind');
        },
        loadCurrentUser: () async => UserInfo(uid: 'u'),
        initializeAuthenticatedRuntime: (_) async {
          calls.add('init-runtime');
        },
        registerPush: () async {
          calls.add('push');
        },
        syncDrafts: () async {
          calls.add('drafts');
        },
      );

      await expectLater(
        () => coordinator.bootstrap(
          AuthCredentialResult.success(
            uid: 'new-user',
            token: 'new-token',
            imToken: 'new-im-token',
            user: UserInfo(uid: 'new-user', token: 'new-token'),
          ),
        ),
        throwsA(isA<StateError>()),
      );

      expect(calls, <String>['rollback']);
      expect(storageUid, 'old-user');
      expect(storageToken, 'old-token');
      expect(storageImToken, 'old-im-token');
    },
  );
}
