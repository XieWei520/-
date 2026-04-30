import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('unused device info plugin is not kept as a direct web dependency', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();

    expect(pubspec, isNot(contains('device_info_plus:')));
  });

  test('geolocator web implementation stays on the web-package line', () {
    final lockfile = File('pubspec.lock').readAsStringSync();
    final version = _lockedPackageVersion(lockfile, 'geolocator_web');

    expect(version, isNotNull);
    expect(
      _compareSemver(version!, '4.1.1'),
      greaterThanOrEqualTo(0),
      reason:
          'geolocator_web 3.x imports dart:html and blocks future Wasm builds.',
    );
  });

  test('device info web implementation stays on js interop package line', () {
    final lockfile = File('pubspec.lock').readAsStringSync();
    final version = _lockedPackageVersion(lockfile, 'device_info_plus');

    expect(version, isNotNull);
    expect(
      _compareSemver(version!, '11.3.0'),
      greaterThanOrEqualTo(0),
      reason:
          'device_info_plus before 11.3.0 keeps a dart:html web entrypoint '
          'that blocks future Wasm builds.',
    );
  });
}

String? _lockedPackageVersion(String lockfile, String packageName) {
  final match = RegExp(
    '^  ${RegExp.escape(packageName)}:\\n'
    r'(?:(?:    .*)\n)*?'
    r'    version: "([^"]+)"',
    multiLine: true,
  ).firstMatch(lockfile);
  return match?.group(1);
}

int _compareSemver(String left, String right) {
  final leftParts = _parseSemver(left);
  final rightParts = _parseSemver(right);
  for (var index = 0; index < 3; index += 1) {
    final diff = leftParts[index] - rightParts[index];
    if (diff != 0) {
      return diff;
    }
  }
  return 0;
}

List<int> _parseSemver(String value) {
  final core = value.split(RegExp(r'[-+]')).first;
  final parts = core.split('.');
  return <int>[
    for (var index = 0; index < 3; index += 1)
      index < parts.length ? int.tryParse(parts[index]) ?? 0 : 0,
  ];
}
