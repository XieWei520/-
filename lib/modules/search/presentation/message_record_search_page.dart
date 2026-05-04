import 'package:flutter/material.dart';

import 'chat_search_entry_page.dart';

class MessageRecordSearchPage extends StatelessWidget {
  const MessageRecordSearchPage({
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
    return ChatSearchEntryPage(
      channelId: channelId,
      channelType: channelType,
      channelName: channelName,
    );
  }
}
