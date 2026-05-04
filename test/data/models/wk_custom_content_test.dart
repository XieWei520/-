import 'package:flutter_test/flutter_test.dart';
import 'package:wukong_im_app/data/models/wk_custom_content.dart';

void main() {
  test('WKFileContent decodes common file payload aliases', () {
    final content =
        WKFileContent().decodeJson(<String, dynamic>{
              'fileName': 'contract.pdf',
              'file_size': '2048',
              'download_url': '/v1/file/preview/chat/1/u_self/contract.pdf',
              'local_path': r'C:\tmp\contract.pdf',
              'file_ext': 'pdf',
            })
            as WKFileContent;

    expect(content.name, 'contract.pdf');
    expect(content.size, 2048);
    expect(content.url, '/v1/file/preview/chat/1/u_self/contract.pdf');
    expect(content.localPath, r'C:\tmp\contract.pdf');
    expect(content.suffix, 'pdf');
  });
}
