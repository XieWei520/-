import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:wukong_im_app/modules/contacts/contacts_presence_controller.dart';

void main() {
  test('suppresses stale presence loads', () async {
    final completers = <Completer<ContactPresenceState?>>[];
    final requestedUids = <String>[];

    Future<ContactPresenceState?> loader(String uid) {
      requestedUids.add(uid);
      final completer = Completer<ContactPresenceState?>();
      completers.add(completer);
      return completer.future;
    }

    final controller = ContactsPresenceController(loader: loader);

    controller.syncPresence(const ['u_1']);
    controller.syncPresence(const ['u_2']);

    expect(requestedUids, ['u_1', 'u_2']);

    completers[0].complete(const ContactPresenceState(online: true));
    await Future<void>.delayed(Duration.zero);
    expect(controller.state, isEmpty);

    completers[1].complete(const ContactPresenceState(online: true));
    await Future<void>.delayed(Duration.zero);
    expect(controller.state.keys, ['u_2']);
  });

  test('does not let in-flight loads overwrite refreshed presence', () async {
    final completer = Completer<ContactPresenceState?>();

    final controller = ContactsPresenceController(
      loader: (_) => completer.future,
    );

    controller.syncPresence(const ['u_1']);
    controller.updatePresence(
      'u_1',
      const ContactPresenceState(
        online: false,
        lastOffline: 42,
      ),
    );

    completer.complete(const ContactPresenceState(online: true));
    await Future<void>.delayed(Duration.zero);

    final state = controller.state['u_1'];
    expect(state, isNotNull);
    expect(state!.online, isFalse);
    expect(state.lastOffline, 42);
  });
}
