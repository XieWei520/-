import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('remote nginx edge optimizer contains safe cache and scanner rules', () {
    final script = File('scripts/ops/apply_nginx_edge_optimizations.sh');

    expect(script.existsSync(), isTrue);

    final content = script.readAsStringSync();
    expect(content, contains('set -euo pipefail'));
    expect(content, contains('BACKUP_DIR'));
    expect(content, contains('default.conf.template'));
    expect(content, contains('nginx.conf'));
    expect(content, contains('worker_connections 8192'));
    expect(content, contains('tcp_nopush     on;'));
    expect(content, contains('server_tokens off;'));
    expect(content, contains('Strict-Transport-Security'));
    expect(content, contains('location = /index.html'));
    expect(content, contains('location = /flutter_bootstrap.js'));
    expect(content, contains('location = /main.dart.js'));
    expect(content, contains('location ~* ^/(assets|canvaskit)/'));
    expect(
      content,
      contains('Cache-Control "public, max-age=31536000, immutable"'),
    );
    expect(content, contains(r'location ~ /\.(?!well-known/acme-challenge/)'));
    expect(content, contains('wp-|wordpress|phpmyadmin|pma|xmlrpc'));
    expect(content, contains('zone=ws_limit:10m rate=60r/m'));
    expect(
      _locationBlock(content, 'location = /ws'),
      contains('limit_req zone=ws_limit burst=30 nodelay'),
    );
    expect(content, contains('location ^~ /v1/file/preview/'));
    expect(content, contains('location ^~ /v1/file/download/'));
    expect(content, contains('location ^~ /minio/'));
    expect(
      _locationBlock(content, 'location ^~ /v1/file/preview/'),
      contains('proxy_pass http://tsdd_api'),
    );
    expect(
      _locationBlock(content, 'location ^~ /v1/file/download/'),
      contains('proxy_pass http://tsdd_api'),
    );
    expect(
      _locationBlock(content, 'location ^~ /minio/'),
      contains('proxy_pass http://minio:9000/'),
    );
    expect(content, contains('proxy_buffering off;'));
    expect(content, contains('Cache-Control "private, max-age=604800"'));
    expect(content, contains('docker compose --env-file .env config -q'));
    expect(content, contains('--force-recreate nginx'));
    expect(content, contains('nginx -t'));
    expect(content, contains('nginx -s reload'));
    expect(content, contains('canvaskit/canvaskit.wasm'));
    expect(content, contains('ROLLBACK_HINT'));
    expect(
      _locationBlock(content, 'location = /index.html'),
      contains('Strict-Transport-Security'),
    );
    expect(
      _locationBlock(content, 'location = /flutter_bootstrap.js'),
      contains('Strict-Transport-Security'),
    );
    expect(
      _locationBlock(content, 'location = /main.dart.js'),
      contains(
        'Cache-Control "no-store, no-cache, must-revalidate, proxy-revalidate, max-age=0"',
      ),
    );
    expect(
      _locationBlock(content, 'location ~* ^/(assets|canvaskit)/'),
      contains('Strict-Transport-Security'),
    );
  });

  test('powershell deploy wrapper uploads and can apply the optimizer', () {
    final script = File('scripts/ops/deploy_nginx_edge_optimizations.ps1');

    expect(script.existsSync(), isTrue);

    final content = script.readAsStringSync();
    expect(content, contains(r'[switch]$Apply'));
    expect(content, contains(r'[switch]$DryRun'));
    expect(content, contains('RollbackBackupDir'));
    expect(content, contains('apply_nginx_edge_optimizations.sh'));
    expect(content, contains('scp'));
    expect(content, contains('ssh'));
    expect(content, contains('--apply'));
    expect(content, contains('--dry-run'));
    expect(content, contains('--rollback'));
  });
}

String _locationBlock(String source, String locationHeader) {
  final start = source.indexOf(locationHeader);
  expect(start, isNonNegative, reason: 'missing $locationHeader');
  final nextLocation = source.indexOf('\n    location ', start + 1);
  if (nextLocation == -1) {
    return source.substring(start);
  }
  return source.substring(start, nextLocation);
}
