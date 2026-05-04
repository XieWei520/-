import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('LocationMapPage does not import geolocator directly', () {
    final source = File(
      'lib/modules/location/location_map_page.dart',
    ).readAsStringSync();

    expect(source, isNot(contains('package:geolocator')));
  });
}
