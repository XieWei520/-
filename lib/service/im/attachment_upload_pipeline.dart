import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:wukongimfluttersdk/entity/msg.dart';

import '../api/file_api.dart';
import 'coordinators/attachment_pipeline.dart';

typedef LegacyAttachmentUploader = Future<bool> Function(WKMsg message);

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
    this.metadataNormalizer = const AttachmentPipeline(),
    this.maxConcurrentUploads = 2,
  });

  final FileApi? fileApi;
  final LegacyAttachmentUploader? legacyUploader;
  final AttachmentPipeline metadataNormalizer;
  final int maxConcurrentUploads;

  Stream<AttachmentUploadEvent> get events {
    throw UnimplementedError('Skeleton only: expose upload event stream here.');
  }

  Future<void> enqueue(AttachmentUploadJob job) {
    throw UnimplementedError(
      'Skeleton only: add durable attachment queueing here.',
    );
  }

  Future<void> cancel(String clientMsgNo) {
    throw UnimplementedError('Skeleton only: cancel queued upload here.');
  }

  Future<bool> uploadMessageAttachments(WKMsg message) {
    final uploader = legacyUploader;
    if (uploader == null) {
      return Future<bool>.value(false);
    }
    return uploader(message);
  }

  Future<String> uploadLocalFile({
    required String filePath,
    required String channelId,
    required int channelType,
  }) {
    throw UnimplementedError(
      'Skeleton only: centralize FileApi upload and retry policy here.',
    );
  }

  Future<void> drain() {
    throw UnimplementedError(
      'Skeleton only: wait until in-flight uploads finish here.',
    );
  }
}
