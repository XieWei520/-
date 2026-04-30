import 'dart:async';

import 'package:path/path.dart' as path;

import 'download_file_naming.dart';

/// Download status enum
enum DownloadStatus { pending, downloading, paused, completed, failed }

/// Download task model
class DownloadTask {
  final String id;
  final String url;
  final String fileName;
  final String? savePath;
  final int totalBytes;
  final int downloadedBytes;
  final DownloadStatus status;
  final String? error;
  final int createTime;

  DownloadTask({
    required this.id,
    required this.url,
    required this.fileName,
    this.savePath,
    this.totalBytes = 0,
    this.downloadedBytes = 0,
    this.status = DownloadStatus.pending,
    this.error,
    int? createTime,
  }) : createTime = createTime ?? DateTime.now().millisecondsSinceEpoch ~/ 1000;

  double get progress => totalBytes > 0 ? downloadedBytes / totalBytes : 0;

  String get progressText {
    if (totalBytes > 0) {
      return '${_formatBytes(downloadedBytes)} / ${_formatBytes(totalBytes)}';
    }
    return _formatBytes(downloadedBytes);
  }

  static String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  DownloadTask copyWith({
    String? id,
    String? url,
    String? fileName,
    String? savePath,
    int? totalBytes,
    int? downloadedBytes,
    DownloadStatus? status,
    String? error,
    int? createTime,
  }) {
    return DownloadTask(
      id: id ?? this.id,
      url: url ?? this.url,
      fileName: fileName ?? this.fileName,
      savePath: savePath ?? this.savePath,
      totalBytes: totalBytes ?? this.totalBytes,
      downloadedBytes: downloadedBytes ?? this.downloadedBytes,
      status: status ?? this.status,
      error: error ?? this.error,
      createTime: createTime ?? this.createTime,
    );
  }
}

/// Download result
class DownloadResult {
  final String filePath;
  final int fileSize;
  final String? error;

  DownloadResult({required this.filePath, required this.fileSize, this.error});

  bool get isSuccess => error == null && filePath.isNotEmpty;
}

/// Web-safe download manager stub.
class DownloadManager {
  static final DownloadManager _instance = DownloadManager._internal();
  factory DownloadManager() => _instance;
  DownloadManager._internal();

  static const int maxConcurrentDownloads = 3;

  final Map<String, DownloadTask> _tasks = {};
  final _downloadController = StreamController<DownloadUpdate>.broadcast();

  Stream<DownloadUpdate> get downloadStream => _downloadController.stream;

  DownloadTask? getTask(String id) => _tasks[id];

  List<DownloadTask> getAllTasks() => _tasks.values.toList();

  DownloadTask? getTaskByUrl(String url) {
    for (final task in _tasks.values) {
      if (task.url == url) {
        return task;
      }
    }
    return null;
  }

  Future<DownloadResult> download({
    required String url,
    required String fileName,
    String? savePath,
    Map<String, dynamic>? headers,
    Function(int, int)? onProgress,
  }) async {
    final safeFileName = safeDownloadFileName(fileName);
    final id = DateTime.now().millisecondsSinceEpoch.toString();
    final task = DownloadTask(
      id: id,
      url: url,
      fileName: safeFileName,
      savePath: savePath == null
          ? safeFileName
          : path.join(savePath, safeFileName),
      status: DownloadStatus.failed,
      error: '当前平台不支持保存下载文件',
    );
    _tasks[id] = task;
    _notifyUpdate(task);
    return DownloadResult(filePath: '', fileSize: 0, error: task.error);
  }

  Future<String?> downloadImage(String url, {String? savePath}) async {
    final fileName = downloadFileNameFromUrl(url);
    final result = await download(
      url: url,
      fileName: fileName,
      savePath: savePath,
    );
    return result.isSuccess ? result.filePath : null;
  }

  Future<DownloadResult> downloadTo({
    required String url,
    required String savePath,
    Map<String, dynamic>? headers,
    Function(int, int)? onProgress,
  }) {
    return download(
      url: url,
      fileName: safeDownloadFileName(path.basename(savePath)),
      savePath: path.dirname(savePath),
      headers: headers,
      onProgress: onProgress,
    );
  }

  void pause(String id) {}

  Future<DownloadResult> resume(String id) async {
    return DownloadResult(filePath: '', fileSize: 0, error: 'Task not found');
  }

  void cancel(String id) {
    _tasks.remove(id);
  }

  void cancelAll() {
    _tasks.clear();
  }

  void pauseAll() {}

  Future<void> deleteFile(String filePath) async {}

  void clearCompleted() {
    _tasks.removeWhere((_, task) => task.status == DownloadStatus.completed);
  }

  void clearFailed() {
    _tasks.removeWhere((_, task) => task.status == DownloadStatus.failed);
  }

  void _notifyUpdate(DownloadTask task) {
    _downloadController.add(DownloadUpdate(taskId: task.id, task: task));
  }

  void dispose() {
    _downloadController.close();
  }
}

/// Download update event
class DownloadUpdate {
  final String taskId;
  final DownloadTask task;

  DownloadUpdate({required this.taskId, required this.task});
}
