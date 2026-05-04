import 'package:flutter_test/flutter_test.dart';
import 'package:wukong_im_app/data/models/user_relationship.dart';
import 'package:wukong_im_app/data/models/call.dart';
import 'package:wukong_im_app/modules/chat/chat_call_entry_service.dart';
import 'package:wukongimfluttersdk/entity/channel.dart';
import 'package:wukongimfluttersdk/entity/channel_member.dart';
import 'package:wukongimfluttersdk/type/const.dart';

void main() {
  group('PlatformChatCallEntryService', () {
    test(
      'short-circuits duplicate-call guard before permission requests',
      () async {
        var microphoneRequestCount = 0;
        var cameraAndMicrophoneRequestCount = 0;

        final service = PlatformChatCallEntryService(
          hasActiveCallOrPendingSetup: () => true,
          requestMicrophone: () async {
            microphoneRequestCount++;
            return true;
          },
          requestCameraAndMicrophone: () async {
            cameraAndMicrophoneRequestCount++;
            return true;
          },
          isMicrophonePermanentlyDenied: () async => false,
          isCameraPermanentlyDenied: () async => false,
        );

        final audioDecision = await service.prepareOutgoingCall(
          CallType.audio,
          channelId: 'u_guard',
          channelType: WKChannelType.personal,
        );
        final videoDecision = await service.prepareOutgoingCall(
          CallType.video,
          channelId: 'u_guard',
          channelType: WKChannelType.personal,
        );

        expect(audioDecision.shouldStart, isFalse);
        expect(audioDecision.feedbackMessage, chatCallAlreadyActiveMessage);
        expect(videoDecision.shouldStart, isFalse);
        expect(videoDecision.feedbackMessage, chatCallAlreadyActiveMessage);
        expect(microphoneRequestCount, 0);
        expect(cameraAndMicrophoneRequestCount, 0);
      },
    );

    test(
      'allows video calls when camera and microphone permissions are granted',
      () async {
        var cameraPermanentCheckCount = 0;
        var microphonePermanentCheckCount = 0;

        final service = PlatformChatCallEntryService(
          hasActiveCallOrPendingSetup: () => false,
          requestMicrophone: () async => false,
          requestCameraAndMicrophone: () async => true,
          isMicrophonePermanentlyDenied: () async {
            microphonePermanentCheckCount++;
            return false;
          },
          isCameraPermanentlyDenied: () async {
            cameraPermanentCheckCount++;
            return false;
          },
        );

        final decision = await service.prepareOutgoingCall(
          CallType.video,
          channelId: 'u_video',
          channelType: WKChannelType.personal,
        );

        expect(decision.shouldStart, isTrue);
        expect(decision.callType, CallType.video);
        expect(decision.feedbackMessage, isNull);
        expect(cameraPermanentCheckCount, 0);
        expect(microphonePermanentCheckCount, 0);
      },
    );

    test('allows audio calls when microphone permission is granted', () async {
      final service = PlatformChatCallEntryService(
        hasActiveCallOrPendingSetup: () => false,
        requestMicrophone: () async => true,
        requestCameraAndMicrophone: () async => false,
        isMicrophonePermanentlyDenied: () async => false,
        isCameraPermanentlyDenied: () async => false,
      );

      final decision = await service.prepareOutgoingCall(
        CallType.audio,
        channelId: 'u_audio',
        channelType: WKChannelType.personal,
      );

      expect(decision.shouldStart, isTrue);
      expect(decision.callType, CallType.audio);
      expect(decision.feedbackMessage, isNull);
    });

    test(
      'returns inline denial feedback for video permission failures',
      () async {
        final service = PlatformChatCallEntryService(
          hasActiveCallOrPendingSetup: () => false,
          requestMicrophone: () async => false,
          requestCameraAndMicrophone: () async => false,
          isMicrophonePermanentlyDenied: () async => false,
          isCameraPermanentlyDenied: () async => false,
        );

        final decision = await service.prepareOutgoingCall(
          CallType.video,
          channelId: 'u_video_denied',
          channelType: WKChannelType.personal,
        );

        expect(decision.shouldStart, isFalse);
        expect(decision.feedbackMessage, chatVideoPermissionDeniedMessage);
      },
    );

    test(
      'returns settings guidance for permanent video denial and short-circuits permanent checks',
      () async {
        var microphonePermanentCheckCount = 0;

        final service = PlatformChatCallEntryService(
          hasActiveCallOrPendingSetup: () => false,
          requestMicrophone: () async => false,
          requestCameraAndMicrophone: () async => false,
          isMicrophonePermanentlyDenied: () async {
            microphonePermanentCheckCount++;
            return false;
          },
          isCameraPermanentlyDenied: () async => true,
        );

        final decision = await service.prepareOutgoingCall(
          CallType.video,
          channelId: 'u_video_settings',
          channelType: WKChannelType.personal,
        );

        expect(decision.shouldStart, isFalse);
        expect(decision.feedbackMessage, chatVideoPermissionSettingsMessage);
        expect(microphonePermanentCheckCount, 0);
      },
    );

    test('returns settings guidance for permanent microphone denial', () async {
      final service = PlatformChatCallEntryService(
        hasActiveCallOrPendingSetup: () => false,
        requestMicrophone: () async => false,
        requestCameraAndMicrophone: () async => false,
        isMicrophonePermanentlyDenied: () async => true,
        isCameraPermanentlyDenied: () async => false,
      );

      final decision = await service.prepareOutgoingCall(
        CallType.audio,
        channelId: 'u_audio_settings',
        channelType: WKChannelType.personal,
      );

      expect(decision.shouldStart, isFalse);
      expect(decision.feedbackMessage, chatAudioPermissionSettingsMessage);
    });

    test('blocks forbidden chats before requesting permissions', () async {
      var microphoneRequestCount = 0;

      final service = PlatformChatCallEntryService(
        hasActiveCallOrPendingSetup: () => false,
        requestMicrophone: () async {
          microphoneRequestCount += 1;
          return true;
        },
        requestCameraAndMicrophone: () async => true,
        isMicrophonePermanentlyDenied: () async => false,
        isCameraPermanentlyDenied: () async => false,
        channelLoader:
            ({required String channelId, required int channelType}) async {
              return WKChannel(channelId, channelType)..forbidden = 1;
            },
        memberLoader:
            ({
              required String channelId,
              required int channelType,
              required String uid,
            }) async => null,
        currentUidReader: () => 'u_self',
      );

      final decision = await service.prepareOutgoingCall(
        CallType.audio,
        channelId: 'u_forbidden',
        channelType: WKChannelType.personal,
      );

      expect(decision.shouldStart, isFalse);
      expect(decision.feedbackMessage, chatCallForbiddenMessage);
      expect(microphoneRequestCount, 0);
    });

    test(
      'blocks personal calls when the relationship is no longer mutual',
      () async {
        final service = PlatformChatCallEntryService(
          hasActiveCallOrPendingSetup: () => false,
          requestMicrophone: () async => true,
          requestCameraAndMicrophone: () async => true,
          isMicrophonePermanentlyDenied: () async => false,
          isCameraPermanentlyDenied: () async => false,
          channelLoader:
              ({required String channelId, required int channelType}) async {
                return WKChannel(channelId, channelType)..follow = 0;
              },
        );

        final decision = await service.prepareOutgoingCall(
          CallType.audio,
          channelId: 'u_non_friend',
          channelType: WKChannelType.personal,
        );

        expect(decision.shouldStart, isFalse);
        expect(decision.feedbackMessage, chatCallNonFriendRelationshipMessage);
      },
    );

    test(
      'blocks personal calls when the other user has blacklisted the current user',
      () async {
        final service = PlatformChatCallEntryService(
          hasActiveCallOrPendingSetup: () => false,
          requestMicrophone: () async => true,
          requestCameraAndMicrophone: () async => true,
          isMicrophonePermanentlyDenied: () async => false,
          isCameraPermanentlyDenied: () async => false,
          channelLoader:
              ({required String channelId, required int channelType}) async {
                return WKChannel(channelId, channelType)
                  ..follow = 1
                  ..localExtra = <String, dynamic>{'be_blacklist': 1};
              },
        );

        final decision = await service.prepareOutgoingCall(
          CallType.audio,
          channelId: 'u_be_blacklist',
          channelType: WKChannelType.personal,
        );

        expect(decision.shouldStart, isFalse);
        expect(decision.feedbackMessage, chatCallBeBlacklistMessage);
      },
    );

    test(
      'blocks personal calls when the current user has blacklisted the target user',
      () async {
        final service = PlatformChatCallEntryService(
          hasActiveCallOrPendingSetup: () => false,
          requestMicrophone: () async => true,
          requestCameraAndMicrophone: () async => true,
          isMicrophonePermanentlyDenied: () async => false,
          isCameraPermanentlyDenied: () async => false,
          channelLoader:
              ({required String channelId, required int channelType}) async {
                return WKChannel(channelId, channelType)
                  ..follow = 1
                  ..status = 2;
              },
        );

        final decision = await service.prepareOutgoingCall(
          CallType.audio,
          channelId: 'u_blacklist',
          channelType: WKChannelType.personal,
        );

        expect(decision.shouldStart, isFalse);
        expect(decision.feedbackMessage, chatCallBlacklistMessage);
      },
    );

    test(
      'blocks group calls when the current member is in the group blacklist',
      () async {
        final service = PlatformChatCallEntryService(
          hasActiveCallOrPendingSetup: () => false,
          requestMicrophone: () async => true,
          requestCameraAndMicrophone: () async => true,
          isMicrophonePermanentlyDenied: () async => false,
          isCameraPermanentlyDenied: () async => false,
          currentUidReader: () => 'u_self',
          channelLoader:
              ({required String channelId, required int channelType}) async =>
                  WKChannel(channelId, channelType),
          memberLoader:
              ({
                required String channelId,
                required int channelType,
                required String uid,
              }) async {
                return WKChannelMember()..status = 2;
              },
        );

        final decision = await service.prepareOutgoingCall(
          CallType.video,
          channelId: 'g_blacklist',
          channelType: WKChannelType.group,
        );

        expect(decision.shouldStart, isFalse);
        expect(decision.feedbackMessage, chatCallBlacklistGroupMessage);
      },
    );

    test(
      'prefers shared relationship state over stale local follow flag for personal calls',
      () async {
        final service = PlatformChatCallEntryService(
          hasActiveCallOrPendingSetup: () => false,
          requestMicrophone: () async => true,
          requestCameraAndMicrophone: () async => true,
          isMicrophonePermanentlyDenied: () async => false,
          isCameraPermanentlyDenied: () async => false,
          channelLoader:
              ({required String channelId, required int channelType}) async {
                return WKChannel(channelId, channelType)..follow = 0;
              },
          personalRelationshipLoader: ({required String uid}) async {
            return const UserRelationshipState(
              isFriend: true,
              isInBlacklist: false,
              isBlockedByPeer: false,
            );
          },
        );

        final decision = await service.prepareOutgoingCall(
          CallType.audio,
          channelId: 'u_shared_friend',
          channelType: WKChannelType.personal,
        );

        expect(decision.shouldStart, isTrue);
        expect(decision.callType, CallType.audio);
        expect(decision.feedbackMessage, isNull);
      },
    );

    test(
      'falls back to local relationship checks when shared relationship lookup is unavailable',
      () async {
        final service = PlatformChatCallEntryService(
          hasActiveCallOrPendingSetup: () => false,
          requestMicrophone: () async => true,
          requestCameraAndMicrophone: () async => true,
          isMicrophonePermanentlyDenied: () async => false,
          isCameraPermanentlyDenied: () async => false,
          channelLoader:
              ({required String channelId, required int channelType}) async {
                return WKChannel(channelId, channelType)..follow = 0;
              },
          personalRelationshipLoader: ({required String uid}) async => null,
        );

        final decision = await service.prepareOutgoingCall(
          CallType.audio,
          channelId: 'u_shared_lookup_unavailable',
          channelType: WKChannelType.personal,
        );

        expect(decision.shouldStart, isFalse);
        expect(decision.feedbackMessage, chatCallNonFriendRelationshipMessage);
      },
    );
  });
}
