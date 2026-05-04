import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wukong_im_app/modules/home/home_badge_snapshot.dart';
import 'package:wukong_im_app/modules/home/home_surface_contract.dart';
import 'package:wukong_im_app/service/api/api_client.dart';
import 'package:wukong_im_app/wukong_base/endpoint/endpoint_manager.dart';
import 'package:wukong_im_app/wukong_push/device_badge_service.dart';

void main() {
  late HttpClientAdapter originalAdapter;

  setUpAll(() {
    originalAdapter = ApiClient.instance.dio.httpClientAdapter;
  });

  tearDown(() {
    ApiClient.instance.dio.httpClientAdapter = originalAdapter;
  });

  test(
    'device badge service registers legacy endpoint and syncs remote and local badge',
    () async {
      final endpointManager = EndpointManager.getInstance();
      endpointManager.clear();
      addTearDown(endpointManager.clear);

      final remoteCalls = <int>[];
      final platformCalls = <int>[];
      final service = DeviceBadgeService(
        registerRemoteBadge: (badge) async => remoteCalls.add(badge),
        platformBridge: _FakeDeviceBadgePlatformBridge(platformCalls),
        isLoggedIn: () => true,
      );

      service.registerEndpoint(endpointManager: endpointManager);
      await endpointManager.invoke(pushUpdateDeviceBadgeEndpoint, 7);

      expect(remoteCalls, <int>[7]);
      expect(platformCalls, <int>[7]);
    },
  );

  test(
    'device badge endpoint reads structured badge payloads from legacy callers',
    () async {
      final endpointManager = EndpointManager.getInstance();
      endpointManager.clear();
      addTearDown(endpointManager.clear);

      final remoteCalls = <int>[];
      final platformCalls = <int>[];
      final service = DeviceBadgeService(
        registerRemoteBadge: (badge) async => remoteCalls.add(badge),
        platformBridge: _FakeDeviceBadgePlatformBridge(platformCalls),
        isLoggedIn: () => true,
      );

      service.registerEndpoint(endpointManager: endpointManager);
      await endpointManager.invoke(pushUpdateDeviceBadgeEndpoint, {
        'badge': ' 12 ',
      });

      expect(remoteCalls, <int>[12]);
      expect(platformCalls, <int>[12]);
    },
  );

  test(
    'default remote badge sync posts to v1 user device badge endpoint',
    () async {
      final recordingAdapter = _RecordingHttpClientAdapter();
      ApiClient.instance.dio.httpClientAdapter = recordingAdapter;
      final service = DeviceBadgeService(
        platformBridge: _FakeDeviceBadgePlatformBridge(<int>[]),
        isLoggedIn: () => true,
      );

      await service.updateBadge(3);

      expect(recordingAdapter.requestPaths, <String>['/v1/user/device_badge']);
    },
  );

  test(
    'clearLocalBadge only clears local badge like Android logout flow',
    () async {
      final remoteCalls = <int>[];
      final platformCalls = <int>[];
      final service = DeviceBadgeService(
        registerRemoteBadge: (badge) async => remoteCalls.add(badge),
        platformBridge: _FakeDeviceBadgePlatformBridge(platformCalls),
        isLoggedIn: () => true,
      );

      await service.clearLocalBadge();

      expect(remoteCalls, isEmpty);
      expect(platformCalls, <int>[0]);
    },
  );

  test(
    'device badge sync bridge forwards changed unread totals and resets across logout',
    () async {
      final synced = <int>[];
      var isLoggedIn = true;
      final bridge = DeviceBadgeSyncBridge(
        updateBadge: (badge) async => synced.add(badge),
        isLoggedIn: () => isLoggedIn,
      );

      await bridge.sync(
        HomeBadgeSnapshot(
          bySurface: <HomeSurfaceId, int>{
            HomeSurfaceId.conversations: 2,
            HomeSurfaceId.contacts: 1,
          },
        ),
      );
      await bridge.sync(
        HomeBadgeSnapshot(
          bySurface: <HomeSurfaceId, int>{
            HomeSurfaceId.conversations: 2,
            HomeSurfaceId.contacts: 1,
          },
        ),
      );
      await bridge.sync(
        HomeBadgeSnapshot(
          bySurface: <HomeSurfaceId, int>{HomeSurfaceId.conversations: 4},
        ),
      );

      isLoggedIn = false;
      await bridge.sync(
        HomeBadgeSnapshot(
          bySurface: <HomeSurfaceId, int>{HomeSurfaceId.conversations: 9},
        ),
      );

      isLoggedIn = true;
      await bridge.sync(
        HomeBadgeSnapshot(
          bySurface: <HomeSurfaceId, int>{HomeSurfaceId.conversations: 9},
        ),
      );

      expect(synced, <int>[3, 4, 9]);
    },
  );
}

class _FakeDeviceBadgePlatformBridge implements DeviceBadgePlatformBridge {
  _FakeDeviceBadgePlatformBridge(this.calls);

  final List<int> calls;

  @override
  Future<void> setBadgeCount(int count) async {
    calls.add(count);
  }
}

class _RecordingHttpClientAdapter implements HttpClientAdapter {
  final List<String> requestPaths = <String>[];

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requestPaths.add(options.path);
    return ResponseBody.fromString(
      '{}',
      200,
      headers: <String, List<String>>{
        Headers.contentTypeHeader: <String>[Headers.jsonContentType],
      },
    );
  }
}
