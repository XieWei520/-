import 'package:wukongimfluttersdk/model/wk_message_content.dart';
import 'package:wukongimfluttersdk/type/const.dart';

/// 位置消息内容
class WKLocationContent extends WKMessageContent {
  double latitude = 0;
  double longitude = 0;
  String title = '';
  String address = '';

  WKLocationContent() {
    contentType = WkMessageContentType.location;
  }

  @override
  Map<String, dynamic> encodeJson() {
    return {
      'latitude': latitude,
      'longitude': longitude,
      'title': title,
      'address': address,
    };
  }

  @override
  WKMessageContent decodeJson(Map<String, dynamic> json) {
    latitude = (json['latitude'] as num?)?.toDouble() ?? 0;
    longitude = (json['longitude'] as num?)?.toDouble() ?? 0;
    title = json['title']?.toString() ?? '';
    address = json['address']?.toString() ?? '';
    return this;
  }

  @override
  String displayText() {
    return '[位置] $title';
  }

  @override
  String searchableWord() {
    return '$title $address';
  }
}

/// 文件消息内容
class WKFileContent extends WKMessageContent {
  String name = '';
  int size = 0;
  String url = '';
  String localPath = '';
  String suffix = '';

  WKFileContent() {
    contentType = WkMessageContentType.file;
  }

  @override
  Map<String, dynamic> encodeJson() {
    return {
      'name': name,
      'size': size,
      'url': url,
      'localPath': localPath,
      'suffix': suffix,
    };
  }

  @override
  WKMessageContent decodeJson(Map<String, dynamic> json) {
    name = _firstNonEmptyString(json, const [
      'name',
      'fileName',
      'file_name',
      'filename',
    ]);
    size = _readIntField(json, const ['size', 'fileSize', 'file_size']);
    url = _firstNonEmptyString(json, const [
      'url',
      'download_url',
      'downloadUrl',
      'file_url',
      'fileUrl',
    ]);
    localPath = _firstNonEmptyString(json, const [
      'localPath',
      'local_path',
      'file_path',
      'filePath',
    ]);
    suffix = _firstNonEmptyString(json, const [
      'suffix',
      'file_ext',
      'fileExt',
      'ext',
    ]);
    return this;
  }

  @override
  String displayText() {
    return '[文件] $name';
  }

  @override
  String searchableWord() {
    return name;
  }
}

String _firstNonEmptyString(Map<String, dynamic> json, List<String> keys) {
  for (final key in keys) {
    final value = json[key]?.toString().trim() ?? '';
    if (value.isNotEmpty) {
      return value;
    }
  }
  return '';
}

int _readIntField(Map<String, dynamic> json, List<String> keys) {
  for (final key in keys) {
    final value = json[key];
    if (value is int) {
      return value;
    }
    final parsed = int.tryParse(value?.toString().trim() ?? '');
    if (parsed != null) {
      return parsed;
    }
  }
  return 0;
}

/// 名片消息内容
class WKCardContent extends WKMessageContent {
  String uid = '';
  String name = '';
  String? vercode;

  WKCardContent(this.uid, this.name) {
    contentType = WkMessageContentType.card;
  }

  @override
  Map<String, dynamic> encodeJson() {
    return {'uid': uid, 'name': name, 'vercode': vercode ?? ''};
  }

  @override
  WKMessageContent decodeJson(Map<String, dynamic> json) {
    uid = json['uid']?.toString() ?? '';
    name = json['name']?.toString() ?? '';
    vercode = json['vercode']?.toString();
    return this;
  }

  @override
  String displayText() {
    return '[名片] $name';
  }

  @override
  String searchableWord() {
    return name;
  }
}
