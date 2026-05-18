import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:feishu_monitor_shell/feishu_monitor_shell.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:webview_windows/webview_windows.dart';

import 'src/feishu_browser_image_body_cache.dart';
import 'src/feishu_network_capture.dart';
import 'src/feishu_network_capture_bridge.dart';
import 'src/feishu_network_capture_parser.dart';
import 'src/feishu_network_capture_probe.dart';
import 'src/feishu_network_capture_retention.dart';
import 'src/feishu_network_forwardable_image_resolver.dart';
import 'src/feishu_network_capture_store.dart';
import 'src/feishu_page_observer.dart';
import 'src/feishu_page_probe.dart';
import 'src/probe_scheduler.dart';
import 'src/runtime_snapshot_mapper.dart';

export 'src/feishu_network_capture_retention.dart';

const String defaultFeishuRuntimeUrl = 'https://www.feishu.cn/messenger/';
const List<String> feishuShellWebviewBackgroundRealtimeFlags = <String>[
  '--disable-background-timer-throttling',
  '--disable-renderer-backgrounding',
  '--disable-backgrounding-occluded-windows',
  '--disable-features=CalculateNativeWinOcclusion,IntensiveWakeUpThrottling',
];
const Duration feishuMediaFeedOpenRetryDelay = Duration(seconds: 20);
const Duration feishuConfiguredMediaFeedKeepAliveCooldown = Duration(
  seconds: 60,
);
const int feishuConfiguredMediaFeedKeepAliveStaleProbeCount = 5;
const bool feishuMediaConversationOpenEnabled = true;
const bool feishuLatestFeedAutoOpenEnabled = false;
const String feishuMediaConversationOpenReason =
    'pending_media_feed_open_enabled';
const String feishuLatestFeedAutoOpenDisabledReason =
    'latest_feed_auto_open_disabled';
const String feishuShellAppTitle = '飞书消息监控助手';
const String feishuShellStableSupportDirectoryName = 'feishu_monitor_shell_app';
const String feishuShellRefreshTooltip = '刷新';

class FeishuShellWorkerOptions {
  const FeishuShellWorkerOptions({
    required this.workerId,
    required this.port,
    required this.profileSuffix,
    required this.titleSuffix,
  });

  final String workerId;
  final int port;
  final String profileSuffix;
  final String titleSuffix;

  static const FeishuShellWorkerOptions defaults = FeishuShellWorkerOptions(
    workerId: 'worker-1',
    port: 18766,
    profileSuffix: '',
    titleSuffix: '',
  );
}

FeishuShellWorkerOptions parseFeishuShellWorkerOptions(List<String> args) {
  var workerId = FeishuShellWorkerOptions.defaults.workerId;
  var port = FeishuShellWorkerOptions.defaults.port;
  var profileSuffix = '';
  var titleSuffix = '';

  for (final arg in args) {
    final index = arg.indexOf('=');
    if (!arg.startsWith('--') || index <= 2) {
      continue;
    }
    final key = arg.substring(2, index).trim();
    final value = arg.substring(index + 1).trim();
    if (value.isEmpty) {
      continue;
    }
    switch (key) {
      case 'worker-id':
        if (_isSafeFeishuShellWorkerToken(value)) {
          workerId = value;
          titleSuffix = value;
        }
      case 'port':
        final parsedPort = int.tryParse(value);
        if (parsedPort != null && _isValidFeishuShellWorkerPort(parsedPort)) {
          port = parsedPort;
        }
      case 'profile-suffix':
        if (_isSafeFeishuShellWorkerToken(value)) {
          profileSuffix = value;
        }
    }
  }

  return FeishuShellWorkerOptions(
    workerId: workerId,
    port: port,
    profileSuffix: profileSuffix,
    titleSuffix: titleSuffix.isEmpty ? workerId : titleSuffix,
  );
}

bool _isSafeFeishuShellWorkerToken(String value) {
  return RegExp(r'^[A-Za-z0-9_-]+$').hasMatch(value.trim());
}

bool _isValidFeishuShellWorkerPort(int value) {
  return value >= 1024 && value <= 65535;
}

Map<String, dynamic> feishuLatestFeedAutoOpenDisabledResult() {
  return <String, dynamic>{
    'attempted': false,
    'opened': false,
    'reason': feishuLatestFeedAutoOpenDisabledReason,
  };
}

String mediaPreviewExtractionSignature({
  required String domImageSignature,
  required String pendingMediaFeedKey,
}) {
  final normalizedDomSignature = domImageSignature.trim();
  if (normalizedDomSignature.isEmpty) {
    return '';
  }
  final normalizedPendingKey = pendingMediaFeedKey.trim();
  if (normalizedPendingKey.isEmpty) {
    return normalizedDomSignature;
  }
  return '$normalizedDomSignature\npending:$normalizedPendingKey';
}

Map<String, dynamic> mediaPreviewExtractionDiagnostics(
  Map<String, dynamic> result, {
  required String extractionSignature,
  required String pendingMediaFeedKey,
}) {
  return <String, dynamic>{
    ...result,
    'signature': extractionSignature,
    'pending_key': pendingMediaFeedKey.trim(),
  };
}

String feishuShellWebviewAdditionalArguments() {
  return feishuShellWebviewBackgroundRealtimeFlags.join(' ');
}

bool shouldOpenConfiguredMediaFeedKeepAlive({
  required int sameFeedSignatureCount,
  required bool hasConfiguredMediaSources,
  required bool pendingMediaNeedsExtraction,
  required DateTime now,
  DateTime? lastOpenedAt,
  int staleProbeCount = feishuConfiguredMediaFeedKeepAliveStaleProbeCount,
  Duration cooldown = feishuConfiguredMediaFeedKeepAliveCooldown,
}) {
  if (!hasConfiguredMediaSources ||
      pendingMediaNeedsExtraction ||
      sameFeedSignatureCount < staleProbeCount) {
    return false;
  }
  if (lastOpenedAt == null) {
    return true;
  }
  return now.toUtc().difference(lastOpenedAt.toUtc()) >= cooldown;
}

int nextConfiguredMediaFeedKeepAliveCursor({
  required int currentIndex,
  required int sourceCount,
}) {
  if (sourceCount <= 0) {
    return 0;
  }
  final normalizedIndex = currentIndex < 0 ? 0 : currentIndex;
  return (normalizedIndex + 1) % sourceCount;
}

Future<void> main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();
  final options = parseFeishuShellWorkerOptions(args);
  await WebviewController.initializeEnvironment(
    additionalArguments: feishuShellWebviewAdditionalArguments(),
  );
  final supportDirectory = await prepareFeishuShellSupportDirectory(
    await getApplicationSupportDirectory(),
    profileSuffix: options.profileSuffix,
  );
  final snapshotFile = feishuShellSnapshotFileFor(supportDirectory);
  final diagnosticsFile = networkCaptureDiagnosticsFileFor(supportDirectory);
  await cleanupFeishuNetworkCaptureRuntime(
    diagnosticsFile: diagnosticsFile,
    now: DateTime.now().toUtc(),
  );
  final store = ShellStore(snapshotFile);
  final initializedSnapshot = (await store.load()).copyWith(
    workerId: options.workerId,
  );
  await store.save(initializedSnapshot);
  final events = ShellEventBus();
  final server = ShellServer(
    store: store,
    host: InternetAddress.loopbackIPv4,
    port: options.port,
    token: 'wukong-feishu-shell-dev',
    events: events,
  );
  await server.start();
  runApp(
    FeishuMonitorShellApp(
      store: store,
      events: events,
      networkDiagnosticsFile: diagnosticsFile,
      workerOptions: options,
    ),
  );
}

Directory feishuShellStableSupportDirectoryFor(
  Directory supportDirectory, {
  String profileSuffix = '',
}) {
  final parent = supportDirectory.parent;
  final suffix = profileSuffix.trim().isEmpty ? '' : '_${profileSuffix.trim()}';
  return Directory(
    '${parent.path}${Platform.pathSeparator}'
    '$feishuShellStableSupportDirectoryName$suffix',
  );
}

File feishuShellSnapshotFileFor(Directory supportDirectory) {
  return File(
    '${supportDirectory.path}${Platform.pathSeparator}feishu_monitor_shell'
    '${Platform.pathSeparator}status.json',
  );
}

Future<Directory> prepareFeishuShellSupportDirectory(
  Directory supportDirectory, {
  String profileSuffix = '',
}) async {
  final stableDirectory = feishuShellStableSupportDirectoryFor(
    supportDirectory,
    profileSuffix: profileSuffix,
  );
  if (profileSuffix.trim().isEmpty) {
    await _migrateRenamedShellStatusFile(
      fromSupportDirectory: supportDirectory,
      toSupportDirectory: stableDirectory,
    );
  }
  return stableDirectory;
}

Future<void> _migrateRenamedShellStatusFile({
  required Directory fromSupportDirectory,
  required Directory toSupportDirectory,
}) async {
  if (fromSupportDirectory.path == toSupportDirectory.path) {
    return;
  }
  final source = feishuShellSnapshotFileFor(fromSupportDirectory);
  if (!await source.exists()) {
    return;
  }
  final target = feishuShellSnapshotFileFor(toSupportDirectory);
  if (await target.exists()) {
    final sourceModified = await source.lastModified();
    final targetModified = await target.lastModified();
    if (!sourceModified.isAfter(targetModified)) {
      return;
    }
  }
  await target.parent.create(recursive: true);
  await source.copy(target.path);
}

File networkCaptureDiagnosticsFileFor(Directory supportDirectory) {
  return File(
    '${supportDirectory.path}${Platform.pathSeparator}feishu_monitor_shell'
    '${Platform.pathSeparator}.runtime${Platform.pathSeparator}'
    'feishu-network-capture${Platform.pathSeparator}network.jsonl',
  );
}

List<String> feishuShellDocumentCreatedScripts() {
  return const <String>[
    feishuPageKeepAliveScript,
    feishuNetworkImageAttributionScript,
  ];
}

List<String> feishuShellPageObserverScripts() {
  return const <String>[
    feishuPageKeepAliveScript,
    feishuPageObserverScript,
    feishuNetworkImageAttributionScript,
    feishuStorageProbeScript,
  ];
}

class FeishuMonitorShellApp extends StatelessWidget {
  const FeishuMonitorShellApp({
    super.key,
    required this.store,
    required this.events,
    required this.networkDiagnosticsFile,
    required this.workerOptions,
  });

  final ShellStore store;
  final ShellEventBus events;
  final File networkDiagnosticsFile;
  final FeishuShellWorkerOptions workerOptions;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: workerOptions.titleSuffix.isEmpty
          ? feishuShellAppTitle
          : '$feishuShellAppTitle ${workerOptions.titleSuffix}',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFFF65835)),
        useMaterial3: true,
      ),
      home: FeishuMonitorShellHome(
        store: store,
        events: events,
        networkDiagnosticsFile: networkDiagnosticsFile,
      ),
    );
  }
}

class FeishuMonitorShellHome extends StatefulWidget {
  const FeishuMonitorShellHome({
    super.key,
    required this.store,
    required this.events,
    required this.networkDiagnosticsFile,
  });

  final ShellStore store;
  final ShellEventBus events;
  final File networkDiagnosticsFile;

  @override
  State<FeishuMonitorShellHome> createState() => _FeishuMonitorShellHomeState();
}

class _FeishuMonitorShellHomeState extends State<FeishuMonitorShellHome> {
  late final WebviewController _controller;
  bool _webviewReady = false;
  String _pageTitle = feishuShellAppTitle;
  String _runtimeUrl = defaultFeishuRuntimeUrl;
  bool _loading = true;
  String _error = '';
  StreamSubscription<String>? _titleSubscription;
  StreamSubscription<String>? _urlSubscription;
  StreamSubscription<LoadingState>? _loadingStateSubscription;
  StreamSubscription<dynamic>? _webMessageSubscription;
  StreamSubscription<ShellEvent>? _shellEventSubscription;
  late final FeishuNetworkCaptureBridge _networkCaptureBridge;
  late final FeishuNetworkCaptureStore _networkCaptureStore;
  late final FeishuNetworkForwardableImageResolver _networkImageResolver;
  final Set<String> _recordedNetworkImageDedupeKeys = <String>{};
  StreamSubscription<FeishuNetworkCaptureEvent>? _networkCaptureSubscription;
  StreamSubscription<String>? _networkCaptureUnavailableSubscription;
  late final ProbeScheduler _probeScheduler;
  Timer? _probeTimer;
  Timer? _networkCaptureRuntimeCleanupTimer;
  String _lastOpenedMediaFeedKey = '';
  DateTime? _lastOpenedMediaFeedAt;
  Map<String, dynamic> _lastMediaOpenResult = const <String, dynamic>{};
  Map<String, dynamic> _lastMediaPreviewOpenResult = const <String, dynamic>{};
  Map<String, dynamic> _lastMediaPreviewOriginalResult =
      const <String, dynamic>{};
  Map<String, dynamic> _lastMediaPreviewCloseResult = const <String, dynamic>{};
  String _lastOpenedDomImageSignature = '';
  Map<String, dynamic> _lastFeedOpenResult = const <String, dynamic>{};
  Map<String, dynamic> _lastActiveConfiguredFeedJumpResult =
      const <String, dynamic>{};
  DateTime? _lastConfiguredMediaFeedKeepAliveAt;
  Map<String, dynamic> _lastConfiguredMediaFeedKeepAliveResult =
      const <String, dynamic>{};
  int _configuredMediaFeedKeepAliveCursor = 0;
  String _lastFeedContentSignature = '';
  int _sameFeedContentSignatureCount = 0;
  bool _disposed = false;

  @override
  void initState() {
    super.initState();
    _controller = WebviewController();
    _probeScheduler = ProbeScheduler(runProbe: _refreshPageProbe);
    _networkCaptureBridge = FeishuNetworkCaptureBridge();
    _networkCaptureStore = FeishuNetworkCaptureStore(
      diagnosticsFile: widget.networkDiagnosticsFile,
    );
    _networkImageResolver = FeishuNetworkForwardableImageResolver();
    _networkCaptureSubscription = _networkCaptureBridge.events.listen(
      _handleNetworkCaptureEvent,
    );
    _networkCaptureUnavailableSubscription = _networkCaptureBridge
        .unavailableErrors
        .listen(_handleNetworkCaptureUnavailable);
    _networkCaptureRuntimeCleanupTimer = Timer.periodic(
      const Duration(hours: 1),
      (_) => unawaited(_cleanupNetworkCaptureRuntime()),
    );
    unawaited(_cleanupNetworkCaptureRuntime());
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
    unawaited(_titleSubscription?.cancel());
    unawaited(_urlSubscription?.cancel());
    unawaited(_loadingStateSubscription?.cancel());
    unawaited(_webMessageSubscription?.cancel());
    unawaited(_shellEventSubscription?.cancel());
    unawaited(_networkCaptureSubscription?.cancel());
    unawaited(_networkCaptureUnavailableSubscription?.cancel());
    unawaited(_networkCaptureBridge.dispose());
    _probeTimer?.cancel();
    _networkCaptureRuntimeCleanupTimer?.cancel();
    unawaited(_controller.dispose());
    super.dispose();
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
      if (_disposed) {
        return;
      }
      await _installDocumentCreatedScripts();
      if (_disposed) {
        return;
      }
      _shellEventSubscription = widget.events.stream.listen((event) {
        if (_disposed) {
          return;
        }
        if (event.type == ShellEventType.runtimeReloadRequested) {
          if (event.reason == 'runtime_session_reset') {
            unawaited(_sessionReset());
          } else if (event.reason == 'runtime_hard_reload') {
            unawaited(_hardReload());
          } else {
            unawaited(_reload());
          }
        }
      });
      _titleSubscription = _controller.title.listen((title) {
        if (_disposed) {
          return;
        }
        _pageTitle = title;
        unawaited(_persistRuntimeState());
        if (!_disposed && mounted) {
          setState(() {});
        }
      });
      _urlSubscription = _controller.url.listen((url) {
        if (_disposed) {
          return;
        }
        _runtimeUrl = url;
        unawaited(_persistRuntimeState());
        if (!_disposed && mounted) {
          setState(() {});
        }
      });
      _loadingStateSubscription = _controller.loadingState.listen((state) {
        if (_disposed) {
          return;
        }
        final isLoading = state == LoadingState.loading;
        _loading = isLoading;
        unawaited(_persistRuntimeState());
        if (state == LoadingState.navigationCompleted) {
          unawaited(_installPageObserver());
          _probeScheduler.request('navigation');
        }
        if (!_disposed && mounted) {
          setState(() {});
        }
      });
      if (_disposed) {
        return;
      }
      await _controller.loadUrl(_runtimeUrl);
      if (_disposed) {
        return;
      }
      await widget.store.update((current) {
        return applyRuntimeSignal(
          current,
          runtimeUrl: _runtimeUrl,
          pageTitle: _pageTitle,
          webviewAvailable: true,
          isLoading: false,
        );
      });
      if (_disposed) {
        return;
      }
      _probeTimer = Timer.periodic(const Duration(seconds: 3), (_) {
        if (_disposed) {
          return;
        }
        if (_webviewReady && !_loading) {
          unawaited(_installPageObserver());
          _probeScheduler.request('fallback');
        }
      });
      if (!_disposed && mounted) {
        setState(() {
          _webviewReady = true;
          _loading = false;
        });
      }
    } catch (error) {
      if (_disposed) {
        return;
      }
      await widget.store.update((current) {
        return current.copyWith(
          shellMode: 'desktop_shell',
          webviewAvailable: false,
          lastError: error.toString(),
          lastUpdatedAt: DateTime.now().toUtc(),
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

  void _handleWebMessage(dynamic message) {
    final json = _asJsonObject(message);
    if (json == null) {
      return;
    }
    final observerMessage = FeishuPageObserverMessage.fromJson(json);
    if (observerMessage.isImageAttribution) {
      final attribution = observerMessage.imageAttribution;
      if (attribution != null) {
        _networkCaptureStore.addAttribution(attribution);
        _probeScheduler.request('image_attribution');
        unawaited(_persistNetworkCaptureDiagnostics());
      }
      return;
    }
    if (observerMessage.isBrowserImageBody) {
      final body = observerMessage.browserImageBody;
      if (body != null) {
        unawaited(_handleBrowserImageBody(body));
      }
      return;
    }
    if (observerMessage.isStorageProbe) {
      unawaited(_persistStorageProbeDiagnostic(json));
      return;
    }
    if (observerMessage.isObserverInstalled) {
      unawaited(_persistRuntimeState());
      return;
    }
    if (observerMessage.isFeedChanged || observerMessage.isMediaResolved) {
      final reason = observerMessage.reason.trim().isEmpty
          ? 'unknown'
          : observerMessage.reason.trim();
      _probeScheduler.request('event:$reason');
    }
  }

  void _handleNetworkCaptureEvent(FeishuNetworkCaptureEvent event) {
    if (_disposed) {
      return;
    }
    _networkCaptureStore.addEvent(event);
    final enrichedEvent = _networkCaptureStore
        .enrichEventWithRequestDiagnostics(event);
    final probe = probeFeishuNetworkCaptureEvent(enrichedEvent);
    if (probe != null) {
      _networkCaptureStore.addProbe(probe);
    }
    for (final candidate in parseFeishuNetworkImageCandidates(enrichedEvent)) {
      _networkCaptureStore.addCandidate(candidate);
    }
    _probeScheduler.request('network_capture');
  }

  Future<void> _handleBrowserImageBody(FeishuBrowserImageBody body) async {
    if (_disposed) {
      return;
    }
    try {
      final saved = await saveFeishuBrowserImageBody(
        body,
        cacheDirectory: _browserImageBodyCacheDirectory(),
      );
      if (_disposed) {
        return;
      }
      final candidate = saved.candidate;
      final attribution = saved.attribution;
      if (candidate != null && attribution != null) {
        _networkCaptureStore.addCandidate(candidate);
        _networkCaptureStore.addAttribution(attribution);
        _probeScheduler.request('browser_image_body');
      } else if (saved.error.trim().isNotEmpty) {
        _networkCaptureStore.addProbe(<String, Object?>{
          'kind': 'browser_image_body',
          'source': 'webview_message',
          'error': saved.error,
          'observed_at': body.observedAt.toUtc().toIso8601String(),
          'source_kind': body.sourceUrl.startsWith('blob:') ? 'blob' : 'url',
          'mime_type': body.mimeType,
          'body_size': body.bodySize,
        });
      }
      unawaited(_persistNetworkCaptureDiagnostics());
    } catch (error) {
      if (_disposed) {
        return;
      }
      _networkCaptureStore.addProbe(<String, Object?>{
        'kind': 'browser_image_body',
        'source': 'webview_message',
        'error': error.toString(),
        'observed_at': body.observedAt.toUtc().toIso8601String(),
      });
      unawaited(_persistNetworkCaptureDiagnostics());
    }
  }

  Directory _browserImageBodyCacheDirectory() {
    return Directory(
      '${widget.networkDiagnosticsFile.parent.path}'
      '${Platform.pathSeparator}network_images',
    );
  }

  void _handleNetworkCaptureUnavailable(String error) {
    if (_disposed) {
      return;
    }
    _networkCaptureStore.setUnavailable(error);
    unawaited(_persistNetworkCaptureDiagnostics());
  }

  Future<void> _persistStorageProbeDiagnostic(
    Map<String, dynamic> probe,
  ) async {
    if (_disposed) {
      return;
    }
    try {
      await widget.store.update((current) {
        return applyStorageProbeDiagnostic(
          current,
          probe.map((key, value) => MapEntry(key.toString(), value)),
        );
      });
    } catch (_) {
      // Storage diagnostics are best-effort and must not crash shell.
    }
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
      if (_disposed) {
        return;
      }
    } catch (_) {
      // Network capture diagnostics are best-effort and must not crash shell.
    }
  }

  Future<void> _cleanupNetworkCaptureRuntime() async {
    if (_disposed) {
      return;
    }
    try {
      await cleanupFeishuNetworkCaptureRuntime(
        diagnosticsFile: widget.networkDiagnosticsFile,
        now: DateTime.now().toUtc(),
      );
    } catch (_) {
      // Runtime cleanup is best-effort and must not interrupt forwarding.
    }
  }

  Map<String, dynamic>? _asJsonObject(dynamic message) {
    if (message is Map) {
      return Map<String, dynamic>.from(
        message.map((key, value) => MapEntry(key.toString(), value)),
      );
    }
    if (message is String) {
      final raw = message.trim();
      if (raw.isEmpty) {
        return null;
      }
      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map) {
          return Map<String, dynamic>.from(
            decoded.map((key, value) => MapEntry(key.toString(), value)),
          );
        }
      } catch (_) {
        return null;
      }
    }
    return null;
  }

  Future<void> _persistRuntimeState() async {
    await widget.store.update((current) {
      return applyRuntimeSignal(
        current,
        runtimeUrl: _runtimeUrl,
        pageTitle: _pageTitle,
        webviewAvailable: _webviewReady,
        isLoading: _loading,
      );
    });
  }

  Future<void> _installPageObserver() async {
    try {
      for (final script in feishuShellPageObserverScripts()) {
        await _controller.executeScript(script);
      }
    } catch (_) {
      // Fallback polling still probes if observer installation fails.
    }
  }

  Future<void> _installDocumentCreatedScripts() async {
    try {
      for (final script in feishuShellDocumentCreatedScripts()) {
        await _controller.addScriptToExecuteOnDocumentCreated(script);
      }
    } catch (_) {
      // The fallback observer install still injects keep-alive after load.
    }
  }

  Future<void> _refreshPageProbe(String reason) async {
    try {
      final result = await _controller.executeScript(feishuPageProbeScript);
      if (result is! Map) {
        await _persistProbeFailure(
          reason: reason,
          resultType: result.runtimeType.toString(),
          resultPreview: _diagnosticPreview(result),
        );
        return;
      }
      final probeJson = await _probeJsonWithPersistentDiagnostics(
        Map<String, dynamic>.from(
          result.map((key, value) => MapEntry(key.toString(), value)),
        ),
      );
      final probe = FeishuPageProbe.fromScriptResult(probeJson);
      if (probe.runtimeUrl.trim().isNotEmpty) {
        _runtimeUrl = probe.runtimeUrl;
      }
      if (probe.pageTitle.trim().isNotEmpty) {
        _pageTitle = probe.pageTitle;
      }
      final feedChanged = _isFeedContentChanged(probe);
      _recordLatestFeedAutoOpenDisabledResult();
      if (feishuMediaConversationOpenEnabled) {
        await _jumpActiveConfiguredMediaFeedToNewestIfNeeded(probe);
        await _openPendingMediaFeedIfNeeded(probe);
        await _openConfiguredMediaFeedKeepAliveIfNeeded(probe);
        await _openLatestMediaPreviewIfNeeded(probe);
        if (feishuLatestFeedAutoOpenEnabled &&
            !probeHasPendingMediaFeedCard(probe) &&
            feedChanged) {
          await _openLatestFeedIfNeeded();
        }
      }
      FeishuNetworkForwardableImageResolution? recordableResolution;
      final next = await widget.store.update((current) {
        var probedSnapshot = applyPageProbe(current, probe);
        final enrichment = applyNetworkImageEnrichment(
          probedSnapshot,
          candidates: _networkCaptureStore.recentCandidates,
          attributions: _networkCaptureStore.recentAttributions,
          recordedNetworkImageDedupeKeys: _recordedNetworkImageDedupeKeys,
          resolve: _networkImageResolver.resolve,
        );
        probedSnapshot = enrichment.snapshot;
        recordableResolution = enrichment.recordableResolution;
        return _withShellDiagnostics(
          probedSnapshot,
          probe,
          reason: reason,
          runtimeUrl: _runtimeUrl,
          pageTitle: _pageTitle,
          webviewAvailable: _webviewReady,
          isLoading: _loading,
        ).copyWith(lastError: _probeDebugMessage(probe));
      });
      final resolutionToRecord = recordableResolution;
      if (resolutionToRecord != null) {
        try {
          _networkCaptureStore.recordForwardableImageResolution(
            resolutionToRecord,
          );
        } catch (_) {
          // Network image diagnostics are best-effort and must not fail probe.
        }
      }
      widget.events.publish(
        ShellEvent(
          type: ShellEventType.snapshotUpdated,
          reason: reason,
          updatedAt: next.lastUpdatedAt,
          recentEventsCount: next.recentEvents.length,
          observedConversationsCount: next.observedConversations.length,
        ),
      );
      if (mounted) {
        setState(() {});
      }
    } catch (error) {
      final next = await widget.store.update((current) {
        return current.copyWith(
          lastError: error.toString(),
          lastUpdatedAt: DateTime.now().toUtc(),
        );
      });
      widget.events.publish(
        ShellEvent(
          type: ShellEventType.shellError,
          reason: reason,
          updatedAt: next.lastUpdatedAt,
          error: error.toString(),
          recentEventsCount: next.recentEvents.length,
          observedConversationsCount: next.observedConversations.length,
        ),
      );
      if (mounted) {
        setState(() {
          _error = error.toString();
        });
      }
    }
  }

  Future<void> _persistProbeFailure({
    required String reason,
    required String resultType,
    required String resultPreview,
  }) async {
    final now = DateTime.now().toUtc();
    final next = await widget.store.update((current) {
      final withRuntime = applyRuntimeSignal(
        current,
        runtimeUrl: _runtimeUrl,
        pageTitle: _pageTitle,
        webviewAvailable: _webviewReady,
        isLoading: _loading,
      );
      return withRuntime.copyWith(
        probeDiagnostics: <String, dynamic>{
          ...withRuntime.probeDiagnostics,
          'last_probe_at': now.toIso8601String(),
          'last_probe_reason': reason,
          'last_probe_success': false,
          'last_probe_result_type': resultType,
          'last_probe_result_preview': resultPreview,
          'shell_probe_reason': reason,
          'shell_probe_observed_at': '',
        },
        lastError: 'probe returned non-map result: $resultType',
        lastUpdatedAt: now,
      );
    });
    widget.events.publish(
      ShellEvent(
        type: ShellEventType.shellError,
        reason: reason,
        updatedAt: next.lastUpdatedAt,
        error: next.lastError,
        recentEventsCount: next.recentEvents.length,
        observedConversationsCount: next.observedConversations.length,
      ),
    );
    if (mounted) {
      setState(() {
        _error = next.lastError;
      });
    }
  }

  String _diagnosticPreview(Object? value) {
    final preview = value?.toString() ?? '';
    return preview.length > 240 ? '${preview.substring(0, 240)}...' : preview;
  }

  Future<Map<String, dynamic>> _probeJsonWithPersistentDiagnostics(
    Map<String, dynamic> probeJson,
  ) async {
    try {
      final current = await widget.store.load();
      final persistent = persistentShellDiagnosticsForProbe(
        current.probeDiagnostics,
        const <String, dynamic>{},
      );
      if (persistent.isEmpty) {
        return probeJson;
      }
      final diagnostics = <String, dynamic>{
        ...persistent,
        if (probeJson['probe_diagnostics'] is Map)
          ...Map<String, dynamic>.from(
            (probeJson['probe_diagnostics'] as Map).map(
              (key, value) => MapEntry(key.toString(), value),
            ),
          ),
      };
      return <String, dynamic>{...probeJson, 'probe_diagnostics': diagnostics};
    } catch (_) {
      return probeJson;
    }
  }

  String _probeDebugMessage(FeishuPageProbe probe) {
    if (probe.observedConversations.isNotEmpty ||
        probe.observedMessages.isNotEmpty) {
      return '';
    }
    final body = probe.bodyText.replaceAll(RegExp(r'\s+'), ' ').trim();
    final preview = body.length > 240 ? '${body.substring(0, 240)}...' : body;
    return 'probe_debug url=${probe.runtimeUrl} title=${probe.pageTitle} '
        'page=${probe.pageKind} body_len=${probe.bodyText.length} '
        'body="$preview"';
  }

  ShellSnapshot _withShellDiagnostics(
    ShellSnapshot snapshot,
    FeishuPageProbe probe, {
    required String reason,
    required String runtimeUrl,
    required String pageTitle,
    required bool webviewAvailable,
    required bool isLoading,
  }) {
    final now = DateTime.now().toUtc();
    final withRuntime = applyRuntimeSignal(
      snapshot,
      runtimeUrl: runtimeUrl,
      pageTitle: pageTitle,
      webviewAvailable: webviewAvailable,
      isLoading: isLoading,
    );
    return withRuntime.copyWith(
      probeDiagnostics: <String, dynamic>{
        ...persistentShellDiagnosticsForProbe(
          withRuntime.probeDiagnostics,
          probe.probeDiagnostics,
        ),
        ..._feedFreshnessDiagnostics(probe),
        ..._networkCaptureStore.toDiagnosticsJson(),
        'pending_media_feed_card_key': probe.pendingMediaFeedCardKey,
        'last_media_open_result': _lastMediaOpenResult,
        'last_media_preview_open_result': _lastMediaPreviewOpenResult,
        'last_media_preview_original_result': _lastMediaPreviewOriginalResult,
        'last_media_preview_close_result': _lastMediaPreviewCloseResult,
        'last_feed_open_result': _lastFeedOpenResult,
        'last_active_configured_feed_jump_result':
            _lastActiveConfiguredFeedJumpResult,
        'last_configured_media_feed_keepalive_result':
            _lastConfiguredMediaFeedKeepAliveResult,
        'last_probe_at': now.toIso8601String(),
        'shell_probe_reason': reason,
        'last_probe_reason': reason,
        'last_probe_success': true,
        'last_probe_result_type': 'Map',
        'body_text_length': probe.bodyText.length,
        'observed_conversation_count': probe.observedConversations.length,
        'observed_message_count': probe.observedMessages.length,
        'recent_event_count': snapshot.recentEvents.length,
        'shell_probe_observed_at':
            probe.observedAt?.toUtc().toIso8601String() ?? '',
      },
      lastUpdatedAt: now,
    );
  }

  Map<String, dynamic> _feedFreshnessDiagnostics(FeishuPageProbe probe) {
    final signature = (probe.probeDiagnostics['feed_content_signature'] ?? '')
        .toString()
        .trim();
    if (signature.isEmpty) {
      return <String, dynamic>{
        'feed_signature_seen': false,
        'same_feed_signature_count': _sameFeedContentSignatureCount,
        'last_feed_content_signature': _lastFeedContentSignature,
      };
    }

    final changed = signature != _lastFeedContentSignature;
    _lastFeedContentSignature = signature;
    _sameFeedContentSignatureCount = changed
        ? 1
        : _sameFeedContentSignatureCount + 1;
    return <String, dynamic>{
      'feed_signature_seen': true,
      'feed_signature_changed': changed,
      'same_feed_signature_count': _sameFeedContentSignatureCount,
      'last_feed_content_signature': signature,
    };
  }

  bool _isFeedContentChanged(FeishuPageProbe probe) {
    final signature = (probe.probeDiagnostics['feed_content_signature'] ?? '')
        .toString()
        .trim();
    return signature.isNotEmpty &&
        _lastFeedContentSignature.isNotEmpty &&
        signature != _lastFeedContentSignature;
  }

  void _recordLatestFeedAutoOpenDisabledResult() {
    if (feishuLatestFeedAutoOpenEnabled) {
      return;
    }
    _lastFeedOpenResult = feishuLatestFeedAutoOpenDisabledResult();
  }

  Future<void> _openConfiguredMediaFeedKeepAliveIfNeeded(
    FeishuPageProbe probe,
  ) async {
    final now = DateTime.now().toUtc();
    final configuredSources = _configuredMediaSourcesFromDiagnostics(
      probe.probeDiagnostics,
    );
    final sourceIds = configuredMediaSourceIdsFromDiagnostics(
      probe.probeDiagnostics,
    );
    final sourceNames = configuredMediaSourceNamesFromDiagnostics(
      probe.probeDiagnostics,
    );
    final currentSnapshot = await widget.store.load();
    final pendingNeedsExtraction = pendingMediaFeedNeedsOriginalExtraction(
      probe: probe,
      recentEvents: currentSnapshot.recentEvents,
    );
    if (!shouldOpenConfiguredMediaFeedKeepAlive(
      sameFeedSignatureCount: _sameFeedContentSignatureCount,
      hasConfiguredMediaSources: sourceIds.isNotEmpty || sourceNames.isNotEmpty,
      pendingMediaNeedsExtraction: pendingNeedsExtraction,
      now: now,
      lastOpenedAt: _lastConfiguredMediaFeedKeepAliveAt,
    )) {
      _lastConfiguredMediaFeedKeepAliveResult = <String, dynamic>{
        'attempted': false,
        'opened': false,
        'reason': 'keepalive_not_due',
        'attempted_at': now.toIso8601String(),
        'same_feed_signature_count': _sameFeedContentSignatureCount,
        'pending_media_needs_extraction': pendingNeedsExtraction,
        'configured_media_source_count': configuredSources.isNotEmpty
            ? configuredSources.length
            : sourceIds.length + sourceNames.length,
      };
      return;
    }
    final preferredIndex = configuredSources.isEmpty
        ? 0
        : _configuredMediaFeedKeepAliveCursor % configuredSources.length;
    final preferredSource = configuredSources.isEmpty
        ? const <String, String>{}
        : configuredSources[preferredIndex];
    try {
      await _controller.executeScript(
        'window.__wukongFeishuMonitorConfiguredMediaSources = '
        '${jsonEncode(<String, Object>{'configured_ids': sourceIds.toList(growable: false), 'configured_names': sourceNames.toList(growable: false), 'preferred_id': preferredSource['conversation_id'] ?? '', 'preferred_name': preferredSource['conversation_name'] ?? ''})};',
      );
      final result = await _controller.executeScript(
        feishuOpenConfiguredMediaFeedScript,
      );
      if (result is Map) {
        final normalizedResult = Map<String, dynamic>.from(
          result.map((key, value) => MapEntry(key.toString(), value)),
        );
        _lastConfiguredMediaFeedKeepAliveResult = <String, dynamic>{
          ...normalizedResult,
          'attempted': true,
          'attempted_at': now.toIso8601String(),
          'same_feed_signature_count': _sameFeedContentSignatureCount,
          'cursor_index': preferredIndex,
          'text_preview': _diagnosticPreview(normalizedResult['text']),
        };
      } else {
        _lastConfiguredMediaFeedKeepAliveResult = <String, dynamic>{
          'attempted': true,
          'opened': false,
          'reason': 'unexpected_result',
          'attempted_at': now.toIso8601String(),
          'cursor_index': preferredIndex,
          'value': result.toString(),
        };
      }
      if (result is Map &&
          (result['opened'] == true || result['matched'] == true)) {
        _lastConfiguredMediaFeedKeepAliveAt = now;
        _configuredMediaFeedKeepAliveCursor =
            nextConfiguredMediaFeedKeepAliveCursor(
              currentIndex: _configuredMediaFeedKeepAliveCursor,
              sourceCount: configuredSources.length,
            );
        _probeScheduler.request('configured_media_feed_keepalive_opened');
      }
    } catch (error) {
      _lastConfiguredMediaFeedKeepAliveResult = <String, dynamic>{
        'attempted': true,
        'opened': false,
        'reason': 'error',
        'attempted_at': now.toIso8601String(),
        'cursor_index': preferredIndex,
        'error': error.toString(),
      };
    }
  }

  Future<void> _jumpActiveConfiguredMediaFeedToNewestIfNeeded(
    FeishuPageProbe probe,
  ) async {
    final now = DateTime.now().toUtc();
    final sourceIds = configuredMediaSourceIdsFromDiagnostics(
      probe.probeDiagnostics,
    );
    final sourceNames = configuredMediaSourceNamesFromDiagnostics(
      probe.probeDiagnostics,
    );
    if (sourceIds.isEmpty && sourceNames.isEmpty) {
      _lastActiveConfiguredFeedJumpResult = <String, dynamic>{
        'attempted': false,
        'jumped': false,
        'reason': 'no_configured_media_sources',
        'attempted_at': now.toIso8601String(),
      };
      return;
    }
    try {
      await _controller.executeScript(
        'window.__wukongFeishuMonitorConfiguredMediaSources = '
        '${jsonEncode(<String, Object>{'configured_ids': sourceIds.toList(growable: false), 'configured_names': sourceNames.toList(growable: false)})};',
      );
      final result = await _controller.executeScript(
        feishuJumpActiveConfiguredMediaFeedToNewestScript,
      );
      if (result is Map) {
        final normalizedResult = Map<String, dynamic>.from(
          result.map((key, value) => MapEntry(key.toString(), value)),
        );
        _lastActiveConfiguredFeedJumpResult = <String, dynamic>{
          ...normalizedResult,
          'attempted_at': now.toIso8601String(),
          'text_preview': _diagnosticPreview(normalizedResult['text']),
        };
        if (normalizedResult['jumped'] == true) {
          _probeScheduler.request('active_configured_media_feed_jumped_newest');
        }
      } else {
        _lastActiveConfiguredFeedJumpResult = <String, dynamic>{
          'attempted': true,
          'jumped': false,
          'reason': 'unexpected_result',
          'attempted_at': now.toIso8601String(),
          'value': result.toString(),
        };
      }
    } catch (error) {
      _lastActiveConfiguredFeedJumpResult = <String, dynamic>{
        'attempted': true,
        'jumped': false,
        'reason': 'error',
        'attempted_at': now.toIso8601String(),
        'error': error.toString(),
      };
    }
  }

  Future<void> _openPendingMediaFeedIfNeeded(FeishuPageProbe probe) async {
    if (!probeHasPendingMediaFeedCard(probe)) {
      _lastMediaOpenResult = <String, dynamic>{
        'attempted': false,
        'opened': false,
        'reason': 'no_pending_media_feed',
        'attempted_at': DateTime.now().toUtc().toIso8601String(),
      };
      return;
    }
    final currentSnapshot = await widget.store.load();
    if (!pendingMediaFeedNeedsOriginalExtraction(
      probe: probe,
      recentEvents: currentSnapshot.recentEvents,
    )) {
      _lastMediaOpenResult = <String, dynamic>{
        'attempted': false,
        'opened': false,
        'reason': 'pending_media_already_extracted',
        'key': _pendingMediaFeedKey(probe),
        'attempted_at': DateTime.now().toUtc().toIso8601String(),
      };
      return;
    }
    final key = _pendingMediaFeedKey(probe);
    final now = DateTime.now().toUtc();
    final openedAt = _lastOpenedMediaFeedAt;
    final recentlyOpened =
        openedAt != null &&
        now.difference(openedAt) < feishuMediaFeedOpenRetryDelay;
    if (key.isNotEmpty && key == _lastOpenedMediaFeedKey && recentlyOpened) {
      _lastMediaOpenResult = <String, dynamic>{
        'attempted': false,
        'opened': false,
        'reason': 'same_pending_media_feed_key',
        'key': key,
        'attempted_at': now.toIso8601String(),
        'last_opened_at': openedAt.toIso8601String(),
        'retry_after_seconds': feishuMediaFeedOpenRetryDelay.inSeconds,
      };
      return;
    }
    try {
      await _controller.executeScript(
        'window.__wukongFeishuMonitorPendingMediaTarget = '
        '${jsonEncode(<String, String>{'key': key, 'text': probePendingMediaFeedCardText(probe)})};',
      );
      final result = await _controller.executeScript(
        feishuOpenLatestMediaFeedScript,
      );
      if (result is Map) {
        final normalizedResult = Map<String, dynamic>.from(
          result.map((key, value) => MapEntry(key.toString(), value)),
        );
        _lastMediaOpenResult = <String, dynamic>{
          ...normalizedResult,
          'attempted': true,
          'attempted_at': now.toIso8601String(),
          'pending_key': key,
          'text_preview': _diagnosticPreview(normalizedResult['text']),
        };
      } else {
        _lastMediaOpenResult = <String, dynamic>{
          'attempted': true,
          'opened': false,
          'reason': 'unexpected_result',
          'attempted_at': now.toIso8601String(),
          'pending_key': key,
          'value': result.toString(),
        };
      }
      if (result is Map && result['opened'] == true) {
        _lastOpenedMediaFeedKey = key;
        _lastOpenedMediaFeedAt = now;
        _probeScheduler.request('media_feed_opened');
      }
    } catch (error) {
      _lastMediaOpenResult = <String, dynamic>{
        'attempted': true,
        'opened': false,
        'reason': 'error',
        'attempted_at': now.toIso8601String(),
        'pending_key': key,
        'error': error.toString(),
      };
      // The next fallback probe will try again if the media preview remains.
    }
  }

  Future<void> _openLatestMediaPreviewIfNeeded(FeishuPageProbe probe) async {
    final domSignature = configuredDomImageSignature(probe);
    if (domSignature.isEmpty) {
      _lastMediaPreviewOpenResult = <String, dynamic>{
        'attempted': false,
        'opened': false,
        'reason': 'no_configured_dom_image',
        'attempted_at': DateTime.now().toUtc().toIso8601String(),
      };
      return;
    }
    final pendingKey = probeHasPendingMediaFeedCard(probe)
        ? _pendingMediaFeedKey(probe)
        : '';
    final extractionSignature = mediaPreviewExtractionSignature(
      domImageSignature: domSignature,
      pendingMediaFeedKey: pendingKey,
    );
    final now = DateTime.now().toUtc();
    if (extractionSignature == _lastOpenedDomImageSignature) {
      await _closeMediaPreviewIfOpen(reason: 'same_configured_dom_image');
      _lastMediaPreviewOpenResult = mediaPreviewExtractionDiagnostics(
        <String, dynamic>{
          'attempted': false,
          'opened': false,
          'reason': 'same_configured_dom_image',
          'attempted_at': now.toIso8601String(),
        },
        extractionSignature: extractionSignature,
        pendingMediaFeedKey: pendingKey,
      );
      _lastMediaPreviewOriginalResult = mediaPreviewExtractionDiagnostics(
        <String, dynamic>{
          'attempted': false,
          'clicked': false,
          'reason': 'same_configured_dom_image',
          'attempted_at': now.toIso8601String(),
        },
        extractionSignature: extractionSignature,
        pendingMediaFeedKey: pendingKey,
      );
      return;
    }
    try {
      final result = await _controller.executeScript(
        feishuOpenLatestMediaPreviewScript,
      );
      if (result is Map) {
        final normalizedResult = Map<String, dynamic>.from(
          result.map((key, value) => MapEntry(key.toString(), value)),
        );
        _lastMediaPreviewOpenResult = mediaPreviewExtractionDiagnostics(
          <String, dynamic>{
            ...normalizedResult,
            'attempted': true,
            'attempted_at': now.toIso8601String(),
          },
          extractionSignature: extractionSignature,
          pendingMediaFeedKey: pendingKey,
        );
      } else {
        _lastMediaPreviewOpenResult = mediaPreviewExtractionDiagnostics(
          <String, dynamic>{
            'attempted': true,
            'opened': false,
            'reason': 'unexpected_result',
            'attempted_at': now.toIso8601String(),
            'value': result.toString(),
          },
          extractionSignature: extractionSignature,
          pendingMediaFeedKey: pendingKey,
        );
      }
      if (result is Map && result['opened'] == true) {
        _lastOpenedDomImageSignature = extractionSignature;
        _probeScheduler.request('media_preview_opened');
      }
    } catch (error) {
      _lastMediaPreviewOpenResult = mediaPreviewExtractionDiagnostics(
        <String, dynamic>{
          'attempted': true,
          'opened': false,
          'reason': 'error',
          'attempted_at': now.toIso8601String(),
          'error': error.toString(),
        },
        extractionSignature: extractionSignature,
        pendingMediaFeedKey: pendingKey,
      );
    }
    await _triggerMediaPreviewOriginalIfNeeded(
      probe,
      signature: extractionSignature,
    );
  }

  Future<void> _closeMediaPreviewIfOpen({required String reason}) async {
    final now = DateTime.now().toUtc();
    try {
      final result = await _controller.executeScript(
        feishuCloseMediaPreviewScript,
      );
      if (result is Map) {
        final normalizedResult = Map<String, dynamic>.from(
          result.map((key, value) => MapEntry(key.toString(), value)),
        );
        _lastMediaPreviewCloseResult = <String, dynamic>{
          ...normalizedResult,
          'trigger_reason': reason,
          'attempted_at': now.toIso8601String(),
        };
        if (normalizedResult['closed'] == true) {
          _probeScheduler.request('media_preview_closed');
        }
      } else {
        _lastMediaPreviewCloseResult = <String, dynamic>{
          'closed': false,
          'reason': 'unexpected_result',
          'trigger_reason': reason,
          'attempted_at': now.toIso8601String(),
          'value': result.toString(),
        };
      }
    } catch (error) {
      _lastMediaPreviewCloseResult = <String, dynamic>{
        'closed': false,
        'reason': 'error',
        'trigger_reason': reason,
        'attempted_at': now.toIso8601String(),
        'error': error.toString(),
      };
    }
  }

  Future<void> _triggerMediaPreviewOriginalIfNeeded(
    FeishuPageProbe probe, {
    required String signature,
  }) async {
    if (signature.isEmpty) {
      _lastMediaPreviewOriginalResult = <String, dynamic>{
        'attempted': false,
        'clicked': false,
        'reason': 'no_configured_dom_image',
        'attempted_at': DateTime.now().toUtc().toIso8601String(),
      };
      return;
    }
    final now = DateTime.now().toUtc();
    try {
      final result = await _controller.executeScript(
        feishuTriggerMediaPreviewOriginalScript,
      );
      if (result is Map) {
        final normalizedResult = Map<String, dynamic>.from(
          result.map((key, value) => MapEntry(key.toString(), value)),
        );
        _lastMediaPreviewOriginalResult = <String, dynamic>{
          ...normalizedResult,
          'attempted': true,
          'attempted_at': now.toIso8601String(),
        };
      } else {
        _lastMediaPreviewOriginalResult = <String, dynamic>{
          'attempted': true,
          'clicked': false,
          'reason': 'unexpected_result',
          'attempted_at': now.toIso8601String(),
          'value': result.toString(),
        };
      }
      if (result is Map && result['clicked'] == true) {
        _lastOpenedDomImageSignature = signature;
        _probeScheduler.request('media_preview_original_clicked');
      }
    } catch (error) {
      _lastMediaPreviewOriginalResult = <String, dynamic>{
        'attempted': true,
        'clicked': false,
        'reason': 'error',
        'attempted_at': now.toIso8601String(),
        'error': error.toString(),
      };
    }
  }

  Future<void> _openLatestFeedIfNeeded() async {
    final now = DateTime.now().toUtc();
    try {
      final result = await _controller.executeScript(
        feishuOpenLatestFeedScript,
      );
      if (result is Map) {
        final normalizedResult = Map<String, dynamic>.from(
          result.map((key, value) => MapEntry(key.toString(), value)),
        );
        _lastFeedOpenResult = <String, dynamic>{
          ...normalizedResult,
          'attempted': true,
          'attempted_at': now.toIso8601String(),
          'text_preview': _diagnosticPreview(normalizedResult['text']),
        };
      } else {
        _lastFeedOpenResult = <String, dynamic>{
          'attempted': true,
          'opened': false,
          'reason': 'unexpected_result',
          'attempted_at': now.toIso8601String(),
          'value': result.toString(),
        };
      }
      if (result is Map && result['opened'] == true) {
        _probeScheduler.request('latest_feed_opened');
      }
    } catch (error) {
      _lastFeedOpenResult = <String, dynamic>{
        'attempted': true,
        'opened': false,
        'reason': 'error',
        'attempted_at': now.toIso8601String(),
        'error': error.toString(),
      };
    }
  }

  String _pendingMediaFeedKey(FeishuPageProbe probe) {
    final key = probePendingMediaFeedCardKey(probe).trim();
    if (key.isNotEmpty) {
      return key;
    }
    return '';
  }

  List<Map<String, String>> _configuredMediaSourcesFromDiagnostics(
    Map<String, dynamic> diagnostics,
  ) {
    final sources = diagnostics['configured_media_sources'];
    if (sources is! List) {
      return const <Map<String, String>>[];
    }
    final result = <Map<String, String>>[];
    final seen = <String>{};
    for (final source in sources) {
      if (source is! Map) {
        continue;
      }
      final id = (source['conversation_id'] ?? '').toString().trim();
      final name = (source['conversation_name'] ?? '').toString().trim();
      if (id.isEmpty && name.isEmpty) {
        continue;
      }
      final key = id.isNotEmpty ? 'id:$id' : 'name:$name';
      if (!seen.add(key)) {
        continue;
      }
      result.add(<String, String>{
        'conversation_id': id,
        'conversation_name': name,
      });
    }
    return result;
  }

  Future<void> _reload() async {
    setState(() {
      _loading = true;
    });
    await _bestEffortRuntimeRecovery(clearCache: false);
    await _controller.reload();
    await _installPageObserver();
    _probeScheduler.request('runtime_reload');
    setState(() {
      _loading = false;
    });
    await _persistRuntimeState();
  }

  Future<void> _hardReload() async {
    setState(() {
      _loading = true;
    });
    _lastOpenedMediaFeedKey = '';
    _lastOpenedMediaFeedAt = null;
    _lastOpenedDomImageSignature = '';
    _lastFeedContentSignature = '';
    _sameFeedContentSignatureCount = 0;
    _lastMediaOpenResult = const <String, dynamic>{
      'attempted': false,
      'opened': false,
      'reason': 'hard_reload_reset',
    };
    _lastMediaPreviewOpenResult = const <String, dynamic>{
      'attempted': false,
      'opened': false,
      'reason': 'hard_reload_reset',
    };
    _lastMediaPreviewOriginalResult = const <String, dynamic>{
      'attempted': false,
      'clicked': false,
      'reason': 'hard_reload_reset',
    };
    _lastFeedOpenResult = const <String, dynamic>{
      'attempted': false,
      'opened': false,
      'reason': 'hard_reload_reset',
    };
    await _bestEffortRuntimeRecovery(clearCache: true);
    await _controller.loadUrl(defaultFeishuRuntimeUrl);
    await _installPageObserver();
    _probeScheduler.request('runtime_hard_reload');
    setState(() {
      _loading = false;
    });
    await _persistRuntimeState();
  }

  Future<void> _sessionReset() async {
    setState(() {
      _loading = true;
    });
    _lastOpenedMediaFeedKey = '';
    _lastOpenedMediaFeedAt = null;
    _lastOpenedDomImageSignature = '';
    _lastFeedContentSignature = '';
    _sameFeedContentSignatureCount = 0;
    _lastMediaOpenResult = const <String, dynamic>{
      'attempted': false,
      'opened': false,
      'reason': 'session_reset',
    };
    _lastMediaPreviewOpenResult = const <String, dynamic>{
      'attempted': false,
      'opened': false,
      'reason': 'session_reset',
    };
    _lastMediaPreviewOriginalResult = const <String, dynamic>{
      'attempted': false,
      'clicked': false,
      'reason': 'session_reset',
    };
    _lastFeedOpenResult = const <String, dynamic>{
      'attempted': false,
      'opened': false,
      'reason': 'session_reset',
    };
    await _bestEffortRuntimeRecovery(clearCache: true, clearCookies: true);
    await _controller.loadUrl(defaultFeishuRuntimeUrl);
    await _installPageObserver();
    _probeScheduler.request('runtime_session_reset');
    setState(() {
      _loading = false;
    });
    await _persistRuntimeState();
  }

  Future<void> _bestEffortRuntimeRecovery({
    required bool clearCache,
    bool clearCookies = false,
  }) async {
    try {
      await _controller.resume();
    } catch (_) {}
    try {
      await _controller.stop();
    } catch (_) {}
    if (!clearCache) {
      return;
    }
    if (clearCookies) {
      try {
        await _controller.clearCookies();
      } catch (_) {}
    }
    try {
      await _controller.setCacheDisabled(true);
    } catch (_) {}
    try {
      await _controller.clearCache();
    } catch (_) {}
    try {
      await _controller.setCacheDisabled(false);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_pageTitle),
        actions: [
          IconButton(
            onPressed: _reload,
            icon: const Icon(Icons.refresh_rounded),
            tooltip: feishuShellRefreshTooltip,
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
          if (_error.isNotEmpty)
            Container(
              width: double.infinity,
              color: const Color(0xFFF8F8F8),
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
