import 'dart:io';

const String juliangFreshSessionDirectoryPrefix = 'juliang_fresh_session_';
const String juliangShellStatusDirectoryName = 'juliang_monitor_shell';

class JuliangIncognitoRuntimePolicy {
  const JuliangIncognitoRuntimePolicy({
    required this.requiresManualLoginEveryLaunch,
    required this.reusesCookies,
    required this.reusesLocalStorage,
    required this.reusesHistory,
    required this.persistentProfileDirectory,
    required this.persistentSessionDirectory,
  });

  const JuliangIncognitoRuntimePolicy.strict()
    : requiresManualLoginEveryLaunch = true,
      reusesCookies = false,
      reusesLocalStorage = false,
      reusesHistory = false,
      persistentProfileDirectory = null,
      persistentSessionDirectory = null;

  final bool requiresManualLoginEveryLaunch;
  final bool reusesCookies;
  final bool reusesLocalStorage;
  final bool reusesHistory;
  final String? persistentProfileDirectory;
  final String? persistentSessionDirectory;
}

Future<Directory> createJuliangFreshSessionDirectory(Directory base) async {
  await base.create(recursive: true);
  return base.createTemp(juliangFreshSessionDirectoryPrefix);
}

Future<void> cleanupJuliangStaleSessionDirectories(Directory base) async {
  if (!await base.exists()) {
    return;
  }
  await for (final entity in base.list(followLinks: false)) {
    if (entity is! Directory) {
      continue;
    }
    final name = entity.uri.pathSegments
        .where((segment) => segment.isNotEmpty)
        .lastOrNull;
    if (name == null || !name.startsWith(juliangFreshSessionDirectoryPrefix)) {
      continue;
    }
    await destroyJuliangFreshSessionDirectoryBestEffort(entity);
  }
}

File juliangShellSnapshotFileFor(Directory supportDirectory) {
  return File(
    '${supportDirectory.path}${Platform.pathSeparator}'
    '$juliangShellStatusDirectoryName${Platform.pathSeparator}status.json',
  );
}

Future<void> destroyJuliangFreshSessionDirectory(Directory session) async {
  if (!await session.exists()) {
    return;
  }
  await session.delete(recursive: true);
}

typedef JuliangSessionDirectoryDestroyer =
    Future<void> Function(Directory session);

Future<bool> destroyJuliangFreshSessionDirectoryBestEffort(
  Directory session, {
  List<Duration> retryDelays = const <Duration>[
    Duration(milliseconds: 100),
    Duration(milliseconds: 250),
    Duration(milliseconds: 500),
  ],
  JuliangSessionDirectoryDestroyer destroy =
      destroyJuliangFreshSessionDirectory,
}) async {
  for (var attempt = 0; ; attempt += 1) {
    try {
      await destroy(session);
      return !await session.exists();
    } on FileSystemException {
      if (attempt >= retryDelays.length) {
        return false;
      }
      await Future<void>.delayed(retryDelays[attempt]);
    }
  }
}
