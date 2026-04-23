import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wukong_im_app/core/constants/app_constants.dart';
import 'package:wukong_im_app/core/config/api_config.dart';
import 'package:wukong_im_app/core/utils/storage_utils.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ApiConfig defaults', () {
    test('point to the new deployment target by default', () {
      expect(ApiConfig.devBaseUrl, 'http://42.194.218.158');
      expect(ApiConfig.prodBaseUrl, 'http://42.194.218.158');
      expect(ApiConfig.devWsAddr, '42.194.218.158:5100');
      expect(ApiConfig.prodWsAddr, '42.194.218.158:5100');
      expect(ApiConfig.baseUrl, 'http://42.194.218.158');
      expect(ApiConfig.wsAddr, '42.194.218.158:5100');
    });

    test(
      'uses persisted auth login API base URL override when present',
      () async {
        SharedPreferences.setMockInitialValues(<String, Object>{});
        await StorageUtils.init();

        expect(ApiConfig.baseUrl, 'http://42.194.218.158');

        await StorageUtils.setString(
          AppConstants.keyAuthLoginApiBaseUrl,
          'http://127.0.0.1:5001',
        );
        expect(ApiConfig.baseUrl, 'http://127.0.0.1:5001');

        await StorageUtils.remove(AppConstants.keyAuthLoginApiBaseUrl);
        expect(ApiConfig.baseUrl, 'http://42.194.218.158');
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
            'https://wemx.cc/minio/chat/1/u_self/demo.png?download=0',
          ),
          '${ApiConfig.baseUrl}/minio/chat/1/u_self/demo.png?download=0',
        );
      },
    );
  });

  group('ApiConfig.normalizeUploadUrl', () {
    test(
      'rewrites backend upload urls onto the configured base host when needed',
      () {
        expect(
          ApiConfig.normalizeUploadUrl(
            'https://wemx.cc/v1/file/upload?type=chat&path=/1/u_self/demo.png',
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
