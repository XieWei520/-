import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:wukong_im_app/wk_foundation/runtime/windows_sqlite_loader.dart';

void main() {
  group('resolveWindowsSqliteLibraryPath', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp(
        'windows_sqlite_loader_test_',
      );
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test(
      'returns the first sqlite3.dll found in the candidate directories',
      () {
        final firstDir = Directory('${tempDir.path}\\first')..createSync();
        final secondDir = Directory('${tempDir.path}\\second')..createSync();

        final expected = File('${secondDir.path}\\sqlite3.dll')
          ..writeAsStringSync('bundled sqlite placeholder');
        File(
          '${firstDir.path}\\sqlite3.dll',
        ).writeAsStringSync('another bundled sqlite placeholder');

        final resolved = resolveWindowsSqliteLibraryPath(
          candidateDirectories: <String>[secondDir.path, firstDir.path],
        );

        expect(resolved, expected.path);
      },
    );

    test('returns null when no candidate directory contains sqlite3.dll', () {
      final resolved = resolveWindowsSqliteLibraryPath(
        candidateDirectories: <String>[
          Directory('${tempDir.path}\\missing').path,
          tempDir.path,
        ],
      );

      expect(resolved, isNull);
    });
  });

  group('ensureWindowsSqliteRuntimeLibrary', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp(
        'windows_sqlite_runtime_test_',
      );
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test(
      'copies sqlite3.dll into the executable directory when only the current directory has it',
      () {
        final currentDir = Directory('${tempDir.path}\\project')
          ..createSync(recursive: true);
        final runnerDir = Directory('${tempDir.path}\\runner\\Debug')
          ..createSync(recursive: true);
        final sourceFile = File('${currentDir.path}\\sqlite3.dll')
          ..writeAsStringSync('bundled sqlite placeholder');

        final resolved = ensureWindowsSqliteRuntimeLibrary(
          currentDirectory: currentDir.path,
          resolvedExecutablePath: '${runnerDir.path}\\wukong_im_app.exe',
        );

        final runtimeFile = File('${runnerDir.path}\\sqlite3.dll');
        expect(resolved, runtimeFile.path);
        expect(runtimeFile.existsSync(), isTrue);
        expect(runtimeFile.readAsStringSync(), sourceFile.readAsStringSync());
      },
    );

    test(
      'keeps the executable directory sqlite3.dll when it already exists',
      () {
        final currentDir = Directory('${tempDir.path}\\project')
          ..createSync(recursive: true);
        final runnerDir = Directory('${tempDir.path}\\runner\\Debug')
          ..createSync(recursive: true);
        File(
          '${currentDir.path}\\sqlite3.dll',
        ).writeAsStringSync('source sqlite placeholder');
        final runtimeFile = File('${runnerDir.path}\\sqlite3.dll')
          ..writeAsStringSync('runtime sqlite placeholder');

        final resolved = ensureWindowsSqliteRuntimeLibrary(
          currentDirectory: currentDir.path,
          resolvedExecutablePath: '${runnerDir.path}\\wukong_im_app.exe',
        );

        expect(resolved, runtimeFile.path);
        expect(runtimeFile.readAsStringSync(), 'runtime sqlite placeholder');
      },
    );
  });
}
