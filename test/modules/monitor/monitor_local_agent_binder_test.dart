import 'dart:convert';
import 'dart:io';

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
          contains('请在 Windows 桌面端使用一键绑定'),
        ),
      ),
    );
  });

  test(
    'bindAndHeartbeat runs pair then one heartbeat with sanitized errors',
    () async {
      final tempDir = await Directory.systemTemp.createTemp(
        'monitor_local_agent_binder_pair_error_test_',
      );
      addTearDown(() async {
        if (await tempDir.exists()) {
          await tempDir.delete(recursive: true);
        }
      });
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
            stderr: 'Authorization: Bearer secret-token-1234567890 failed',
          );
        },
      );

      await expectLater(
        binder.bindAndHeartbeat(
          LocalAgentBindRequest(
            serverUrl: 'https://infoequity.qingyunshe.top',
            pairingCode: 'ABC123',
            storeDir: tempDir.path,
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
      expect(calls.first, contains('--store-dir ${tempDir.path}'));
      expect(calls.last, contains('run --once'));
    },
  );

  test('bindAndHeartbeat maps used pairing code to friendly error', () async {
    final tempDir = await Directory.systemTemp.createTemp(
      'monitor_local_agent_binder_used_code_test_',
    );
    addTearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });
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
        LocalAgentBindRequest(
          serverUrl: 'https://infoequity.qingyunshe.top',
          pairingCode: 'USED-1',
          storeDir: tempDir.path,
        ),
      ),
      throwsA(
        isA<LocalAgentBindException>()
            .having((error) => error.phase, 'phase', LocalAgentBindPhase.pair)
            .having((error) => error.message, 'message', contains('配对码已被使用'))
            .having(
              (error) => error.message,
              'message',
              isNot(contains('Unhandled exception')),
            )
            .having((error) => error.message, 'message', isNot(contains('#0'))),
      ),
    );
  });

  test(
    'bindAndHeartbeat returns success after pair and heartbeat complete',
    () async {
      final tempDir = await Directory.systemTemp.createTemp(
        'monitor_local_agent_binder_success_test_',
      );
      addTearDown(() async {
        if (await tempDir.exists()) {
          await tempDir.delete(recursive: true);
        }
      });
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
        LocalAgentBindRequest(
          serverUrl: 'https://infoequity.qingyunshe.top',
          pairingCode: 'ABC123',
          storeDir: tempDir.path,
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

  test(
    'bindAndHeartbeat uses existing local config heartbeat without pairing again',
    () async {
      final tempDir = await Directory.systemTemp.createTemp(
        'monitor_local_agent_binder_existing_config_test_',
      );
      addTearDown(() async {
        if (await tempDir.exists()) {
          await tempDir.delete(recursive: true);
        }
      });
      await File(
        '${tempDir.path}${Platform.pathSeparator}agent_config.json',
      ).writeAsString('{"agent_id":"agent_1","agent_token":"secret-token"}');

      final calls = <List<String>>[];
      final binder = MonitorLocalAgentBinder(
        isWindows: () => true,
        runProcess: (executable, arguments) async {
          calls.add(arguments);
          return const LocalAgentProcessResult(
            exitCode: 0,
            stdout: 'heartbeat ok',
            stderr: '',
          );
        },
      );

      final result = await binder.bindAndHeartbeat(
        LocalAgentBindRequest(
          serverUrl: 'https://infoequity.qingyunshe.top',
          pairingCode: 'SHOULD-NOT-PAIR',
          storeDir: tempDir.path,
        ),
      );

      expect(result.message, 'Agent 已绑定并上线');
      expect(calls, hasLength(1));
      expect(calls.single, containsAll(<String>['run', '--once']));
      expect(calls.single, isNot(contains('pair')));
      expect(calls.single, isNot(contains('--code')));
    },
  );

  test('bindAndHeartbeat force-pair ignores existing local config', () async {
    final tempDir = await Directory.systemTemp.createTemp(
      'monitor_local_agent_binder_force_pair_test_',
    );
    addTearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });
    await File(
      '${tempDir.path}${Platform.pathSeparator}agent_config.json',
    ).writeAsString('{"agent_id":"agent_1","agent_token":"secret-token"}');

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

    await binder.bindAndHeartbeat(
      LocalAgentBindRequest(
        serverUrl: 'https://infoequity.qingyunshe.top',
        pairingCode: 'FORCE-PAIR',
        storeDir: tempDir.path,
        forcePair: true,
      ),
    );

    expect(calls, hasLength(2));
    expect(calls.first, containsAll(<String>['pair', '--code', 'FORCE-PAIR']));
    expect(calls.last, containsAll(<String>['run', '--once']));
  });

  test('openBrowserLogin maps to browser-login command', () async {
    final calls = <List<String>>[];
    final binder = MonitorLocalAgentBinder(
      isWindows: () => true,
      runProcess: (executable, arguments) async {
        calls.add(arguments);
        return const LocalAgentProcessResult(
          exitCode: 0,
          stdout: '已打开 Chromium 飞书登录窗口，请扫码登录。',
          stderr: '',
        );
      },
    );

    final result = await binder.openBrowserLogin(storeDir: r'C:\Temp\agent');

    expect(result.message, contains('Chromium 飞书登录窗口'));
    expect(
      calls.single,
      containsAll(<String>['browser-login', '--store-dir', r'C:\Temp\agent']),
    );
  });

  test('checkBrowserStatus maps to browser-status command', () async {
    final calls = <List<String>>[];
    final binder = MonitorLocalAgentBinder(
      isWindows: () => true,
      runProcess: (executable, arguments) async {
        calls.add(arguments);
        return const LocalAgentProcessResult(
          exitCode: 0,
          stdout: '飞书已登录，浏览器状态已同步。',
          stderr: '',
        );
      },
    );

    final result = await binder.checkBrowserStatus(storeDir: r'C:\Temp\agent');

    expect(result.message, contains('飞书已登录'));
    expect(
      calls.single,
      containsAll(<String>['browser-status', '--store-dir', r'C:\Temp\agent']),
    );
  });

  test('clearBrowserProfile maps to clear-browser-profile command', () async {
    final calls = <List<String>>[];
    final binder = MonitorLocalAgentBinder(
      isWindows: () => true,
      runProcess: (executable, arguments) async {
        calls.add(arguments);
        return const LocalAgentProcessResult(
          exitCode: 0,
          stdout: '已清除飞书登录状态，请重新打开飞书登录并扫码。',
          stderr: '',
        );
      },
    );

    final result = await binder.clearBrowserProfile(storeDir: r'C:\Temp\agent');

    expect(result.message, contains('已清除飞书登录状态'));
    expect(
      calls.single,
      containsAll(<String>[
        'clear-browser-profile',
        '--store-dir',
        r'C:\Temp\agent',
      ]),
    );
  });

  test(
    'listenOnce returns friendly summary instead of raw Agent stdout',
    () async {
      final calls = <List<String>>[];
      final binder = MonitorLocalAgentBinder(
        isWindows: () => true,
        runProcess: (executable, arguments) async {
          calls.add(arguments);
          return const LocalAgentProcessResult(
            exitCode: 0,
            stdout: '监听完成：规则 1 条，观察 1 条，上报 1 条。',
            stderr: '',
          );
        },
      );

      final result = await binder.listenOnce(storeDir: r'C:\Temp\agent');

      expect(result.message, '监听完成，页面已刷新。');
      expect(
        calls.single,
        containsAll(<String>[
          'listen',
          '--once',
          '--store-dir',
          r'C:\Temp\agent',
        ]),
      );
    },
  );

  test(
    'heartbeatOnce sends one heartbeat and returns friendly summary',
    () async {
      final calls = <List<String>>[];
      final binder = MonitorLocalAgentBinder(
        isWindows: () => true,
        runProcess: (executable, arguments) async {
          calls.add(arguments);
          return const LocalAgentProcessResult(
            exitCode: 0,
            stdout: '蹇冭烦鎴愬姛锛歰nline',
            stderr: '',
          );
        },
      );

      final result = await binder.heartbeatOnce(storeDir: r'C:\Temp\agent');

      expect(result.message, 'Agent 状态已更新，页面已刷新。');
      expect(
        calls.single,
        containsAll(<String>['run', '--once', '--store-dir', r'C:\Temp\agent']),
      );
    },
  );

  test('listChats parses list-chats JSON output', () async {
    final calls = <List<String>>[];
    final binder = MonitorLocalAgentBinder(
      isWindows: () => true,
      runProcess: (executable, arguments) async {
        calls.add(arguments);
        return const LocalAgentProcessResult(
          exitCode: 0,
          stdout: '[{"name":"飞书新闻群"},{"name":"产品交流群"},{"name":"飞书新闻群"}]',
          stderr: '',
        );
      },
    );

    final chats = await binder.listChats(storeDir: r'C:\Temp\agent');

    expect(chats, <String>['飞书新闻群', '产品交流群']);
    expect(
      calls.single,
      containsAll(<String>['list-chats', '--store-dir', r'C:\Temp\agent']),
    );
  });

  test(
    'listChats falls back to local cached Feishu chats when Agent returns empty',
    () async {
      final tempDir = await Directory.systemTemp.createTemp(
        'monitor_local_agent_binder_chat_cache_test_',
      );
      addTearDown(() async {
        if (await tempDir.exists()) {
          await tempDir.delete(recursive: true);
        }
      });
      final runtimeDir = Directory(
        '${tempDir.path}${Platform.pathSeparator}runtime',
      );
      await runtimeDir.create(recursive: true);
      await File(
        '${runtimeDir.path}${Platform.pathSeparator}feishu-chat-cache.json',
      ).writeAsString(jsonEncode(<String>['飞书新闻群', '产品交流群']));

      final binder = MonitorLocalAgentBinder(
        isWindows: () => true,
        runProcess: (_, _) async => const LocalAgentProcessResult(
          exitCode: 0,
          stdout: '[]',
          stderr: '',
        ),
      );

      final chats = await binder.listChats(storeDir: tempDir.path);

      expect(chats, <String>['飞书新闻群', '产品交流群']);
    },
  );
}
