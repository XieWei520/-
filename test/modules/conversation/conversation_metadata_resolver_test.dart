import 'dart:async';

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
      expect((await second)?.name, 'Alice');
      expect(calls, 1);
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

    test('coalesces and clears group loads', () async {
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
