import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wukong_im_app/core/config/api_config.dart';
import 'package:wukong_im_app/service/api/api_client.dart';
import 'package:wukong_im_app/service/api/search_api.dart';
import 'package:wukong_im_app/wukong_base/msg/msg_content_type.dart';
import 'package:wukongimfluttersdk/type/const.dart';

void main() {
  group('SearchApi', () {
    test(
      'globalSearch uses Android global search endpoint and aggregates hits',
      () async {
        final adapter = _RecordingJsonAdapter(
          payload: <String, dynamic>{
            'friends': <Map<String, dynamic>>[
              <String, dynamic>{
                'channel_id': 'u_alice',
                'channel_type': 1,
                'channel_name': '<mark>Alice</mark>',
                'channel_remark': '<mark>Teammate</mark>',
              },
            ],
            'groups': <Map<String, dynamic>>[
              <String, dynamic>{
                'channel_id': 'g1001',
                'channel_type': 2,
                'channel_name': '<mark>设计群</mark>',
                'channel_remark': '',
              },
            ],
            'messages': <Map<String, dynamic>>[
              <String, dynamic>{
                'message_idstr': 'm1',
                'message_seq': 1,
                'client_msg_no': 'c1',
                'from_uid': 'u_alice',
                'timestamp': 1710000000,
                'payload': <String, dynamic>{
                  'type': 1,
                  'content': '<mark>Alice</mark> 相关消息',
                },
                'channel': <String, dynamic>{
                  'channel_id': 'g1001',
                  'channel_type': 2,
                  'channel_name': '<mark>设计群</mark>',
                  'channel_remark': '',
                },
                'from_channel': <String, dynamic>{
                  'channel_id': 'u_alice',
                  'channel_type': 1,
                  'channel_name': '<mark>Alice</mark>',
                  'channel_remark': '',
                },
              },
              <String, dynamic>{
                'message_idstr': 'm2',
                'message_seq': 2,
                'client_msg_no': 'c2',
                'from_uid': 'u_alice',
                'timestamp': 1710000010,
                'payload': <String, dynamic>{'type': 1, 'content': '第二条命中'},
                'channel': <String, dynamic>{
                  'channel_id': 'g1001',
                  'channel_type': 2,
                  'channel_name': '设计群',
                  'channel_remark': '',
                },
                'from_channel': <String, dynamic>{
                  'channel_id': 'u_alice',
                  'channel_type': 1,
                  'channel_name': 'Alice',
                  'channel_remark': '',
                },
              },
            ],
          },
        );
        ApiClient.instance.dio.httpClientAdapter = adapter;

        final result = await SearchApi.instance.globalSearch('alice');

        expect(adapter.lastRequestOptions?.path, ApiConfig.searchGlobal);
        expect(
          adapter.lastRequestOptions?.data,
          containsPair('only_message', 0),
        );
        expect(
          adapter.lastRequestOptions?.data,
          containsPair('keyword', 'alice'),
        );

        final users = List<Map<String, dynamic>>.from(result['users'] as List);
        final groups = List<Map<String, dynamic>>.from(
          result['groups'] as List,
        );
        final messages = List<Map<String, dynamic>>.from(
          result['messages'] as List,
        );

        expect(users.single['uid'], 'u_alice');
        expect(users.single['name'], 'Alice');
        expect(users.single['remark'], 'Teammate');

        expect(groups.single['group_no'], 'g1001');
        expect(groups.single['name'], '设计群');

        expect(messages, hasLength(1));
        expect(messages.single['channel_id'], 'g1001');
        expect(messages.single['channel_type'], 2);
        expect(messages.single['channel_name'], '设计群');
        expect(messages.single['message_count'], 2);
        expect(messages.single['searchable_word'], isNotEmpty);
      },
    );

    test(
      'searchImages sends content filter to global search and normalizes urls',
      () async {
        final adapter = _RecordingJsonAdapter(
          payload: <String, dynamic>{
            'messages': <Map<String, dynamic>>[
              <String, dynamic>{
                'message_idstr': 'm3',
                'message_seq': 3,
                'client_msg_no': 'c3',
                'from_uid': 'u_alice',
                'timestamp': 1710000100,
                'payload': <String, dynamic>{
                  'type': 2,
                  'url': 'media/chat/image.png',
                },
                'channel': <String, dynamic>{
                  'channel_id': 'g1001',
                  'channel_type': 2,
                  'channel_name': '设计群',
                  'channel_remark': '',
                },
                'from_channel': <String, dynamic>{
                  'channel_id': 'u_alice',
                  'channel_type': 1,
                  'channel_name': 'Alice',
                  'channel_remark': '',
                },
              },
            ],
          },
        );
        ApiClient.instance.dio.httpClientAdapter = adapter;

        final images = await SearchApi.instance.searchImages(
          channelId: 'g1001',
          channelType: 2,
          limit: 30,
        );

        expect(adapter.lastRequestOptions?.path, ApiConfig.searchGlobal);
        expect(
          adapter.lastRequestOptions?.data,
          containsPair('only_message', 1),
        );
        expect(
          adapter.lastRequestOptions?.data,
          containsPair('content_type', <int>[2]),
        );
        expect(
          adapter.lastRequestOptions?.data,
          containsPair('channel_id', 'g1001'),
        );
        expect(
          adapter.lastRequestOptions?.data,
          containsPair('channel_type', 2),
        );
        expect(adapter.lastRequestOptions?.data, containsPair('limit', 30));

        expect(images, hasLength(1));
        expect(
          images.single['image_url'],
          ApiConfig.resolveMediaUrl('media/chat/image.png'),
        );
        expect(
          images.single['url'],
          ApiConfig.resolveMediaUrl('media/chat/image.png'),
        );
        expect(images.single['channel_id'], 'g1001');
        expect(images.single['channel_type'], 2);
      },
    );

    test('searchMessagesByDate forwards unix-second range filters', () async {
      final adapter = _RecordingJsonAdapter(
        payload: const <String, dynamic>{'messages': <dynamic>[]},
      );
      ApiClient.instance.dio.httpClientAdapter = adapter;

      final start = DateTime.fromMillisecondsSinceEpoch(1710000000000);
      final end = DateTime.fromMillisecondsSinceEpoch(1710086400000);

      await SearchApi.instance.searchMessagesByDate(
        channelId: 'g1001',
        channelType: 2,
        startDate: start,
        endDate: end,
        limit: 40,
      );

      expect(adapter.lastRequestOptions?.path, ApiConfig.searchGlobal);
      expect(
        adapter.lastRequestOptions?.data,
        containsPair('start_time', 1710000000),
      );
      expect(
        adapter.lastRequestOptions?.data,
        containsPair('end_time', 1710086400),
      );
      expect(adapter.lastRequestOptions?.data, containsPair('limit', 40));
    });

    test('searchMessagesByMember forwards page limit and from_uid', () async {
      final adapter = _RecordingJsonAdapter(
        payload: <String, dynamic>{
          'messages': <Map<String, dynamic>>[
            <String, dynamic>{
              'message_idstr': 'm20',
              'message_seq': 20,
              'client_msg_no': 'c20',
              'from_uid': 'u_alice',
              'timestamp': 1710000200,
              'order_seq': 4321,
              'payload': <String, dynamic>{
                'type': WkMessageContentType.text,
                'content': 'member hit',
              },
              'channel': <String, dynamic>{
                'channel_id': 'g1001',
                'channel_type': 2,
                'channel_name': 'Design Group',
                'channel_remark': '',
              },
              'from_channel': <String, dynamic>{
                'channel_id': 'u_alice',
                'channel_type': 1,
                'channel_name': 'Alice',
                'channel_remark': '',
              },
            },
          ],
        },
      );
      ApiClient.instance.dio.httpClientAdapter = adapter;

      final messages = await SearchApi.instance.searchMessagesByMember(
        channelId: 'g1001',
        channelType: 2,
        senderId: 'u_alice',
        keyword: 'member',
        page: 3,
        limit: 20,
      );

      expect(adapter.lastRequestOptions?.path, ApiConfig.searchGlobal);
      expect(adapter.lastRequestOptions?.data, containsPair('page', 3));
      expect(adapter.lastRequestOptions?.data, containsPair('limit', 20));
      expect(
        adapter.lastRequestOptions?.data,
        containsPair('from_uid', 'u_alice'),
      );
      expect(messages.single['order_seq'], 4321);
    });

    test(
      'searchMessagesByMember normalizes nested robot card payload without plain_text to title/body preview',
      () async {
        final adapter = _RecordingJsonAdapter(
          payload: <String, dynamic>{
            'messages': <Map<String, dynamic>>[
              <String, dynamic>{
                'message_idstr': 'm21',
                'message_seq': 21,
                'client_msg_no': 'c21',
                'from_uid': 'u_alice',
                'timestamp': 1710000210,
                'order_seq': 5001,
                'payload': <String, dynamic>{
                  'type': MsgContentType.robotCard,
                  'robot': <String, dynamic>{
                    'provider': 'feishu',
                    'name': 'Weather Robot',
                  },
                  'card': <String, dynamic>{
                    'title': 'Robot title',
                    'body': 'Robot body',
                    'link_url': 'https://example.com',
                    'link_mode': 'whole_card',
                  },
                },
                'channel': <String, dynamic>{
                  'channel_id': 'g1001',
                  'channel_type': 2,
                  'channel_name': 'Design Group',
                  'channel_remark': '',
                },
                'from_channel': <String, dynamic>{
                  'channel_id': 'u_alice',
                  'channel_type': 1,
                  'channel_name': 'Alice',
                  'channel_remark': '',
                },
              },
            ],
          },
        );
        ApiClient.instance.dio.httpClientAdapter = adapter;

        final messages = await SearchApi.instance.searchMessagesByMember(
          channelId: 'g1001',
          channelType: 2,
          senderId: 'u_alice',
          keyword: 'robot',
          page: 1,
          limit: 20,
        );

        expect(messages, hasLength(1));
        expect(messages.single['content'], 'Robot title Robot body');
      },
    );

    test(
      'searchLinks retains robot card hit when nested card.link_url is present',
      () async {
        final adapter = _RecordingJsonAdapter(
          payload: <String, dynamic>{
            'messages': <Map<String, dynamic>>[
              <String, dynamic>{
                'message_idstr': 'm22',
                'message_seq': 22,
                'client_msg_no': 'c22',
                'from_uid': 'u_alice',
                'timestamp': 1710000220,
                'payload': <String, dynamic>{
                  'type': MsgContentType.robotCard,
                  'robot': <String, dynamic>{
                    'provider': 'feishu',
                    'name': 'Weather Robot',
                  },
                  'card': <String, dynamic>{
                    'title': 'Robot title',
                    'body': 'Robot body',
                    'link_url': 'https://example.com/robot-card',
                    'link_mode': 'whole_card',
                  },
                },
                'channel': <String, dynamic>{
                  'channel_id': 'g1001',
                  'channel_type': 2,
                  'channel_name': 'Design Group',
                  'channel_remark': '',
                },
                'from_channel': <String, dynamic>{
                  'channel_id': 'u_alice',
                  'channel_type': 1,
                  'channel_name': 'Alice',
                  'channel_remark': '',
                },
              },
            ],
          },
        );
        ApiClient.instance.dio.httpClientAdapter = adapter;

        final links = await SearchApi.instance.searchLinks(
          channelId: 'g1001',
          channelType: 2,
          page: 1,
          limit: 20,
        );

        expect(links, hasLength(1));
        expect(links.single['link_url'], 'https://example.com/robot-card');
        expect(links.single['content'], 'Robot title Robot body');
      },
    );
  });
}

class _RecordingJsonAdapter implements HttpClientAdapter {
  _RecordingJsonAdapter({required this.payload});

  final Object payload;
  RequestOptions? lastRequestOptions;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    lastRequestOptions = options;
    return ResponseBody.fromString(
      jsonEncode(payload),
      200,
      headers: <String, List<String>>{
        Headers.contentTypeHeader: <String>[Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
