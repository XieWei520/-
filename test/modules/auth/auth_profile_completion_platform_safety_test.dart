import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('AuthProfileCompletionPage source does not import dart io directly', () {
    final source = File(
      'lib/modules/auth/presentation/pages/auth_profile_completion_page.dart',
    ).readAsStringSync();

    expect(source, isNot(contains("import 'dart:io'")));
  });

  test('auth providers keep picker plugins behind an adapter', () {
    final source = File(
      'lib/modules/auth/application/auth_providers.dart',
    ).readAsStringSync();

    expect(source, isNot(contains("package:file_picker")));
    expect(source, isNot(contains("package:image_picker")));
  });
}
