import 'package:flutter_test/flutter_test.dart';
import 'package:wukong_im_app/modules/video_call/group_call_service.dart';
import 'package:wukong_im_app/wukong_base/endpoint/endpoint_handler.dart';
import 'package:wukong_im_app/wukong_base/endpoint/endpoint_manager.dart';
import 'package:wukong_im_app/wukong_base/endpoint/menu/endpoint_menu.dart';
import 'package:wukongimfluttersdk/entity/channel_member.dart';
import 'package:wukongimfluttersdk/type/const.dart';

void main() {
  setUp(() {
    EndpointManager.getInstance().clear();
  });

  test(
    'loadMembers filters self and system accounts, then paginates keyword results',
    () async {
      final service = GroupCallService(
        loadGroupMembers:
            ({required String channelId, required int channelType}) async {
              return <WKChannelMember>[
                _member('u_self', 'Self'),
                _member('u_10000', 'System Team'),
                _member('fileHelper', 'File Helper'),
                _member('u_alice', 'Alice'),
                _member('u_bob', 'Bob'),
                _member('u_bobby', 'Bobby'),
              ];
            },
        currentUidReader: () => 'u_self',
      );

      final firstPage = await service.loadMembers(
        channelId: 'g_demo',
        channelType: WKChannelType.group,
        keyword: 'bo',
        page: 1,
        pageSize: 1,
      );
      final secondPage = await service.loadMembers(
        channelId: 'g_demo',
        channelType: WKChannelType.group,
        keyword: 'bo',
        page: 2,
        pageSize: 1,
      );

      expect(firstPage.items.map((item) => item.uid), <String>['u_bob']);
      expect(firstPage.hasMore, isTrue);
      expect(secondPage.items.map((item) => item.uid), <String>['u_bobby']);
      expect(secondPage.hasMore, isFalse);
    },
  );

  test(
    'createGroupCall returns close signal without invoking legacy RTC endpoint',
    () async {
      var legacyEndpointInvoked = false;
      EndpointManager.getInstance().register(
        CallMenuIDs.createVideoCall,
        '',
        0,
        SimpleFunctionHandler(([dynamic _]) {
          legacyEndpointInvoked = true;
          return null;
        }),
      );

      final service = GroupCallService();
      final result = await service.createGroupCall(
        channelId: 'g_demo',
        channelType: WKChannelType.group,
        selectedMembers: const <GroupCallMemberCandidate>[
          GroupCallMemberCandidate(uid: 'u_alice', displayName: 'Alice'),
          GroupCallMemberCandidate(uid: 'u_bob', displayName: 'Bob'),
        ],
      );

      expect(result.shouldClose, isTrue);
      expect(legacyEndpointInvoked, isFalse);
    },
  );
}

WKChannelMember _member(String uid, String name) {
  return WKChannelMember()
    ..memberUID = uid
    ..memberName = name;
}
