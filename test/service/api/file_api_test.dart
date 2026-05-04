import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wukong_im_app/core/config/api_config.dart';
import 'package:wukong_im_app/service/api/api_client.dart';
import 'package:wukong_im_app/service/api/file_api.dart';

void main() {
  late HttpClientAdapter originalAdapter;

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    originalAdapter = ApiClient.instance.dio.httpClientAdapter;
  });

  tearDown(() {
    ApiClient.instance.dio.httpClientAdapter = originalAdapter;
    FileApi.multipartUploadThresholdBytes =
        FileApi.defaultMultipartUploadThresholdBytes;
  });

  test('uploadChatFile trims local path and sanitizes object path', () async {
    final tempDir = await Directory.systemTemp.createTemp('wk_file_api_upload');
    addTearDown(() => tempDir.delete(recursive: true));
    final file = File('${tempDir.path}${Platform.pathSeparator}Photo.JPG');
    await file.writeAsBytes(<int>[1, 2, 3]);

    final adapter = _RecordingUploadAdapter();
    ApiClient.instance.dio.httpClientAdapter = adapter;

    final uploadedUrl = await FileApi.instance.uploadChatFile(
      filePath: ' ${file.path} ',
      channelId: r'..\group/alpha?tab=files',
      channelType: 2,
    );

    expect(uploadedUrl, ApiConfig.resolveMediaUrl('file/chat/uploaded.jpg'));
    expect(adapter.uploadRequestPaths, <String>['/v1/file/upload/session']);
    expect(adapter.requestedObjectPaths, hasLength(1));
    final objectPath = adapter.requestedObjectPaths.single;
    expect(objectPath, startsWith('/2/group_alpha_tab_files/'));
    expect(objectPath, endsWith('.jpg'));
    expect(objectPath, isNot(contains('..')));
    expect(objectPath, isNot(contains(r'\')));
    expect(objectPath, isNot(contains('?')));
  });

  test('uploadChatFileBytes uploads browser selected bytes', () async {
    final adapter = _RecordingUploadAdapter();
    ApiClient.instance.dio.httpClientAdapter = adapter;

    final uploadedUrl = await FileApi.instance.uploadChatFileBytes(
      bytes: Uint8List.fromList(<int>[9, 8, 7, 6]),
      fileName: r'..\photo final.PNG',
      channelId: r'web/room?bad=true',
      channelType: 1,
    );

    expect(uploadedUrl, ApiConfig.resolveMediaUrl('file/chat/uploaded.jpg'));
    expect(adapter.uploadRequestPaths, <String>['/v1/file/upload/session']);
    expect(adapter.requestedObjectPaths, hasLength(1));
    final objectPath = adapter.requestedObjectPaths.single;
    expect(objectPath, startsWith('/1/web_room_bad_true/'));
    expect(objectPath, endsWith('.png'));
    expect(objectPath, isNot(contains('..')));
    expect(objectPath, isNot(contains(r'\')));
    expect(adapter.uploadRequestBodies.single, containsAll(<int>[9, 8, 7, 6]));
    expect(
      utf8.decode(adapter.uploadRequestBodies.single, allowMalformed: true),
      contains('photo final.PNG'),
    );
  });

  test('uploadCommonImage normalizes caller supplied object paths', () async {
    final tempDir = await Directory.systemTemp.createTemp(
      'wk_file_api_common_upload',
    );
    addTearDown(() => tempDir.delete(recursive: true));
    final file = File('${tempDir.path}${Platform.pathSeparator}avatar.png');
    await file.writeAsBytes(<int>[1, 2, 3]);

    final adapter = _RecordingUploadAdapter();
    ApiClient.instance.dio.httpClientAdapter = adapter;

    await FileApi.instance.uploadCommonImage(
      filePath: ' ${file.path} ',
      uploadPath: r'/group/../g\bad/robot/avatar?.PNG',
    );

    expect(adapter.requestedObjectPaths, <String>[
      '/group/g/bad/robot/avatar_.PNG',
    ]);
  });

  test(
    'uploadChatFile uses multipart endpoints for large local files',
    () async {
      final tempDir = await Directory.systemTemp.createTemp(
        'wk_file_api_multipart_upload',
      );
      addTearDown(() => tempDir.delete(recursive: true));
      final file = File('${tempDir.path}${Platform.pathSeparator}archive.bin');
      await file.writeAsBytes(<int>[1, 2, 3, 4]);

      FileApi.multipartUploadThresholdBytes = 1;
      final adapter = _RecordingUploadAdapter();
      ApiClient.instance.dio.httpClientAdapter = adapter;

      final uploadedUrl = await FileApi.instance.uploadChatFile(
        filePath: file.path,
        channelId: 'large-room',
        channelType: 1,
      );

      expect(
        uploadedUrl,
        ApiConfig.resolveMediaUrl('file/preview/chat/large-upload.bin'),
      );
      expect(adapter.requestedObjectPaths, isEmpty);
      expect(adapter.uploadRequestPaths, isEmpty);
      expect(adapter.multipartInitBodies, hasLength(1));
      expect(adapter.multipartInitBodies.single['type'], 'chat');
      expect(
        adapter.multipartInitBodies.single['path'],
        startsWith('/1/large-room/'),
      );
      expect(adapter.multipartPartQueries.single['part_number'], '1');
      expect(adapter.multipartPartBytes.single, <int>[1, 2, 3, 4]);
      expect(adapter.multipartCompleteBodies.single['parts'], <int>[1]);
    },
  );
}

class _RecordingUploadAdapter implements HttpClientAdapter {
  final List<String> requestedObjectPaths = <String>[];
  final List<String> uploadRequestPaths = <String>[];
  final List<Map<String, dynamic>> multipartInitBodies =
      <Map<String, dynamic>>[];
  final List<List<int>> uploadRequestBodies = <List<int>>[];
  final List<Map<String, dynamic>> multipartPartQueries =
      <Map<String, dynamic>>[];
  final List<List<int>> multipartPartBytes = <List<int>>[];
  final List<Map<String, dynamic>> multipartCompleteBodies =
      <Map<String, dynamic>>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    if (options.method.toUpperCase() == 'GET' &&
        options.uri.path == ApiConfig.fileUpload) {
      requestedObjectPaths.add(
        options.queryParameters['path']?.toString() ?? '',
      );
      return _json(<String, dynamic>{'url': '/v1/file/upload/session'});
    }

    if (options.method.toUpperCase() == 'POST' &&
        options.uri.path == '/v1/file/upload/session') {
      final chunks = await requestStream?.toList() ?? const <Uint8List>[];
      uploadRequestBodies.add(
        chunks.expand((chunk) => chunk).toList(growable: false),
      );
      uploadRequestPaths.add(options.uri.path);
      return _json(<String, dynamic>{'path': 'file/chat/uploaded.jpg'});
    }

    if (options.method.toUpperCase() == 'POST' &&
        options.uri.path == ApiConfig.fileMultipartInit) {
      multipartInitBodies.add(Map<String, dynamic>.from(options.data as Map));
      return _json(<String, dynamic>{
        'upload_id': 'upload-large-1',
        'path': multipartInitBodies.last['path'],
      });
    }

    if (options.method.toUpperCase() == 'PUT' &&
        options.uri.path == ApiConfig.fileMultipartPart) {
      multipartPartQueries.add(
        options.queryParameters.map(
          (key, value) => MapEntry<String, dynamic>(key, value.toString()),
        ),
      );
      final chunks = await requestStream?.toList() ?? const <Uint8List>[];
      multipartPartBytes.add(
        chunks.expand((chunk) => chunk).toList(growable: false),
      );
      return _json(<String, dynamic>{'part_number': 1});
    }

    if (options.method.toUpperCase() == 'POST' &&
        options.uri.path == ApiConfig.fileMultipartComplete) {
      multipartCompleteBodies.add(
        Map<String, dynamic>.from(options.data as Map),
      );
      return _json(<String, dynamic>{
        'path': 'file/preview/chat/large-upload.bin',
      });
    }

    return _json(<String, dynamic>{
      'code': 404,
      'msg': 'Unhandled request: ${options.method} ${options.uri.path}',
    }, statusCode: 404);
  }

  ResponseBody _json(Object payload, {int statusCode = 200}) {
    return ResponseBody.fromString(
      jsonEncode(payload),
      statusCode,
      headers: <String, List<String>>{
        Headers.contentTypeHeader: <String>[Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
