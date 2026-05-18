import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:local_monitor_shell_core/local_monitor_shell_core.dart';
import 'package:path_provider/path_provider.dart';
import 'package:webview_windows/webview_windows.dart';

import 'src/juliang_incognito_runtime.dart';
import 'src/juliang_page_observer.dart';
import 'src/juliang_page_probe.dart';
import 'src/juliang_runtime_capture.dart';

const String defaultJuliangRuntimeUrl = 'https://msg.juliang888.top/';
const int defaultJuliangShellPort = 18796;
const String defaultJuliangShellToken = 'wukong-juliang-shell-dev';
const String juliangShellAppTitle = '聚合消息监控助手';
const String juliangManualLoginNotice =
    'Manual login is required every launch.';
const String juliangNoTraceNotice =
    'No cookies, localStorage, history, profile, or session directory are reused.';
const List<String> juliangShellWebviewFlags = <String>[
  '--disable-background-timer-throttling',
  '--disable-renderer-backgrounding',
  '--disable-backgrounding-occluded-windows',
  '--disable-features=CalculateNativeWinOcclusion,IntensiveWakeUpThrottling',
];

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final runtime = await prepareJuliangShellRuntime(
    await getApplicationSupportDirectory(),
  );
  await WebviewController.initializeEnvironment(
    userDataPath: runtime.webviewUserDataPath,
    additionalArguments: juliangShellWebviewFlags.join(' '),
  );
  final store = ShellStore(runtime.snapshotFile);
  await initializeJuliangShellStore(store);
  final events = ShellEventBus();
  final server = createJuliangShellServer(store: store, events: events);
  await server.start();
  runApp(
    JuliangMonitorShellApp(
      runtime: runtime,
      store: store,
      events: events,
      server: server,
    ),
  );
}

class JuliangShellRuntime {
  const JuliangShellRuntime({
    required this.supportDirectory,
    required this.sessionDirectory,
    required this.snapshotFile,
  });

  final Directory supportDirectory;
  final Directory sessionDirectory;
  final File snapshotFile;

  String get webviewUserDataPath => sessionDirectory.path;
}

Future<JuliangShellRuntime> prepareJuliangShellRuntime(
  Directory supportDirectory,
) async {
  final runtimeBaseDirectory = Directory(
    '${supportDirectory.path}${Platform.pathSeparator}'
    'juliang_monitor_shell_runtime',
  );
  await cleanupJuliangStaleSessionDirectories(runtimeBaseDirectory);
  final sessionDirectory = await createJuliangFreshSessionDirectory(
    runtimeBaseDirectory,
  );
  return JuliangShellRuntime(
    supportDirectory: supportDirectory,
    sessionDirectory: sessionDirectory,
    snapshotFile: juliangShellSnapshotFileFor(supportDirectory),
  );
}

Future<bool> disposeJuliangShellRuntimeResources({
  required Directory sessionDirectory,
  required Future<void> Function() disposeWebview,
  Future<void> Function()? closeServer,
  Iterable<Future<void> Function()> cancelSubscriptions =
      const <Future<void> Function()>[],
  List<Duration> cleanupRetryDelays = const <Duration>[
    Duration(milliseconds: 100),
    Duration(milliseconds: 250),
    Duration(milliseconds: 500),
  ],
}) async {
  for (final cancel in cancelSubscriptions) {
    await cancel();
  }
  await closeServer?.call();
  await disposeWebview();
  return destroyJuliangFreshSessionDirectoryBestEffort(
    sessionDirectory,
    retryDelays: cleanupRetryDelays,
  );
}

Future<void> initializeJuliangShellStore(
  ShellStore store, {
  DateTime Function()? clock,
}) async {
  final now = (clock ?? DateTime.now)().toUtc();
  const policy = JuliangIncognitoRuntimePolicy.strict();
  await store.save(
    ShellSnapshot.initial().copyWith(
      shellState: 'online',
      captureState: 'stopped',
      loginState: 'login_required',
      hookState: 'healthy',
      runtimeUrl: defaultJuliangRuntimeUrl,
      pageTitle: juliangShellAppTitle,
      webviewAvailable: false,
      shellMode: 'desktop_shell',
      pageKind: 'login',
      probeDiagnostics: <String, dynamic>{
        'strict_incognito': true,
        'requires_manual_login': policy.requiresManualLoginEveryLaunch,
        'reuses_cookies': policy.reusesCookies,
        'reuses_local_storage': policy.reusesLocalStorage,
        'reuses_history': policy.reusesHistory,
        'persistent_profile_directory': policy.persistentProfileDirectory,
        'persistent_session_directory': policy.persistentSessionDirectory,
        'target_url': defaultJuliangRuntimeUrl,
      },
      lastUpdatedAt: now,
      lastError: '',
    ),
  );
}

ShellServer createJuliangShellServer({
  required ShellStore store,
  InternetAddress? host,
  int port = defaultJuliangShellPort,
  String token = defaultJuliangShellToken,
  ShellEventBus? events,
}) {
  return ShellServer(
    store: store,
    host: host ?? InternetAddress.loopbackIPv4,
    port: port,
    token: token,
    events: events,
  );
}

class JuliangMonitorShellApp extends StatelessWidget {
  const JuliangMonitorShellApp({
    super.key,
    this.runtime,
    this.store,
    this.events,
    this.server,
  });

  final JuliangShellRuntime? runtime;
  final ShellStore? store;
  final ShellEventBus? events;
  final ShellServer? server;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: juliangShellAppTitle,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF2167D2)),
        useMaterial3: true,
      ),
      home: runtime == null || store == null || events == null
          ? const JuliangMonitorShellInfoHome()
          : JuliangMonitorShellHome(
              runtime: runtime!,
              store: store!,
              events: events!,
              server: server,
            ),
    );
  }
}

class JuliangMonitorShellInfoHome extends StatelessWidget {
  const JuliangMonitorShellInfoHome({super.key});

  static const JuliangIncognitoRuntimePolicy policy =
      JuliangIncognitoRuntimePolicy.strict();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text(juliangShellAppTitle)),
      body: const Center(child: _PrivacyNotice()),
    );
  }
}

class _PrivacyNotice extends StatelessWidget {
  const _PrivacyNotice();

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 720),
      child: const Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            juliangManualLoginNotice,
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
          ),
          SizedBox(height: 6),
          Text(juliangNoTraceNotice, style: TextStyle(fontSize: 16)),
        ],
      ),
    );
  }
}

class JuliangMonitorShellHome extends StatefulWidget {
  const JuliangMonitorShellHome({
    super.key,
    required this.runtime,
    required this.store,
    required this.events,
    this.server,
  });

  final JuliangShellRuntime runtime;
  final ShellStore store;
  final ShellEventBus events;
  final ShellServer? server;

  @override
  State<JuliangMonitorShellHome> createState() =>
      _JuliangMonitorShellHomeState();
}

class _JuliangMonitorShellHomeState extends State<JuliangMonitorShellHome> {
  late final WebviewController _controller;
  late final JuliangRuntimeCapture _capture;
  bool _webviewReady = false;
  bool _loading = true;
  bool _disposed = false;
  String _error = '';
  String _title = juliangShellAppTitle;
  String _runtimeUrl = defaultJuliangRuntimeUrl;
  Timer? _probeTimer;
  StreamSubscription<String>? _titleSubscription;
  StreamSubscription<String>? _urlSubscription;
  StreamSubscription<LoadingState>? _loadingStateSubscription;
  StreamSubscription<dynamic>? _webMessageSubscription;
  StreamSubscription<ShellEvent>? _shellEventSubscription;

  @override
  void initState() {
    super.initState();
    _controller = WebviewController();
    _capture = JuliangRuntimeCapture(
      store: widget.store,
      events: widget.events,
    );
    unawaited(_bootstrap());
  }

  @override
  void dispose() {
    _disposed = true;
    _probeTimer?.cancel();
    unawaited(_disposeRuntimeResources());
    super.dispose();
  }

  Future<void> _disposeRuntimeResources() {
    return disposeJuliangShellRuntimeResources(
      sessionDirectory: widget.runtime.sessionDirectory,
      cancelSubscriptions: <Future<void> Function()>[
        if (_titleSubscription != null) _titleSubscription!.cancel,
        if (_urlSubscription != null) _urlSubscription!.cancel,
        if (_loadingStateSubscription != null)
          _loadingStateSubscription!.cancel,
        if (_webMessageSubscription != null) _webMessageSubscription!.cancel,
        if (_shellEventSubscription != null) _shellEventSubscription!.cancel,
      ],
      closeServer: widget.server?.close,
      disposeWebview: _controller.dispose,
    );
  }

  Future<void> _bootstrap() async {
    try {
      await _controller.initialize();
      if (_disposed) {
        return;
      }
      _webMessageSubscription = _controller.webMessage.listen(
        _handleWebMessage,
        onError: (_) {},
      );
      await _controller.setBackgroundColor(Colors.white);
      await _controller.addScriptToExecuteOnDocumentCreated(
        juliangPageObserverScript,
      );
      if (_disposed) {
        return;
      }
      _shellEventSubscription = widget.events.stream.listen((event) {
        if (_disposed) {
          return;
        }
        if (event.type == ShellEventType.runtimeReloadRequested) {
          unawaited(_reloadFreshRuntime());
        }
      });
      _titleSubscription = _controller.title.listen((title) {
        _title = title.trim().isEmpty ? juliangShellAppTitle : title.trim();
        unawaited(_persistRuntimeSignal());
        if (!_disposed && mounted) {
          setState(() {});
        }
      });
      _urlSubscription = _controller.url.listen((url) {
        _runtimeUrl = url.trim().isEmpty
            ? defaultJuliangRuntimeUrl
            : url.trim();
        unawaited(_persistRuntimeSignal());
        if (!_disposed && mounted) {
          setState(() {});
        }
      });
      _loadingStateSubscription = _controller.loadingState.listen((state) {
        if (_disposed) {
          return;
        }
        _loading = state == LoadingState.loading;
        unawaited(_persistRuntimeSignal());
        if (state == LoadingState.navigationCompleted) {
          unawaited(_installObserverAndProbe());
        }
        if (mounted) {
          setState(() {});
        }
      });
      await _controller.loadUrl(defaultJuliangRuntimeUrl);
      await _persistRuntimeSignal(webviewAvailable: true);
      _probeTimer = Timer.periodic(const Duration(seconds: 2), (_) {
        if (!_disposed && !_loading) {
          unawaited(_installObserverAndProbe());
        }
      });
      if (!_disposed && mounted) {
        setState(() {
          _webviewReady = true;
          _loading = false;
        });
      }
    } catch (error) {
      await widget.store.update((current) {
        return current.copyWith(
          shellState: 'online',
          captureState: 'stopped',
          loginState: 'login_required',
          hookState: 'error',
          runtimeUrl: _runtimeUrl,
          pageTitle: _title,
          webviewAvailable: false,
          shellMode: 'desktop_shell',
          pageKind: 'login',
          lastUpdatedAt: DateTime.now().toUtc(),
          lastError: error.toString(),
        );
      });
      if (!_disposed && mounted) {
        setState(() {
          _error = error.toString();
          _loading = false;
        });
      }
    }
  }

  Future<void> _reloadFreshRuntime() async {
    if (mounted) {
      setState(() {
        _loading = true;
      });
    }
    try {
      await _controller.clearCookies();
      await _controller.clearCache();
      await _controller.loadUrl(defaultJuliangRuntimeUrl);
      await _installObserverAndProbe();
    } finally {
      if (!_disposed && mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  Future<void> _installObserverAndProbe() async {
    try {
      await _controller.executeScript(juliangPageObserverScript);
      await _refreshPageProbe();
    } catch (error) {
      await widget.store.update((current) {
        return current.copyWith(
          lastUpdatedAt: DateTime.now().toUtc(),
          lastError: error.toString(),
        );
      });
    }
  }

  void _handleWebMessage(dynamic message) {
    final json = _asJsonObject(message);
    if (json == null) {
      return;
    }
    final observerMessage = JuliangPageObserverMessage.fromJson(json);
    if (observerMessage.isPageChanged) {
      unawaited(_refreshPageProbe());
    }
  }

  Future<void> _refreshPageProbe() async {
    if (_disposed) {
      return;
    }
    final raw = await _controller.executeScript(juliangPageProbeScript);
    final json = _asJsonObject(raw);
    if (json == null) {
      return;
    }
    final probe = juliangPageProbeFromJson(json);
    await _capture.applyProbe(probe);
  }

  Future<void> _persistRuntimeSignal({bool? webviewAvailable}) async {
    await widget.store.update((current) {
      final pageKind = deriveJuliangPageKind(
        runtimeUrl: _runtimeUrl,
        pageTitle: _title,
        bodyText: '',
        hasForwardableContent:
            current.recentEvents.isNotEmpty ||
            current.observedConversations.isNotEmpty,
      );
      return current.copyWith(
        shellState: 'online',
        captureState: pageKind == JuliangPageKind.login ? 'stopped' : 'running',
        loginState: pageKind == JuliangPageKind.login
            ? 'login_required'
            : 'logged_in',
        hookState: 'healthy',
        runtimeUrl: _runtimeUrl,
        pageTitle: _title,
        webviewAvailable: webviewAvailable ?? current.webviewAvailable,
        shellMode: 'desktop_shell',
        pageKind: pageKind.wireName,
        lastUpdatedAt: DateTime.now().toUtc(),
      );
    }, preserveCaptureState: false);
  }

  Map<String, Object?>? _asJsonObject(Object? value) {
    if (value is Map<String, Object?>) {
      return value;
    }
    if (value is Map) {
      return value.map((key, itemValue) => MapEntry(key.toString(), itemValue));
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_title),
        bottom: _loading
            ? const PreferredSize(
                preferredSize: Size.fromHeight(2),
                child: LinearProgressIndicator(minHeight: 2),
              )
            : null,
      ),
      body: Column(
        children: <Widget>[
          const Padding(padding: EdgeInsets.all(12), child: _PrivacyNotice()),
          if (_error.trim().isNotEmpty)
            Container(
              width: double.infinity,
              color: const Color(0xFFFFF2F0),
              padding: const EdgeInsets.all(12),
              child: Text(_error),
            ),
          Expanded(
            child: _webviewReady
                ? Webview(_controller)
                : const Center(child: CircularProgressIndicator()),
          ),
        ],
      ),
    );
  }
}
