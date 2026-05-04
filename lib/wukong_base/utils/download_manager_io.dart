import 'dart:async';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
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

/// Download manager
class DownloadManager {
  static final DownloadManager _instance = DownloadManager._internal();
  factory DownloadManager() => _instance;
  DownloadManager._internal();

  final Dio _dio = Dio();
  final Map<String, CancelToken> _cancelTokens = {};
  final Map<String, DownloadTask> _tasks = {};

  // Stream controller for download updates
  final _downloadController = StreamController<DownloadUpdate>.broadcast();
  Stream<DownloadUpdate> get downloadStream => _downloadController.stream;

  // Maximum concurrent downloads
  static const int maxConcurrentDownloads = 3;
  int _activeDownloads = 0;

  /// Get download task by ID
  DownloadTask? getTask(String id) => _tasks[id];

  /// Get all tasks
  List<DownloadTask> getAllTasks() => _tasks.values.toList();

  /// Get task by file URL
  DownloadTask? getTaskByUrl(String url) {
    for (final task in _tasks.values) {
      if (task.url == url) {
        return task;
      }
    }
    return null;
  }

  /// Download file
  Future<DownloadResult> download({
    required String url,
    required String fileName,
    String? savePath,
    Map<String, dynamic>? headers,
    Function(int, int)? onProgress,
  }) async {
    final id = _generateId();
    final safeFileName = safeDownloadFileName(fileName);

    // Determine save path
    final customDirectory = savePath?.trim();
    final directory = customDirectory?.isNotEmpty == true
        ? customDirectory!
        : await _getDownloadDirectory();
    await Directory(directory).create(recursive: true);
    final filePath = path.join(directory, safeFileName);

    // Create task
    var task = DownloadTask(
      id: id,
      url: url,
      fileName: safeFileName,
      savePath: filePath,
    );

    _tasks[id] = task;
    _notifyUpdate(task);

    // Check concurrent limit
    if (_activeDownloads >= maxConcurrentDownloads) {
      task = task.copyWith(status: DownloadStatus.pending);
      _tasks[id] = task;
      _notifyUpdate(task);

      // Wait for a slot
      await _waitForSlot();
    }

    _activeDownloads++;
    task = task.copyWith(status: DownloadStatus.downloading);
    _tasks[id] = task;
    _notifyUpdate(task);

    // Create cancel token
    final cancelToken = CancelToken();
    _cancelTokens[id] = cancelToken;

    try {
      await _dio.download(
        url,
        filePath,
        cancelToken: cancelToken,
        options: Options(headers: headers),
        onReceiveProgress: (received, total) {
          if (total > 0) {
            task = task.copyWith(downloadedBytes: received, totalBytes: total);
            _tasks[id] = task;
            _notifyUpdate(task);
            onProgress?.call(received, total);
          }
        },
      );

      // Get file size
      final file = File(filePath);
      final fileSize = await file.length();

      task = task.copyWith(
        status: DownloadStatus.completed,
        downloadedBytes: fileSize,
        totalBytes: fileSize,
      );
      _tasks[id] = task;
      _notifyUpdate(task);

      _activeDownloads--;
      _cancelTokens.remove(id);

      return DownloadResult(filePath: filePath, fileSize: fileSize);
    } on DioException catch (e) {
      _activeDownloads--;
      _cancelTokens.remove(id);

      if (e.type == DioExceptionType.cancel) {
        // Cancelled by user
        task = task.copyWith(status: DownloadStatus.failed, error: 'Cancelled');
      } else {
        task = task.copyWith(status: DownloadStatus.failed, error: e.message);
      }
      _tasks[id] = task;
      _notifyUpdate(task);

      return DownloadResult(filePath: filePath, fileSize: 0, error: e.message);
    } catch (e) {
      _activeDownloads--;
      _cancelTokens.remove(id);

      task = task.copyWith(status: DownloadStatus.failed, error: e.toString());
      _tasks[id] = task;
      _notifyUpdate(task);

      return DownloadResult(
        filePath: filePath,
        fileSize: 0,
        error: e.toString(),
      );
    }
  }

  /// Download image
  Future<String?> downloadImage(String url, {String? savePath}) async {
    final fileName = downloadFileNameFromUrl(url);
    final result = await download(
      url: url,
      fileName: fileName,
      savePath: savePath,
    );
    return result.isSuccess ? result.filePath : null;
  }

  /// Download file with custom save path
  Future<DownloadResult> downloadTo({
    required String url,
    required String savePath,
    Map<String, dynamic>? headers,
    Function(int, int)? onProgress,
  }) async {
    final fileName = safeDownloadFileName(path.basename(savePath));
    return download(
      url: url,
      fileName: fileName,
      savePath: path.dirname(savePath),
      headers: headers,
      onProgress: onProgress,
    );
  }

  /// Pause download
  void pause(String id) {
    final cancelToken = _cancelTokens[id];
    if (cancelToken != null) {
      cancelToken.cancel('Paused');
      _cancelTokens.remove(id);

      final task = _tasks[id];
      if (task != null) {
        _tasks[id] = task.copyWith(status: DownloadStatus.paused);
        _notifyUpdate(_tasks[id]!);
      }

      _activeDownloads--;
    }
  }

  /// Resume download
  Future<DownloadResult> resume(String id) async {
    final task = _tasks[id];
    if (task == null) {
      return DownloadResult(filePath: '', fileSize: 0, error: 'Task not found');
    }

    // Re-download with resume support
    return download(
      url: task.url,
      fileName: task.fileName,
      savePath: path.dirname(task.savePath ?? ''),
    );
  }

  /// Cancel download
  void cancel(String id) {
    final cancelToken = _cancelTokens[id];
    if (cancelToken != null) {
      cancelToken.cancel();
      _cancelTokens.remove(id);
    }

    _tasks.remove(id);
    _activeDownloads--;
  }

  /// Cancel all downloads
  void cancelAll() {
    for (final id in _cancelTokens.keys.toList()) {
      cancel(id);
    }
  }

  /// Pause all downloads
  void pauseAll() {
    for (final id in _cancelTokens.keys.toList()) {
      pause(id);
    }
  }

  /// Delete downloaded file
  Future<void> deleteFile(String filePath) async {
    final file = File(filePath);
    if (await file.exists()) {
      await file.delete();
    }
  }

  /// Clear completed downloads
  void clearCompleted() {
    _tasks.removeWhere((_, task) => task.status == DownloadStatus.completed);
  }

  /// Clear failed downloads
  void clearFailed() {
    _tasks.removeWhere((_, task) => task.status == DownloadStatus.failed);
  }

  Future<String> _getDownloadDirectory() async {
    final dir = await getApplicationDocumentsDirectory();
    final downloadDir = Directory(path.join(dir.path, 'downloads'));
    if (!await downloadDir.exists()) {
      await downloadDir.create(recursive: true);
    }
    return downloadDir.path;
  }

  Future<void> _waitForSlot() async {
    while (_activeDownloads >= maxConcurrentDownloads) {
      await Future.delayed(const Duration(milliseconds: 100));
    }
  }

  String _generateId() {
    return DateTime.now().millisecondsSinceEpoch.toString();
  }

  void _notifyUpdate(DownloadTask task) {
    _downloadController.add(DownloadUpdate(taskId: task.id, task: task));
  }

  void dispose() {
    cancelAll();
    _downloadController.close();
    _dio.close();
  }
}

/// Download update event
class DownloadUpdate {
  final String taskId;
  final DownloadTask task;

  DownloadUpdate({required this.taskId, required this.task});
}
