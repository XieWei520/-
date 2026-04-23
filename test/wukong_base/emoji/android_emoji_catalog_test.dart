import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:wukong_im_app/wukong_base/emoji/android_emoji_catalog.dart';

import '../../../tool/generate_android_emoji_catalog.dart';

void main() {
  group('android emoji catalog', () {
    test('contains generated source of truth entries', () {
      expect(androidEmojiEntries.length, greaterThan(350));
      expect(androidEmojiCatalog.groupIds, const <String>['0', '1', '2']);
    });

    test('supports lookup by id, tag, and base id resolution', () {
      expect(
        androidEmojiCatalog.lookupById('0_0')?.assetPath,
        'assets/emoji/android/default/0_0.png',
      );
      expect(androidEmojiCatalog.lookupById('0_114_default')?.baseId, '0_114');
      expect(androidEmojiCatalog.lookupByTag('👋')?.id, '0_114_default');
      expect(androidEmojiCatalog.lookupByTag('👋')?.baseId, '0_114');
      expect(androidEmojiCatalog.lookupByTag('__missing__'), isNull);
    });

    test('longestMatchAt uses the longest available tag', () {
      final match = androidEmojiCatalog.longestMatchAt('x👋🏻y', 1);
      expect(match?.id, '0_114_color_1');
      expect(androidEmojiCatalog.longestMatchAt('x👋🏻y', 0), isNull);
    });

    test('entriesForGroup excludes color variants from tab grids', () {
      final groupEntries = androidEmojiCatalog.entriesForGroup('0');

      expect(groupEntries, isNotEmpty);
      expect(groupEntries.any((entry) => entry.id == '0_114_default'), isTrue);
      expect(groupEntries.any((entry) => entry.id == '0_114_color_1'), isFalse);
      expect(
        groupEntries.any((entry) => entry.id.contains('_color_')),
        isFalse,
      );
    });
  });

  group('android emoji generator', () {
    test('parses xml and generates catalog for a minimal valid source', () {
      final fixture = _GeneratorFixture.create();
      addTearDown(fixture.dispose);

      fixture.writeSourceXml('''
<?xml version="1.0" encoding="utf-8"?>
<PopoEmoticons>
  <Catalog Title="default">
    <Emoticon ID="0_0" Tag="A" File="0_0.png" />
  </Catalog>
</PopoEmoticons>
''');
      fixture.writeSourcePng('0_0.png', const <int>[0, 1, 2, 3]);

      final result = generateAndroidEmojiCatalog(
        androidSourceRootPath: fixture.sourceRoot.path,
        projectRootPath: fixture.projectRoot.path,
      );

      expect(result.parsedEntryCount, 1);
      expect(result.copiedAssetCount, 1);
      expect(File(result.generatedFilePath).existsSync(), isTrue);
      expect(
        File(result.generatedFilePath).readAsStringSync(),
        contains("id: '0_0'"),
      );
      expect(
        File(result.generatedFilePath).readAsStringSync(),
        contains("tag: 'A'"),
      );
      expect(
        File(
          p.join(
            fixture.projectRoot.path,
            'assets',
            'emoji',
            'android',
            'default',
            '0_0.png',
          ),
        ).existsSync(),
        isTrue,
      );
    });

    test('rejects duplicate ids in source xml', () {
      final fixture = _GeneratorFixture.create();
      addTearDown(fixture.dispose);

      fixture.writeSourceXml('''
<?xml version="1.0" encoding="utf-8"?>
<PopoEmoticons>
  <Catalog Title="default">
    <Emoticon ID="0_0" Tag="A" File="0_0.png" />
    <Emoticon ID="0_0" Tag="B" File="0_1.png" />
  </Catalog>
</PopoEmoticons>
''');
      fixture.writeSourcePng('0_0.png', const <int>[1]);
      fixture.writeSourcePng('0_1.png', const <int>[2]);

      expect(
        () => generateAndroidEmojiCatalog(
          androidSourceRootPath: fixture.sourceRoot.path,
          projectRootPath: fixture.projectRoot.path,
        ),
        throwsA(
          isA<StateError>().having(
            (error) => error.toString(),
            'message',
            contains('Duplicate Emoticon ID'),
          ),
        ),
      );
    });

    test('rejects duplicate tags in source xml', () {
      final fixture = _GeneratorFixture.create();
      addTearDown(fixture.dispose);

      fixture.writeSourceXml('''
<?xml version="1.0" encoding="utf-8"?>
<PopoEmoticons>
  <Catalog Title="default">
    <Emoticon ID="0_0" Tag="A" File="0_0.png" />
    <Emoticon ID="0_1" Tag="A" File="0_1.png" />
  </Catalog>
</PopoEmoticons>
''');
      fixture.writeSourcePng('0_0.png', const <int>[1]);
      fixture.writeSourcePng('0_1.png', const <int>[2]);

      expect(
        () => generateAndroidEmojiCatalog(
          androidSourceRootPath: fixture.sourceRoot.path,
          projectRootPath: fixture.projectRoot.path,
        ),
        throwsA(
          isA<StateError>().having(
            (error) => error.toString(),
            'message',
            contains('Duplicate Emoticon Tag'),
          ),
        ),
      );
    });

    test(
      'keeps existing live assets intact when validation fails before replacement',
      () {
        final fixture = _GeneratorFixture.create();
        addTearDown(fixture.dispose);

        final liveAsset = fixture.writeLiveAsset('live_only.png', const <int>[
          9,
          8,
          7,
        ]);

        fixture.writeSourceXml('''
<?xml version="1.0" encoding="utf-8"?>
<PopoEmoticons>
  <Catalog Title="default">
    <Emoticon ID="0_0" Tag="A" File="missing.png" />
  </Catalog>
</PopoEmoticons>
''');

        expect(
          () => generateAndroidEmojiCatalog(
            androidSourceRootPath: fixture.sourceRoot.path,
            projectRootPath: fixture.projectRoot.path,
          ),
          throwsA(
            isA<StateError>().having(
              (error) => error.toString(),
              'message',
              contains('Missing source PNG'),
            ),
          ),
        );

        expect(liveAsset.existsSync(), isTrue);
        expect(liveAsset.readAsBytesSync(), const <int>[9, 8, 7]);
      },
    );
  });
}

class _GeneratorFixture {
  _GeneratorFixture._({
    required this.root,
    required this.projectRoot,
    required this.sourceRoot,
  });

  final Directory root;
  final Directory projectRoot;
  final Directory sourceRoot;

  static _GeneratorFixture create() {
    final root = Directory.systemTemp.createTempSync(
      'android_emoji_generator_test_',
    );
    final projectRoot = Directory(p.join(root.path, 'project'))
      ..createSync(recursive: true);
    Directory(p.join(projectRoot.path, 'lib')).createSync(recursive: true);
    final sourceRoot = Directory(p.join(root.path, 'source'))
      ..createSync(recursive: true);
    Directory(p.join(sourceRoot.path, 'default')).createSync(recursive: true);

    return _GeneratorFixture._(
      root: root,
      projectRoot: projectRoot,
      sourceRoot: sourceRoot,
    );
  }

  void writeSourceXml(String xml) {
    File(p.join(sourceRoot.path, 'emoji.xml'))
      ..parent.createSync(recursive: true)
      ..writeAsStringSync(xml);
  }

  void writeSourcePng(String relativePath, List<int> bytes) {
    File(p.join(sourceRoot.path, 'default', relativePath))
      ..parent.createSync(recursive: true)
      ..writeAsBytesSync(bytes);
  }

  File writeLiveAsset(String name, List<int> bytes) {
    final file = File(
      p.join(projectRoot.path, 'assets', 'emoji', 'android', 'default', name),
    );
    file.parent.createSync(recursive: true);
    file.writeAsBytesSync(bytes);
    return file;
  }

  void dispose() {
    if (root.existsSync()) {
      root.deleteSync(recursive: true);
    }
  }
}
