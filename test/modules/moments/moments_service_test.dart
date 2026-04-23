import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wukong_im_app/core/config/api_config.dart';
import 'package:wukong_im_app/modules/moments/moments_service.dart';
import 'package:wukong_im_app/wk_foundation/net/wk_http_client.dart';

void main() {
  group('MomentsService', () {
    test(
      'maps authoritative moments list payload returned by MomentsApi path',
      () async {
        final adapter = _RoutingJsonAdapter(
          routes: <_RouteStub>[
            _RouteStub(
              method: 'GET',
              path: ApiConfig.moments,
              payload: <String, dynamic>{
                'data': <Map<String, dynamic>>[
                  <String, dynamic>{
                    'id': 'm-1',
                    'author': <String, dynamic>{
                      'uid': 'u-1',
                      'name': 'Alice',
                      'avatar': '/avatars/a.png',
                    },
                    'content': 'hello',
                    'location': 'Shanghai',
                    'images': <String>['/images/1.png'],
                    'likes': <Map<String, dynamic>>[
                      <String, dynamic>{'uid': 'u-2', 'name': 'Bob'},
                    ],
                    'comments': <Map<String, dynamic>>[
                      <String, dynamic>{
                        'id': 'c-1',
                        'uid': 'u-3',
                        'author_name': 'Carol',
                        'content': 'Nice',
                        'reply_to_uid': 'u-2',
                        'reply_to_name': 'Bob',
                        'created_at': '1710000100',
                      },
                    ],
                    'like_count': 1,
                    'comment_count': 1,
                    'is_liked': true,
                    'created_at': '1710000000',
                  },
                ],
              },
            ),
          ],
        );
        WkHttpClient.instance.dio.httpClientAdapter = adapter;

        final moments = await MomentsService.instance.getMoments(
          page: 2,
          pageSize: 40,
        );

        expect(adapter.requests.single.path, ApiConfig.moments);
        expect(
          adapter.requests.single.queryParameters,
          containsPair('page', 2),
        );
        expect(
          adapter.requests.single.queryParameters,
          containsPair('page_size', 40),
        );
        expect(moments, hasLength(1));
        expect(moments.single.id, 'm-1');
        expect(moments.single.uid, 'u-1');
        expect(moments.single.username, 'Alice');
        expect(
          moments.single.avatar,
          ApiConfig.resolveMediaUrl('/avatars/a.png'),
        );
        expect(moments.single.images, <String>[
          ApiConfig.resolveMediaUrl('/images/1.png'),
        ]);
        expect(moments.single.likeCount, 1);
        expect(moments.single.commentCount, 1);
        expect(moments.single.isLiked, true);
        expect(moments.single.createdAt, 1710000000);
        expect(moments.single.likes.single.uid, 'u-2');
        expect(moments.single.likes.single.username, 'Bob');
        expect(moments.single.comments.single.id, 'c-1');
        expect(moments.single.comments.single.username, 'Carol');
        expect(moments.single.comments.single.replyUid, 'u-2');
        expect(moments.single.comments.single.replyUsername, 'Bob');
        expect(moments.single.comments.single.createdAt, 1710000100);
      },
    );

    test(
      'loads detail using list+comments routes instead of nonexistent detail route',
      () async {
        const momentId = 'm-42';
        final adapter = _RoutingJsonAdapter(
          routes: <_RouteStub>[
            _RouteStub(
              method: 'GET',
              path: ApiConfig.moments,
              payload: <String, dynamic>{
                'data': <Map<String, dynamic>>[
                  <String, dynamic>{
                    'id': momentId,
                    'author': <String, dynamic>{
                      'uid': 'u-1',
                      'name': 'Alice',
                      'avatar': '/avatars/a.png',
                    },
                    'content': 'detail',
                    'images': <String>[],
                    'likes': <Map<String, dynamic>>[],
                    'comments': <Map<String, dynamic>>[],
                    'like_count': 0,
                    'comment_count': 1,
                    'is_liked': false,
                    'created_at': '1710000000',
                  },
                ],
              },
            ),
            _RouteStub(
              method: 'GET',
              path: '${ApiConfig.moment}/$momentId/comments',
              payload: <String, dynamic>{
                'data': <Map<String, dynamic>>[
                  <String, dynamic>{
                    'id': 'c-99',
                    'uid': 'u-8',
                    'author_name': 'Dora',
                    'content': 'from comments api',
                    'created_at': '1710000200',
                  },
                ],
              },
            ),
          ],
        );
        WkHttpClient.instance.dio.httpClientAdapter = adapter;

        final moment = await MomentsService.instance.getMomentDetail(momentId);

        final requested = adapter.requests
            .map((request) => '${request.method} ${request.path}')
            .toList(growable: false);
        expect(requested, <String>[
          'GET ${ApiConfig.moments}',
          'GET ${ApiConfig.moment}/$momentId/comments',
        ]);
        expect(requested, isNot(contains('GET ${ApiConfig.moment}/$momentId')));
        expect(moment.id, momentId);
        expect(moment.comments, hasLength(1));
        expect(moment.comments.single.id, 'c-99');
        expect(moment.comments.single.username, 'Dora');
      },
    );

    test('commentMoment sends reply_to and maps returned comment id', () async {
      const momentId = 'm-7';
      final adapter = _RoutingJsonAdapter(
        routes: <_RouteStub>[
          _RouteStub(
            method: 'POST',
            path: '${ApiConfig.moment}/$momentId/comment',
            payload: <String, dynamic>{
              'data': <String, dynamic>{'id': 'c-9'},
            },
          ),
        ],
      );
      WkHttpClient.instance.dio.httpClientAdapter = adapter;

      final comment = await MomentsService.instance.commentMoment(
        momentId: momentId,
        content: 'reply content',
        replyUid: 'u-2',
        replyUsername: 'Bob',
      );

      final body = adapter.requests.single.data as Map<String, dynamic>;
      expect(body, containsPair('content', 'reply content'));
      expect(body, containsPair('reply_to', 'u-2'));
      expect(body.containsKey('reply_uid'), false);
      expect(body.containsKey('reply_username'), false);
      expect(comment.id, 'c-9');
    });

    test('publishMoment forwards mentions and location to the API', () async {
      final adapter = _RoutingJsonAdapter(
        routes: <_RouteStub>[
          _RouteStub(
            method: 'POST',
            path: ApiConfig.moment,
            payload: <String, dynamic>{
              'data': <String, dynamic>{'id': 'm-101'},
            },
          ),
          _RouteStub(
            method: 'GET',
            path: ApiConfig.moments,
            payload: <String, dynamic>{
              'data': <Map<String, dynamic>>[
                <String, dynamic>{
                  'id': 'm-101',
                  'author': <String, dynamic>{'uid': 'u-1', 'name': 'Alice'},
                  'content': 'hello',
                  'location': '上海市·静安区',
                  'mentions': <String>['u-2'],
                  'images': <String>[],
                  'likes': <Map<String, dynamic>>[],
                  'comments': <Map<String, dynamic>>[],
                  'like_count': 0,
                  'comment_count': 0,
                  'is_liked': false,
                  'created_at': '1710000000',
                },
              ],
            },
          ),
          _RouteStub(
            method: 'GET',
            path: '${ApiConfig.moment}/m-101/comments',
            payload: <String, dynamic>{'data': <Map<String, dynamic>>[]},
          ),
        ],
      );
      WkHttpClient.instance.dio.httpClientAdapter = adapter;

      final published = await MomentsService.instance.publishMoment(
        content: 'hello',
        mentions: const <String>['u-2'],
        location: '上海市·静安区',
      );

      final body =
          adapter.requests
                  .firstWhere((request) => request.method == 'POST')
                  .data
              as Map<String, dynamic>;
      expect(body['mentions'], <String>['u-2']);
      expect(body['location'], '上海市·静安区');
      expect(published.location, '上海市·静安区');
      expect(published.mentions, <String>['u-2']);
    });
  });
}

class _RouteStub {
  const _RouteStub({
    required this.method,
    required this.path,
    required this.payload,
  });

  final String method;
  final String path;
  final Object payload;
}

class _RoutingJsonAdapter implements HttpClientAdapter {
  _RoutingJsonAdapter({required this.routes});

  final List<_RouteStub> routes;
  final List<RequestOptions> requests = <RequestOptions>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    final route = _findRoute(options.method, options.path);
    if (route == null) {
      throw StateError('No route stub for ${options.method} ${options.path}');
    }

    return ResponseBody.fromString(
      jsonEncode(route.payload),
      200,
      headers: <String, List<String>>{
        Headers.contentTypeHeader: <String>[Headers.jsonContentType],
      },
    );
  }

  _RouteStub? _findRoute(String method, String path) {
    for (final route in routes) {
      if (route.method == method && route.path == path) {
        return route;
      }
    }
    return null;
  }

  @override
  void close({bool force = false}) {}
}
