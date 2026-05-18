import 'package:flutter_test/flutter_test.dart';
import 'package:wukong_im_app/data/models/wk_custom_content.dart';
import 'package:wukong_im_app/modules/chat/chat_scene_gateway.dart';
import 'package:wukong_im_app/modules/chat/robot_message_identity.dart';
import 'package:wukong_im_app/modules/local_monitor/local_monitor_forwarding.dart';

void main() {
  test(
    'file sender uploads prepared files and sends WK file content',
    () async {
      final sentFiles = <WKFileContent>[];
      final expires = <int?>[];
      final sender = WkImLocalMonitorFileSender(
        gateway: ApiChatSceneGateway(
          sendMessageWithOptions: (content, channel, options) {
            sentFiles.add(content as WKFileContent);
            expires.add(options?.expire);
            expect(channel.channelID, 'wk-alpha');
            expect(channel.channelType, 2);
            expect(channel.channelName, 'WuKong Alpha');
          },
        ),
        prepareFile: (file) async =>
            file.copyWith(localPath: r'C:\tmp\lesson.pdf'),
        uploadFile:
            ({
              required filePath,
              required channelId,
              required channelType,
              required fileName,
            }) async {
              expect(filePath, r'C:\tmp\lesson.pdf');
              expect(channelId, 'wk-alpha');
              expect(channelType, 2);
              expect(fileName, 'lesson.pdf');
              return 'https://cdn.example.com/lesson.pdf';
            },
        maxFileBytes: 20 * 1024 * 1024,
      );

      await sender.sendFile(
        channelId: 'wk-alpha',
        channelType: 2,
        channelName: 'WuKong Alpha',
        file: const LocalMonitorForwardableFile(
          sourceUrl: 'https://source.example.com/lesson.pdf',
          localPath: '',
          fileName: r'..\lesson.pdf',
          mimeType: 'application/pdf',
          sizeBytes: 1024,
        ),
        relayIdentity: const LocalMonitorRelayIdentity(
          provider: 'xiaoe',
          displayName: 'Xiaoe Relay',
          avatar: 'https://cdn.example.com/xiaoe.png',
        ),
      );

      expect(sentFiles, hasLength(1));
      expect(sentFiles.single.localPath, r'C:\tmp\lesson.pdf');
      expect(sentFiles.single.name, 'lesson.pdf');
      expect(sentFiles.single.size, 1024);
      expect(sentFiles.single.url, 'https://cdn.example.com/lesson.pdf');
      expect(sentFiles.single.suffix, 'pdf');
      final robot = parseRobotMessageIdentity(sentFiles.single.encodeJson());
      expect(robot?.provider, 'xiaoe');
      expect(robot?.displayName, 'Xiaoe Relay');
      expect(expires, <int?>[localMonitorForwardedMessageExpireSeconds]);
    },
  );

  test(
    'file sender rejects files over the configured limit before upload',
    () async {
      final sender = WkImLocalMonitorFileSender(
        prepareFile: (file) async =>
            file.copyWith(localPath: r'C:\tmp\large.zip'),
        uploadFile:
            ({
              required filePath,
              required channelId,
              required channelType,
              required fileName,
            }) async {
              fail('oversized files should not be uploaded');
            },
        maxFileBytes: 1024,
      );

      expect(
        sender.sendFile(
          channelId: 'wk-alpha',
          channelType: 2,
          file: const LocalMonitorForwardableFile(
            sourceUrl: '',
            localPath: '',
            fileName: 'large.zip',
            mimeType: 'application/zip',
            sizeBytes: 1025,
          ),
        ),
        throwsA(isA<LocalMonitorFileTooLargeException>()),
      );
    },
  );
}
