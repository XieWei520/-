import 'dart:io';

import 'package:path/path.dart' as p;

const String _windowsSqliteDllName = 'sqlite3.dll';

String? ensureWindowsSqliteRuntimeLibrary({
  Iterable<String>? candidateDirectories,
  String? currentDirectory,
  String? resolvedExecutablePath,
}) {
  final executablePath = resolvedExecutablePath ?? Platform.resolvedExecutable;
  final executableDirectory = _normalizeDirectory(p.dirname(executablePath));
  if (executableDirectory == null) {
    return null;
  }

  final runtimeLibrary = File(
    p.join(executableDirectory, _windowsSqliteDllName),
  );
  if (runtimeLibrary.existsSync()) {
    return runtimeLibrary.absolute.path;
  }

  final searchDirectories =
      candidateDirectories ??
      buildWindowsSqliteSearchDirectories(
        currentDirectory: currentDirectory,
        resolvedExecutablePath: executablePath,
      );

  final sourcePath = resolveWindowsSqliteLibraryPath(
    candidateDirectories: searchDirectories.where((directory) {
      return _normalizeDirectory(directory) != executableDirectory;
    }),
  );
  if (sourcePath == null) {
    return null;
  }

  runtimeLibrary.parent.createSync(recursive: true);
  File(sourcePath).copySync(runtimeLibrary.path);
  return runtimeLibrary.absolute.path;
}

String? resolveWindowsSqliteLibraryPath({
  Iterable<String>? candidateDirectories,
}) {
  final directories =
      candidateDirectories ?? buildWindowsSqliteSearchDirectories();

  for (final directory in directories) {
    final normalizedDirectory = _normalizeDirectory(directory);
    if (normalizedDirectory == null) {
      continue;
    }

    final sqliteFile = File(p.join(normalizedDirectory, _windowsSqliteDllName));
    if (sqliteFile.existsSync()) {
      return sqliteFile.absolute.path;
    }
  }

  return null;
}

List<String> buildWindowsSqliteSearchDirectories({
  String? currentDirectory,
  String? resolvedExecutablePath,
}) {
  final baseCurrentDirectory = currentDirectory ?? Directory.current.path;
  final baseExecutablePath =
      resolvedExecutablePath ?? Platform.resolvedExecutable;

  final candidates = <String>[
    p.dirname(baseExecutablePath),
    baseCurrentDirectory,
    p.join(baseCurrentDirectory, 'build', 'windows', 'x64', 'runner', 'Debug'),
    p.join(
      baseCurrentDirectory,
      'build',
      'windows',
      'x64',
      'runner',
      'Release',
    ),
  ];

  final uniqueDirectories = <String>[];
  final seen = <String>{};
  for (final directory in candidates) {
    final normalizedDirectory = _normalizeDirectory(directory);
    if (normalizedDirectory == null || !seen.add(normalizedDirectory)) {
      continue;
    }
    uniqueDirectories.add(normalizedDirectory);
  }

  return uniqueDirectories;
}

String? _normalizeDirectory(String directory) {
  final trimmed = directory.trim();
  if (trimmed.isEmpty) {
    return null;
  }

  return p.normalize(p.absolute(trimmed));
}
