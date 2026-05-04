import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wukongimfluttersdk/entity/channel.dart';
import 'package:wukongimfluttersdk/type/const.dart';
import 'package:wukongimfluttersdk/wkim.dart';

import '../../core/config/im_config.dart';

@immutable
class ContactPresenceState {
  const ContactPresenceState({
    this.online = false,
    this.lastOffline = 0,
    this.deviceFlag = IMConfig.deviceFlagApp,
  });

  final bool online;
  final int lastOffline;
  final int deviceFlag;

  factory ContactPresenceState.fromChannel(WKChannel channel) {
    return ContactPresenceState(
      online: channel.online == 1,
      lastOffline: channel.lastOffline,
      deviceFlag: channel.deviceFlag,
    );
  }
}

typedef ContactPresenceLoader = Future<ContactPresenceState?> Function(
  String uid,
);

final contactsPresenceControllerProvider = StateNotifierProvider.autoDispose<
  ContactsPresenceController,
  Map<String, ContactPresenceState>
>((ref) {
  return ContactsPresenceController(
    loader: (uid) async {
      final channel = await WKIM.shared.channelManager.getChannel(
        uid,
        WKChannelType.personal,
      );
      if (channel == null) {
        return null;
      }
      return ContactPresenceState.fromChannel(channel);
    },
  );
});

class ContactsPresenceController
    extends StateNotifier<Map<String, ContactPresenceState>> {
  ContactsPresenceController({required ContactPresenceLoader loader})
    : _loader = loader,
      super(const {});

  final ContactPresenceLoader _loader;
  String _signature = '';
  int _generation = 0;
  final Map<String, int> _revisionsByUid = <String, int>{};

  void syncPresence(Iterable<String> uids) {
    final normalizedUids = uids
        .map((uid) => uid.trim())
        .where((uid) => uid.isNotEmpty)
        .toSet()
        .toList(growable: false);
    final signature = normalizedUids.join('|');
    if (signature == _signature) {
      return;
    }

    _signature = signature;
    final generation = ++_generation;
    if (normalizedUids.isEmpty) {
      state = const {};
      return;
    }

    unawaited(_load(normalizedUids, generation, _captureRevisions(normalizedUids)));
  }

  void updatePresence(String uid, ContactPresenceState nextState) {
    final normalizedUid = uid.trim();
    if (normalizedUid.isEmpty) {
      return;
    }

    final previousState = state[normalizedUid];
    if (previousState != null &&
        previousState.online == nextState.online &&
        previousState.lastOffline == nextState.lastOffline &&
        previousState.deviceFlag == nextState.deviceFlag) {
      return;
    }

    _revisionsByUid[normalizedUid] = (_revisionsByUid[normalizedUid] ?? 0) + 1;
    state = <String, ContactPresenceState>{
      ...state,
      normalizedUid: nextState,
    };
  }

  void reset() {
    _signature = '';
    _generation++;
    _revisionsByUid.clear();
    state = const {};
  }

  Map<String, int> _captureRevisions(List<String> uids) {
    return <String, int>{
      for (final uid in uids) uid: _revisionsByUid[uid] ?? 0,
    };
  }

  Future<void> _load(
    List<String> uids,
    int generation,
    Map<String, int> revisionsAtLoadStart,
  ) async {
    final loadedState = <String, ContactPresenceState>{};
    for (final uid in uids) {
      final presence = await _loader(uid);
      if (presence != null) {
        loadedState[uid] = presence;
      }
    }

    if (generation != _generation) {
      return;
    }

    final currentState = state;
    final nextState = <String, ContactPresenceState>{};
    for (final uid in uids) {
      final initialRevision = revisionsAtLoadStart[uid] ?? 0;
      final currentRevision = _revisionsByUid[uid] ?? 0;
      if (currentRevision != initialRevision) {
        final refreshedPresence = currentState[uid];
        if (refreshedPresence != null) {
          nextState[uid] = refreshedPresence;
        }
        continue;
      }

      final loadedPresence = loadedState[uid];
      if (loadedPresence != null) {
        nextState[uid] = loadedPresence;
      }
    }
    state = nextState;
  }
}
