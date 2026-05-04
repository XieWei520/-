import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wukongimfluttersdk/wkim.dart';

import 'global_search_controller.dart';
import '../data/search_api_gateway.dart';
import '../data/search_local_timeline_data_source.dart';
import '../data/search_remote_data_source.dart';
import '../data/search_repository_impl.dart';
import '../domain/search_repository.dart';
import '../data/search_locate_resolver.dart';
import 'chat_locate_coordinator.dart';

final searchApiGatewayProvider = Provider<SearchApiGateway>(
  (ref) => LiveSearchApiGateway(),
);

final searchRemoteDataSourceProvider = Provider<SearchRemoteDataSource>(
  (ref) =>
      SearchRemoteDataSource(apiGateway: ref.watch(searchApiGatewayProvider)),
);

final searchLocalTimelineDataSourceProvider =
    Provider<SearchLocalTimelineDataSource>(
      (ref) => SearchLocalTimelineDataSource(),
    );

final searchRepositoryProvider = Provider<SearchRepository>(
  (ref) => SearchRepositoryImpl(
    remoteDataSource: ref.watch(searchRemoteDataSourceProvider),
    localTimelineDataSource: ref.watch(searchLocalTimelineDataSourceProvider),
  ),
);

final searchLocateResolverProvider = Provider<SearchLocateResolver>(
  (ref) => const SearchLocateResolver(),
);

final globalSearchControllerProvider =
    StateNotifierProvider.autoDispose<
      GlobalSearchController,
      GlobalSearchState
    >(
      (ref) => GlobalSearchController(
        repository: ref.watch(searchRepositoryProvider),
      ),
    );

final chatLocateCoordinatorProvider = Provider<ChatLocateCoordinator>(
  (ref) => ChatLocateCoordinator(
    resolveOrderSeq:
        ({
          required int messageSeq,
          required String channelId,
          required int channelType,
        }) {
          return WKIM.shared.messageManager.getMessageOrderSeq(
            messageSeq,
            channelId,
            channelType,
          );
        },
  ),
);
