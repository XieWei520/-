import 'dart:async';
import 'dart:io';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:local_monitor_shell_core/local_monitor_shell_core.dart';
import 'package:path_provider/path_provider.dart';
import 'package:webview_windows/webview_windows.dart';

import 'src/mengxia_incognito_runtime.dart';
import 'src/mengxia_configured_source_cycler.dart';
import 'src/mengxia_network_capture.dart';
import 'src/mengxia_network_capture_bridge.dart';
import 'src/mengxia_network_capture_parser.dart';
import 'src/mengxia_network_capture_store.dart';
import 'src/mengxia_page_observer.dart';
import 'src/mengxia_page_probe.dart';
import 'src/mengxia_runtime_snapshot_mapper.dart';
import 'src/mengxia_shell_snapshot_updater.dart';

const String defaultMengxiaRuntimeUrl =
    'https://mx.2026.naaifu.cn/#/pages/login/login';
const int defaultMengxiaShellPort = 18786;
const String defaultMengxiaShellToken = 'wukong-mengxia-shell-dev';
const String mengxiaShellAppTitle = 'MX信息监控';
const String mengxiaManualLoginNotice =
    'Manual login is required every launch.';
const String mengxiaNoTraceNotice =
    'No cookies, localStorage, history, profile, or session directory are reused.';
const String mengxiaSourceDiscoveryNotice = '可使用鼠标滚轮滚动群列表和消息区，正在扫描可见来源。';
const String mengxiaConfiguredSourceCycleNotice =
    '配置转发规则后，将轮询已配置且页面可点击的萌侠来源。';
const List<String> mengxiaShellWebviewFlags = <String>[
  '--disable-background-timer-throttling',
  '--disable-renderer-backgrounding',
  '--disable-backgrounding-occluded-windows',
  '--disable-features=CalculateNativeWinOcclusion,IntensiveWakeUpThrottling',
];

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final runtime = await prepareMengxiaShellRuntime(
    await getApplicationSupportDirectory(),
  );
  await WebviewController.initializeEnvironment(
    userDataPath: runtime.webviewUserDataPath,
    additionalArguments: mengxiaShellWebviewFlags.join(' '),
  );
  final store = ShellStore(runtime.snapshotFile);
  await _initializeShellStore(store);
  final events = ShellEventBus();
  final server = ShellServer(
    store: store,
    host: InternetAddress.loopbackIPv4,
    port: defaultMengxiaShellPort,
    token: defaultMengxiaShellToken,
    events: events,
  );
  await server.start();
  runApp(
    MengxiaMonitorShellApp(
      runtime: runtime,
      store: store,
      events: events,
      server: server,
    ),
  );
}

class MengxiaShellRuntime {
  const MengxiaShellRuntime({
    required this.supportDirectory,
    required this.sessionDirectory,
    required this.snapshotFile,
  });

  final Directory supportDirectory;
  final Directory sessionDirectory;
  final File snapshotFile;

  String get webviewUserDataPath => sessionDirectory.path;
}

Future<MengxiaShellRuntime> prepareMengxiaShellRuntime(
  Directory supportDirectory,
) async {
  final sessionDirectory = await createMengxiaFreshSessionDirectory(
    Directory(
      '${supportDirectory.path}${Platform.pathSeparator}'
      'mengxia_monitor_shell_runtime',
    ),
  );
  return MengxiaShellRuntime(
    supportDirectory: supportDirectory,
    sessionDirectory: sessionDirectory,
    snapshotFile: mengxiaShellSnapshotFileFor(supportDirectory),
  );
}

Future<bool> disposeMengxiaShellRuntimeResources({
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
  return destroyMengxiaFreshSessionDirectoryBestEffort(
    sessionDirectory,
    retryDelays: cleanupRetryDelays,
  );
}

Future<void> _initializeShellStore(ShellStore store) async {
  final now = DateTime.now().toUtc();
  await store.save(
    ShellSnapshot.initial().copyWith(
      shellState: 'online',
      captureState: 'stopped',
      loginState: 'login_required',
      hookState: 'healthy',
      runtimeUrl: defaultMengxiaRuntimeUrl,
      pageTitle: mengxiaShellAppTitle,
      webviewAvailable: false,
      shellMode: 'desktop_shell',
      pageKind: 'login',
      lastUpdatedAt: now,
      lastError: '',
    ),
  );
}

class MengxiaMonitorShellApp extends StatelessWidget {
  const MengxiaMonitorShellApp({
    super.key,
    this.runtime,
    this.store,
    this.events,
    this.server,
  });

  final MengxiaShellRuntime? runtime;
  final ShellStore? store;
  final ShellEventBus? events;
  final ShellServer? server;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: mengxiaShellAppTitle,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF1B6F5C)),
        useMaterial3: true,
      ),
      home: runtime == null || store == null || events == null
          ? const MengxiaMonitorShellInfoHome()
          : MengxiaMonitorShellHome(
              runtime: runtime!,
              store: store!,
              events: events!,
              server: server,
            ),
    );
  }
}

class MengxiaMonitorShellInfoHome extends StatelessWidget {
  const MengxiaMonitorShellInfoHome({super.key});

  static const MengxiaIncognitoRuntimePolicy policy =
      MengxiaIncognitoRuntimePolicy.strict();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text(mengxiaShellAppTitle)),
      body: const Center(child: _PrivacyNotice()),
    );
  }
}

class MengxiaMonitorShellHome extends StatefulWidget {
  const MengxiaMonitorShellHome({
    super.key,
    required this.runtime,
    required this.store,
    required this.events,
    this.server,
  });

  final MengxiaShellRuntime runtime;
  final ShellStore store;
  final ShellEventBus events;
  final ShellServer? server;

  @override
  State<MengxiaMonitorShellHome> createState() =>
      _MengxiaMonitorShellHomeState();
}

class _MengxiaMonitorShellHomeState extends State<MengxiaMonitorShellHome> {
  late final WebviewController _controller;
  final GlobalKey _webviewHostKey = GlobalKey(debugLabel: 'mengxia-webview');
  bool _webviewReady = false;
  bool _loading = true;
  bool _disposed = false;
  String _title = mengxiaShellAppTitle;
  String _runtimeUrl = defaultMengxiaRuntimeUrl;
  String _error = '';
  Timer? _probeTimer;
  final MengxiaConfiguredSourceCycler _configuredSourceCycler =
      MengxiaConfiguredSourceCycler();
  late final MengxiaNetworkCaptureBridge _networkCaptureBridge;
  late final MengxiaNetworkCaptureStore _networkCaptureStore;
  StreamSubscription<MengxiaNetworkCaptureEvent>? _networkCaptureSubscription;
  StreamSubscription<String>? _networkCaptureUnavailableSubscription;
  StreamSubscription<String>? _titleSubscription;
  StreamSubscription<String>? _urlSubscription;
  StreamSubscription<LoadingState>? _loadingStateSubscription;
  StreamSubscription<dynamic>? _webMessageSubscription;
  StreamSubscription<ShellEvent>? _shellEventSubscription;

  @override
  void initState() {
    super.initState();
    _controller = WebviewController();
    _networkCaptureBridge = MengxiaNetworkCaptureBridge();
    _networkCaptureStore = MengxiaNetworkCaptureStore();
    _networkCaptureSubscription = _networkCaptureBridge.events.listen(
      _handleNetworkCaptureEvent,
    );
    _networkCaptureUnavailableSubscription = _networkCaptureBridge
        .unavailableErrors
        .listen(_handleNetworkCaptureUnavailable);
    unawaited(
      _networkCaptureBridge.start().catchError((Object error) {
        _handleNetworkCaptureUnavailable(error.toString());
      }),
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

  Future<void> _disposeRuntimeResources() async {
    await disposeMengxiaShellRuntimeResources(
      sessionDirectory: widget.runtime.sessionDirectory,
      cancelSubscriptions: <Future<void> Function()>[
        if (_titleSubscription != null) _titleSubscription!.cancel,
        if (_urlSubscription != null) _urlSubscription!.cancel,
        if (_loadingStateSubscription != null)
          _loadingStateSubscription!.cancel,
        if (_webMessageSubscription != null) _webMessageSubscription!.cancel,
        if (_shellEventSubscription != null) _shellEventSubscription!.cancel,
        if (_networkCaptureSubscription != null)
          _networkCaptureSubscription!.cancel,
        if (_networkCaptureUnavailableSubscription != null)
          _networkCaptureUnavailableSubscription!.cancel,
        _networkCaptureBridge.dispose,
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
        mengxiaPageObserverScript,
      );
      if (_disposed) {
        return;
      }
      _shellEventSubscription = widget.events.stream.listen((event) {
        if (_disposed) {
          return;
        }
        if (event.type == ShellEventType.runtimeReloadRequested) {
          unawaited(_reloadFreshLoginPage());
        }
      });
      _titleSubscription = _controller.title.listen((title) {
        _title = title.trim().isEmpty ? mengxiaShellAppTitle : title;
        unawaited(_persistRuntimeSignal());
        if (!_disposed && mounted) {
          setState(() {});
        }
      });
      _urlSubscription = _controller.url.listen((url) {
        _runtimeUrl = url.trim().isEmpty ? defaultMengxiaRuntimeUrl : url;
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
      await _controller.loadUrl(defaultMengxiaRuntimeUrl);
      if (_disposed) {
        return;
      }
      await _persistRuntimeSignal(webviewAvailable: true);
      _probeTimer = Timer.periodic(const Duration(seconds: 2), (_) {
        if (!_disposed && !_loading) {
          unawaited(_installObserverAndProbe());
        }
      });
      if (mounted) {
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

  Future<void> _reloadFreshLoginPage() async {
    setState(() {
      _loading = true;
    });
    try {
      await _controller.clearCookies();
      await _controller.clearCache();
      await _controller.loadUrl(defaultMengxiaRuntimeUrl);
      await _installObserverAndProbe();
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  Future<void> _installObserverAndProbe() async {
    try {
      await _controller.executeScript(mengxiaPageObserverScript);
      await _visitNextConfiguredSourceIfAvailable();
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
    final observerMessage = MengxiaPageObserverMessage.fromJson(json);
    if (observerMessage.isPageChanged) {
      unawaited(_refreshPageProbe());
    }
  }

  void _handleNetworkCaptureEvent(MengxiaNetworkCaptureEvent event) {
    if (_disposed) {
      return;
    }
    _networkCaptureStore.addNetworkEvent(event);
    final parsedEvents = parseMengxiaNetworkMessageEvents(event);
    for (final parsedEvent in parsedEvents) {
      _networkCaptureStore.addMessageEvent(parsedEvent);
    }
    if (parsedEvents.isNotEmpty) {
      unawaited(_refreshPageProbe());
    } else {
      unawaited(_persistNetworkCaptureDiagnostics());
    }
  }

  void _handleNetworkCaptureUnavailable(String error) {
    if (_disposed) {
      return;
    }
    _networkCaptureStore.setUnavailable(error);
    unawaited(_persistNetworkCaptureDiagnostics());
  }

  Future<void> _persistNetworkCaptureDiagnostics() async {
    if (_disposed) {
      return;
    }
    try {
      await widget.store.update((current) {
        return current.copyWith(
          probeDiagnostics: <String, dynamic>{
            ...current.probeDiagnostics,
            ..._networkCaptureStore.toDiagnosticsJson(),
          },
          lastUpdatedAt: DateTime.now().toUtc(),
        );
      });
    } catch (_) {
      // Network diagnostics are best-effort and must not interrupt capture.
    }
  }

  Future<void> _refreshPageProbe() async {
    if (_disposed) {
      return;
    }
    final raw = await _controller.executeScript(mengxiaPageProbeScript);
    final json = _asJsonObject(raw);
    if (json == null) {
      return;
    }
    final probe = mengxiaPageProbeFromJson(json);
    final snapshot = mapMengxiaRuntimeSnapshot(probe);
    final next = await widget.store.update(
      (current) => applyMengxiaRuntimeSnapshot(
        current: current,
        snapshot: snapshot,
        probe: probe,
        updatedAt: DateTime.now().toUtc(),
        networkEvents: _networkCaptureStore.recentMessageEvents,
        networkDiagnostics: _networkCaptureStore.toDiagnosticsJson(),
      ),
      preserveCaptureState: false,
    );
    widget.events.publish(
      ShellEvent(
        type: ShellEventType.snapshotUpdated,
        reason: 'mengxia_probe',
        updatedAt: next.lastUpdatedAt,
        recentEventsCount: next.recentEvents.length,
        observedConversationsCount: next.observedConversations.length,
      ),
    );
  }

  Future<void> _visitNextConfiguredSourceIfAvailable() async {
    final snapshot = await widget.store.load();
    final sources = mengxiaConfiguredSourcesFromDiagnostics(
      snapshot.probeDiagnostics,
    );
    final source = _configuredSourceCycler.next(sources);
    if (source == null) {
      return;
    }
    final raw = await _controller.executeScript(
      mengxiaClickConfiguredSourceScript(source),
    );
    final json = _asJsonObject(raw);
    final handled = json?['handled'] == true;
    await widget.store.update((current) {
      return current.copyWith(
        probeDiagnostics: <String, dynamic>{
          ...current.probeDiagnostics,
          'configured_source_cycle_count': sources.length,
          'last_configured_source_cycle_at': DateTime.now()
              .toUtc()
              .toIso8601String(),
          'last_configured_source_cycle_id': source.conversationId,
          'last_configured_source_cycle_name': source.conversationName,
          'last_configured_source_cycle_result':
              (json?['reason'] ?? (handled ? 'configured-source-click' : ''))
                  .toString(),
        },
        lastUpdatedAt: DateTime.now().toUtc(),
      );
    });
    if (handled) {
      await Future<void>.delayed(const Duration(milliseconds: 450));
    }
  }

  void _handleWebviewPointerSignal(PointerSignalEvent signal) {
    if (signal is PointerScrollEvent) {
      unawaited(_runManualWheelScrollFallback(signal));
    }
  }

  Future<void> _runManualWheelScrollFallback(PointerScrollEvent signal) async {
    await Future<void>.delayed(const Duration(milliseconds: 90));
    if (_disposed || !_webviewReady) {
      return;
    }
    final box =
        _webviewHostKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) {
      return;
    }
    final localPosition = box.globalToLocal(signal.position);
    if (localPosition.dx < 0 ||
        localPosition.dy < 0 ||
        localPosition.dx > box.size.width ||
        localPosition.dy > box.size.height) {
      return;
    }
    try {
      await _controller.executeScript(
        mengxiaManualWheelScrollFallbackScript(
          clientX: localPosition.dx,
          clientY: localPosition.dy,
          deltaX: signal.scrollDelta.dx,
          deltaY: signal.scrollDelta.dy,
        ),
      );
    } catch (_) {
      // The shell may be navigating; the periodic probe will reinstall helpers.
    }
  }

  Future<void> _persistRuntimeSignal({bool? webviewAvailable}) async {
    await widget.store.update((current) {
      final pageKind = deriveMengxiaPageKind(
        runtimeUrl: _runtimeUrl,
        pageTitle: _title,
        bodyText: '',
        hasForwardableContent: current.recentEvents.isNotEmpty,
      );
      return current.copyWith(
        shellState: 'online',
        captureState: pageKind == MengxiaPageKind.login ? 'stopped' : 'running',
        loginState: pageKind == MengxiaPageKind.login
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
        title: const Text(mengxiaShellAppTitle),
        actions: [
          IconButton(
            onPressed: _reloadFreshLoginPage,
            icon: const Icon(Icons.refresh_rounded),
            tooltip: '重载无痕登录页',
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
                ? Listener(
                    key: _webviewHostKey,
                    onPointerSignal: _handleWebviewPointerSignal,
                    child: Webview(_controller),
                  )
                : const Center(child: CircularProgressIndicator()),
          ),
        ],
      ),
    );
  }
}

class _PrivacyNotice extends StatelessWidget {
  const _PrivacyNotice();

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 720),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            mengxiaManualLoginNotice,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(mengxiaNoTraceNotice, style: const TextStyle(fontSize: 16)),
          const SizedBox(height: 10),
          const _SourceDiscoveryProgress(),
          const SizedBox(height: 8),
          Text(mengxiaConfiguredSourceCycleNotice),
        ],
      ),
    );
  }
}

class _SourceDiscoveryProgress extends StatelessWidget {
  const _SourceDiscoveryProgress();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      label: mengxiaSourceDiscoveryNotice,
      liveRegion: true,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        decoration: BoxDecoration(
          color: theme.colorScheme.primaryContainer.withValues(alpha: 0.34),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: theme.colorScheme.primary.withValues(alpha: 0.18),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Icon(
                  Icons.radar_rounded,
                  size: 18,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    mengxiaSourceDiscoveryNotice,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            LinearProgressIndicator(
              minHeight: 3,
              backgroundColor: theme.colorScheme.surface,
              color: theme.colorScheme.primary,
            ),
          ],
        ),
      ),
    );
  }
}
