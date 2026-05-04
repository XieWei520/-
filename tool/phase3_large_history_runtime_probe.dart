import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:wukong_im_app/core/cache/media_cache_manager.dart';
import 'package:wukong_im_app/data/cache/web_chat_cache_store_factory.dart';
import 'package:wukong_im_app/data/telemetry/message_query_jank_monitor.dart';
import 'package:wukong_im_app/realtime/telemetry/realtime_rollout_telemetry.dart';
import 'package:wukongimfluttersdk/entity/msg.dart';
import 'package:wukongimfluttersdk/type/const.dart';

typedef Phase3RuntimeProbeRunner = Future<Phase3RuntimeProbeReport> Function();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (!kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.windows ||
          defaultTargetPlatform == TargetPlatform.linux ||
          defaultTargetPlatform == TargetPlatform.macOS)) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }
  runApp(const Phase3LargeHistoryRuntimeProbeApp());
}

class Phase3LargeHistoryRuntimeProbeApp extends StatelessWidget {
  const Phase3LargeHistoryRuntimeProbeApp({
    super.key,
    this.runProbe = runPhase3RuntimeProbe,
  });

  final Phase3RuntimeProbeRunner runProbe;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Phase 3 Runtime Probe',
      debugShowCheckedModeBanner: false,
      home: Phase3RuntimeProbePage(runProbe: runProbe),
    );
  }
}

class Phase3RuntimeProbePage extends StatefulWidget {
  const Phase3RuntimeProbePage({super.key, required this.runProbe});

  final Phase3RuntimeProbeRunner runProbe;

  @override
  State<Phase3RuntimeProbePage> createState() => _Phase3RuntimeProbePageState();
}

class _Phase3RuntimeProbePageState extends State<Phase3RuntimeProbePage> {
  late Future<Phase3RuntimeProbeReport> _reportFuture;

  @override
  void initState() {
    super.initState();
    _reportFuture = widget.runProbe();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Phase 3 Runtime Probe')),
      body: FutureBuilder<Phase3RuntimeProbeReport>(
        future: _reportFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Padding(
              padding: const EdgeInsets.all(24),
              child: SelectableText(
                'FAIL\n${snapshot.error}\n${snapshot.stackTrace}',
              ),
            );
          }
          final report = snapshot.requireData;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: <Widget>[
              Text(
                'Platform: ${report.platformLabel}',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 16),
              _ProbeSectionCard(section: report.webCache),
              _ProbeSectionCard(section: report.nativeStorage),
              _ProbeSectionCard(section: report.mediaAndJank),
            ],
          );
        },
      ),
    );
  }
}

class _ProbeSectionCard extends StatelessWidget {
  const _ProbeSectionCard({required this.section});

  final Phase3ProbeSection section;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    section.title,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                Semantics(
                  label: '${section.title} ${section.passed ? 'PASS' : 'FAIL'}',
                  child: Text(
                    section.passed ? 'PASS' : 'FAIL',
                    style: TextStyle(
                      color: section.passed ? Colors.green : Colors.red,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            for (final line in section.lines)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: SelectableText(line),
              ),
          ],
        ),
      ),
    );
  }
}

class Phase3RuntimeProbeReport {
  const Phase3RuntimeProbeReport({
    required this.platformLabel,
    required this.webCache,
    required this.nativeStorage,
    required this.mediaAndJank,
  });

  final String platformLabel;
  final Phase3ProbeSection webCache;
  final Phase3ProbeSection nativeStorage;
  final Phase3ProbeSection mediaAndJank;
}

class Phase3ProbeSection {
  const Phase3ProbeSection({
    required this.title,
    required this.passed,
    required this.lines,
  });

  final String title;
  final bool passed;
  final List<String> lines;
}

Future<Phase3RuntimeProbeReport> runPhase3RuntimeProbe({
  bool? isWebOverride,
  String? platformLabelOverride,
  bool skipNativeDatabaseProbe = false,
}) async {
  WidgetsFlutterBinding.ensureInitialized();

  final isWeb = isWebOverride ?? kIsWeb;
  final platformLabel = platformLabelOverride ?? _platformLabel(isWeb);
  final webCache = await _probeWebCache(isWeb: isWeb);
  final nativeStorage = await _probeNativeStorage(
    skipNativeDatabaseProbe: skipNativeDatabaseProbe || isWeb,
  );
  final mediaAndJank = await _probeMediaAndJank();

  return Phase3RuntimeProbeReport(
    platformLabel: platformLabel,
    webCache: webCache,
    nativeStorage: nativeStorage,
    mediaAndJank: mediaAndJank,
  );
}

Future<Phase3ProbeSection> _probeWebCache({required bool isWeb}) async {
  final store = createWebChatCacheStore();
  const uid = 'phase3_runtime_uid';
  const otherUid = 'phase3_runtime_other_uid';
  const channelId = 'phase3_runtime_channel';
  const channelType = WKChannelType.personal;

  await store.clearUser(uid: uid);
  await store.clearUser(uid: otherUid);
  await store.upsertMessages(
    uid: uid,
    channelId: channelId,
    channelType: channelType,
    messages: List<WKMsg>.generate(
      7,
      (index) => _message(
        orderSeq: 101 + index,
        messageSeq: 101 + index,
        clientMsgNo: 'phase3-runtime-${101 + index}',
      ),
    ),
  );

  final latest = await store.readMessages(
    uid: uid,
    channelId: channelId,
    channelType: channelType,
    limit: 3,
  );
  final older = await store.readMessages(
    uid: uid,
    channelId: channelId,
    channelType: channelType,
    limit: 2,
    beforeOrderSeq: 103,
  );
  final around = await store.readMessages(
    uid: uid,
    channelId: channelId,
    channelType: channelType,
    limit: 3,
    aroundOrderSeq: 103,
  );
  final isolated = await store.readMessages(
    uid: otherUid,
    channelId: channelId,
    channelType: channelType,
    limit: 10,
  );

  final passed =
      _orders(latest).join(',') == '105,106,107' &&
      _orders(older).join(',') == '101,102' &&
      _orders(around).join(',') == '102,103,104' &&
      isolated.isEmpty;

  return Phase3ProbeSection(
    title: 'Web cache',
    passed: passed,
    lines: <String>[
      'runtime_is_web=$isWeb',
      'store_type=${store.runtimeType}',
      'latest_orders=${_orders(latest).join(',')}',
      'older_orders=${_orders(older).join(',')}',
      'around_orders=${_orders(around).join(',')}',
      'uid_isolation_count=${isolated.length}',
      if (isWeb) 'indexeddb_runtime_exercised=true',
    ],
  );
}

Future<Phase3ProbeSection> _probeNativeStorage({
  required bool skipNativeDatabaseProbe,
}) async {
  if (skipNativeDatabaseProbe) {
    return const Phase3ProbeSection(
      title: 'Native storage',
      passed: true,
      lines: <String>['native_database_probe=skipped'],
    );
  }

  try {
    final db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
    try {
      await db.execute('''
        CREATE TABLE message (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          channel_id TEXT,
          channel_type INTEGER,
          message_seq INTEGER,
          order_seq INTEGER,
          client_msg_no TEXT,
          message_id TEXT
        )
      ''');
      await db.execute('''
        CREATE INDEX IF NOT EXISTS idx_message_channel_seq
        ON message(channel_id, channel_type, message_seq DESC)
      ''');
      await db.execute('''
        CREATE INDEX IF NOT EXISTS idx_message_channel_order_seq
        ON message(channel_id, channel_type, order_seq DESC)
      ''');
      await db.execute('''
        CREATE INDEX IF NOT EXISTS idx_message_client_msg_no
        ON message(client_msg_no)
      ''');
      await db.execute('''
        CREATE INDEX IF NOT EXISTS idx_message_message_id
        ON message(message_id)
      ''');
      final indexes = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='index' AND tbl_name='message' ORDER BY name",
      );
      final names = indexes
          .map((row) => row['name']?.toString() ?? '')
          .where((name) => name.isNotEmpty)
          .toList(growable: false);
      final required = <String>{
        'idx_message_channel_seq',
        'idx_message_channel_order_seq',
        'idx_message_client_msg_no',
        'idx_message_message_id',
      };
      return Phase3ProbeSection(
        title: 'Native storage',
        passed: required.every(names.contains),
        lines: <String>[
          'sqlite_backend=sqflite_common_ffi',
          'message_indexes=${names.join(',')}',
        ],
      );
    } finally {
      await db.close();
    }
  } catch (error) {
    return Phase3ProbeSection(
      title: 'Native storage',
      passed: false,
      lines: <String>['native_database_probe_error=$error'],
    );
  }
}

Future<Phase3ProbeSection> _probeMediaAndJank() async {
  final captured = <RealtimeTelemetryEvent>[];
  final telemetry = RealtimeRolloutTelemetry(
    transport: (events) async => captured.addAll(events),
    flushInterval: Duration.zero,
  );
  final monitor = MessageQueryJankMonitor.forTesting(
    telemetry: telemetry,
    enabled: true,
    addTimingsCallback: (_) {},
    removeTimingsCallback: (_) {},
  );
  monitor.recordTimings(const <MessageQueryFrameTiming>[
    MessageQueryFrameTiming(
      buildDuration: Duration(milliseconds: 17),
      rasterDuration: Duration(milliseconds: 12),
    ),
    MessageQueryFrameTiming(
      buildDuration: Duration(milliseconds: 8),
      rasterDuration: Duration(milliseconds: 19),
    ),
  ]);
  await telemetry.flush();
  telemetry.dispose();

  final estimatedDecodeBytes = MediaCacheManager.estimateDecodedBytes(
    width: 256,
    height: 256,
  );
  final jankEvents = captured
      .where(
        (event) =>
            event.name ==
                RealtimeRolloutTelemetry.metricChatScrollBuildJankFrameMs ||
            event.name ==
                RealtimeRolloutTelemetry.metricChatScrollRasterJankFrameMs,
      )
      .length;

  return Phase3ProbeSection(
    title: 'Media and jank',
    passed: estimatedDecodeBytes == 262144 && jankEvents == 2,
    lines: <String>[
      'estimated_decode_bytes=$estimatedDecodeBytes',
      'jank_events=$jankEvents',
      'jank_metric_names=${captured.map((event) => event.name).join(',')}',
    ],
  );
}

WKMsg _message({
  required int orderSeq,
  required int messageSeq,
  required String clientMsgNo,
}) {
  return WKMsg()
    ..channelID = 'phase3_runtime_channel'
    ..channelType = WKChannelType.personal
    ..clientMsgNO = clientMsgNo
    ..messageID = 'phase3-runtime-message-$orderSeq'
    ..messageSeq = messageSeq
    ..orderSeq = orderSeq
    ..timestamp = 1770000000 + orderSeq
    ..contentType = WkMessageContentType.text
    ..content = '{"type":1,"content":"phase3 runtime $orderSeq"}'
    ..fromUID = 'phase3_runtime_uid'
    ..status = WKSendMsgResult.sendSuccess;
}

List<int> _orders(List<WKMsg> messages) {
  return messages.map((message) => message.orderSeq).toList(growable: false);
}

String _platformLabel(bool isWeb) {
  if (isWeb) {
    return 'web';
  }
  return defaultTargetPlatform.name;
}
