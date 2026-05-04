import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:xml/xml.dart';

class AndroidEmojiCatalogGenerationResult {
  const AndroidEmojiCatalogGenerationResult({
    required this.parsedEntryCount,
    required this.copiedAssetCount,
    required this.generatedFilePath,
    required this.assetDirectoryPath,
  });

  final int parsedEntryCount;
  final int copiedAssetCount;
  final String generatedFilePath;
  final String assetDirectoryPath;
}

void main(List<String> args) {
  if (args.length != 1) {
    stderr.writeln(
      'Usage: dart run tool/generate_android_emoji_catalog.dart <android-emoji-root>',
    );
    exitCode = 64;
    return;
  }

  try {
    final result = generateAndroidEmojiCatalog(
      androidSourceRootPath: args.first,
    );

    stdout.writeln('Parsed ${result.parsedEntryCount} emoticon entries.');
    stdout.writeln(
      'Copied ${result.copiedAssetCount} PNG assets into ${result.assetDirectoryPath}.',
    );
    stdout.writeln('Generated ${result.generatedFilePath}.');
  } on _GeneratorCliException catch (error) {
    stderr.writeln(error.message);
    exitCode = error.exitCode;
  } on Object catch (error) {
    stderr.writeln('Failed to generate Android emoji catalog: $error');
    exitCode = 1;
  }
}

AndroidEmojiCatalogGenerationResult generateAndroidEmojiCatalog({
  required String androidSourceRootPath,
  String? projectRootPath,
}) {
  final projectRoot = projectRootPath == null
      ? _resolveProjectRoot()
      : _resolveDirectoryPath(projectRootPath);
  _validateProjectRoot(projectRoot);

  final androidSourceRoot = _resolveDirectoryPath(androidSourceRootPath);
  final xmlFile = File(p.join(androidSourceRoot.path, 'emoji.xml'));
  final sourceDefaultDir = Directory(p.join(androidSourceRoot.path, 'default'));

  if (!xmlFile.existsSync()) {
    throw _GeneratorCliException('emoji.xml not found at: ${xmlFile.path}', 66);
  }
  if (!sourceDefaultDir.existsSync()) {
    throw _GeneratorCliException(
      'default/ directory not found at: ${sourceDefaultDir.path}',
      66,
    );
  }

  final rawXml = utf8.decode(xmlFile.readAsBytesSync());
  final entries = _parseEmojiXml(rawXml);
  if (entries.isEmpty) {
    throw _GeneratorCliException(
      'No <Emoticon /> entries found in: ${xmlFile.path}',
      65,
    );
  }

  _validateUniqueEntries(entries);
  _validateSourceFiles(entries, sourceDefaultDir);

  final targetDefaultDir = Directory(
    p.join(projectRoot.path, 'assets', 'emoji', 'android', 'default'),
  );
  targetDefaultDir.parent.createSync(recursive: true);
  final stagingDirectory = targetDefaultDir.parent.createTempSync(
    '${p.basename(targetDefaultDir.path)}_staging_',
  );

  int copiedCount = 0;
  try {
    copiedCount = _copyPngAssets(
      sourceDirectory: sourceDefaultDir,
      targetDirectory: stagingDirectory,
    );
    _replaceDirectoryAtomically(
      stagingDirectory: stagingDirectory,
      targetDirectory: targetDefaultDir,
    );
  } catch (_) {
    if (stagingDirectory.existsSync()) {
      stagingDirectory.deleteSync(recursive: true);
    }
    rethrow;
  }

  final generatedFile = File(
    p.join(
      projectRoot.path,
      'lib',
      'wukong_base',
      'emoji',
      'android_emoji_catalog.g.dart',
    ),
  );
  generatedFile.parent.createSync(recursive: true);
  generatedFile.writeAsStringSync(_generateCatalog(entries));

  return AndroidEmojiCatalogGenerationResult(
    parsedEntryCount: entries.length,
    copiedAssetCount: copiedCount,
    generatedFilePath: generatedFile.path,
    assetDirectoryPath: targetDefaultDir.path,
  );
}

Directory _resolveProjectRoot() {
  final scriptFile = File.fromUri(Platform.script);
  final projectRoot = scriptFile.parent.parent;
  if (!Directory(p.join(projectRoot.path, 'lib')).existsSync()) {
    throw StateError(
      'Could not resolve project root from script path: ${scriptFile.path}',
    );
  }
  return projectRoot;
}

Directory _resolveDirectoryPath(String inputPath) {
  final directory = Directory(inputPath);
  final resolved = directory.absolute;
  if (!resolved.existsSync()) {
    throw ArgumentError('Directory does not exist: ${resolved.path}');
  }
  return Directory(p.normalize(resolved.path));
}

void _validateProjectRoot(Directory projectRoot) {
  final libDir = Directory(p.join(projectRoot.path, 'lib'));
  if (!libDir.existsSync()) {
    throw StateError(
      'Invalid project root, missing lib directory: ${projectRoot.path}',
    );
  }
}

int _copyPngAssets({
  required Directory sourceDirectory,
  required Directory targetDirectory,
}) {
  var copied = 0;
  for (final entity in sourceDirectory.listSync(recursive: true)) {
    if (entity is! File || p.extension(entity.path).toLowerCase() != '.png') {
      continue;
    }
    final relative = p.relative(entity.path, from: sourceDirectory.path);
    final destination = File(p.join(targetDirectory.path, relative));
    destination.parent.createSync(recursive: true);
    entity.copySync(destination.path);
    copied++;
  }
  return copied;
}

void _replaceDirectoryAtomically({
  required Directory stagingDirectory,
  required Directory targetDirectory,
}) {
  final parentDirectory = targetDirectory.parent;
  parentDirectory.createSync(recursive: true);

  final backupDirectory = Directory(
    p.join(
      parentDirectory.path,
      '${p.basename(targetDirectory.path)}_backup_${DateTime.now().microsecondsSinceEpoch}',
    ),
  );

  if (targetDirectory.existsSync()) {
    targetDirectory.renameSync(backupDirectory.path);
  }

  try {
    stagingDirectory.renameSync(targetDirectory.path);
  } on Object {
    if (targetDirectory.existsSync()) {
      targetDirectory.deleteSync(recursive: true);
    }
    if (backupDirectory.existsSync()) {
      backupDirectory.renameSync(targetDirectory.path);
    }
    rethrow;
  }

  if (backupDirectory.existsSync()) {
    backupDirectory.deleteSync(recursive: true);
  }
}

void _validateUniqueEntries(List<_AndroidEmojiGenerationEntry> entries) {
  final byId = <String, _AndroidEmojiGenerationEntry>{};
  final byTag = <String, _AndroidEmojiGenerationEntry>{};

  for (final entry in entries) {
    final duplicateId = byId[entry.id];
    if (duplicateId != null) {
      throw StateError(
        'Duplicate Emoticon ID "${entry.id}" for files '
        '"${duplicateId.sourceFilePath}" and "${entry.sourceFilePath}".',
      );
    }
    byId[entry.id] = entry;

    final duplicateTag = byTag[entry.tag];
    if (duplicateTag != null) {
      throw StateError(
        'Duplicate Emoticon Tag "${entry.tag}" for ids '
        '"${duplicateTag.id}" and "${entry.id}".',
      );
    }
    byTag[entry.tag] = entry;
  }
}

void _validateSourceFiles(
  List<_AndroidEmojiGenerationEntry> entries,
  Directory sourceDefaultDir,
) {
  final sourceRoot = p.normalize(sourceDefaultDir.absolute.path);
  for (final entry in entries) {
    final normalizedRelativePath = p.posix.normalize(entry.sourceFilePath);
    if (p.posix.isAbsolute(normalizedRelativePath) ||
        normalizedRelativePath == '..' ||
        normalizedRelativePath.startsWith('../')) {
      throw StateError(
        'Invalid source file path for ${entry.id}: ${entry.sourceFilePath}',
      );
    }
    if (p.posix.extension(normalizedRelativePath).toLowerCase() != '.png') {
      throw StateError(
        'Non-PNG source file path for ${entry.id}: ${entry.sourceFilePath}',
      );
    }

    final sourcePath = p.join(
      sourceDefaultDir.path,
      normalizedRelativePath.replaceAll('/', p.separator),
    );
    final normalizedSourcePath = p.normalize(sourcePath);
    if (!p.isWithin(sourceRoot, normalizedSourcePath)) {
      throw StateError(
        'Source path escapes default directory for ${entry.id}: '
        '${entry.sourceFilePath}',
      );
    }
    if (!File(sourcePath).existsSync()) {
      throw StateError('Missing source PNG for ${entry.id}: $sourcePath');
    }
  }
}

List<_AndroidEmojiGenerationEntry> _parseEmojiXml(String rawXml) {
  final document = XmlDocument.parse(rawXml);
  final entries = <_AndroidEmojiGenerationEntry>[];

  for (final element in document.findAllElements('Emoticon')) {
    final id = _requiredAttribute(element, 'ID');
    final tag = _requiredAttribute(element, 'Tag');
    final file = _requiredAttribute(element, 'File');

    final sourceFilePath = _normalizeAsPosix(file);
    final groupId = id.split('_').first;
    final assetPath = p.posix.join(
      'assets',
      'emoji',
      'android',
      'default',
      sourceFilePath,
    );

    entries.add(
      _AndroidEmojiGenerationEntry(
        id: id,
        groupId: groupId,
        tag: tag,
        sourceFilePath: sourceFilePath,
        assetPath: assetPath,
        baseId: _resolveBaseId(id),
      ),
    );
  }

  return entries;
}

String _requiredAttribute(XmlElement element, String name) {
  for (final attribute in element.attributes) {
    if (attribute.name.local.toLowerCase() == name.toLowerCase()) {
      return attribute.value;
    }
  }
  throw FormatException(
    'Missing "$name" attribute on <${element.name.local}> element.',
  );
}

String _normalizeAsPosix(String path) {
  final normalized = path.replaceAll('\\', '/');
  return p.posix.normalize(normalized);
}

String? _resolveBaseId(String id) {
  const defaultSuffix = '_default';
  if (id.endsWith(defaultSuffix)) {
    return id.substring(0, id.length - defaultSuffix.length);
  }

  final colorMatch = RegExp(r'^(.*)_color_\d+$').firstMatch(id);
  if (colorMatch != null) {
    return colorMatch.group(1);
  }
  return null;
}

String _generateCatalog(List<_AndroidEmojiGenerationEntry> entries) {
  final output = StringBuffer()
    ..writeln('// GENERATED CODE - DO NOT MODIFY BY HAND.')
    ..writeln('// Generated by tool/generate_android_emoji_catalog.dart')
    ..writeln()
    ..writeln("part of 'android_emoji_catalog.dart';")
    ..writeln()
    ..writeln(
      'const List<AndroidEmojiEntry> androidEmojiEntries = <AndroidEmojiEntry>[',
    );

  for (final entry in entries) {
    output
      ..writeln('  AndroidEmojiEntry(')
      ..writeln("    id: '${_escapeDartString(entry.id)}',")
      ..writeln("    groupId: '${_escapeDartString(entry.groupId)}',")
      ..writeln("    tag: '${_escapeDartString(entry.tag)}',")
      ..writeln("    assetPath: '${_escapeDartString(entry.assetPath)}',");
    if (entry.baseId != null) {
      output.writeln("    baseId: '${_escapeDartString(entry.baseId!)}',");
    }
    output.writeln('  ),');
  }

  output.writeln('];');
  return output.toString();
}

String _escapeDartString(String value) {
  return value
      .replaceAll(r'\', r'\\')
      .replaceAll("'", r"\'")
      .replaceAll(r'$', r'\$')
      .replaceAll('\r', r'\r')
      .replaceAll('\n', r'\n');
}

class _AndroidEmojiGenerationEntry {
  const _AndroidEmojiGenerationEntry({
    required this.id,
    required this.groupId,
    required this.tag,
    required this.sourceFilePath,
    required this.assetPath,
    this.baseId,
  });

  final String id;
  final String groupId;
  final String tag;
  final String sourceFilePath;
  final String assetPath;
  final String? baseId;
}

class _GeneratorCliException implements Exception {
  const _GeneratorCliException(this.message, this.exitCode);

  final String message;
  final int exitCode;
}
