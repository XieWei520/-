import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'app and IM startup do not directly import video call implementations',
    () {
      final guardedSources = <String, String>{
        'lib/app/app.dart': File('lib/app/app.dart').readAsStringSync(),
        'lib/service/im/im_service.dart': File(
          'lib/service/im/im_service.dart',
        ).readAsStringSync(),
      };

      for (final entry in guardedSources.entries) {
        expect(
          entry.value,
          isNot(contains("modules/video_call/call_coordinator.dart")),
          reason: entry.key,
        );
        expect(
          entry.value,
          isNot(contains("modules/video_call/video_call_service.dart")),
          reason: entry.key,
        );
        expect(
          entry.value,
          contains('video_call_runtime_bridge.dart'),
          reason: entry.key,
        );
      }
    },
  );

  test(
    'chat scene providers build deferred call pages instead of importing RTC UI',
    () {
      final source = File(
        'lib/modules/chat/chat_scene_providers.dart',
      ).readAsStringSync();

      expect(source, contains('deferred_video_call_pages.dart'));
      expect(source, isNot(contains("video_call_page.dart")));
      expect(source, isNot(contains("group_call_member_picker_page.dart")));
      expect(source, contains('DeferredVideoCallPage('));
      expect(source, contains('DeferredGroupCallMemberPickerPage('));
    },
  );

  test('deferred call page wrapper does not directly import RTC UI', () {
    final source = File(
      'lib/modules/video_call/deferred_video_call_pages.dart',
    ).readAsStringSync();

    expect(source, contains('deferred as video_call_pages'));
    expect(source, contains('video_call_pages.loadLibrary()'));
    expect(source, isNot(contains('video_call_page.dart')));
    expect(source, isNot(contains('group_call_member_picker_page.dart')));
  });

  test('deferred call page factory owns the video call UI imports', () {
    final source = File(
      'lib/modules/video_call/video_call_page_factory.dart',
    ).readAsStringSync();

    expect(source, contains('video_call_page.dart'));
    expect(source, contains('group_call_member_picker_page.dart'));
    expect(source, contains('VideoCallPage('));
    expect(source, contains('GroupCallMemberPickerPage('));
  });

  test(
    'video call runtime bridge defers coordinator and media service loading',
    () {
      final source = File(
        'lib/modules/video_call/video_call_runtime_bridge.dart',
      ).readAsStringSync();

      expect(source, contains('deferred as video_call_runtime'));
      expect(source, contains('video_call_runtime.loadLibrary()'));
      expect(source, contains('hasActiveCallOrPendingSetupSync()'));
      expect(source, contains('_shouldRunCoordinator'));
      expect(source, isNot(contains("call_coordinator.dart'")));
      expect(source, isNot(contains("video_call_service.dart'")));
    },
  );
}
