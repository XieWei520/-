import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  const scriptPath = 'scripts/ops/phase6_prometheus_gate_report.ps1';
  final script = File(scriptPath);

  test('phase6 prometheus gate report contains required production queries', () {
    expect(script.existsSync(), isTrue);
    final content = script.readAsStringSync();

    expect(content, contains('up{job="wukongim_api"}'));
    expect(
      content,
      contains(
        'sum by (status_class) (increase(wukongim_http_requests_total[__WINDOW__]))',
      ),
    );
    expect(content, contains('histogram_quantile(0.95'));
    expect(content, contains('histogram_quantile(0.99'));
    expect(
      content,
      contains(
        'sum(increase(wukongim_http_requests_total{route="unknown"}[__WINDOW__]))',
      ),
    );
    expect(content, contains('topk(20'));
    expect(content, contains('p95_regression_threshold=1.5'));
    expect(content, contains('p99_regression_threshold=1.5'));
    expect(content, contains('phase6_prometheus_gate_report=completed'));
  });

  test('phase6 prometheus gate report hardens prometheus curl URL', () {
    expect(script.existsSync(), isTrue);
    final content = script.readAsStringSync();

    expect(content, contains('curl -fsS --'));
    expect(content, contains('[System.Uri]::TryCreate'));
    expect(content, contains("Absolute"));
    expect(content, contains("'http'"));
    expect(content, contains("'https'"));
  });

  test(
    'phase6 prometheus gate report dry-run prints both windows',
    () async {
      final result = await Process.run('powershell', [
        '-NoProfile',
        '-ExecutionPolicy',
        'Bypass',
        '-File',
        scriptPath,
      ], workingDirectory: Directory.current.path);

      expect(result.exitCode, 0, reason: result.stderr.toString());
      final output = result.stdout.toString();
      expect(output, contains('window=5m'));
      expect(output, contains('window=30m'));
      expect(output, contains('Dry run only'));
    },
    skip: !Platform.isWindows,
  );

  test(
    'phase6 prometheus gate report rejects non-http prometheus URL before ssh',
    () async {
      final result = await Process.run('powershell', [
        '-NoProfile',
        '-ExecutionPolicy',
        'Bypass',
        '-File',
        scriptPath,
        '-Run',
        '-PrometheusUrl',
        'file:///tmp/x',
      ], workingDirectory: Directory.current.path);

      expect(result.exitCode, isNot(0));
      final output = '${result.stdout}\n${result.stderr}';
      expect(output, contains('PrometheusUrl must be an absolute http/https URI'));
      expect(output, isNot(contains('Prometheus query failed')));
    },
    skip: !Platform.isWindows,
  );
}
