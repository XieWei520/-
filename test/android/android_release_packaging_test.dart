import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Android Gradle marks public release without declaring ABI splits', () {
    final gradle = File('android/app/build.gradle.kts').readAsStringSync();

    expect(gradle, contains('wkPublicRelease'));
    expect(gradle, isNot(contains('abiFilters')));
    expect(gradle, isNot(contains('splits')));
  });

  test('public release script builds only arm ABI split APKs', () {
    final script = File(
      'scripts/ops/build_android_public_release.ps1',
    ).readAsStringSync();

    expect(script, contains(r"[string]$ProjectRoot = ''"));
    expect(script, contains(r'$MyInvocation.MyCommand.Path'));
    expect(script, contains('--split-per-abi'));
    expect(script, contains('--target-platform'));
    expect(script, contains('android-arm,android-arm64'));
    expect(script, contains('-P wkPublicRelease=true'));
    expect(script, isNot(contains('android-x64')));
  });

  test('Gradle is configured for cached parallel release builds', () {
    final properties = File('android/gradle.properties').readAsStringSync();

    expect(properties, contains('org.gradle.daemon=true'));
    expect(properties, contains('org.gradle.parallel=true'));
    expect(properties, contains('org.gradle.caching=true'));
    expect(properties, isNot(contains('org.gradle.workers.max=1')));
  });
}
