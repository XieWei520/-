import 'package:flutter/widgets.dart';

import '../../data/models/call.dart';
import 'group_call_member_picker_page.dart';
import 'video_call_page.dart';

Widget buildVideoCallPage({
  required String channelId,
  String? channelName,
  required CallType callType,
}) {
  return VideoCallPage(
    channelId: channelId,
    channelName: channelName,
    callType: callType,
  );
}

Widget buildGroupCallMemberPickerPage({
  required String channelId,
  required int channelType,
  String? channelName,
}) {
  return GroupCallMemberPickerPage(
    channelId: channelId,
    channelType: channelType,
    channelName: channelName,
  );
}
