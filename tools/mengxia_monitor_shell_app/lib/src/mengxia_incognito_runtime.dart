import 'dart:io';

const String mengxiaFreshSessionDirectoryPrefix = 'mengxia_fresh_session_';
const String mengxiaShellStatusDirectoryName = 'mengxia_monitor_shell';

class MengxiaIncognitoRuntimePolicy {
  const MengxiaIncognitoRuntimePolicy({
    required this.requiresManualLoginEveryLaunch,
    required this.reusesCookies,
    required this.reusesLocalStorage,
    required this.reusesHistory,
    required this.persistentProfileDirectory,
    required this.persistentSessionDirectory,
  });

  const MengxiaIncognitoRuntimePolicy.strict()
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

Future<Directory> createMengxiaFreshSessionDirectory(Directory base) async {
  await base.create(recursive: true);
  return base.createTemp(mengxiaFreshSessionDirectoryPrefix);
}

File mengxiaShellSnapshotFileFor(Directory supportDirectory) {
  return File(
    '${supportDirectory.path}${Platform.pathSeparator}'
    '$mengxiaShellStatusDirectoryName${Platform.pathSeparator}status.json',
  );
}

Future<void> destroyMengxiaFreshSessionDirectory(Directory session) async {
  if (!await session.exists()) {
    return;
  }
  await session.delete(recursive: true);
}

typedef MengxiaSessionDirectoryDestroyer =
    Future<void> Function(Directory session);

Future<bool> destroyMengxiaFreshSessionDirectoryBestEffort(
  Directory session, {
  List<Duration> retryDelays = const <Duration>[
    Duration(milliseconds: 100),
    Duration(milliseconds: 250),
    Duration(milliseconds: 500),
  ],
  MengxiaSessionDirectoryDestroyer destroy =
      destroyMengxiaFreshSessionDirectory,
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
