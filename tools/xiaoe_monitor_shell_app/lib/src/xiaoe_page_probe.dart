import 'package:local_monitor_shell_core/local_monitor_shell_core.dart';

const String xiaoePageProbeScript = r'''
(() => {
  const observedAt = new Date().toISOString();
  const href = window.location?.href || '';
  const title = document.title || '';
  const bodyText = document.body?.innerText || '';
  const stableHash = (value) => {
    let hash = 0x811c9dc5;
    const text = String(value || '');
    for (let index = 0; index < text.length; index += 1) {
      hash ^= text.charCodeAt(index);
      hash = Math.imul(hash, 0x01000193);
    }
    return (hash >>> 0).toString(16);
  };
  const compact = (value, max = 300) => {
    const text = String(value || '').replace(/\s+/g, ' ').trim();
    return text.length > max ? text.slice(0, max) : text;
  };
  const sourceType = (() => {
    const lower = `${href} ${title} ${bodyText.slice(0, 1000)}`.toLowerCase();
    if (lower.includes('live') || lower.includes('直播')) return 'live';
    if (lower.includes('circle') || lower.includes('圈子')) return 'circle';
    if (lower.includes('course') || lower.includes('课程') || lower.includes('互动')) return 'course';
    return '';
  })();
  const sourceName = (() => {
    const heading = document.querySelector('h1,h2,[class*="title"],[class*="Title"]');
    return compact(heading?.innerText || title || '小鹅通页面', 80);
  })();
  const source = {
    id: sourceType ? `${sourceType}:${stableHash(href || sourceName)}` : '',
    name: sourceName,
    type: sourceType
  };
  const imageFromNode = (img) => {
    const sourceUrl =
      img.currentSrc ||
      img.src ||
      img.getAttribute('data-src') ||
      img.getAttribute('data-original') ||
      img.getAttribute('data-url') ||
      '';
    if (!sourceUrl) return null;
    const context = `${img.className || ''} ${img.parentElement?.className || ''}`.toLowerCase();
    if (context.includes('avatar') || sourceUrl.toLowerCase().includes('avatar')) return null;
    return {
      source_url: sourceUrl,
      local_path: '',
      width: Number(img.naturalWidth || img.width || 0),
      height: Number(img.naturalHeight || img.height || 0)
    };
  };
  const fileFromNode = (node) => {
    const hrefValue = node.href || node.getAttribute?.('href') || node.getAttribute?.('data-url') || '';
    const text = compact(node.innerText || node.textContent || node.getAttribute?.('download') || '', 120);
    const lower = `${hrefValue} ${text}`.toLowerCase();
    const looksFile =
      /\.(pdf|doc|docx|xls|xlsx|ppt|pptx|zip|rar|txt)(?:\?|$)/i.test(hrefValue) ||
      lower.includes('下载') ||
      lower.includes('附件') ||
      lower.includes('文件');
    if (!looksFile || !hrefValue) return null;
    return {
      source_url: hrefValue,
      local_path: '',
      file_name: text || hrefValue.split('/').pop() || 'xiaoe-file',
      mime_type: '',
      size_bytes: 0
    };
  };
  const collectImages = (node) => {
    const seen = new Set();
    const images = [];
    for (const img of Array.from(node.querySelectorAll('img')).slice(0, 6)) {
      const image = imageFromNode(img);
      if (!image || seen.has(image.source_url)) continue;
      seen.add(image.source_url);
      images.push(image);
    }
    return images;
  };
  const collectFiles = (node) => {
    const seen = new Set();
    const files = [];
    for (const item of Array.from(node.querySelectorAll('a,[data-url],[class*="file"],[class*="File"]')).slice(0, 8)) {
      const file = fileFromNode(item);
      if (!file || seen.has(file.source_url)) continue;
      seen.add(file.source_url);
      files.push(file);
    }
    return files;
  };
  const selectors = [
    '[data-comment-id]',
    '[data-message-id]',
    '[class*="comment"]',
    '[class*="Comment"]',
    '[class*="interaction"]',
    '[class*="message"]',
    '[role="listitem"]'
  ];
  const selectorHits = [];
  const candidates = [];
  const seen = new Set();
  for (const selector of selectors) {
    const nodes = Array.from(document.querySelectorAll(selector));
    selectorHits.push({ selector, count: nodes.length });
    for (const node of nodes) {
      const text = compact(node.innerText || node.textContent || '', 800);
      const images = collectImages(node);
      const files = collectFiles(node);
      if (!text && images.length === 0 && files.length === 0) continue;
      if (text.length > 1200 || (node.children?.length || 0) > 120) continue;
      const id =
        node.getAttribute('data-comment-id') ||
        node.getAttribute('data-message-id') ||
        node.getAttribute('data-id') ||
        `dom:${stableHash(`${source.id}:${text}:${images.map((x) => x.source_url).join('|')}:${files.map((x) => x.source_url).join('|')}`)}`;
      if (seen.has(id)) continue;
      seen.add(id);
      candidates.push({
        id,
        sender_name: compact(node.querySelector('[class*="name"],[class*="author"],[class*="user"]')?.innerText || '', 80),
        text: text || (files.length > 0 ? '[文件]' : images.length > 0 ? '[图片]' : ''),
        sent_at: '',
        image_attachments: images,
        file_attachments: files
      });
      if (candidates.length >= 80) break;
    }
    if (candidates.length >= 80) break;
  }
  return {
    runtime_url: href,
    page_title: title,
    body_text: bodyText.slice(0, 2000),
    observed_at: observedAt,
    source,
    comment_candidates: candidates,
    probe_diagnostics: {
      selector_hits: selectorHits,
      visible_candidate_count: candidates.length,
      latest_candidate_text: candidates.length ? candidates[candidates.length - 1].text : ''
    }
  };
})();
''';

enum XiaoePageKind {
  login('login'),
  mutiIndex('muti_index'),
  live('live'),
  circle('circle'),
  course('course'),
  unknown('unknown');

  const XiaoePageKind(this.wireName);

  final String wireName;
}

class XiaoePageProbe {
  const XiaoePageProbe({
    required this.runtimeUrl,
    required this.pageTitle,
    required this.pageKind,
    required this.observedAt,
    required this.source,
    required this.commentCandidates,
    required this.probeDiagnostics,
    this.bodyText = '',
  });

  final String runtimeUrl;
  final String pageTitle;
  final String bodyText;
  final XiaoePageKind pageKind;
  final DateTime observedAt;
  final XiaoeProbeSource source;
  final List<XiaoeCommentCandidate> commentCandidates;
  final Map<String, dynamic> probeDiagnostics;

  factory XiaoePageProbe.fromScriptResult(Map<String, Object?> json) {
    final runtimeUrl = (json['runtime_url'] ?? '').toString();
    final pageTitle = (json['page_title'] ?? '').toString();
    final bodyText = (json['body_text'] ?? '').toString();
    final source = XiaoeProbeSource.fromJson(_object(json['source']));
    final observedAt =
        DateTime.tryParse((json['observed_at'] ?? '').toString()) ??
        DateTime.now().toUtc();
    final comments = _readCommentCandidates(json['comment_candidates']);
    final ignoredCount = _ignoredCandidateCount(comments, source);
    final diagnostics = <String, dynamic>{
      ..._object(json['probe_diagnostics']),
      'comment_candidate_count': comments.length,
      'ignored_candidate_count': ignoredCount,
    };
    return XiaoePageProbe(
      runtimeUrl: runtimeUrl,
      pageTitle: pageTitle,
      bodyText: bodyText,
      pageKind: deriveXiaoePageKind(
        runtimeUrl: runtimeUrl,
        pageTitle: pageTitle,
        bodyText: bodyText,
        source: source,
        hasCandidates: comments.isNotEmpty,
      ),
      observedAt: observedAt,
      source: source,
      commentCandidates: comments,
      probeDiagnostics: Map<String, dynamic>.unmodifiable(diagnostics),
    );
  }
}

class XiaoeProbeSource {
  const XiaoeProbeSource({
    required this.id,
    required this.name,
    required this.type,
  });

  final String id;
  final String name;
  final String type;

  factory XiaoeProbeSource.fromJson(Map<String, dynamic> json) {
    return XiaoeProbeSource(
      id: (json['id'] ?? '').toString().trim(),
      name: (json['name'] ?? '').toString().trim(),
      type: (json['type'] ?? '').toString().trim(),
    );
  }
}

class XiaoeCommentCandidate {
  const XiaoeCommentCandidate({
    required this.id,
    required this.senderName,
    required this.text,
    required this.sentAt,
    required this.imageAttachments,
    required this.fileAttachments,
  });

  final String id;
  final String senderName;
  final String text;
  final String sentAt;
  final List<MessageImageAttachment> imageAttachments;
  final List<MessageFileAttachment> fileAttachments;

  bool get hasForwardableContent =>
      text.trim().isNotEmpty ||
      imageAttachments.isNotEmpty ||
      fileAttachments.isNotEmpty;

  bool isForwardableFor(XiaoeProbeSource source) {
    if (!hasForwardableContent) {
      return false;
    }
    if (source.id.trim().isEmpty && source.name.trim().isEmpty) {
      return false;
    }
    if (isNoisyXiaoeUiText(text)) {
      return false;
    }
    return true;
  }

  factory XiaoeCommentCandidate.fromJson(Map<String, dynamic> json) {
    return XiaoeCommentCandidate(
      id: (json['id'] ?? '').toString().trim(),
      senderName: (json['sender_name'] ?? json['senderName'] ?? '')
          .toString()
          .trim(),
      text: (json['text'] ?? '').toString().trim(),
      sentAt: (json['sent_at'] ?? json['sentAt'] ?? '').toString().trim(),
      imageAttachments: MessageImageAttachment.listFromJson(
        json['image_attachments'] ?? json['imageAttachments'],
      ),
      fileAttachments: MessageFileAttachment.listFromJson(
        json['file_attachments'] ?? json['fileAttachments'],
      ),
    );
  }
}

XiaoePageKind deriveXiaoePageKind({
  required String runtimeUrl,
  required String pageTitle,
  required String bodyText,
  required XiaoeProbeSource source,
  required bool hasCandidates,
}) {
  final url = runtimeUrl.trim().toLowerCase();
  final title = pageTitle.trim().toLowerCase();
  final body = bodyText.trim().toLowerCase();
  final sourceType = source.type.trim().toLowerCase();
  if (url.contains('login') ||
      url.contains('passport') ||
      body.contains('扫码') ||
      body.contains('登录')) {
    return XiaoePageKind.login;
  }
  if (url.contains('muti_index')) {
    return XiaoePageKind.mutiIndex;
  }
  if (sourceType == 'live' || url.contains('live') || title.contains('直播')) {
    return XiaoePageKind.live;
  }
  if (sourceType == 'circle' ||
      url.contains('circle') ||
      title.contains('圈子')) {
    return XiaoePageKind.circle;
  }
  if (sourceType == 'course' ||
      url.contains('course') ||
      title.contains('课程')) {
    return XiaoePageKind.course;
  }
  if (hasCandidates) {
    return XiaoePageKind.unknown;
  }
  return XiaoePageKind.unknown;
}

List<NormalizedMessageEvent> normalizeXiaoeProbeEvents(XiaoePageProbe probe) {
  final source = probe.source;
  if (source.id.trim().isEmpty && source.name.trim().isEmpty) {
    return const <NormalizedMessageEvent>[];
  }
  final byKey = <String, NormalizedMessageEvent>{};
  for (final candidate in probe.commentCandidates) {
    if (!_isForwardableCandidate(candidate, source)) {
      continue;
    }
    final messageId = _messageIdFor(candidate);
    final sourceId = _sourceIdFor(source);
    final dedupeKey = '$sourceId:$messageId';
    final event = NormalizedMessageEvent(
      eventId: 'xiaoe:$sourceId:$messageId',
      dedupeKey: dedupeKey,
      accountId: '',
      conversationId: sourceId,
      conversationName: source.name.trim().isEmpty ? sourceId : source.name,
      conversationType: source.type.trim().isEmpty ? 'unknown' : source.type,
      messageId: messageId,
      senderId: '',
      senderName: candidate.senderName,
      messageType: _messageTypeFor(candidate),
      text: candidate.text,
      sentAt: candidate.sentAt,
      observedAt: probe.observedAt.toUtc().toIso8601String(),
      captureSource: 'xiaoe_dom_probe',
      imageAttachments: candidate.imageAttachments,
      fileAttachments: candidate.fileAttachments,
    );
    final current = byKey[dedupeKey];
    if (current == null || _compareObservedAt(event, current) >= 0) {
      byKey[dedupeKey] = event;
    }
  }
  final events = byKey.values.toList()
    ..sort((left, right) => _compareObservedAt(left, right));
  return List<NormalizedMessageEvent>.unmodifiable(events);
}

bool _isForwardableCandidate(
  XiaoeCommentCandidate candidate,
  XiaoeProbeSource source,
) {
  return candidate.isForwardableFor(source);
}

String _messageTypeFor(XiaoeCommentCandidate candidate) {
  if (candidate.fileAttachments.isNotEmpty) {
    return 'file';
  }
  if (candidate.imageAttachments.isNotEmpty) {
    return 'image';
  }
  return 'text';
}

String _sourceIdFor(XiaoeProbeSource source) {
  final id = source.id.trim();
  if (id.isNotEmpty) {
    return id;
  }
  return 'source:${_stableHash(source.name.trim())}';
}

String _messageIdFor(XiaoeCommentCandidate candidate) {
  final id = candidate.id.trim();
  if (id.isNotEmpty) {
    return id;
  }
  final source = <String>[
    candidate.senderName,
    candidate.sentAt,
    candidate.text,
    ...candidate.imageAttachments.map(_imageAttachmentStableSource),
    ...candidate.fileAttachments.map(_fileAttachmentStableSource),
  ].join(':');
  return 'dom:${_stableHash(source)}';
}

String _imageAttachmentStableSource(MessageImageAttachment image) {
  return <String>[
    image.sourceUrl,
    image.localPath,
    image.width.toString(),
    image.height.toString(),
  ].join(':');
}

String _fileAttachmentStableSource(MessageFileAttachment file) {
  return <String>[
    file.sourceUrl,
    file.localPath,
    file.fileName,
    file.sizeBytes.toString(),
  ].join(':');
}

bool isNoisyXiaoeUiText(String value) {
  final normalized = value.replaceAll(RegExp(r'\s+'), ' ').trim();
  if (normalized.isEmpty) {
    return false;
  }
  const exactNoise = <String>{'首页 课程 圈子 订单 设置', '首页 课程 圈子 直播 我的'};
  if (exactNoise.contains(normalized)) {
    return true;
  }
  final noiseTokenCount = <String>[
    '首页',
    '课程',
    '圈子',
    '订单',
    '设置',
    '我的',
  ].where(normalized.contains).length;
  return noiseTokenCount >= 4 && normalized.length <= 40;
}

List<XiaoeCommentCandidate> _readCommentCandidates(Object? value) {
  if (value is! List) {
    return const <XiaoeCommentCandidate>[];
  }
  return value
      .whereType<Map>()
      .map(
        (item) => XiaoeCommentCandidate.fromJson(
          item.map((key, itemValue) => MapEntry(key.toString(), itemValue)),
        ),
      )
      .toList(growable: false);
}

int _ignoredCandidateCount(
  List<XiaoeCommentCandidate> candidates,
  XiaoeProbeSource source,
) {
  return candidates
      .where((candidate) => !_isForwardableCandidate(candidate, source))
      .length;
}

Map<String, dynamic> _object(Object? value) {
  if (value is! Map) {
    return const <String, dynamic>{};
  }
  return Map<String, dynamic>.from(
    value.map((key, itemValue) => MapEntry(key.toString(), itemValue)),
  );
}

int _compareObservedAt(
  NormalizedMessageEvent left,
  NormalizedMessageEvent right,
) {
  final leftParsed = DateTime.tryParse(left.observedAt.trim());
  final rightParsed = DateTime.tryParse(right.observedAt.trim());
  if (leftParsed != null && rightParsed != null) {
    return leftParsed.compareTo(rightParsed);
  }
  return left.observedAt.compareTo(right.observedAt);
}

String _stableHash(String value) {
  var hash = 0x811c9dc5;
  for (final unit in value.codeUnits) {
    hash ^= unit;
    hash = (hash * 0x01000193) & 0xffffffff;
  }
  return hash.toRadixString(16);
}
