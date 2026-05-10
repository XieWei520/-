import 'package:flutter_test/flutter_test.dart';
import 'package:wukong_im_app/data/models/wk_custom_content.dart';
import 'package:wukong_im_app/modules/chat/chat_file_opening.dart';

void main() {
  test('prefers local file paths when both local and remote targets exist', () {
    final content = WKFileContent()
      ..name = '预算.xlsx'
      ..localPath = r'C:\Users\COLORFUL\Desktop\budget.xlsx'
      ..url = '/v1/file/download/budget.xlsx';

    final target = resolveChatFileOpenTarget(messageContent: content);

    expect(target, isNotNull);
    expect(target!.type, ChatFileOpenTargetType.localFile);
    expect(target.value, content.localPath);
  });

  test('normalizes remote download paths from structured payloads', () {
    final target = resolveChatFileOpenTarget(
      structuredPayload: <String, dynamic>{
        'name': '合同.pdf',
        'download_url': '/v1/file/download/contract.pdf',
      },
    );

    expect(target, isNotNull);
    expect(target!.type, ChatFileOpenTargetType.remoteUrl);
    final uri = Uri.parse(target.value);
    expect(uri.path, '/minio/contract.pdf');
    expect(
      uri.queryParameters['response-content-disposition'],
      'attachment; filename="合同.pdf"',
    );
  });

  test('uses attachment semantics for remote preview file urls', () {
    final target = resolveChatFileOpenTarget(
      structuredPayload: <String, dynamic>{
        'name': 'contract.pdf',
        'url': '/v1/file/preview/chat/1/u_self/contract.pdf',
      },
    );

    expect(target, isNotNull);
    expect(target!.type, ChatFileOpenTargetType.remoteUrl);

    final uri = Uri.parse(target.value);
    expect(uri.path, '/minio/chat/1/u_self/contract.pdf');
    expect(
      uri.queryParameters['response-content-disposition'],
      'attachment; filename="contract.pdf"',
    );
  });

  test('normalizes monitor file preview paths without v1 prefix', () {
    final content = WKFileContent()
      ..name = 'report.xlsx'
      ..url = 'file/preview/chat/2/group_1/report.xlsx';

    final target = resolveChatFileOpenTarget(messageContent: content);

    expect(target, isNotNull);
    expect(target!.type, ChatFileOpenTargetType.remoteUrl);
    final uri = Uri.parse(target.value);
    expect(uri.path, '/minio/chat/2/group_1/report.xlsx');
    expect(
      uri.queryParameters['response-content-disposition'],
      'attachment; filename="report.xlsx"',
    );
  });

  test('treats chat object paths as remote minio targets, not local files', () {
    final target = resolveChatFileOpenTarget(
      structuredPayload: <String, dynamic>{
        'name': 'report.pdf',
        'path': '/chat/1/u_self/report.pdf',
      },
    );

    expect(target, isNotNull);
    expect(target!.type, ChatFileOpenTargetType.remoteUrl);
    expect(Uri.parse(target.value).path, '/minio/chat/1/u_self/report.pdf');
  });

  test('rejects malformed absolute remote file urls', () {
    final target = resolveChatFileOpenTarget(
      structuredPayload: <String, dynamic>{'download_url': 'https://'},
    );

    expect(target, isNull);
  });

  test('returns null when no usable open target exists', () {
    final target = resolveChatFileOpenTarget(
      structuredPayload: <String, dynamic>{'name': '空白附件'},
    );

    expect(target, isNull);
  });
}
