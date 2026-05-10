import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:feishu_monitor_shell/feishu_monitor_shell.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:webview_windows/webview_windows.dart';

import 'src/feishu_network_capture.dart';
import 'src/feishu_network_capture_bridge.dart';
import 'src/feishu_network_capture_parser.dart';
import 'src/feishu_network_capture_store.dart';
import 'src/feishu_page_observer.dart';
import 'src/feishu_page_probe.dart';
import 'src/probe_scheduler.dart';
import 'src/runtime_snapshot_mapper.dart';

const String defaultFeishuRuntimeUrl = 'https://www.feishu.cn/messenger/';
const Duration feishuMediaFeedOpenRetryDelay = Duration(seconds: 20);
const bool feishuStrictNoDomForwardingEnabled = true;
const String feishuStrictNoDomForwardingReason = 'strict_no_dom_forwarding';
const String feishuShellRefreshTooltip = '刷新';
const String feishuShellReadyMessage =
    '本地壳程序已启动，WuKongIM 可通过 localhost 控制接口读取当前登录运行态。';

Map<String, dynamic> feishuStrictNoDomOpenResult() {
  return <String, dynamic>{
    'attempted': false,
    'opened': false,
    'reason': feishuStrictNoDomForwardingReason,
  };
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final supportDirectory = await getApplicationSupportDirectory();
  final snapshotFile = File(
    '${supportDirectory.path}${Platform.pathSeparator}feishu_monitor_shell${Platform.pathSeparator}status.json',
  );
  final diagnosticsFile = networkCaptureDiagnosticsFileFor(supportDirectory);
  final store = ShellStore(snapshotFile);
  final events = ShellEventBus();
  final server = ShellServer(
    store: store,
    host: InternetAddress.loopbackIPv4,
    port: 18766,
    token: 'wukong-feishu-shell-dev',
    events: events,
  );
  await server.start();
  runApp(
    FeishuMonitorShellApp(
      store: store,
      events: events,
      networkDiagnosticsFile: diagnosticsFile,
    ),
  );
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
  ];
}

class FeishuMonitorShellApp extends StatelessWidget {
  const FeishuMonitorShellApp({
    super.key,
    required this.store,
    required this.events,
    required this.networkDiagnosticsFile,
  });

  final ShellStore store;
  final ShellEventBus events;
  final File networkDiagnosticsFile;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Feishu Monitor Shell',
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
  ShellSnapshot? _snapshot;
  bool _webviewReady = false;
  String _pageTitle = 'Feishu Monitor Shell';
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
  StreamSubscription<FeishuNetworkCaptureEvent>? _networkCaptureSubscription;
  StreamSubscription<String>? _networkCaptureUnavailableSubscription;
  late final ProbeScheduler _probeScheduler;
  Timer? _probeTimer;
  String _lastOpenedMediaFeedKey = '';
  DateTime? _lastOpenedMediaFeedAt;
  Map<String, dynamic> _lastMediaOpenResult = const <String, dynamic>{};
  Map<String, dynamic> _lastFeedOpenResult = const <String, dynamic>{};
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
    unawaited(_titleSubscription?.cancel());
    unawaited(_urlSubscription?.cancel());
    unawaited(_loadingStateSubscription?.cancel());
    unawaited(_webMessageSubscription?.cancel());
    unawaited(_shellEventSubscription?.cancel());
    unawaited(_networkCaptureSubscription?.cancel());
    unawaited(_networkCaptureUnavailableSubscription?.cancel());
    unawaited(_networkCaptureBridge.dispose());
    _probeTimer?.cancel();
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
      final current = await widget.store.load();
      if (_disposed) {
        return;
      }
      _snapshot = applyRuntimeSignal(
        current,
        runtimeUrl: _runtimeUrl,
        pageTitle: _pageTitle,
        webviewAvailable: true,
        isLoading: false,
      );
      if (_disposed) {
        return;
      }
      await widget.store.save(_snapshot!);
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
      final current = await widget.store.load();
      if (_disposed) {
        return;
      }
      _snapshot = current.copyWith(
        shellMode: 'desktop_shell',
        webviewAvailable: false,
        lastError: error.toString(),
        lastUpdatedAt: DateTime.now().toUtc(),
      );
      if (_disposed) {
        return;
      }
      await widget.store.save(_snapshot!);
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
    for (final candidate in parseFeishuNetworkImageCandidates(event)) {
      _networkCaptureStore.addCandidate(candidate);
    }
    _probeScheduler.request('network_capture');
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
      final persisted = await widget.store.load();
      if (_disposed) {
        return;
      }
      final current = mergeExternalControlState(
        localSnapshot: _snapshot ?? persisted,
        persistedSnapshot: persisted,
      );
      final next = current.copyWith(
        probeDiagnostics: <String, dynamic>{
          ...current.probeDiagnostics,
          ..._networkCaptureStore.toDiagnosticsJson(),
        },
        lastUpdatedAt: DateTime.now().toUtc(),
      );
      if (_disposed) {
        return;
      }
      _snapshot = next;
      await widget.store.save(next);
    } catch (_) {
      // Network capture diagnostics are best-effort and must not crash shell.
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
    final persisted = await widget.store.load();
    final current = mergeExternalControlState(
      localSnapshot: _snapshot ?? persisted,
      persistedSnapshot: persisted,
    );
    final next = applyRuntimeSignal(
      current,
      runtimeUrl: _runtimeUrl,
      pageTitle: _pageTitle,
      webviewAvailable: _webviewReady,
      isLoading: _loading,
    );
    _snapshot = next;
    await widget.store.save(next);
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
      final probe = FeishuPageProbe.fromScriptResult(
        Map<String, dynamic>.from(
          result.map((key, value) => MapEntry(key.toString(), value)),
        ),
      );
      if (probe.runtimeUrl.trim().isNotEmpty) {
        _runtimeUrl = probe.runtimeUrl;
      }
      if (probe.pageTitle.trim().isNotEmpty) {
        _pageTitle = probe.pageTitle;
      }
      final persisted = await widget.store.load();
      final current = mergeExternalControlState(
        localSnapshot: _snapshot ?? persisted,
        persistedSnapshot: persisted,
      );
      final feedChanged = _isFeedContentChanged(probe);
      _recordStrictNoDomOpenResults();
      if (!feishuStrictNoDomForwardingEnabled) {
        await _openPendingMediaFeedIfNeeded(probe);
        if (!probeHasPendingMediaFeedCard(probe) && feedChanged) {
          await _openLatestFeedIfNeeded();
        }
      }
      final next = _withShellDiagnostics(
        applyPageProbe(current, probe),
        probe,
        reason: reason,
        runtimeUrl: _runtimeUrl,
        pageTitle: _pageTitle,
        webviewAvailable: _webviewReady,
        isLoading: _loading,
      ).copyWith(lastError: _probeDebugMessage(probe));
      _snapshot = next;
      await widget.store.save(next);
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
      final persisted = await widget.store.load();
      final current = mergeExternalControlState(
        localSnapshot: _snapshot ?? persisted,
        persistedSnapshot: persisted,
      );
      final next = current.copyWith(
        lastError: error.toString(),
        lastUpdatedAt: DateTime.now().toUtc(),
      );
      _snapshot = next;
      await widget.store.save(next);
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
    final persisted = await widget.store.load();
    final current = mergeExternalControlState(
      localSnapshot: _snapshot ?? persisted,
      persistedSnapshot: persisted,
    );
    final withRuntime = applyRuntimeSignal(
      current,
      runtimeUrl: _runtimeUrl,
      pageTitle: _pageTitle,
      webviewAvailable: _webviewReady,
      isLoading: _loading,
    );
    final next = withRuntime.copyWith(
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
    _snapshot = next;
    await widget.store.save(next);
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
        ...probe.probeDiagnostics,
        ..._feedFreshnessDiagnostics(probe),
        ..._networkCaptureStore.toDiagnosticsJson(),
        'pending_media_feed_card_key': probe.pendingMediaFeedCardKey,
        'last_media_open_result': _lastMediaOpenResult,
        'last_feed_open_result': _lastFeedOpenResult,
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

  void _recordStrictNoDomOpenResults() {
    if (!feishuStrictNoDomForwardingEnabled) {
      return;
    }
    _lastMediaOpenResult = feishuStrictNoDomOpenResult();
    _lastFeedOpenResult = feishuStrictNoDomOpenResult();
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
    _lastFeedContentSignature = '';
    _sameFeedContentSignatureCount = 0;
    _lastMediaOpenResult = const <String, dynamic>{
      'attempted': false,
      'opened': false,
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
    _lastFeedContentSignature = '';
    _sameFeedContentSignatureCount = 0;
    _lastMediaOpenResult = const <String, dynamic>{
      'attempted': false,
      'opened': false,
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
          Container(
            width: double.infinity,
            color: const Color(0xFFF8F8F8),
            padding: const EdgeInsets.all(12),
            child: Text(_error.isEmpty ? feishuShellReadyMessage : _error),
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
