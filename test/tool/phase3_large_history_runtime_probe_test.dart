import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../tool/phase3_large_history_runtime_probe.dart';

void main() {
  testWidgets('renders Phase 3 runtime probe result sections', (tester) async {
    await tester.pumpWidget(
      Phase3LargeHistoryRuntimeProbeApp(
        runProbe: () async => const Phase3RuntimeProbeReport(
          platformLabel: 'test-platform',
          webCache: Phase3ProbeSection(
            title: 'Web cache',
            passed: true,
            lines: <String>['IndexedDB factory exercised'],
          ),
          nativeStorage: Phase3ProbeSection(
            title: 'Native storage',
            passed: true,
            lines: <String>['SQLite indexes present'],
          ),
          mediaAndJank: Phase3ProbeSection(
            title: 'Media and jank',
            passed: true,
            lines: <String>['Decode cap and jank monitor exercised'],
          ),
        ),
      ),
    );

    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    await tester.pumpAndSettle();

    expect(find.text('Phase 3 Runtime Probe'), findsOneWidget);
    expect(find.text('Platform: test-platform'), findsOneWidget);
    expect(find.text('PASS'), findsNWidgets(3));
    expect(find.text('Web cache'), findsOneWidget);
    expect(find.text('IndexedDB factory exercised'), findsOneWidget);
    expect(find.text('Native storage'), findsOneWidget);
    expect(find.text('SQLite indexes present'), findsOneWidget);
    expect(find.text('Media and jank'), findsOneWidget);
    expect(find.text('Decode cap and jank monitor exercised'), findsOneWidget);
  });

  test(
    'Phase 3 runtime probe exercises real cache and telemetry primitives',
    () async {
      final report = await runPhase3RuntimeProbe(
        isWebOverride: false,
        platformLabelOverride: 'unit-native',
        skipNativeDatabaseProbe: true,
      );

      expect(report.platformLabel, 'unit-native');
      expect(report.webCache.passed, isTrue);
      expect(
        report.webCache.lines,
        contains('store_type=MemoryWebChatCacheStore'),
      );
      expect(report.webCache.lines, contains('latest_orders=105,106,107'));
      expect(report.webCache.lines, contains('older_orders=101,102'));
      expect(report.webCache.lines, contains('around_orders=102,103,104'));
      expect(report.webCache.lines, contains('uid_isolation_count=0'));
      expect(report.nativeStorage.passed, isTrue);
      expect(
        report.nativeStorage.lines,
        contains('native_database_probe=skipped'),
      );
      expect(report.mediaAndJank.passed, isTrue);
      expect(
        report.mediaAndJank.lines,
        contains('estimated_decode_bytes=262144'),
      );
      expect(report.mediaAndJank.lines, contains('jank_events=2'));
    },
  );
}
