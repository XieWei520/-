import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:wukong_im_app/widgets/wk_avatar.dart';

void main() {
  test('WKAvatar source does not import dart io directly', () {
    final source = File('lib/widgets/wk_avatar.dart').readAsStringSync();

    expect(source, isNot(contains("import 'dart:io'")));
  });

  test('WKAvatar bounds remote byte cache with LRU eviction', () async {
    final calls = <String, int>{};
    WKAvatar.setBytesLoaderForTesting((url) async {
      calls[url] = (calls[url] ?? 0) + 1;
      return Uint8List(3 * 1024 * 1024);
    });
    addTearDown(() => WKAvatar.setBytesLoaderForTesting(null));

    await WKAvatar.loadBytesForTesting('https://cdn.example.com/a.png');
    await WKAvatar.loadBytesForTesting('https://cdn.example.com/b.png');
    await WKAvatar.loadBytesForTesting('https://cdn.example.com/a.png');

    expect(calls['https://cdn.example.com/a.png'], 2);
    expect(calls['https://cdn.example.com/b.png'], 1);
    expect(
      WKAvatar.cachedAvatarBytesForTesting,
      lessThanOrEqualTo(WKAvatar.maxAvatarMemoryCacheBytes),
    );
    expect(WKAvatar.cachedAvatarEntriesForTesting, 1);
  });

  test('WKAvatar uses browser networking for remote avatars on web', () {
    expect(
      WKAvatar.shouldUseBrowserNetworkImageForTesting(
        isWeb: true,
        url: 'https://cdn.example.com/avatar.png',
      ),
      isTrue,
    );
    expect(
      WKAvatar.shouldUseBrowserNetworkImageForTesting(isWeb: true, url: '   '),
      isFalse,
    );
    expect(
      WKAvatar.shouldUseBrowserNetworkImageForTesting(
        isWeb: false,
        url: 'https://cdn.example.com/avatar.png',
      ),
      isFalse,
    );
  });

  test(
    'WKAvatar keeps generated user and group avatars on byte loader path on web',
    () {
      expect(
        WKAvatar.shouldUseBrowserNetworkImageForTesting(
          isWeb: true,
          url: 'https://infoequity.qingyunshe.top/v1/users/u_01/avatar',
        ),
        isFalse,
      );
      expect(
        WKAvatar.shouldUseBrowserNetworkImageForTesting(
          isWeb: true,
          url: 'https://infoequity.qingyunshe.top/v1/groups/g_01/avatar',
        ),
        isFalse,
      );
      expect(
        WKAvatar.shouldUseBrowserNetworkImageForTesting(
          isWeb: true,
          url: 'https://infoequity.qingyunshe.top/v1/users/u_01/avatar?cache=1',
        ),
        isFalse,
      );
    },
  );
}
