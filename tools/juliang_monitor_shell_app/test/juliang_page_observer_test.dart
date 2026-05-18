import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:juliang_monitor_shell_app/src/juliang_page_observer.dart';

void main() {
  test('observer script posts Juliang page change notifications', () {
    expect(juliangPageObserverScript, contains('MutationObserver'));
    expect(juliangPageObserverScript, contains('chrome.webview.postMessage'));
    expect(juliangPageObserverScript, contains('juliang_monitor_page_changed'));
  });

  test('probe script targets MUI source lists and text messages', () {
    expect(juliangPageProbeScript, contains('MuiListItem'));
    expect(juliangPageProbeScript, contains('MuiListItemButton'));
    expect(juliangPageProbeScript, contains('message_type'));
    expect(juliangPageProbeScript, contains("'text'"));
    expect(juliangPageProbeScript, contains('isVisibleElement'));
    expect(juliangPageProbeScript, isNot(contains('.MuiBox-root,.MuiStack-root')));
    expect(juliangPageProbeScript, isNot(contains('localStorage')));
    expect(juliangPageProbeScript, isNot(contains('sessionStorage')));
    expect(juliangPageProbeScript, isNot(contains('document.cookie')));
  });

  test('shell app wires probe, observer, and shared event bus', () {
    final mainSource = File('lib/main.dart').readAsStringSync();

    expect(mainSource, contains('juliangPageObserverScript'));
    expect(mainSource, contains('juliangPageProbeScript'));
    expect(mainSource, contains('JuliangRuntimeCapture'));
    expect(mainSource, contains('final events = ShellEventBus()'));
    expect(mainSource, contains('events: events'));
  });

  test('parses page observer message from json', () {
    final message = JuliangPageObserverMessage.fromJson(<String, Object?>{
      'type': 'juliang_monitor_page_changed',
      'reason': 'mutation',
      'observed_at': '2026-05-17T02:00:00.000Z',
    });

    expect(message.isPageChanged, isTrue);
    expect(message.reason, 'mutation');
    expect(message.observedAt, DateTime.utc(2026, 5, 17, 2));
  });
}
