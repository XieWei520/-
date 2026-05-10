import 'dart:convert';

import 'package:dio/dio.dart';

import 'feishu_monitor_shell_models.dart';

class FeishuMonitorShellClient {
  FeishuMonitorShellClient({
    Dio? dio,
    String? baseUrl,
    String? token,
  }) : _dio = dio ?? Dio(),
       _baseUrl = (baseUrl ?? 'http://127.0.0.1:18766').trim(),
       _token = (token ?? 'wukong-feishu-shell-dev').trim();

  final Dio _dio;
  final String _baseUrl;
  final String _token;

  Options get _options => Options(
    headers: <String, String>{
      'Authorization': 'Bearer $_token',
    },
    responseType: ResponseType.plain,
  );

  Options get _streamOptions => Options(
    headers: <String, String>{
      'Authorization': 'Bearer $_token',
    },
    responseType: ResponseType.stream,
  );

  Future<FeishuMonitorShellStatus> fetchStatus() async {
    final response = await _dio.get<String>(
      '$_baseUrl/status',
      options: _options,
    );
    return FeishuMonitorShellStatus.fromJson(_readObject(response.data));
  }

  Future<FeishuMonitorShellHealth> fetchHealth() async {
    final response = await _dio.get<String>(
      '$_baseUrl/health',
      options: _options,
    );
    return FeishuMonitorShellHealth.fromJson(_readObject(response.data));
  }

  Future<void> startCapture() => _postWithoutBody('/capture/start');

  Future<void> stopCapture() => _postWithoutBody('/capture/stop');

  Future<void> reloadRuntime() => _postWithoutBody('/runtime/reload');

  Stream<FeishuMonitorShellEvent> watchEvents() async* {
    final response = await _dio.get<ResponseBody>(
      '$_baseUrl/events',
      options: _streamOptions,
    );
    final stream = response.data?.stream;
    if (stream == null) {
      return;
    }

    var eventName = '';
    final dataLines = <String>[];
    final lines = stream.cast<List<int>>()
        .transform(utf8.decoder)
        .transform(const LineSplitter());

    await for (final line in lines) {
      if (line.isEmpty) {
        final event = _readSseEvent(eventName, dataLines);
        if (event != null) {
          yield event;
        }
        eventName = '';
        dataLines.clear();
        continue;
      }
      if (line.startsWith(':')) {
        continue;
      }
      if (line.startsWith('event:')) {
        eventName = line.substring('event:'.length).trim();
        continue;
      }
      if (line.startsWith('data:')) {
        dataLines.add(line.substring('data:'.length).trimLeft());
      }
    }

    final event = _readSseEvent(eventName, dataLines);
    if (event != null) {
      yield event;
    }
  }

  Future<void> _postWithoutBody(String path) async {
    await _dio.post<String>(
      '$_baseUrl$path',
      options: _options,
    );
  }

  Map<String, dynamic> _readObject(String? raw) {
    final normalized = raw?.trim() ?? '';
    if (normalized.isEmpty) {
      return const <String, dynamic>{};
    }
    final decoded = jsonDecode(normalized);
    if (decoded is Map<String, dynamic>) {
      return decoded;
    }
    if (decoded is Map) {
      return Map<String, dynamic>.from(decoded);
    }
    return const <String, dynamic>{};
  }

  FeishuMonitorShellEvent? _readSseEvent(
    String eventName,
    List<String> dataLines,
  ) {
    if (dataLines.isEmpty) {
      return null;
    }
    final raw = dataLines.join('\n').trim();
    if (raw.isEmpty) {
      return null;
    }

    Object? decoded;
    try {
      decoded = jsonDecode(raw);
    } on FormatException {
      return null;
    }
    if (decoded is! Map) {
      return null;
    }

    final json = Map<String, dynamic>.from(decoded);
    if ((json['type']?.toString().trim() ?? '').isEmpty &&
        eventName.isNotEmpty) {
      json['type'] = eventName;
    }
    return FeishuMonitorShellEvent.fromJson(json);
  }
}
