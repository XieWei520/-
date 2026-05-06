import 'dart:io';

class BrowserProfilePaths {
  BrowserProfilePaths(this.storeDir);

  final String storeDir;

  Directory get profileDir =>
      Directory('$storeDir${Platform.pathSeparator}chromium-profile');

  Directory get runtimeDir =>
      Directory('$storeDir${Platform.pathSeparator}runtime');

  File get lastBrowserStatusFile => File(
    '${runtimeDir.path}${Platform.pathSeparator}last-browser-status.json',
  );

  File get dedupeCacheFile =>
      File('${runtimeDir.path}${Platform.pathSeparator}dedupe-cache.json');
}

class BrowserProfileCleaner {
  const BrowserProfileCleaner(this.paths);

  final BrowserProfilePaths paths;

  Future<void> clearProfile() async {
    final profile = paths.profileDir;
    if (await profile.exists()) {
      await profile.delete(recursive: true);
    }
  }
}
