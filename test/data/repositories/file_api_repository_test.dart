import 'package:flutter_test/flutter_test.dart';
import 'package:wukong_im_app/core/repositories/file_repository.dart';
import 'package:wukong_im_app/data/repositories/file_api_repository.dart';

void main() {
  test('FileApiRepository delegates chat and common uploads', () async {
    final calls = <String>[];
    final repository = FileApiRepository(
      uploadChatFile:
          ({
            required filePath,
            required channelId,
            required channelType,
          }) async {
            calls.add('chat:$filePath:$channelId:$channelType');
            return 'https://cdn/chat.jpg';
          },
      uploadCommonImage: ({required filePath, required uploadPath}) async {
        calls.add('common:$filePath:$uploadPath');
        return 'https://cdn/avatar.png';
      },
    );

    final chatUrl = await repository.uploadChatFile(
      const ChatFileUploadRequest(
        filePath: ' a.jpg ',
        channelId: 'c1',
        channelType: 2,
      ),
    );
    final imageUrl = await repository.uploadCommonImage(
      const CommonImageUploadRequest(
        filePath: ' b.png ',
        uploadPath: '/avatars/b.png',
      ),
    );

    expect(chatUrl, 'https://cdn/chat.jpg');
    expect(imageUrl, 'https://cdn/avatar.png');
    expect(calls, <String>[
      'chat: a.jpg :c1:2',
      'common: b.png :/avatars/b.png',
    ]);
  });
}
