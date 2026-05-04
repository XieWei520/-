import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('file picker plugin is isolated behind the platform adapter', () {
    final allowedPath = _normalizePath('lib/core/platform/local_file_picker.dart');
    final offenders = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) => file.path.endsWith('.dart'))
        .where((file) {
          final normalizedPath = _normalizePath(file.path);
          if (normalizedPath == allowedPath) {
            return false;
          }
          return file.readAsStringSync().contains('package:file_picker');
        })
        .map((file) => _normalizePath(file.path))
        .toList(growable: false);

    expect(offenders, isEmpty);
  });
}

String _normalizePath(String value) => value.replaceAll(r'\', '/');
