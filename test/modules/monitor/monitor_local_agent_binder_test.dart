import 'package:flutter_test/flutter_test.dart';
import 'package:wukong_im_app/modules/monitor/monitor_local_agent_binder.dart';

void main() {
  test('bindAndHeartbeat rejects non-Windows desktop platforms', () async {
    final binder = MonitorLocalAgentBinder(
      isWindows: () => false,
      runProcess: (_, _) async =>
          const LocalAgentProcessResult(exitCode: 0, stdout: '', stderr: ''),
    );

    await expectLater(
      binder.bindAndHeartbeat(
        const LocalAgentBindRequest(
          serverUrl: 'https://infoequity.qingyunshe.top',
          pairingCode: 'ABC123',
        ),
      ),
      throwsA(
        isA<LocalAgentBindException>().having(
          (error) => error.message,
          'message',
          contains('Windows 桌面端'),
        ),
      ),
    );
  });

  test(
    'bindAndHeartbeat runs pair then one heartbeat with sanitized errors',
    () async {
      final calls = <String>[];
      final binder = MonitorLocalAgentBinder(
        isWindows: () => true,
        runProcess: (executable, arguments) async {
          calls.add('$executable ${arguments.join(' ')}');
          if (calls.length == 1) {
            return const LocalAgentProcessResult(
              exitCode: 0,
              stdout: '绑定成功：Agent agent_xxx，心跳间隔 20 秒',
              stderr: '',
            );
          }
          return const LocalAgentProcessResult(
            exitCode: 7,
            stdout: '',
            stderr:
                'Authorization: '
                'Bearer secret-token-1234567890 failed',
          );
        },
      );

      await expectLater(
        binder.bindAndHeartbeat(
          const LocalAgentBindRequest(
            serverUrl: 'https://infoequity.qingyunshe.top',
            pairingCode: 'ABC123',
            storeDir: r'C:\Temp\feishu-agent-test',
          ),
        ),
        throwsA(
          isA<LocalAgentBindException>()
              .having(
                (error) => error.phase,
                'phase',
                LocalAgentBindPhase.heartbeat,
              )
              .having(
                (error) => error.message,
                'message',
                isNot(contains('secret-token')),
              )
              .having(
                (error) => error.message,
                'message',
                contains('Bearer ***'),
              ),
        ),
      );

      expect(calls, hasLength(2));
      expect(calls.first, contains('pair'));
      expect(calls.first, contains('--code ABC123'));
      expect(calls.first, contains(r'--store-dir C:\Temp\feishu-agent-test'));
      expect(calls.last, contains('run --once'));
    },
  );

  test('bindAndHeartbeat maps used pairing code to friendly error', () async {
    final binder = MonitorLocalAgentBinder(
      isWindows: () => true,
      runProcess: (_, _) async => const LocalAgentProcessResult(
        exitCode: 1,
        stdout: '',
        stderr:
            'Unhandled exception:\n'
            'AgentApiException(statusCode: 409, code: pairing_code_used, message: used)\n'
            '#0 AgentApi._postJson (package:feishu_monitor_agent/src/agent_api.dart:72:7)',
      ),
    );

    await expectLater(
      binder.bindAndHeartbeat(
        const LocalAgentBindRequest(
          serverUrl: 'https://infoequity.qingyunshe.top',
          pairingCode: 'USED-1',
        ),
      ),
      throwsA(
        isA<LocalAgentBindException>()
            .having((error) => error.phase, 'phase', LocalAgentBindPhase.pair)
            .having(
              (error) => error.message,
              'message',
              contains('配对码已被使用'),
            )
            .having(
              (error) => error.message,
              'message',
              isNot(contains('Unhandled exception')),
            )
            .having(
              (error) => error.message,
              'message',
              isNot(contains('#0')),
            ),
      ),
    );
  });

  test(
    'bindAndHeartbeat returns success after pair and heartbeat complete',
    () async {
      final calls = <List<String>>[];
      final binder = MonitorLocalAgentBinder(
        isWindows: () => true,
        runProcess: (executable, arguments) async {
          calls.add(arguments);
          return const LocalAgentProcessResult(
            exitCode: 0,
            stdout: 'ok',
            stderr: '',
          );
        },
      );

      final result = await binder.bindAndHeartbeat(
        const LocalAgentBindRequest(
          serverUrl: 'https://infoequity.qingyunshe.top',
          pairingCode: 'ABC123',
        ),
      );

      expect(result.message, 'Agent 已绑定并上线');
      expect(calls, hasLength(2));
      expect(
        calls[0],
        containsAll(<String>[
          'pair',
          '--server',
          'https://infoequity.qingyunshe.top',
          '--code',
          'ABC123',
        ]),
      );
      expect(calls[1], containsAll(<String>['run', '--once']));
    },
  );
}
