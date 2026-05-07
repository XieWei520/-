import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wukong_im_app/data/models/group.dart';
import 'package:wukong_im_app/data/models/user.dart';
import 'package:wukong_im_app/modules/conversation/conversation_metadata_resolver.dart';

void main() {
  group('ConversationMetadataResolver', () {
    test('coalesces duplicate in-flight personal loads', () async {
      final completer = Completer<UserInfo?>();
      var calls = 0;
      final resolver = ConversationMetadataResolver(
        personalLoader: (uid) {
          calls += 1;
          return completer.future;
        },
        groupLoader: (_) async => null,
      );

      final first = resolver.loadPersonal('u_alice');
      final second = resolver.loadPersonal(' u_alice ');

      expect(identical(first, second), isTrue);
      expect(calls, 1);

      completer.complete(UserInfo(uid: 'u_alice', name: 'Alice'));
      expect((await first)?.name, 'Alice');
      expect((await second)?.name, 'Alice');
      expect(calls, 1);
    });

    test('legacy loadPersonalInfo API coalesces duplicate requests', () async {
      final resolver = ConversationMetadataResolver();
      final completer = Completer<UserInfo?>();
      var calls = 0;

      Future<UserInfo?> load(String uid) {
        calls += 1;
        return completer.future;
      }

      final first = resolver.loadPersonalInfo(' u_alice ', load);
      final second = resolver.loadPersonalInfo('u_alice', load);

      expect(identical(first, second), isTrue);
      expect(calls, 1);

      completer.complete(UserInfo(uid: 'u_alice', name: 'Alice'));
      expect((await first)?.name, 'Alice');
      expect((await second)?.name, 'Alice');
    });

    test('serves cached personal loads until ttl expires', () async {
      var now = DateTime.utc(2026, 4, 24, 10);
      var calls = 0;
      final resolver = ConversationMetadataResolver(
        ttl: const Duration(minutes: 5),
        now: () => now,
        personalLoader: (uid) async {
          calls += 1;
          return UserInfo(uid: uid, name: 'Alice $calls');
        },
        groupLoader: (_) async => null,
      );

      expect((await resolver.loadPersonal('u_alice'))?.name, 'Alice 1');
      expect((await resolver.loadPersonal('u_alice'))?.name, 'Alice 1');
      expect(calls, 1);

      now = now.add(const Duration(minutes: 6));
      expect((await resolver.loadPersonal('u_alice'))?.name, 'Alice 2');
      expect(calls, 2);
    });

    test('serves cached group metadata until the ttl expires', () async {
      var now = DateTime(2026, 4, 27, 12);
      final resolver = ConversationMetadataResolver(
        cacheTtl: const Duration(minutes: 5),
        now: () => now,
      );
      var calls = 0;

      Future<GroupInfo?> load(String groupNo) async {
        calls += 1;
        return GroupInfo(groupNo: groupNo, name: 'Group $calls');
      }

      final first = await resolver.loadGroupInfo('g_demo', load);
      final second = await resolver.loadGroupInfo(' g_demo ', load);
      now = now.add(const Duration(minutes: 6));
      final third = await resolver.loadGroupInfo('g_demo', load);

      expect(first?.name, 'Group 1');
      expect(second?.name, 'Group 1');
      expect(third?.name, 'Group 2');
      expect(calls, 2);
    });

    test('does not cache failed personal loads', () async {
      var calls = 0;
      final resolver = ConversationMetadataResolver(
        personalLoader: (_) async {
          calls += 1;
          if (calls == 1) throw StateError('temporary failure');
          return UserInfo(uid: 'u_alice', name: 'Recovered Alice');
        },
        groupLoader: (_) async => null,
      );

      expect(await resolver.loadPersonal('u_alice'), isNull);
      expect((await resolver.loadPersonal('u_alice'))?.name, 'Recovered Alice');
      expect(calls, 2);
    });

    test('does not cache synchronously thrown personal loads', () async {
      var calls = 0;
      final resolver = ConversationMetadataResolver(
        personalLoader: (uid) {
          calls += 1;
          if (calls == 1) {
            throw StateError('temporary sync failure');
          }
          return Future<UserInfo?>.value(
            UserInfo(uid: uid, name: 'Recovered Alice'),
          );
        },
        groupLoader: (_) async => null,
      );

      expect(await resolver.loadPersonal('u_alice'), isNull);
      expect((await resolver.loadPersonal('u_alice'))?.name, 'Recovered Alice');
      expect(calls, 2);
    });

    test('synchronous futures complete safely and cache values', () async {
      var personalCalls = 0;
      var groupCalls = 0;
      final resolver = ConversationMetadataResolver(
        personalLoader: (uid) {
          personalCalls += 1;
          return SynchronousFuture<UserInfo?>(
            UserInfo(uid: uid, name: 'Sync Alice $personalCalls'),
          );
        },
        groupLoader: (groupNo) {
          groupCalls += 1;
          return SynchronousFuture<GroupInfo?>(
            GroupInfo(groupNo: groupNo, name: 'Sync Group $groupCalls'),
          );
        },
      );

      expect((await resolver.loadPersonal('u_alice'))?.name, 'Sync Alice 1');
      expect((await resolver.loadPersonal(' u_alice '))?.name, 'Sync Alice 1');
      expect(personalCalls, 1);

      expect((await resolver.loadGroup('g_demo'))?.name, 'Sync Group 1');
      expect((await resolver.loadGroup(' g_demo '))?.name, 'Sync Group 1');
      expect(groupCalls, 1);
    });

    test(
      'evicts least recently used personal metadata entries over budget',
      () async {
        final resolver = ConversationMetadataResolver(maxCacheEntries: 2);
        var calls = 0;

        Future<UserInfo?> load(String uid) async {
          calls += 1;
          return UserInfo(uid: uid, name: '$uid-$calls');
        }

        final first = await resolver.loadPersonalInfo('u1', load);
        await resolver.loadPersonalInfo('u2', load);
        final cachedFirst = await resolver.loadPersonalInfo('u1', load);
        await resolver.loadPersonalInfo('u3', load);
        final reloadedSecond = await resolver.loadPersonalInfo('u2', load);

        expect(identical(first, cachedFirst), isTrue);
        expect(reloadedSecond?.name, 'u2-4');
        expect(resolver.personalCacheSizeForTesting, 2);
        expect(calls, 4);
      },
    );

    test(
      'evicts least recently used group metadata entries over budget',
      () async {
        final resolver = ConversationMetadataResolver(maxCacheEntries: 1);

        Future<GroupInfo?> load(String groupNo) async {
          return GroupInfo(groupNo: groupNo, name: 'Group $groupNo');
        }

        await resolver.loadGroupInfo('g1', load);
        await resolver.loadGroupInfo('g2', load);

        expect(resolver.groupCacheSizeForTesting, 1);
      },
    );

    test('loader failures resolve null and allow later retry', () async {
      final resolver = ConversationMetadataResolver();
      var personalCalls = 0;
      var groupCalls = 0;

      Future<UserInfo?> loadPersonal(String uid) async {
        personalCalls += 1;
        if (personalCalls == 1) {
          throw StateError('temporary personal failure');
        }
        return UserInfo(uid: uid, name: 'Recovered Alice');
      }

      Future<GroupInfo?> loadGroup(String groupNo) async {
        groupCalls += 1;
        if (groupCalls == 1) {
          throw StateError('temporary group failure');
        }
        return GroupInfo(groupNo: groupNo, name: 'Recovered Group');
      }

      expect(await resolver.loadPersonalInfo('u_alice', loadPersonal), isNull);
      expect(
        (await resolver.loadPersonalInfo('u_alice', loadPersonal))?.name,
        'Recovered Alice',
      );
      expect(await resolver.loadGroupInfo('g_demo', loadGroup), isNull);
      expect(
        (await resolver.loadGroupInfo('g_demo', loadGroup))?.name,
        'Recovered Group',
      );
      expect(personalCalls, 2);
      expect(groupCalls, 2);
    });

    test(
      'clear while personal load is in-flight prevents stale cache writes',
      () async {
        final firstCompleter = Completer<UserInfo?>();
        var calls = 0;
        final resolver = ConversationMetadataResolver(
          personalLoader: (uid) {
            calls += 1;
            if (calls == 1) return firstCompleter.future;
            return Future<UserInfo?>.value(
              UserInfo(uid: uid, name: 'Fresh Alice'),
            );
          },
          groupLoader: (_) async => null,
        );

        final first = resolver.loadPersonal('u_alice');
        resolver.clear();

        firstCompleter.complete(UserInfo(uid: 'u_alice', name: 'Stale Alice'));
        await first;

        expect((await resolver.loadPersonal('u_alice'))?.name, 'Fresh Alice');
        expect(calls, 2);
      },
    );

    test(
      'stale personal completion does not remove newer in-flight load',
      () async {
        final firstCompleter = Completer<UserInfo?>();
        final secondCompleter = Completer<UserInfo?>();
        var calls = 0;
        final resolver = ConversationMetadataResolver(
          personalLoader: (_) {
            calls += 1;
            if (calls == 1) return firstCompleter.future;
            return secondCompleter.future;
          },
          groupLoader: (_) async => null,
        );

        final first = resolver.loadPersonal('u_alice');
        resolver.clear();
        final second = resolver.loadPersonal('u_alice');

        firstCompleter.complete(null);
        expect(await first, isNull);

        final third = resolver.loadPersonal('u_alice');

        expect(identical(second, third), isTrue);
        expect(calls, 2);

        secondCompleter.complete(
          UserInfo(uid: 'u_alice', name: 'Current Alice'),
        );
        expect((await third)?.name, 'Current Alice');
      },
    );

    test('coalesces duplicate in-flight group loads', () async {
      final completer = Completer<GroupInfo?>();
      var calls = 0;
      final resolver = ConversationMetadataResolver(
        personalLoader: (_) async => null,
        groupLoader: (groupNo) {
          calls += 1;
          return completer.future;
        },
      );

      final first = resolver.loadGroup('g_demo');
      final second = resolver.loadGroup(' g_demo ');

      expect(identical(first, second), isTrue);
      expect(calls, 1);

      completer.complete(GroupInfo(groupNo: 'g_demo', name: 'Group 1'));
      expect((await second)?.name, 'Group 1');
      expect(calls, 1);
    });

    test('serves cached group loads until cleared', () async {
      var calls = 0;
      final resolver = ConversationMetadataResolver(
        personalLoader: (_) async => null,
        groupLoader: (groupNo) async {
          calls += 1;
          return GroupInfo(groupNo: groupNo, name: 'Group $calls');
        },
      );

      expect((await resolver.loadGroup('g_demo'))?.name, 'Group 1');
      expect((await resolver.loadGroup('g_demo'))?.name, 'Group 1');
      expect(calls, 1);

      resolver.clear();
      expect((await resolver.loadGroup('g_demo'))?.name, 'Group 2');
      expect(calls, 2);
    });

    test('empty ids return null without calling loaders', () async {
      var personalCalls = 0;
      var groupCalls = 0;
      final resolver = ConversationMetadataResolver(
        personalLoader: (_) async {
          personalCalls += 1;
          return null;
        },
        groupLoader: (_) async {
          groupCalls += 1;
          return null;
        },
      );

      expect(await resolver.loadPersonal('   '), isNull);
      expect(await resolver.loadGroup(''), isNull);
      expect(personalCalls, 0);
      expect(groupCalls, 0);
    });
  });
}
