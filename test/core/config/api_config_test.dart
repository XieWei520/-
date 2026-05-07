import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wukong_im_app/core/constants/app_constants.dart';
import 'package:wukong_im_app/core/config/api_config.dart';
import 'package:wukong_im_app/core/utils/storage_utils.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ApiConfig defaults', () {
    test('point to the secure production domain by default', () {
      expect(ApiConfig.devBaseUrl, 'https://infoequity.cn');
      expect(ApiConfig.prodBaseUrl, 'https://infoequity.cn');
      expect(ApiConfig.devWsAddr, 'wss://infoequity.cn/ws');
      expect(ApiConfig.prodWsAddr, 'wss://infoequity.cn/ws');
      expect(ApiConfig.baseUrl, 'https://infoequity.cn');
      expect(ApiConfig.wsAddr, 'wss://infoequity.cn/ws');
    });

    test(
      'uses persisted auth login API base URL override when present',
      () async {
        SharedPreferences.setMockInitialValues(<String, Object>{});
        await StorageUtils.init();

        expect(ApiConfig.baseUrl, 'https://infoequity.cn');

        await StorageUtils.setString(
          AppConstants.keyAuthLoginApiBaseUrl,
          'http://127.0.0.1:5001',
        );
        expect(ApiConfig.baseUrl, 'http://127.0.0.1:5001');

        await StorageUtils.remove(AppConstants.keyAuthLoginApiBaseUrl);
        expect(ApiConfig.baseUrl, 'https://infoequity.cn');
      },
    );

    test(
      'ignores and clears persisted non-approved public host overrides',
      () async {
        SharedPreferences.setMockInitialValues(<String, Object>{});
        await StorageUtils.init();

        for (final disallowedOverride in <String>[
          'https://legacy-public.example.com',
          'https://legacy-public.example.com/',
          'http://legacy-public.example.com:8090',
        ]) {
          await StorageUtils.setString(
            AppConstants.keyAuthLoginApiBaseUrl,
            disallowedOverride,
          );

          expect(ApiConfig.baseUrl, 'https://infoequity.cn');
          expect(
            StorageUtils.getString(AppConstants.keyAuthLoginApiBaseUrl),
            isEmpty,
          );
        }

        await StorageUtils.clear();
      },
    );

    test(
      'maps the desktop tunnel API override onto the local IM fallback addr',
      () async {
        SharedPreferences.setMockInitialValues(<String, Object>{});
        await StorageUtils.init();

        await StorageUtils.setString(
          AppConstants.keyAuthLoginApiBaseUrl,
          'http://127.0.0.1:15001',
        );

        expect(ApiConfig.baseUrl, 'http://127.0.0.1:15001');
        expect(ApiConfig.wsAddr, '127.0.0.1:15100');

        await StorageUtils.remove(AppConstants.keyAuthLoginApiBaseUrl);
      },
    );
  });

  group('ApiConfig.resolveMediaUrl', () {
    test('prefixes v1 for relative media paths and preserves full urls', () {
      expect(
        ApiConfig.resolveMediaUrl('files/avatar.png'),
        '${ApiConfig.baseUrl}/v1/files/avatar.png',
      );
      expect(
        ApiConfig.resolveMediaUrl('/v1/files/avatar.png'),
        '${ApiConfig.baseUrl}/v1/files/avatar.png',
      );
      expect(
        ApiConfig.resolveMediaUrl(r'files\avatar.png'),
        '${ApiConfig.baseUrl}/v1/files/avatar.png',
      );
      expect(
        ApiConfig.resolveMediaUrl('https://cdn.example.com/files/avatar.png'),
        'https://cdn.example.com/files/avatar.png',
      );
    });

    test(
      'rewrites self-hosted minio download urls onto the configured base host',
      () {
        expect(
          ApiConfig.resolveMediaUrl(
            'https://infoequity.cn/minio/chat/1/u_self/demo.png?download=0',
          ),
          '${ApiConfig.baseUrl}/minio/chat/1/u_self/demo.png?download=0',
        );
      },
    );

    test('keeps relative minio paths outside the v1 api namespace', () {
      expect(
        ApiConfig.resolveMediaUrl('/minio/chat/1/u_self/demo.png?download=0'),
        '${ApiConfig.baseUrl}/minio/chat/1/u_self/demo.png?download=0',
      );
      expect(
        ApiConfig.resolveMediaUrl('minio/chat/1/u_self/demo.png'),
        '${ApiConfig.baseUrl}/minio/chat/1/u_self/demo.png',
      );
    });

    test('maps raw object storage media paths onto the minio edge path', () {
      expect(
        ApiConfig.resolveMediaUrl('chat/1/u_self/demo.png'),
        '${ApiConfig.baseUrl}/minio/chat/1/u_self/demo.png',
      );
      expect(
        ApiConfig.resolveMediaUrl('/common/avatar/u_self.png'),
        '${ApiConfig.baseUrl}/minio/common/avatar/u_self.png',
      );
    });

    test(
      'maps self-hosted preview urls onto the local minio tunnel in desktop tunnel mode',
      () async {
        SharedPreferences.setMockInitialValues(<String, Object>{});
        await StorageUtils.init();
        await StorageUtils.setString(
          AppConstants.keyAuthLoginApiBaseUrl,
          ApiConfig.windowsDesktopTunnelBaseUrl,
        );

        expect(
          ApiConfig.resolveMediaUrl(
            'https://infoequity.cn/v1/file/preview/chat/1/u_self/demo.png?download=0',
          ),
          'http://127.0.0.1:15002/chat/1/u_self/demo.png?download=0',
        );

        await StorageUtils.remove(AppConstants.keyAuthLoginApiBaseUrl);
      },
    );

    test(
      'maps local API preview urls onto the local minio tunnel in desktop tunnel mode',
      () async {
        SharedPreferences.setMockInitialValues(<String, Object>{});
        await StorageUtils.init();
        await StorageUtils.setString(
          AppConstants.keyAuthLoginApiBaseUrl,
          ApiConfig.windowsDesktopTunnelBaseUrl,
        );

        expect(
          ApiConfig.resolveMediaUrl(
            'http://127.0.0.1:15001/v1/file/preview/chat/1/u_self/demo.png',
          ),
          'http://127.0.0.1:15002/chat/1/u_self/demo.png',
        );

        await StorageUtils.remove(AppConstants.keyAuthLoginApiBaseUrl);
      },
    );

    test(
      'maps self-hosted minio urls onto the local minio tunnel in desktop tunnel mode',
      () async {
        SharedPreferences.setMockInitialValues(<String, Object>{});
        await StorageUtils.init();
        await StorageUtils.setString(
          AppConstants.keyAuthLoginApiBaseUrl,
          ApiConfig.windowsDesktopTunnelBaseUrl,
        );

        expect(
          ApiConfig.resolveMediaUrl(
            'https://infoequity.cn/minio/chat/1/u_self/demo.png?download=0',
          ),
          'http://127.0.0.1:15002/chat/1/u_self/demo.png?download=0',
        );

        await StorageUtils.remove(AppConstants.keyAuthLoginApiBaseUrl);
      },
    );

    test(
      'maps relative preview urls onto the local minio tunnel in desktop tunnel mode',
      () async {
        SharedPreferences.setMockInitialValues(<String, Object>{});
        await StorageUtils.init();
        await StorageUtils.setString(
          AppConstants.keyAuthLoginApiBaseUrl,
          ApiConfig.windowsDesktopTunnelBaseUrl,
        );

        expect(
          ApiConfig.resolveMediaUrl(
            '/v1/file/preview/chat/1/u_self/demo.png?download=0',
          ),
          'http://127.0.0.1:15002/chat/1/u_self/demo.png?download=0',
        );

        await StorageUtils.remove(AppConstants.keyAuthLoginApiBaseUrl);
      },
    );
  });

  group('ApiConfig.normalizeUploadUrl', () {
    test(
      'rewrites backend upload urls onto the configured base host when needed',
      () {
        expect(
          ApiConfig.normalizeUploadUrl(
            'https://infoequity.cn/v1/file/upload?type=chat&path=/1/u_self/demo.png',
          ),
          '${ApiConfig.baseUrl}/v1/file/upload?type=chat&path=/1/u_self/demo.png',
        );
      },
    );

    test('keeps unrelated absolute urls unchanged', () {
      expect(
        ApiConfig.normalizeUploadUrl('https://cdn.example.com/files/demo.png'),
        'https://cdn.example.com/files/demo.png',
      );
    });
  });
}
