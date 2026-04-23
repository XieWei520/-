import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'app/app.dart';
import 'app/bootstrap/app_startup.dart';
import 'app/bootstrap/error_reporting.dart';
import 'core/config/im_config.dart';
import 'core/utils/storage_utils.dart';
import 'wk_foundation/logging/app_logger.dart';
import 'wk_foundation/net/wk_http_client.dart';
import 'wk_foundation/runtime/app_environment.dart';
import 'wk_foundation/runtime/windows_sqlite_loader.dart';
import 'wukong_base/msg/draft_manager.dart';
import 'wukong_push/push_service.dart';

export 'app/app.dart' show WuKongApp, WuKongIMApp;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final environment = AppEnvironment.detect();
  const debugDeviceFlagOverride = int.fromEnvironment(
    'WK_DEBUG_OVERRIDE_DEVICE_FLAG',
    defaultValue: -1,
  );

  if (kDebugMode && IMConfig.isSupportedDeviceFlag(debugDeviceFlagOverride)) {
    IMConfig.setDebugDeviceFlagOverride(debugDeviceFlagOverride);
    const AppLogger('startup').info(
      'debug device flag override enabled: $debugDeviceFlagOverride',
    );
  }

  if (environment.usesSqfliteFfi) {
    if (environment.platform == AppPlatform.windows) {
      final sqliteLibraryPath = ensureWindowsSqliteRuntimeLibrary();
      const AppLogger('startup').info(
        'windows sqlite runtime library: ${sqliteLibraryPath ?? 'not found'}',
      );
    }
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }

  final startup = AppStartupRunner(
    logger: const AppLogger('startup'),
    steps: <AppStartupStep>[
      AppStartupStep('storage', StorageUtils.init),
      AppStartupStep(
        'drafts',
        () => DraftManager().loadAllDrafts(syncRemote: false),
      ),
      AppStartupStep('network_warmup', () async {
        WkHttpClient.instance.warmUp();
      }),
      AppStartupStep('push', PushService.instance.ensureInitialized),
    ],
  );

  final config = ErrorReportingConfig(
    dsn: ErrorReportingConfig.normalizeDsn(
      const String.fromEnvironment('SENTRY_DSN', defaultValue: ''),
    ),
  );

  await runWithErrorReporting(
    config: config,
    startup: startup.ensureStarted,
    runAppCallback: () => runApp(const ProviderScope(child: WuKongApp())),
  );
}
