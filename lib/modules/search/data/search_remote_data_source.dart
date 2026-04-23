import 'search_api_gateway.dart';

class SearchRemoteDataSource {
  SearchRemoteDataSource({required SearchApiGateway apiGateway})
    : _apiGateway = apiGateway;

  final SearchApiGateway _apiGateway;

  Future<List<Map<String, dynamic>>> getChannelMembers({
    required String channelId,
  }) async {
    return _apiGateway.getChannelMembers(channelId: channelId);
  }

  Future<Map<String, dynamic>> globalSearch({
    required String keyword,
    required int page,
    required int limit,
  }) async {
    final result = await _apiGateway.globalSearch(
      keyword: keyword,
      page: page,
      limit: limit,
    );
    return Map<String, dynamic>.from(result);
  }

  Future<List<Map<String, dynamic>>> searchFiles({
    required String channelId,
    required int channelType,
    required int page,
    required int limit,
  }) async {
    return _apiGateway.searchFiles(
      channelId: channelId,
      channelType: channelType,
      page: page,
      limit: limit,
    );
  }

  Future<List<Map<String, dynamic>>> searchImages({
    required String channelId,
    required int channelType,
    required int page,
    required int limit,
  }) async {
    return _apiGateway.searchImages(
      channelId: channelId,
      channelType: channelType,
      page: page,
      limit: limit,
    );
  }

  Future<List<Map<String, dynamic>>> searchLinks({
    required String channelId,
    required int channelType,
    required int page,
    required int limit,
  }) async {
    return _apiGateway.searchLinks(
      channelId: channelId,
      channelType: channelType,
      page: page,
      limit: limit,
    );
  }

  Future<List<Map<String, dynamic>>> searchMessages({
    required String channelId,
    required int channelType,
    required String keyword,
    required int page,
    required int pageSize,
  }) async {
    return _apiGateway.searchMessages(
      channelId: channelId,
      channelType: channelType,
      keyword: keyword,
      page: page,
      pageSize: pageSize,
    );
  }

  Future<List<Map<String, dynamic>>> searchMessagesByMember({
    required String channelId,
    required int channelType,
    required String senderId,
    required String keyword,
    required int page,
    required int limit,
  }) async {
    return _apiGateway.searchMessagesByMember(
      channelId: channelId,
      channelType: channelType,
      senderId: senderId,
      keyword: keyword,
      page: page,
      limit: limit,
    );
  }
}
