import 'package:flutter_test/flutter_test.dart';
import 'package:mengxia_monitor_shell_app/src/mengxia_configured_source_cycler.dart';

void main() {
  test('reads configured routing sources from shell diagnostics', () {
    final sources = mengxiaConfiguredSourcesFromDiagnostics(<String, Object?>{
      'configured_media_sources': <Map<String, Object?>>[
        <String, Object?>{
          'conversation_id': 'mx-alpha',
          'conversation_name': 'Alpha',
        },
        <String, Object?>{
          'conversation_id': 'mx-alpha',
          'conversation_name': 'Alpha',
        },
        <String, Object?>{
          'conversation_id': 'fallback:Beta',
          'conversation_name': 'Beta',
        },
        <String, Object?>{
          'conversation_id': '',
          'conversation_name': '',
        },
      ],
    });

    expect(sources.map((source) => source.conversationId), <String>[
      'mx-alpha',
      'fallback:Beta',
    ]);
    expect(sources.map((source) => source.conversationName), <String>[
      'Alpha',
      'Beta',
    ]);
  });

  test('cycles configured sources in order', () {
    final cycler = MengxiaConfiguredSourceCycler();
    final sources = <MengxiaConfiguredSource>[
      const MengxiaConfiguredSource(
        conversationId: 'mx-alpha',
        conversationName: 'Alpha',
      ),
      const MengxiaConfiguredSource(
        conversationId: 'mx-beta',
        conversationName: 'Beta',
      ),
    ];

    expect(cycler.next(sources)?.conversationId, 'mx-alpha');
    expect(cycler.next(sources)?.conversationId, 'mx-beta');
    expect(cycler.next(sources)?.conversationId, 'mx-alpha');
  });

  test('configured source click script stays inside DOM click boundaries', () {
    final script = mengxiaClickConfiguredSourceScript(
      const MengxiaConfiguredSource(
        conversationId: 'fallback:Beta',
        conversationName: 'Beta',
      ),
    );

    expect(script, contains('configured-source-click'));
    expect(script, contains('querySelectorAll'));
    expect(script, contains('dispatchEvent'));
    expect(script, isNot(contains('localStorage')));
    expect(script, isNot(contains('sessionStorage')));
    expect(script, isNot(contains('cookie')));
  });
}
