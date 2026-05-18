import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:wukong_im_app/data/models/wk_custom_content.dart';
import 'package:wukongimfluttersdk/entity/msg.dart';
import 'package:wukongimfluttersdk/model/wk_media_message_content.dart';
import 'package:wukongimfluttersdk/model/wk_video_content.dart';

import '../api/file_api.dart';
import 'coordinators/attachment_pipeline.dart';
import 'local_attachment_file.dart';

typedef LegacyAttachmentUploader = Future<bool> Function(WKMsg message);
typedef ChatFileUploader =
    Future<String> Function({
      required String filePath,
      required String channelId,
      required int channelType,
    });
typedef LocalAttachmentFileExists = Future<bool> Function(String filePath);
typedef LocalAttachmentFileLength = Future<int?> Function(String filePath);

enum AttachmentUploadJobState { queued, uploading, uploaded, failed, cancelled }

@immutable
class AttachmentUploadJob {
  const AttachmentUploadJob({
    required this.clientMsgNo,
    required this.channelId,
    required this.channelType,
    required this.localPath,
    this.contentType = 0,
    this.metadata = const <String, Object?>{},
  });

  final String clientMsgNo;
  final String channelId;
  final int channelType;
  final String localPath;
  final int contentType;
  final Map<String, Object?> metadata;
}

@immutable
class AttachmentUploadEvent {
  const AttachmentUploadEvent({
    required this.job,
    required this.state,
    this.remoteUrl = '',
    this.error,
  });

  final AttachmentUploadJob job;
  final AttachmentUploadJobState state;
  final String remoteUrl;
  final Object? error;
}

class AttachmentUploadPipeline {
  AttachmentUploadPipeline({
    this.fileApi,
    this.legacyUploader,
    ChatFileUploader? chatFileUploader,
    LocalAttachmentFileExists? fileExists,
    LocalAttachmentFileLength? fileLength,
    this.metadataNormalizer = const AttachmentPipeline(),
    this.maxConcurrentUploads = 2,
  }) : _chatFileUploader = chatFileUploader,
       _fileExists = fileExists ?? localAttachmentFileExists,
       _fileLength = fileLength ?? localAttachmentFileLength;

  final FileApi? fileApi;
  final LegacyAttachmentUploader? legacyUploader;
  final ChatFileUploader? _chatFileUploader;
  final LocalAttachmentFileExists _fileExists;
  final LocalAttachmentFileLength _fileLength;
  final AttachmentPipeline metadataNormalizer;
  final int maxConcurrentUploads;
  final StreamController<AttachmentUploadEvent> _eventsController =
      StreamController<AttachmentUploadEvent>.broadcast();
  final List<AttachmentUploadJob> _queue = <AttachmentUploadJob>[];
  final Set<String> _cancelledClientMsgNos = <String>{};
  final Set<String> _inFlightClientMsgNos = <String>{};
  Completer<void>? _drainCompleter;

  Stream<AttachmentUploadEvent> get events {
    return _eventsController.stream;
  }

  Future<void> enqueue(AttachmentUploadJob job) {
    _cancelledClientMsgNos.remove(job.clientMsgNo);
    _queue.add(job);
    _emit(job, AttachmentUploadJobState.queued);
    _pumpQueue();
    return Future<void>.value();
  }

  Future<void> cancel(String clientMsgNo) {
    final normalizedClientMsgNo = clientMsgNo.trim();
    if (normalizedClientMsgNo.isEmpty) {
      return Future<void>.value();
    }
    _cancelledClientMsgNos.add(normalizedClientMsgNo);
    final index = _queue.indexWhere(
      (job) => job.clientMsgNo == normalizedClientMsgNo,
    );
    if (index >= 0) {
      final job = _queue.removeAt(index);
      _emit(job, AttachmentUploadJobState.cancelled);
      _completeDrainIfIdle();
    }
    return Future<void>.value();
  }

  Future<bool> uploadMessageAttachments(WKMsg message) {
    final uploader = legacyUploader;
    if (uploader == null) {
      return _uploadMessageAttachments(message);
    }
    return uploader(message);
  }

  Future<String> uploadLocalFile({
    required String filePath,
    required String channelId,
    required int channelType,
  }) {
    final uploader = _chatFileUploader;
    if (uploader != null) {
      return uploader(
        filePath: filePath,
        channelId: channelId,
        channelType: channelType,
      );
    }
    final api = fileApi;
    if (api == null) {
      return Future<String>.value('');
    }
    return api.uploadChatFile(
      filePath: filePath,
      channelId: channelId,
      channelType: channelType,
    );
  }

  Future<void> drain() {
    if (_queue.isEmpty && _inFlightClientMsgNos.isEmpty) {
      return Future<void>.value();
    }
    return (_drainCompleter ??= Completer<void>()).future;
  }

  void _pumpQueue() {
    final limit = maxConcurrentUploads <= 0 ? 1 : maxConcurrentUploads;
    while (_inFlightClientMsgNos.length < limit && _queue.isNotEmpty) {
      final job = _queue.removeAt(0);
      if (_cancelledClientMsgNos.remove(job.clientMsgNo)) {
        _emit(job, AttachmentUploadJobState.cancelled);
        continue;
      }
      _inFlightClientMsgNos.add(job.clientMsgNo);
      unawaited(_runQueuedJob(job));
    }
    _completeDrainIfIdle();
  }

  Future<void> _runQueuedJob(AttachmentUploadJob job) async {
    _emit(job, AttachmentUploadJobState.uploading);
    try {
      if (!await _fileExists(job.localPath)) {
        _emit(job, AttachmentUploadJobState.failed);
        return;
      }
      final remoteUrl = await uploadLocalFile(
        filePath: job.localPath,
        channelId: job.channelId,
        channelType: job.channelType,
      );
      if (remoteUrl.trim().isEmpty) {
        _emit(job, AttachmentUploadJobState.failed);
        return;
      }
      _emit(job, AttachmentUploadJobState.uploaded, remoteUrl: remoteUrl);
    } catch (error) {
      _emit(job, AttachmentUploadJobState.failed, error: error);
    } finally {
      _inFlightClientMsgNos.remove(job.clientMsgNo);
      _pumpQueue();
    }
  }

  void _emit(
    AttachmentUploadJob job,
    AttachmentUploadJobState state, {
    String remoteUrl = '',
    Object? error,
  }) {
    _eventsController.add(
      AttachmentUploadEvent(
        job: job,
        state: state,
        remoteUrl: remoteUrl,
        error: error,
      ),
    );
  }

  void _completeDrainIfIdle() {
    if (_queue.isNotEmpty || _inFlightClientMsgNos.isNotEmpty) {
      return;
    }
    final completer = _drainCompleter;
    if (completer != null && !completer.isCompleted) {
      completer.complete();
    }
    _drainCompleter = null;
  }

  Future<bool> _uploadMessageAttachments(WKMsg message) async {
    final content = message.messageContent;
    if (content == null) {
      return false;
    }

    if (content is WKVideoContent) {
      final uploadedVideo = await _ensureMediaContentUploaded(content, message);
      if (!uploadedVideo) {
        return false;
      }
      if (content.cover.trim().isEmpty) {
        final coverLocalPath = content.coverLocalPath.trim();
        if (coverLocalPath.isNotEmpty) {
          if (!await _fileExists(coverLocalPath)) {
            return false;
          }
          content.cover = await uploadLocalFile(
            filePath: coverLocalPath,
            channelId: message.channelID,
            channelType: message.channelType,
          );
        }
      }
      message.messageContent = content;
      return content.url.trim().isNotEmpty;
    }

    if (content is WKFileContent) {
      final uploaded = await _ensureFileContentUploaded(content, message);
      message.messageContent = content;
      return uploaded;
    }

    if (content is WKMediaMessageContent) {
      final uploaded = await _ensureMediaContentUploaded(content, message);
      message.messageContent = content;
      return uploaded;
    }

    return true;
  }

  Future<bool> _ensureMediaContentUploaded(
    WKMediaMessageContent content,
    WKMsg message,
  ) async {
    if (content.url.trim().isNotEmpty) {
      return true;
    }

    final localPath = content.localPath.trim();
    if (localPath.isEmpty) {
      return false;
    }
    if (!await _fileExists(localPath)) {
      return false;
    }

    final uploadedUrl = await uploadLocalFile(
      filePath: localPath,
      channelId: message.channelID,
      channelType: message.channelType,
    );
    content.url = uploadedUrl;
    return uploadedUrl.trim().isNotEmpty;
  }

  Future<bool> _ensureFileContentUploaded(
    WKFileContent content,
    WKMsg message,
  ) async {
    if (content.url.trim().isNotEmpty) {
      return true;
    }

    final localPath = content.localPath.trim();
    if (localPath.isEmpty) {
      return false;
    }
    if (!await _fileExists(localPath)) {
      return false;
    }

    final uploadedUrl = await uploadLocalFile(
      filePath: localPath,
      channelId: message.channelID,
      channelType: message.channelType,
    );
    content.url = uploadedUrl;
    metadataNormalizer.normalizeFileMetadata(
      content,
      localPath: localPath,
      inferredSize: content.size > 0
          ? content.size
          : await _fileLength(localPath),
    );
    return uploadedUrl.trim().isNotEmpty;
  }
}
