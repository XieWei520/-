import 'package:flutter_test/flutter_test.dart';
import 'package:wukong_im_app/core/config/api_config.dart';
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
    expect(
      target.value,
      ApiConfig.resolveMediaUrl('/v1/file/download/contract.pdf'),
    );
  });

  test('returns null when no usable open target exists', () {
    final target = resolveChatFileOpenTarget(
      structuredPayload: <String, dynamic>{'name': '空白附件'},
    );

    expect(target, isNull);
  });
}
