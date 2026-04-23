import 'package:flutter/material.dart';

import 'domain/search_models.dart';
import 'presentation/chat_search_member_page.dart';

class SearchWithMemberPage extends StatelessWidget {
  const SearchWithMemberPage({
    super.key,
    required this.channelId,
    this.channelType = 2,
    this.channelName,
    this.member,
  });

  final String channelId;
  final int channelType;
  final String? channelName;
  final SearchMemberHit? member;

  @override
  Widget build(BuildContext context) {
    if (member != null) {
      return ChatSearchMemberResultsPage(
        channelId: channelId,
        channelType: channelType,
        channelName: channelName,
        member: member!,
      );
    }
    return ChatSearchMemberPage(
      channelId: channelId,
      channelType: channelType,
      channelName: channelName,
    );
  }
}
