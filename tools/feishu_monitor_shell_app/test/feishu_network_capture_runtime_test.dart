import 'dart:io';

import 'package:feishu_monitor_shell_app/main.dart';
import 'package:feishu_monitor_shell_app/src/feishu_page_observer.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('network diagnostics file lives under shell runtime directory', () {
    final supportDirectory = Directory('C:\\app_support');

    final file = networkCaptureDiagnosticsFileFor(supportDirectory);

    expect(
      file.path,
      'C:\\app_support\\feishu_monitor_shell\\.runtime\\feishu-network-capture\\network.jsonl',
    );
  });

  test('shell installs image attribution hook during startup and fallback', () {
    expect(
      feishuShellDocumentCreatedScripts(),
      contains(feishuNetworkImageAttributionScript),
    );
    expect(
      feishuShellPageObserverScripts(),
      contains(feishuNetworkImageAttributionScript),
    );
  });

  test('shell keeps existing feed observer before diagnostic hook fallback', () {
    final scripts = feishuShellPageObserverScripts();

    expect(
      scripts.indexOf(feishuPageObserverScript),
      lessThan(scripts.indexOf(feishuNetworkImageAttributionScript)),
    );
  });

  test('shell exposes strict no-DOM forwarding policy', () {
    expect(feishuStrictNoDomForwardingEnabled, isTrue);
    expect(feishuStrictNoDomForwardingReason, 'strict_no_dom_forwarding');
  });

  test('shell reports media opening disabled by strict no-DOM policy', () {
    final diagnostic = feishuStrictNoDomOpenResult();

    expect(diagnostic['attempted'], isFalse);
    expect(diagnostic['opened'], isFalse);
    expect(diagnostic['reason'], 'strict_no_dom_forwarding');
  });

  test('strict no-DOM open result is safe for status diagnostics', () {
    final diagnostic = feishuStrictNoDomOpenResult();

    expect(diagnostic.keys, containsAll(<String>[
      'attempted',
      'opened',
      'reason',
    ]));
    expect(diagnostic, isNot(containsPair('key', anything)));
    expect(diagnostic, isNot(containsPair('text_preview', anything)));
  });
}
