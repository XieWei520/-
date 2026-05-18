import 'dart:convert';

import 'package:dio/dio.dart';

import 'local_monitor_shell_models.dart';

class LocalMonitorRoutingSource {
  const LocalMonitorRoutingSource({
    required this.conversationId,
    required this.conversationName,
  });

  final String conversationId;
  final String conversationName;

  bool get isEmpty =>
      conversationId.trim().isEmpty && conversationName.trim().isEmpty;

  String get key => '${conversationId.trim()}\n${conversationName.trim()}';

  Map<String, String> toJson() {
    return <String, String>{
      'conversation_id': conversationId.trim(),
      'conversation_name': conversationName.trim(),
    };
  }
}

class LocalMonitorShellClient {
  LocalMonitorShellClient({
    Dio? dio,
    required String baseUrl,
    required String token,
  }) : _dio = dio ?? Dio(),
       _baseUrl = baseUrl.trim(),
       _token = token.trim();

  final Dio _dio;
  final String _baseUrl;
  final String _token;

  Options get _options => Options(
    headers: <String, String>{'Authorization': 'Bearer $_token'},
    responseType: ResponseType.plain,
  );

  Options get _streamOptions => Options(
    headers: <String, String>{'Authorization': 'Bearer $_token'},
    responseType: ResponseType.stream,
  );

  Future<LocalMonitorShellStatus> fetchStatus() async {
    final response = await _dio.get<String>(
      '$_baseUrl/status',
      options: _options,
    );
    return LocalMonitorShellStatus.fromJson(
      readLocalMonitorJsonObject(response.data),
    );
  }

  Future<LocalMonitorShellHealth> fetchHealth() async {
    final response = await _dio.get<String>(
      '$_baseUrl/health',
      options: _options,
    );
    return LocalMonitorShellHealth.fromJson(
      readLocalMonitorJsonObject(response.data),
    );
  }

  Future<void> startCapture() => _postWithoutBody('/capture/start');

  Future<void> stopCapture() => _postWithoutBody('/capture/stop');

  Future<void> reloadRuntime() => _postWithoutBody('/runtime/reload');

  Future<void> syncConfiguredSources(
    Iterable<LocalMonitorRoutingSource> sources,
  ) async {
    final payload = <Map<String, String>>[];
    final seen = <String>{};
    for (final source in sources) {
      if (source.isEmpty || !seen.add(source.key)) {
        continue;
      }
      payload.add(source.toJson());
    }
    await _dio.post<String>(
      '$_baseUrl/routing/sources',
      data: jsonEncode(<String, Object>{'sources': payload}),
      options: _options,
    );
  }

  Stream<LocalMonitorShellEvent> watchEvents() async* {
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
    final lines = stream
        .cast<List<int>>()
        .transform(utf8.decoder)
        .transform(const LineSplitter());

    await for (final line in lines) {
      if (line.isEmpty) {
        final event = readLocalMonitorSseEvent(eventName, dataLines);
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

    final event = readLocalMonitorSseEvent(eventName, dataLines);
    if (event != null) {
      yield event;
    }
  }

  Future<void> _postWithoutBody(String path) async {
    await _dio.post<String>('$_baseUrl$path', options: _options);
  }
}

Map<String, dynamic> readLocalMonitorJsonObject(String? raw) {
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

LocalMonitorShellEvent? readLocalMonitorSseEvent(
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
  if ((json['type']?.toString().trim() ?? '').isEmpty && eventName.isNotEmpty) {
    json['type'] = eventName;
  }
  return LocalMonitorShellEvent.fromJson(json);
}
