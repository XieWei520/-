import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'geolocator plugin is isolated behind the location position service',
    () {
      final allowedPath = _normalizePath(
        'lib/modules/location/location_position_service.dart',
      );
      final offenders = Directory('lib')
          .listSync(recursive: true)
          .whereType<File>()
          .where((file) => file.path.endsWith('.dart'))
          .where((file) {
            final normalizedPath = _normalizePath(file.path);
            if (normalizedPath == allowedPath) {
              return false;
            }
            return file.readAsStringSync().contains('package:geolocator');
          })
          .map((file) => _normalizePath(file.path))
          .toList(growable: false);

      expect(offenders, isEmpty);
    },
  );

  test('location service uses geolocator LocationSettings API', () {
    final source = File(
      'lib/modules/location/location_position_service.dart',
    ).readAsStringSync();

    expect(source, contains('locationSettings:'));
    expect(source, isNot(contains('desiredAccuracy:')));
  });
}

String _normalizePath(String value) => value.replaceAll(r'\', '/');
