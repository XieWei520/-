import 'package:meta/meta.dart';

import 'slot_descriptor.dart';
import 'slot_entry.dart';

typedef DisposeCallback = void Function();

class SlotRegistry {
  final Map<_SlotKey, List<_SlotRecord<Object?, Object?>>> _records =
      <_SlotKey, List<_SlotRecord<Object?, Object?>>>{};
  int _nextSequence = 0;

  SlotRegistration register<TContext, TPayload>(
    SlotDescriptor<TContext, TPayload> descriptor,
    SlotEntry<TContext, TPayload> entry, {
    Object owner = 'global',
  }) {
    final key = _descriptorKey(descriptor);
    final list = _records.putIfAbsent(
      key,
      () => <_SlotRecord<Object?, Object?>>[],
    );
    final record = _SlotRecord<TContext, TPayload>(
      owner: owner,
      descriptor: descriptor,
      entry: entry,
      sequence: _nextSequence++,
    );
    list.add(record);
    return SlotRegistration._(() {
      list.remove(record);
      final activeList = _records[key];
      if (list.isEmpty && identical(activeList, list)) {
        _records.remove(key);
      }
    });
  }

  List<TPayload> resolve<TContext, TPayload>(
    SlotDescriptor<TContext, TPayload> descriptor,
    TContext context,
  ) {
    final list = _records[_descriptorKey(descriptor)];
    if (list == null || list.isEmpty) {
      return List<TPayload>.empty(growable: false);
    }

    final typed = list.cast<_SlotRecord<TContext, TPayload>>().toList()
      ..sort((left, right) {
        final priorityCompare =
            right.entry.priority.compareTo(left.entry.priority);
        if (priorityCompare != 0) {
          return priorityCompare;
        }
        return left.sequence.compareTo(right.sequence);
      });

    return typed
        .where((record) => record.entry.matches(context))
        .map((record) => record.entry.build(context))
        .toList(growable: false);
  }

  bool containsId<TContext, TPayload>(
    SlotDescriptor<TContext, TPayload> descriptor,
    String id,
  ) {
    final list = _records[_descriptorKey(descriptor)];
    if (list == null) {
      return false;
    }
    return list.any((record) => record.entry.id == id);
  }

  SlotScope scope(Object owner) => SlotScope._(this, owner);

  void unregisterOwner(Object owner) {
    final keys = _records.keys.toList(growable: false);
    for (final key in keys) {
      final list = _records[key];
      if (list == null) {
        continue;
      }
      list.removeWhere((record) => _ownerMatches(record.owner, owner));
      if (list.isEmpty) {
        _records.remove(key);
      }
    }
  }

  bool _ownerMatches(Object recordOwner, Object owner) {
    if (recordOwner is String && owner is String) {
      return recordOwner == owner;
    }
    return identical(recordOwner, owner);
  }

  _SlotKey _descriptorKey<TContext, TPayload>(
    SlotDescriptor<TContext, TPayload> descriptor,
  ) {
    return _SlotKey(
      name: descriptor.name,
      contextType: descriptor.contextType,
      payloadType: descriptor.payloadType,
    );
  }
}

class SlotScope {
  SlotScope._(this._registry, this._owner);

  final SlotRegistry _registry;
  final Object _owner;

  SlotRegistration register<TContext, TPayload>(
    SlotDescriptor<TContext, TPayload> descriptor,
    SlotEntry<TContext, TPayload> entry,
  ) {
    return _registry.register(descriptor, entry, owner: _owner);
  }

  void dispose() {
    _registry.unregisterOwner(_owner);
  }
}

class SlotRegistration {
  SlotRegistration._(this._dispose);

  final DisposeCallback _dispose;
  bool _disposed = false;

  void dispose() {
    if (_disposed) {
      return;
    }
    _disposed = true;
    _dispose();
  }
}

class _SlotRecord<TContext, TPayload> {
  const _SlotRecord({
    required this.owner,
    required this.descriptor,
    required this.entry,
    required this.sequence,
  });

  final Object owner;
  final SlotDescriptor<TContext, TPayload> descriptor;
  final SlotEntry<TContext, TPayload> entry;
  final int sequence;
}

@immutable
class _SlotKey {
  const _SlotKey({
    required this.name,
    required this.contextType,
    required this.payloadType,
  });

  final String name;
  final Type contextType;
  final Type payloadType;

  @override
  bool operator ==(Object other) {
    return other is _SlotKey &&
        other.name == name &&
        other.contextType == contextType &&
        other.payloadType == payloadType;
  }

  @override
  int get hashCode => Object.hash(name, contextType, payloadType);
}
