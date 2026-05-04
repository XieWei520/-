import 'package:flutter/material.dart';

import 'domain/search_models.dart';
import 'presentation/chat_search_collection_page.dart';

class SearchWithImgPage extends StatelessWidget {
  const SearchWithImgPage({
    super.key,
    required this.channelId,
    this.channelType = 2,
    this.channelName,
  });

  final String channelId;
  final int channelType;
  final String? channelName;

  @override
  Widget build(BuildContext context) {
    return ChatSearchCollectionPage(
      channelId: channelId,
      channelType: channelType,
      channelName: channelName,
      scope: SearchCollectionScope.image,
    );
  }
}
