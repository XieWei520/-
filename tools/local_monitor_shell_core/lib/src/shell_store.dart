import 'dart:convert';
import 'dart:async';
import 'dart:io';

import 'shell_models.dart';

typedef ShellSnapshotMutator =
    FutureOr<ShellSnapshot> Function(ShellSnapshot snapshot);

class ShellStore {
  ShellStore(
    this.snapshotFile, {
    DateTime Function()? clock,
    this.captureRetention = defaultLocalCaptureRetention,
  }) : _clock = clock ?? DateTime.now;

  static const List<Duration> _replaceRetryDelays = <Duration>[
    Duration(milliseconds: 25),
    Duration(milliseconds: 50),
    Duration(milliseconds: 100),
    Duration(milliseconds: 200),
    Duration(milliseconds: 400),
  ];

  final File snapshotFile;
  final Duration captureRetention;
  final DateTime Function() _clock;
  Future<void> _writeQueue = Future<void>.value();

  Future<ShellSnapshot> load() async {
    await _writeQueue;
    return _loadUnlocked();
  }

  Future<ShellSnapshot> _loadUnlocked() async {
    if (!await snapshotFile.exists()) {
      final initial = ShellSnapshot.initial();
      await save(initial);
      return initial;
    }
    final raw = await snapshotFile.readAsString();
    final snapshot = ShellSnapshot.fromJsonString(raw);
    final pruned = _pruneCaptureRecords(snapshot);
    if (!identical(pruned, snapshot)) {
      await save(pruned);
    }
    return pruned;
  }

  Future<void> save(ShellSnapshot snapshot) async {
    final retainedSnapshot = _pruneCaptureRecords(snapshot);
    final directory = snapshotFile.parent;
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }
    final tempFile = File(
      '${snapshotFile.path}.tmp-${DateTime.now().microsecondsSinceEpoch}',
    );
    await tempFile.writeAsString(
      jsonEncode(retainedSnapshot.toJson()),
      flush: true,
    );
    try {
      await _replaceSnapshotFile(tempFile);
    } catch (_) {
      await _deleteTempFileIfPresent(tempFile);
      rethrow;
    }
  }

  Future<void> _replaceSnapshotFile(File tempFile) async {
    for (var attempt = 0; ; attempt += 1) {
      try {
        await tempFile.rename(snapshotFile.path);
        return;
      } on FileSystemException catch (error) {
        if (!_shouldRetryReplace(error) ||
            attempt >= _replaceRetryDelays.length) {
          rethrow;
        }
        await Future<void>.delayed(_replaceRetryDelays[attempt]);
      }
    }
  }

  bool _shouldRetryReplace(FileSystemException error) {
    return Platform.isWindows &&
        (error is PathAccessException ||
            error.osError?.errorCode == 5 ||
            error.osError?.errorCode == 32);
  }

  Future<void> _deleteTempFileIfPresent(File tempFile) async {
    try {
      if (await tempFile.exists()) {
        await tempFile.delete();
      }
    } catch (_) {
      // A stale temp file is less harmful than masking the original write error.
    }
  }

  Future<ShellSnapshot> update(
    ShellSnapshotMutator mutate, {
    bool preserveCaptureState = true,
  }) {
    final completer = Completer<ShellSnapshot>();
    _writeQueue = _writeQueue
        .then((_) async {
          final current = await _loadUnlocked();
          final updated = await mutate(current);
          final next = preserveCaptureState
              ? updated.copyWith(captureState: current.captureState)
              : updated;
          final retainedNext = _pruneCaptureRecords(next);
          await save(retainedNext);
          completer.complete(retainedNext);
        })
        .catchError((Object error, StackTrace stackTrace) {
          if (!completer.isCompleted) {
            completer.completeError(error, stackTrace);
          }
        });
    return completer.future;
  }

  ShellSnapshot _pruneCaptureRecords(ShellSnapshot snapshot) {
    return pruneExpiredLocalCaptureRecords(
      snapshot,
      now: _clock(),
      retention: captureRetention,
    );
  }
}
