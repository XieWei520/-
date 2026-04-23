import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wukong_im_app/modules/conversation/conversation_list_page.dart';
import 'package:wukong_im_app/modules/conversation/conversation_list_refresh_controller.dart';
import 'package:wukong_im_app/modules/home/home_surface_contract.dart';
import 'package:wukong_im_app/modules/home/home_surface_invalidation_bus.dart';
import 'package:wukongimfluttersdk/type/const.dart';

void main() {
  test('conversation surface exposes a home surface contract', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final contract = container.read(conversationSurfaceContractProvider);

    expect(contract.surfaceId, HomeSurfaceId.conversations);
  });

  test(
    'conversation surface bridge marks dirty and emits invalidation',
    () async {
      final controller = ConversationListRefreshController(
        attachSources: false,
      );
      final bus = HomeSurfaceInvalidationBus();
      addTearDown(controller.dispose);
      addTearDown(bus.dispose);

      final bridge = ConversationSurfaceBridge(
        refreshController: controller,
        invalidationBus: bus,
      );
      final invalidationFuture = expectLater(
        bus.stream,
        emits(
          isA<HomeSurfaceInvalidation>()
              .having(
                (event) => event.surfaceId,
                'surfaceId',
                HomeSurfaceId.conversations,
              )
              .having(
                (event) => event.kind,
                'kind',
                HomeInvalidationKind.structural,
              ),
        ),
      );

      const requestKey = '1_u_demo';
      final before = controller.state.versionFor('u_demo', 1);

      bridge.onConversationChanged(requestKey);

      expect(controller.state.versionFor('u_demo', 1), isNot(before));
      await invalidationFuture;
    },
  );

  test('conversation header title uses Chinese status copy', () {
    expect(
      resolveConversationHeaderTitle(WKConnectStatus.connecting),
      '连接中...',
    );
    expect(resolveConversationHeaderTitle(WKConnectStatus.syncMsg), '同步消息中...');
    expect(resolveConversationHeaderTitle(WKConnectStatus.fail), '连接已断开');
    expect(resolveConversationHeaderTitle(WKConnectStatus.success), '消息');
  });

  test('conversation surface reliability follows connection status', () {
    expect(
      resolveConversationSurfaceReliability(WKConnectStatus.syncCompleted),
      SurfaceReliabilityState.healthy,
    );
    expect(
      resolveConversationSurfaceReliability(WKConnectStatus.connecting),
      SurfaceReliabilityState.stale,
    );
    expect(
      resolveConversationSurfaceReliability(WKConnectStatus.fail),
      SurfaceReliabilityState.degraded,
    );
  });
}
