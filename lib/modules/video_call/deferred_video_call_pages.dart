import 'package:flutter/material.dart';

import '../../data/models/call.dart';
import 'video_call_page_factory.dart' deferred as video_call_pages;

class DeferredVideoCallPage extends StatelessWidget {
  const DeferredVideoCallPage({
    super.key,
    required this.channelId,
    this.channelName,
    required this.callType,
  });

  final String channelId;
  final String? channelName;
  final CallType callType;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: video_call_pages.loadLibrary(),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            backgroundColor: Colors.black,
            body: Center(child: CircularProgressIndicator()),
          );
        }
        return video_call_pages.buildVideoCallPage(
          channelId: channelId,
          channelName: channelName,
          callType: callType,
        );
      },
    );
  }
}

class DeferredGroupCallMemberPickerPage extends StatelessWidget {
  const DeferredGroupCallMemberPickerPage({
    super.key,
    required this.channelId,
    required this.channelType,
    this.channelName,
  });

  final String channelId;
  final int channelType;
  final String? channelName;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: video_call_pages.loadLibrary(),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        return video_call_pages.buildGroupCallMemberPickerPage(
          channelId: channelId,
          channelType: channelType,
          channelName: channelName,
        );
      },
    );
  }
}
