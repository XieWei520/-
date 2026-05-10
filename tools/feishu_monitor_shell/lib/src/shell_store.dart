import 'dart:convert';
import 'dart:io';

import 'shell_models.dart';

class ShellStore {
  ShellStore(this.snapshotFile);

  final File snapshotFile;

  Future<ShellSnapshot> load() async {
    if (!await snapshotFile.exists()) {
      final initial = ShellSnapshot.initial();
      await save(initial);
      return initial;
    }
    final raw = await snapshotFile.readAsString();
    return ShellSnapshot.fromJsonString(raw);
  }

  Future<void> save(ShellSnapshot snapshot) async {
    final directory = snapshotFile.parent;
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }
    await snapshotFile.writeAsString(jsonEncode(snapshot.toJson()));
  }
}
