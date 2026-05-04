import 'package:flutter_test/flutter_test.dart';
import 'package:wukong_im_app/data/models/group_forbidden_time_option.dart';

void main() {
  test('fromJson parses backend forbidden time options', () {
    final option = GroupForbiddenTimeOption.fromJson({
      'text': '1 hour',
      'key': 3,
    });

    expect(option.text, '1 hour');
    expect(option.key, 3);
  });

  test('fromJson parses trimmed numeric-string keys', () {
    final option = GroupForbiddenTimeOption.fromJson({
      'text': 'custom',
      'key': '  42  ',
    });

    expect(option.key, 42);
  });

  test('fromJson coerces float-string keys by truncating to int', () {
    final option = GroupForbiddenTimeOption.fromJson({
      'text': 'float',
      'key': '3.9',
    });

    expect(option.key, 3);
  });

  test('fromJson falls back key to 0 for empty/invalid values', () {
    final empty = GroupForbiddenTimeOption.fromJson({
      'text': 'empty',
      'key': '   ',
    });
    final invalid = GroupForbiddenTimeOption.fromJson({
      'text': 'invalid',
      'key': 'not-a-number',
    });
    final unsupported = GroupForbiddenTimeOption.fromJson({
      'text': 'unsupported',
      'key': const <String>['x'],
    });

    expect(empty.key, 0);
    expect(invalid.key, 0);
    expect(unsupported.key, 0);
  });
}
