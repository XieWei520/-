import '../../../service/api/search_api.dart';

abstract class SearchApiGateway {
  Future<Map<String, dynamic>> globalSearch({
    required String keyword,
    required int page,
    required int limit,
  });

  Future<List<Map<String, dynamic>>> searchMessages({
    required String channelId,
    required int channelType,
    required String keyword,
    required int page,
    required int pageSize,
  });

  Future<List<Map<String, dynamic>>> searchImages({
    required String channelId,
    required int channelType,
    required int page,
    required int limit,
  });

  Future<List<Map<String, dynamic>>> searchFiles({
    required String channelId,
    required int channelType,
    required int page,
    required int limit,
  });

  Future<List<Map<String, dynamic>>> searchLinks({
    required String channelId,
    required int channelType,
    required int page,
    required int limit,
  });

  Future<List<Map<String, dynamic>>> searchMessagesByMember({
    required String channelId,
    required int channelType,
    required String senderId,
    required String keyword,
    required int page,
    required int limit,
  });

  Future<List<Map<String, dynamic>>> getChannelMembers({
    required String channelId,
  });
}

class LiveSearchApiGateway implements SearchApiGateway {
  LiveSearchApiGateway({SearchApi? api}) : _api = api ?? SearchApi.instance;

  final SearchApi _api;

  @override
  Future<List<Map<String, dynamic>>> getChannelMembers({
    required String channelId,
  }) {
    return _api.getChannelMembers(channelId: channelId);
  }

  @override
  Future<Map<String, dynamic>> globalSearch({
    required String keyword,
    required int page,
    required int limit,
  }) {
    return _api.globalSearch(
      keyword,
      page: page,
      limit: limit,
    );
  }

  @override
  Future<List<Map<String, dynamic>>> searchFiles({
    required String channelId,
    required int channelType,
    required int page,
    required int limit,
  }) {
    return _api.searchFiles(
      channelId: channelId,
      channelType: channelType,
      page: page,
      limit: limit,
    );
  }

  @override
  Future<List<Map<String, dynamic>>> searchImages({
    required String channelId,
    required int channelType,
    required int page,
    required int limit,
  }) {
    return _api.searchImages(
      channelId: channelId,
      channelType: channelType,
      page: page,
      limit: limit,
    );
  }

  @override
  Future<List<Map<String, dynamic>>> searchLinks({
    required String channelId,
    required int channelType,
    required int page,
    required int limit,
  }) {
    return _api.searchLinks(
      channelId: channelId,
      channelType: channelType,
      page: page,
      limit: limit,
    );
  }

  @override
  Future<List<Map<String, dynamic>>> searchMessages({
    required String channelId,
    required int channelType,
    required String keyword,
    required int page,
    required int pageSize,
  }) {
    return _api.searchMessages(
      channelId: channelId,
      channelType: channelType,
      keyword: keyword,
      page: page,
      pageSize: pageSize,
    );
  }

  @override
  Future<List<Map<String, dynamic>>> searchMessagesByMember({
    required String channelId,
    required int channelType,
    required String senderId,
    required String keyword,
    required int page,
    required int limit,
  }) {
    return _api.searchMessagesByMember(
      channelId: channelId,
      channelType: channelType,
      senderId: senderId,
      keyword: keyword,
      page: page,
      limit: limit,
    );
  }
}
