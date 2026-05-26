import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String _prependPath(String directory, Map<String, String> environment) {
  final separator = Platform.isWindows ? ';' : ':';
  final currentPath = environment['PATH'] ?? '';
  return currentPath.isEmpty ? directory : '$directory$separator$currentPath';
}

void main() {
  test('phase3 backend optimization prepare script is gated and scoped', () {
    final script = File('scripts/ops/phase3_backend_optimization_prepare.ps1');

    expect(script.existsSync(), isTrue);

    final content = script.readAsStringSync();
    expect(content, contains(r'[switch]$Run'));
    expect(content, contains(r'[switch]$AllowProductionSync'));
    expect(content, contains(r'[switch]$BuildImage'));
    expect(content, contains(r'[switch]$AllowProductionBuild'));
    expect(content, contains(r'[switch]$RunTests'));
    expect(content, contains(r'[switch]$ApplyLocalPatch'));
    expect(content, contains(r'[string]$RemoteBackupRoot'));

    expect(content, contains('Dry run only'));
    expect(
      content,
      contains(
        'Dry run only. Use -Run -AllowProductionSync -BuildImage -AllowProductionBuild for one-shot sync+build.',
      ),
    );
    expect(
      content,
      contains(
        'Refusing to sync production backend source without -AllowProductionSync',
      ),
    );
    expect(
      content,
      contains(
        'Refusing to run production Phase 3 prepare without -BuildImage.',
      ),
    );
    expect(
      content,
      contains(
        'Refusing to build production backend image without -AllowProductionBuild',
      ),
    );
    expect(content, contains('/opt/wukongim-prod/src'));
    expect(content, contains('/opt/wukongim-prod/src/deploy/production'));
    expect(
      content,
      contains('backups/phase3-backend-optimization-source-sync'),
    );
    expect(
      content,
      contains(
        '/opt/wukongim-prod/backups/phase3-backend-optimization-source-sync',
      ),
    );
    expect(content, contains(r'sudo mkdir -p "`$backup_dir"'));
    expect(
      content,
      contains(r'sudo chown "`$(id -u):`$(id -g)" "`$backup_dir"'),
    );
    expect(content, contains('phase3_backend_optimization_sync=applied'));
    expect(
      content,
      contains('phase3_backend_optimization_build_context=verified'),
    );
    expect(content, contains('phase3_backend_optimization_build=completed'));
    expect(content, contains('phase3_backend_optimization_build=skipped'));
    expect(
      content,
      contains(
        r'docker compose --env-file .env -f "`$remote_tmp/docker-compose.phase3-build.yaml" build tsdd-api',
      ),
    );
    expect(
      content,
      isNot(
        contains(
          r'cd "`$remote_production"`ndocker compose --env-file .env build tsdd-api',
        ),
      ),
    );
    expect(
      content,
      contains('phase3_backend_optimization_build_context_unreviewed_change='),
    );
    expect(
      content,
      contains('phase3_backend_optimization_build_context_root='),
    );
    expect(content, contains('function should_include_build_context_path()'));
    expect(content, contains('copy_build_context_file_list()'));
    expect(content, contains('hash_build_context_file_list()'));
    expect(content, contains('install -m 0644'));
    expect(
      content,
      isNot(contains(r'cp -a "`$item" "`$build_context_root/`$item"')),
    );
    expect(
      content,
      contains(
        r'copy_build_context_file_list | hash_build_context_file_list | sort > "`$build_context_after"',
      ),
    );
    expect(
      content,
      contains('phase3_backend_optimization_previous_image_tag='),
    );
    expect(content, contains(r'image_timestamp="`$(date -u +%Y%m%dT%H%M%SZ)"'));
    expect(
      content,
      contains(
        r'previous_image_tag="wukongim/tsdd-api:phase3-pre-`$image_timestamp"',
      ),
    );
    expect(content, contains('previous production image is missing'));
    expect(content, contains('realpath -m'));
    expect(content, contains('phase3-remote-bash-'));
    expect(
      content,
      contains(r'[System.IO.File]::WriteAllText($remoteScriptFile'),
    );
    expect(content, contains(r"< ' + (Quote-CmdArgument"));
    expect(
      content,
      contains(
        r"$startInfo.Arguments = '/d /c ' + (Quote-CmdArgument -Value $cmdFile) + ' 2>&1'",
      ),
    );
    expect(content, contains(r'$startInfo.RedirectStandardError = $false'));
    expect(content, isNot(contains(r'$process.StandardError.ReadToEnd()')));
    expect(content, contains(r'[System.Text.UTF8Encoding]::new($false)'));
    expect(content, contains(r'cat > "`$build_context_root/.dockerignore"'));
    expect(content, contains('**/*.p12'));
    expect(content, contains('**/*.sql'));
    expect(content, contains('**/*.log'));
    expect(
      content,
      contains(
        'find go.mod go.sum main.go assets configs internal modules pkg serverlib',
      ),
    );
    expect(content, contains(r'$ExpectedManifestRows'));
    expect(
      content,
      contains('phase3_backend_optimization_reviewed_manifest=verified'),
    );
    expect(
      content,
      contains('phase3_backend_optimization_absent_files_manifest'),
    );
    expect(content, contains('.phase3_absent_files'));

    const releaseFiles = [
      'modules/user/api.go',
      'modules/user/api_im_route_test.go',
      'modules/message/api_conversation.go',
      'modules/message/api_conversation_syncack_test.go',
      'modules/file/service_minio.go',
      'modules/file/service_minio_test.go',
      'serverlib/pkg/metrics/metrics.go',
      'serverlib/pkg/metrics/metrics_test.go',
    ];
    for (final file in releaseFiles) {
      expect(content, contains("'$file'"));
    }

    const outOfScopeFiles = [
      'main.go',
      'go.mod',
      'go.sum',
      'serverlib/go.mod',
      'serverlib/go.sum',
      'modules/message/api.go',
      'modules/file/api.go',
      'modules/common/api.go',
      'modules/user/api_manager.go',
      'modules/file/service.go',
      'modules/message/api_manager.go',
      'deploy/production/monitoring/prometheus.yml',
      'ops/monitoring/prometheus/prometheus.yml',
    ];
    for (final file in outOfScopeFiles) {
      expect(content, isNot(contains("'$file'")));
    }

    expect(
      content,
      contains(
        r"Push-Location -LiteralPath (Join-Path $backendRoot 'serverlib')",
      ),
    );
    expect(
      content,
      contains(
        'go test -count=1 ./pkg/metrics -run TestStorageOperationMetricsDoNotLeakObjectPaths',
      ),
    );
    expect(
      content,
      contains("go test -count=1 ./modules/user -run 'TestUserIM_'"),
    );
    expect(
      content,
      contains(
        "go test -count=1 ./modules/message -run 'TestBuildUserLastOffsetsDedupesByChannelWithMaxSeq|TestClearSyncConversationCacheRemovesUserEntries'",
      ),
    );
    expect(
      content,
      contains(
        "go test -count=1 ./modules/file -run 'TestServiceMinioReusesClientAndBucketReadinessForUpload|TestMinio'",
      ),
    );
    expect(
      content,
      isNot(
        contains(
          r"go test -count=1 ./modules/user ./modules/message ./modules/file",
        ),
      ),
    );

    expect(content, isNot(contains('docker compose up')));
    expect(content, isNot(contains('docker compose down')));
    expect(content, isNot(contains('docker compose restart')));
    expect(content, isNot(contains('systemctl restart')));
    expect(content, isNot(contains('test-token')));
    expect(content, isNot(contains('dummy-token')));
  });

  test('phase3 backend optimization patch exists and stays backend-scoped', () {
    final patch = File(
      'deploy/production/backend-optimization/patches/0001-phase3-backend-low-risk-optimization.patch',
    );
    expect(patch.existsSync(), isTrue);

    final content = patch.readAsStringSync();
    for (final expected in [
      'diff --git a/modules/user/api.go b/modules/user/api.go',
      'diff --git a/modules/user/api_im_route_test.go b/modules/user/api_im_route_test.go',
      'diff --git a/modules/message/api_conversation.go b/modules/message/api_conversation.go',
      'diff --git a/modules/message/api_conversation_syncack_test.go b/modules/message/api_conversation_syncack_test.go',
      'diff --git a/modules/file/service_minio.go b/modules/file/service_minio.go',
      'diff --git a/modules/file/service_minio_test.go b/modules/file/service_minio_test.go',
      'diff --git a/serverlib/pkg/metrics/metrics.go b/serverlib/pkg/metrics/metrics.go',
      'diff --git a/serverlib/pkg/metrics/metrics_test.go b/serverlib/pkg/metrics/metrics_test.go',
    ]) {
      expect(content, contains(expected));
    }
    expect(
      content,
      isNot(
        contains(
          '.\\scripts\\ops\\phase3_backend_optimization_prepare.ps1 -Run -AllowProductionSync\n',
        ),
      ),
    );

    for (final unexpected in [
      'TangSengDaoDaoManager-main/',
      'lib/modules/',
      'release_packages/',
      'deploy/production/monitoring/',
      'ops/monitoring/',
      'docker-compose',
    ]) {
      expect(content, isNot(contains(unexpected)));
    }
  });

  test('phase3 backend optimization rollout runbook covers gates and rollback', () {
    final doc = File('docs/production/phase3-backend-optimization-rollout.md');
    expect(doc.existsSync(), isTrue);

    final content = doc.readAsStringSync();
    for (final expected in [
      'phase3_backend_optimization_prepare.ps1 -RunTests',
      '-Run -AllowProductionSync -BuildImage -AllowProductionBuild',
      '-BuildImage -AllowProductionBuild',
      'phase6_backend_service_switch.ps1',
      '-Run',
      '-AllowProductionServiceSwitch',
      '/v1/ping',
      'Authorization: Bearer <metrics-token>',
      'phase3_backend_optimization_sync_backup_dir',
      '.phase3_absent_files',
      'phase3_backend_optimization_build_context=verified',
      r'case "$path" in',
      'modules/user/api.go|modules/user/api_im_route_test.go|modules/message/api_conversation.go|modules/message/api_conversation_syncack_test.go|modules/file/service_minio.go|modules/file/service_minio_test.go|serverlib/pkg/metrics/metrics.go|serverlib/pkg/metrics/metrics_test.go)',
      r'rm -f -- "$path"',
      'phase3_backend_optimization_build_context=verified',
      'phase3_backend_optimization_build_context_root=',
      'phase3_backend_optimization_previous_image_tag',
      'up{job="wukongim_api"}',
      'sum by (status_class) (increase(wukongim_http_requests_total[30m]))',
      'histogram_quantile(0.95',
      'histogram_quantile(0.99',
      'sum by (operation, result) (increase(wukongim_operation_total[30m]))',
      'sum by (provider, operation, result) (increase(wukongim_storage_operation_total[30m]))',
      'sum(increase(wukongim_http_requests_total{route="unknown"}[30m]))',
      'rsync -a --exclude .phase3_absent_files',
    ]) {
      expect(content, contains(expected));
    }

    expect(
      content,
      isNot(
        contains(RegExp(r'Bearer\s+(?!<metrics-token>)[A-Za-z0-9._~+/=-]{8,}')),
      ),
      reason: 'runbook must not include a real bearer token',
    );
  });

  test(
    'phase3 backend optimization prepare dry-run lists manifest without production writes',
    () async {
      final result = await Process.run('powershell', [
        '-NoProfile',
        '-ExecutionPolicy',
        'Bypass',
        '-File',
        'scripts\\ops\\phase3_backend_optimization_prepare.ps1',
      ], workingDirectory: Directory.current.path);

      expect(result.exitCode, 0, reason: result.stderr.toString());
      final output = result.stdout.toString();
      expect(output, contains('Dry run only'));
      expect(output, contains('Files to sync:'));
      expect(output, contains('Manifest:'));
      expect(output, contains('Reviewed manifest: verified'));
      expect(output, contains('phase3_backend_optimization_sync_backup_dir'));
      expect(output, contains('modules/user/api.go'));
      expect(output, contains('modules/message/api_conversation.go'));
      expect(output, contains('modules/file/service_minio.go'));
      expect(output, contains('serverlib/pkg/metrics/metrics.go'));
      expect(output, isNot(contains('serverlib/go.mod')));
      expect(output, isNot(contains('serverlib/go.sum')));
      expect(
        output,
        isNot(contains('phase3_backend_optimization_sync=applied')),
      );
      expect(output, isNot(contains('test-token')));
      expect(output, isNot(contains('dummy-token')));
    },
    skip: !Platform.isWindows,
  );

  test(
    'phase3 backend optimization prepare rejects unsafe production flags',
    () async {
      Future<ProcessResult> run(List<String> arguments) {
        return Process.run('powershell', [
          '-NoProfile',
          '-ExecutionPolicy',
          'Bypass',
          '-File',
          'scripts\\ops\\phase3_backend_optimization_prepare.ps1',
          ...arguments,
        ], workingDirectory: Directory.current.path);
      }

      final missingSyncApproval = await run(['-Run']);
      expect(missingSyncApproval.exitCode, isNot(0));
      expect(
        '${missingSyncApproval.stdout}\n${missingSyncApproval.stderr}',
        contains(
          'Refusing to sync production backend source without -AllowProductionSync',
        ),
      );

      final missingBuildApproval = await run([
        '-Run',
        '-AllowProductionSync',
        '-BuildImage',
      ]);
      expect(missingBuildApproval.exitCode, isNot(0));
      expect(
        '${missingBuildApproval.stdout}\n${missingBuildApproval.stderr}',
        contains(
          'Refusing to build production backend image without -AllowProductionBuild',
        ),
      );

      final buildOnlyMissingBuildApproval = await run(['-Run', '-BuildImage']);
      expect(buildOnlyMissingBuildApproval.exitCode, isNot(0));
      final buildOnlyMissingBuildApprovalOutput =
          '${buildOnlyMissingBuildApproval.stdout}\n${buildOnlyMissingBuildApproval.stderr}';
      expect(
        buildOnlyMissingBuildApprovalOutput,
        contains(
          'Refusing to build production backend image without -AllowProductionBuild',
        ),
      );
      expect(
        buildOnlyMissingBuildApprovalOutput,
        isNot(
          contains(
            'Refusing to sync production backend source without -AllowProductionSync',
          ),
        ),
      );

      final buildOnlyMissingSyncApproval = await run([
        '-Run',
        '-BuildImage',
        '-AllowProductionBuild',
      ]);
      expect(buildOnlyMissingSyncApproval.exitCode, isNot(0));
      expect(
        '${buildOnlyMissingSyncApproval.stdout}\n${buildOnlyMissingSyncApproval.stderr}',
        contains(
          'Refusing to sync production backend source without -AllowProductionSync',
        ),
      );

      final syncOnly = await run(['-Run', '-AllowProductionSync']);
      expect(syncOnly.exitCode, isNot(0));
      expect(
        '${syncOnly.stdout}\n${syncOnly.stderr}',
        contains(
          'Refusing to run production Phase 3 prepare without -BuildImage.',
        ),
      );

      final unsafeHost = await run(['-RemoteHost', '-oProxyCommand=bad']);
      expect(unsafeHost.exitCode, isNot(0));
      expect(
        '${unsafeHost.stdout}\n${unsafeHost.stderr}',
        contains('RemoteHost must be a single safe ssh host token'),
      );

      final unsafePath = await run(['-RemoteSourceRoot', '/opt/../src']);
      expect(unsafePath.exitCode, isNot(0));
      expect(
        '${unsafePath.stdout}\n${unsafePath.stderr}',
        contains('RemoteSourceRoot must be a safe absolute remote path'),
      );

      final mismatchedProductionRoot = await run([
        '-RemoteSourceRoot',
        '/opt/wukongim-prod/src',
        '-RemoteProductionRoot',
        '/opt/other-prod/src/deploy/production',
      ]);
      expect(mismatchedProductionRoot.exitCode, isNot(0));
      expect(
        '${mismatchedProductionRoot.stdout}\n${mismatchedProductionRoot.stderr}',
        contains(
          'RemoteProductionRoot must equal RemoteSourceRoot/deploy/production',
        ),
      );
    },
    skip: !Platform.isWindows,
  );

  test(
    'phase3 backend optimization prepare rejects unreviewed local backend payload',
    () async {
      final tempRoot = Directory.systemTemp.createTempSync(
        'phase3-unreviewed-backend-',
      );
      try {
        const releaseFiles = [
          'modules/user/api.go',
          'modules/user/api_im_route_test.go',
          'modules/message/api_conversation.go',
          'modules/message/api_conversation_syncack_test.go',
          'modules/file/service_minio.go',
          'modules/file/service_minio_test.go',
          'serverlib/pkg/metrics/metrics.go',
          'serverlib/pkg/metrics/metrics_test.go',
        ];
        for (final relative in releaseFiles) {
          final file = File(
            '${tempRoot.path}${Platform.pathSeparator}${relative.replaceAll('/', Platform.pathSeparator)}',
          );
          file.parent.createSync(recursive: true);
          file.writeAsStringSync('unreviewed $relative\n');
        }

        final result = await Process.run('powershell', [
          '-NoProfile',
          '-ExecutionPolicy',
          'Bypass',
          '-File',
          'scripts\\ops\\phase3_backend_optimization_prepare.ps1',
          '-LocalBackendRoot',
          tempRoot.path,
        ], workingDirectory: Directory.current.path);

        expect(result.exitCode, isNot(0));
        expect(
          '${result.stdout}\n${result.stderr}',
          contains(
            'LocalBackendRoot files do not match reviewed Phase 3 manifest',
          ),
        );
      } finally {
        tempRoot.deleteSync(recursive: true);
      }
    },
    skip: !Platform.isWindows,
  );

  test(
    'phase3 backend optimization sync+build rejects unreviewed build context changes',
    () async {
      final tempRoot = Directory.systemTemp.createTempSync(
        'phase3-remote-harness-',
      );
      try {
        final shimDir = Directory(
          '${tempRoot.path}${Platform.pathSeparator}bin',
        )..createSync(recursive: true);
        final remoteSource = Directory(
          '${tempRoot.path}${Platform.pathSeparator}remote-src',
        )..createSync(recursive: true);
        final remoteTmp = Directory(
          '${tempRoot.path}${Platform.pathSeparator}remote-tmp',
        )..createSync(recursive: true);
        final remoteProduction = Directory(
          '${remoteSource.path}${Platform.pathSeparator}deploy${Platform.pathSeparator}production',
        )..createSync(recursive: true);

        File(
          '${remoteProduction.path}${Platform.pathSeparator}.env',
        ).writeAsStringSync('PHASE3_TEST=1\n');
        File(
          '${remoteProduction.path}${Platform.pathSeparator}Dockerfile.tsdd',
        ).writeAsStringSync('FROM scratch\n');

        const buildContextFiles = [
          'go.mod',
          'go.sum',
          'main.go',
          'assets/web/report_notice.html',
          'assets/web/report_success.html',
          'assets/web/success.png',
          'assets/web/join_group.html',
          'assets/web/privacy_policy.html',
          'assets/web/invite_detail.html',
          'assets/web/user_agreement.html',
          'assets/web/sdkinfo.html',
          'assets/web/report.html',
          'assets/assets/g_avatar.jpeg',
          'assets/assets/fileHelper.jpeg',
          'assets/assets/org_avatar.png',
          'assets/assets/u_10000.png',
          'assets/assets/dept_avatar.png',
          'assets/assets/avatar.png',
          'configs/tsdd.yaml',
          'configs/push/push_dev.p12',
        ];
        for (final relative in buildContextFiles) {
          final file = File(
            '${remoteSource.path}${Platform.pathSeparator}${relative.replaceAll('/', Platform.pathSeparator)}',
          );
          file.parent.createSync(recursive: true);
          file.writeAsStringSync('context $relative\n');
        }
        for (final relative in [
          'internal/modules.go',
          'pkg/placeholder.go',
          'serverlib/go.mod',
        ]) {
          final file = File(
            '${remoteSource.path}${Platform.pathSeparator}${relative.replaceAll('/', Platform.pathSeparator)}',
          );
          file.parent.createSync(recursive: true);
          file.writeAsStringSync('context $relative\n');
        }
        const releaseFiles = [
          'modules/user/api.go',
          'modules/user/api_im_route_test.go',
          'modules/message/api_conversation.go',
          'modules/message/api_conversation_syncack_test.go',
          'modules/file/service_minio.go',
          'modules/file/service_minio_test.go',
          'serverlib/pkg/metrics/metrics.go',
          'serverlib/pkg/metrics/metrics_test.go',
        ];
        for (final relative in releaseFiles) {
          final remoteFile = File(
            '${remoteSource.path}${Platform.pathSeparator}${relative.replaceAll('/', Platform.pathSeparator)}',
          );
          remoteFile.parent.createSync(recursive: true);
          remoteFile.writeAsStringSync('previous release $relative\n');
        }

        final captureFile = File(
          '${tempRoot.path}${Platform.pathSeparator}remote-script.txt',
        );
        final buildLog = File(
          '${tempRoot.path}${Platform.pathSeparator}docker-build.log',
        );
        final harnessGo = File(
          '${shimDir.path}${Platform.pathSeparator}remote_harness.go',
        );
        final sshExe = File('${shimDir.path}${Platform.pathSeparator}ssh.exe');
        final scpExe = File('${shimDir.path}${Platform.pathSeparator}scp.exe');
        harnessGo.writeAsStringSync(r'''
package main

import (
	"crypto/sha256"
	"encoding/hex"
	"fmt"
	"io"
	"os"
	"path/filepath"
	"sort"
	"strings"
)

func fail(format string, args ...interface{}) {
	fmt.Fprintf(os.Stderr, format+"\n", args...)
	os.Exit(1)
}

func remotePath(path string) string {
	source := os.Getenv("PHASE3_FAKE_SOURCE")
	tmp := os.Getenv("PHASE3_FAKE_TMP")
	if strings.HasPrefix(path, "/opt/wukongim-prod/src") {
		suffix := strings.TrimPrefix(path, "/opt/wukongim-prod/src")
		return filepath.Join(source, filepath.FromSlash(strings.TrimPrefix(suffix, "/")))
	}
	if strings.HasPrefix(path, "/tmp") {
		suffix := strings.TrimPrefix(path, "/tmp")
		return filepath.Join(tmp, filepath.FromSlash(strings.TrimPrefix(suffix, "/")))
	}
	return path
}

func parseSingleQuoted(script, name string) string {
	prefix := name + "='"
	start := strings.Index(script, prefix)
	if start < 0 {
		return ""
	}
	rest := script[start+len(prefix):]
	end := strings.Index(rest, "'")
	if end < 0 {
		return ""
	}
	return rest[:end]
}

func parseManifest(script string) string {
	value := parseSingleQuoted(script, "manifest_text")
	if value == "" {
		fail("manifest_text missing")
	}
	return value
}

func shaFile(path string) string {
	body, err := os.ReadFile(path)
	if err != nil {
		fail("read %s: %v", path, err)
	}
	sum := sha256.Sum256(body)
	return hex.EncodeToString(sum[:])
}

func buildContext(root string) map[string]string {
	roots := []string{"go.mod", "go.sum", "main.go", "assets", "configs", "internal", "modules", "pkg", "serverlib"}
	result := map[string]string{}
	for _, item := range roots {
		full := filepath.Join(root, filepath.FromSlash(item))
		info, err := os.Stat(full)
		if err != nil {
			fail("missing build context %s: %v", item, err)
		}
		if !info.IsDir() {
			result[item] = shaFile(full)
			continue
		}
		err = filepath.WalkDir(full, func(path string, d os.DirEntry, err error) error {
			if err != nil {
				return err
			}
			if d.IsDir() {
				return nil
			}
			rel, err := filepath.Rel(root, path)
			if err != nil {
				return err
			}
			result[filepath.ToSlash(rel)] = shaFile(path)
			return nil
		})
		if err != nil {
			fail("walk %s: %v", item, err)
		}
	}
	return result
}

func changedPaths(before, after map[string]string) []string {
	seen := map[string]bool{}
	for path := range before {
		seen[path] = true
	}
	for path := range after {
		seen[path] = true
	}
	var changed []string
	for path := range seen {
		if before[path] != after[path] {
			changed = append(changed, path)
		}
	}
	sort.Strings(changed)
	return changed
}

func runSSH() {
	content, err := io.ReadAll(os.Stdin)
	if err != nil {
		fail("read stdin: %v", err)
	}
	if len(content) >= 3 && content[0] == 0xEF && content[1] == 0xBB && content[2] == 0xBF {
		fail("remote bash script must not start with UTF-8 BOM")
	}
	script := string(content)
	if !strings.HasPrefix(script, "set -euo pipefail\n") {
		fail("remote bash script must start with strict mode")
	}
	if capture := os.Getenv("PHASE3_FAKE_CAPTURE"); capture != "" {
		_ = os.WriteFile(capture, content, 0644)
	}

	if strings.Contains(script, "rm -rf") && strings.Contains(script, "remote_tmp=") && !strings.Contains(script, "manifest_text=") {
		tmpPath := parseSingleQuoted(script, "remote_tmp")
		if tmpPath == "" {
			fail("remote_tmp missing")
		}
		local := remotePath(tmpPath)
		_ = os.RemoveAll(local)
		if err := os.MkdirAll(local, 0755); err != nil {
			fail("mkdir remote tmp: %v", err)
		}
		return
	}

	if strings.Contains(script, "mkdir -p ") && !strings.Contains(script, "manifest_text=") {
		start := strings.Index(script, "mkdir -p '")
		if start >= 0 {
			rest := script[start+len("mkdir -p '"):]
			end := strings.Index(rest, "'")
			if end >= 0 {
				if err := os.MkdirAll(remotePath(rest[:end]), 0755); err != nil {
					fail("mkdir staged dir: %v", err)
				}
			}
		}
		return
	}

	if strings.Contains(script, "rm -rf ") && !strings.Contains(script, "manifest_text=") {
		start := strings.Index(script, "rm -rf '")
		if start >= 0 {
			rest := script[start+len("rm -rf '"):]
			end := strings.Index(rest, "'")
			if end >= 0 {
				_ = os.RemoveAll(remotePath(rest[:end]))
			}
		}
		return
	}

	manifest := parseManifest(script)
	source := os.Getenv("PHASE3_FAKE_SOURCE")
	production := filepath.Join(source, "deploy", "production")
	if _, err := os.Stat(filepath.Join(production, ".env")); err != nil {
		fail("missing production .env: %v", err)
	}
	before := buildContext(source)

	allowed := map[string]bool{}
	tmpPath := parseSingleQuoted(script, "remote_tmp")
	if tmpPath == "" {
		fail("remote_tmp missing in apply")
	}
	tmpLocal := remotePath(tmpPath)
	for _, row := range strings.Split(manifest, "\n") {
		row = strings.TrimSpace(row)
		if row == "" {
			continue
		}
		fields := strings.Fields(row)
		if len(fields) != 2 {
			fail("bad manifest row: %s", row)
		}
		expectedHash := fields[0]
		relativePath := fields[1]
		allowed[relativePath] = true
		staged := filepath.Join(tmpLocal, filepath.FromSlash(relativePath))
		if shaFile(staged) != expectedHash {
			fail("staged hash mismatch for %s", relativePath)
		}
		target := filepath.Join(source, filepath.FromSlash(relativePath))
		if err := os.MkdirAll(filepath.Dir(target), 0755); err != nil {
			fail("mkdir target: %v", err)
		}
		body, err := os.ReadFile(staged)
		if err != nil {
			fail("read staged: %v", err)
		}
		if err := os.WriteFile(target, body, 0644); err != nil {
			fail("write target: %v", err)
		}
		if shaFile(target) != expectedHash {
			fail("installed hash mismatch for %s", relativePath)
		}
	}

	if payload := os.Getenv("PHASE3_TAMPER_BUILD_CONTEXT"); payload != "" {
		tamperPath := filepath.Join(source, filepath.FromSlash(payload))
		if err := os.WriteFile(tamperPath, []byte("tampered\n"), 0644); err != nil {
			fail("tamper: %v", err)
		}
	}

	after := buildContext(source)
	for _, path := range changedPaths(before, after) {
		if !allowed[path] {
			fail("phase3_backend_optimization_build_context_unreviewed_change=%s", path)
		}
	}

	if strings.Contains(script, "build_image='1'") {
		if !strings.Contains(script, "build_context_root=\"$remote_tmp/build-context\"") {
			fail("temporary build context root missing")
		}
		if strings.Contains(script, "backup_dir=\"$remote_production/backups/") {
			fail("backup directory must be outside remote source tree")
		}
		if !strings.Contains(script, "docker compose --env-file .env -f \"$remote_tmp/docker-compose.phase3-build.yaml\" build tsdd-api") {
			fail("temporary compose build command missing")
		}
		if !strings.Contains(script, "cat > \"$build_context_root/.dockerignore\"") ||
			!strings.Contains(script, "**/*.p12") ||
			!strings.Contains(script, "**/*.sql") ||
			!strings.Contains(script, "**/*.log") {
			fail("temporary build context dockerignore missing sensitive file patterns")
		}
		f, err := os.OpenFile(os.Getenv("PHASE3_FAKE_BUILD_LOG"), os.O_CREATE|os.O_WRONLY|os.O_APPEND, 0644)
		if err != nil {
			fail("open build log: %v", err)
		}
		defer f.Close()
		fmt.Fprintln(f, "docker compose --env-file .env -f \"$remote_tmp/docker-compose.phase3-build.yaml\" build tsdd-api")
		fmt.Println("phase3_backend_optimization_build_context=verified")
		fmt.Println("phase3_backend_optimization_build_context_root=/tmp/phase3/build-context")
		fmt.Println("phase3_backend_optimization_previous_image_tag=wukongim/tsdd-api:phase3-pre-test")
		fmt.Println("phase3_backend_optimization_sync=applied")
		fmt.Println("phase3_backend_optimization_build=completed")
	}
}

func runSCP(args []string) {
	if len(args) < 2 {
		fail("bad scp args")
	}
	local := args[len(args)-2]
	remote := args[len(args)-1]
	colon := strings.Index(remote, ":")
	if colon < 0 {
		fail("bad remote scp target: %s", remote)
	}
	remoteTarget := remote[colon+1:]
	body, err := os.ReadFile(local)
	if err != nil {
		fail("read scp local: %v", err)
	}
	target := remotePath(remoteTarget)
	if err := os.MkdirAll(filepath.Dir(target), 0755); err != nil {
		fail("mkdir scp target: %v", err)
	}
	if err := os.WriteFile(target, body, 0644); err != nil {
		fail("write scp target: %v", err)
	}
}

func main() {
	switch filepath.Base(os.Args[0]) {
	case "ssh.exe", "ssh":
		runSSH()
	case "scp.exe", "scp":
		runSCP(os.Args[1:])
	default:
		fail("unexpected harness name: %s", filepath.Base(os.Args[0]))
	}
}
''');
        final compileSsh = await Process.run('go', [
          'build',
          '-o',
          sshExe.path,
          harnessGo.path,
        ]);
        expect(
          compileSsh.exitCode,
          0,
          reason: '${compileSsh.stdout}\n${compileSsh.stderr}',
        );
        final compileScp = await Process.run('go', [
          'build',
          '-o',
          scpExe.path,
          harnessGo.path,
        ]);
        expect(
          compileScp.exitCode,
          0,
          reason: '${compileScp.stdout}\n${compileScp.stderr}',
        );

        final env = Map<String, String>.from(Platform.environment);
        env['PATH'] = _prependPath(shimDir.path, env);
        env['PHASE3_FAKE_CAPTURE'] = captureFile.path;
        env['PHASE3_FAKE_SOURCE'] = remoteSource.path;
        env['PHASE3_FAKE_TMP'] = remoteTmp.path;
        env['PHASE3_FAKE_BUILD_LOG'] = buildLog.path;

        Future<ProcessResult> runSyncBuild() {
          return Process.run(
            'powershell',
            [
              '-NoProfile',
              '-ExecutionPolicy',
              'Bypass',
              '-File',
              'scripts\\ops\\phase3_backend_optimization_prepare.ps1',
              '-Run',
              '-AllowProductionSync',
              '-BuildImage',
              '-AllowProductionBuild',
            ],
            workingDirectory: Directory.current.path,
            environment: env,
          );
        }

        final success = await runSyncBuild();
        expect(
          success.exitCode,
          0,
          reason: '${success.stdout}\n${success.stderr}',
        );
        expect(
          buildLog.readAsStringSync(),
          contains(
            r'docker compose --env-file .env -f "$remote_tmp/docker-compose.phase3-build.yaml" build tsdd-api',
          ),
        );

        buildLog.writeAsStringSync('');
        env['PHASE3_TAMPER_BUILD_CONTEXT'] = 'configs/tsdd.yaml';
        final mismatch = await runSyncBuild();
        expect(mismatch.exitCode, isNot(0));
        expect(
          '${mismatch.stdout}\n${mismatch.stderr}',
          contains(
            'phase3_backend_optimization_build_context_unreviewed_change=configs/tsdd.yaml',
          ),
        );
        expect(buildLog.readAsStringSync(), isEmpty);
      } finally {
        tempRoot.deleteSync(recursive: true);
      }
    },
    skip: !Platform.isWindows,
    timeout: const Timeout(Duration(minutes: 2)),
  );
}
