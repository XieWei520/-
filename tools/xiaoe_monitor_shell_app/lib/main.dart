import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:local_monitor_shell_core/local_monitor_shell_core.dart';
import 'package:path_provider/path_provider.dart';
import 'package:webview_windows/webview_windows.dart';

import 'src/xiaoe_page_observer.dart';
import 'src/xiaoe_page_probe.dart';
import 'src/xiaoe_runtime_capture.dart';

const String defaultXiaoeRuntimeUrl =
    'https://study.xiaoe-tech.com/#/muti_index';
const int defaultXiaoeShellPort = 18806;
const String defaultXiaoeShellToken = 'wukong-xiaoe-shell-dev';
const String xiaoeShellAppTitle = '小鹅通信息监控';
const int xiaoeFileSizeLimitBytes = 20 * 1024 * 1024;
const List<String> xiaoeShellWebviewFlags = <String>[
  '--disable-background-timer-throttling',
  '--disable-renderer-backgrounding',
  '--disable-backgrounding-occluded-windows',
  '--disable-features=CalculateNativeWinOcclusion,IntensiveWakeUpThrottling',
];

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final runtime = await prepareXiaoeShellRuntime(
    await getApplicationSupportDirectory(),
  );
  await WebviewController.initializeEnvironment(
    userDataPath: runtime.webviewUserDataPath,
    additionalArguments: xiaoeShellWebviewFlags.join(' '),
  );
  final store = ShellStore(runtime.snapshotFile);
  await initializeXiaoeShellStore(store);
  final events = ShellEventBus();
  final server = createXiaoeShellServer(store: store, events: events);
  await server.start();
  runApp(
    XiaoeMonitorShellApp(
      runtime: runtime,
      store: store,
      events: events,
      server: server,
    ),
  );
}

class XiaoeShellRuntime {
  const XiaoeShellRuntime({
    required this.supportDirectory,
    required this.profileDirectory,
    required this.snapshotFile,
  });

  final Directory supportDirectory;
  final Directory profileDirectory;
  final File snapshotFile;

  String get webviewUserDataPath => profileDirectory.path;
}

Future<XiaoeShellRuntime> prepareXiaoeShellRuntime(
  Directory supportDirectory,
) async {
  final profileDirectory = Directory(
    '${supportDirectory.path}${Platform.pathSeparator}'
    'xiaoe_monitor_shell_profile',
  );
  await profileDirectory.create(recursive: true);
  return XiaoeShellRuntime(
    supportDirectory: supportDirectory,
    profileDirectory: profileDirectory,
    snapshotFile: xiaoeShellSnapshotFileFor(supportDirectory),
  );
}

File xiaoeShellSnapshotFileFor(Directory supportDirectory) {
  return File(
    '${supportDirectory.path}${Platform.pathSeparator}xiaoe_monitor_shell'
    '${Platform.pathSeparator}status.json',
  );
}

Future<void> initializeXiaoeShellStore(
  ShellStore store, {
  DateTime Function()? clock,
}) async {
  final now = (clock ?? DateTime.now)().toUtc();
  await store.save(
    ShellSnapshot.initial().copyWith(
      shellState: 'online',
      captureState: 'stopped',
      loginState: 'unknown',
      hookState: 'healthy',
      runtimeUrl: defaultXiaoeRuntimeUrl,
      pageTitle: xiaoeShellAppTitle,
      webviewAvailable: false,
      shellMode: 'desktop_shell',
      pageKind: 'muti_index',
      probeDiagnostics: <String, dynamic>{
        'target_url': defaultXiaoeRuntimeUrl,
        'manual_target_page_required': true,
        'requires_login_session': true,
        'captures_live_comments': true,
        'captures_circle_course_files': true,
        'file_size_limit_bytes': xiaoeFileSizeLimitBytes,
      },
      lastUpdatedAt: now,
      lastError: '',
    ),
  );
}

ShellServer createXiaoeShellServer({
  required ShellStore store,
  InternetAddress? host,
  int port = defaultXiaoeShellPort,
  String token = defaultXiaoeShellToken,
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

class XiaoeMonitorShellApp extends StatelessWidget {
  const XiaoeMonitorShellApp({
    super.key,
    this.runtime,
    this.store,
    this.events,
    this.server,
  });

  final XiaoeShellRuntime? runtime;
  final ShellStore? store;
  final ShellEventBus? events;
  final ShellServer? server;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: xiaoeShellAppTitle,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF2F6FED)),
        useMaterial3: true,
      ),
      home: runtime == null || store == null || events == null
          ? const XiaoeMonitorShellInfoHome()
          : XiaoeMonitorShellHome(
              runtime: runtime!,
              store: store!,
              events: events!,
              server: server,
            ),
    );
  }
}

class XiaoeMonitorShellInfoHome extends StatelessWidget {
  const XiaoeMonitorShellInfoHome({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text(xiaoeShellAppTitle)),
      body: const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            '打开小鹅通后手动停留在目标圈子、课程互动或直播评论页面。',
            style: TextStyle(fontSize: 16),
          ),
        ),
      ),
    );
  }
}

class XiaoeMonitorShellHome extends StatefulWidget {
  const XiaoeMonitorShellHome({
    super.key,
    required this.runtime,
    required this.store,
    required this.events,
    this.server,
  });

  final XiaoeShellRuntime runtime;
  final ShellStore store;
  final ShellEventBus events;
  final ShellServer? server;

  @override
  State<XiaoeMonitorShellHome> createState() => _XiaoeMonitorShellHomeState();
}

class _XiaoeMonitorShellHomeState extends State<XiaoeMonitorShellHome> {
  late final WebviewController _controller;
  late final XiaoeRuntimeCapture _capture;
  bool _webviewReady = false;
  bool _loading = true;
  bool _disposed = false;
  String _title = xiaoeShellAppTitle;
  String _runtimeUrl = defaultXiaoeRuntimeUrl;
  String _error = '';
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
    _capture = XiaoeRuntimeCapture(store: widget.store, events: widget.events);
    unawaited(_bootstrap());
  }

  @override
  void dispose() {
    _disposed = true;
    _probeTimer?.cancel();
    unawaited(_disposeRuntimeResources());
    super.dispose();
  }

  Future<void> _disposeRuntimeResources() async {
    await _titleSubscription?.cancel();
    await _urlSubscription?.cancel();
    await _loadingStateSubscription?.cancel();
    await _webMessageSubscription?.cancel();
    await _shellEventSubscription?.cancel();
    await widget.server?.close();
    await _controller.dispose();
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
        xiaoePageObserverScript,
      );
      _shellEventSubscription = widget.events.stream.listen((event) {
        if (_disposed) {
          return;
        }
        if (event.type == ShellEventType.runtimeReloadRequested) {
          unawaited(_reload());
        }
      });
      _titleSubscription = _controller.title.listen((title) {
        _title = title.trim().isEmpty ? xiaoeShellAppTitle : title.trim();
        unawaited(_persistRuntimeSignal());
        if (!_disposed && mounted) {
          setState(() {});
        }
      });
      _urlSubscription = _controller.url.listen((url) {
        _runtimeUrl = url.trim().isEmpty ? defaultXiaoeRuntimeUrl : url.trim();
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
      await _controller.loadUrl(defaultXiaoeRuntimeUrl);
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
          loginState: 'unknown',
          hookState: 'error',
          runtimeUrl: _runtimeUrl,
          pageTitle: _title,
          webviewAvailable: false,
          shellMode: 'desktop_shell',
          pageKind: 'unknown',
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

  Future<void> _reload() async {
    if (mounted) {
      setState(() {
        _loading = true;
      });
    }
    try {
      await _controller.loadUrl(defaultXiaoeRuntimeUrl);
      await _installObserverAndProbe();
      await _persistRuntimeSignal(webviewAvailable: true);
    } finally {
      if (!_disposed && mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  Future<void> _persistRuntimeSignal({bool? webviewAvailable}) async {
    await widget.store.update((current) {
      return current.copyWith(
        shellState: 'online',
        hookState: 'healthy',
        runtimeUrl: _runtimeUrl,
        pageTitle: _title,
        webviewAvailable: webviewAvailable ?? current.webviewAvailable,
        shellMode: 'desktop_shell',
        pageKind: deriveXiaoePageKind(
          runtimeUrl: _runtimeUrl,
          pageTitle: _title,
        ),
        lastUpdatedAt: DateTime.now().toUtc(),
      );
    });
  }

  void _handleWebMessage(dynamic message) {
    final json = _asJsonObject(message);
    if (json == null) {
      return;
    }
    final observerMessage = XiaoePageObserverMessage.fromJson(json);
    if (observerMessage.isPageChanged) {
      unawaited(_refreshPageProbe());
    }
  }

  Future<void> _installObserverAndProbe() async {
    try {
      await _controller.executeScript(xiaoePageObserverScript);
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

  Future<void> _refreshPageProbe() async {
    if (_disposed) {
      return;
    }
    final raw = await _controller.executeScript(xiaoePageProbeScript);
    final json = _asJsonObject(raw);
    if (json == null) {
      return;
    }
    final probe = XiaoePageProbe.fromScriptResult(json);
    await _capture.applyProbe(probe);
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

  String deriveXiaoePageKind({
    required String runtimeUrl,
    required String pageTitle,
  }) {
    final url = runtimeUrl.trim().toLowerCase();
    final title = pageTitle.trim();
    if (url.contains('muti_index')) {
      return 'muti_index';
    }
    if (url.contains('live') || title.contains('直播')) {
      return 'live';
    }
    if (url.contains('circle') || title.contains('圈子')) {
      return 'circle';
    }
    if (url.contains('course') || title.contains('课程')) {
      return 'course';
    }
    return 'unknown';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_title),
        actions: [
          IconButton(
            onPressed: _reload,
            icon: const Icon(Icons.refresh_rounded),
            tooltip: '重新打开小鹅通',
          ),
        ],
        bottom: _loading
            ? const PreferredSize(
                preferredSize: Size.fromHeight(2),
                child: LinearProgressIndicator(minHeight: 2),
              )
            : null,
      ),
      body: Column(
        children: [
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
