import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:wukong_im_app/data/models/group.dart';
import 'package:wukong_im_app/data/models/user.dart';
import 'package:wukong_im_app/modules/conversation/conversation_metadata_resolver.dart';

void main() {
  test('deduplicates in-flight personal metadata requests', () async {
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
}
