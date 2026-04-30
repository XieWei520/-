import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wukong_im_app/data/repositories/file_api_repository.dart';
import 'package:wukong_im_app/data/repositories/repository_providers.dart';
import 'package:wukong_im_app/data/repositories/wk_message_repository.dart';

void main() {
  test('repository providers expose default production adapters', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    expect(
      container.read(messageRepositoryProvider),
      isA<WkMessageRepository>(),
    );
    expect(container.read(fileRepositoryProvider), isA<FileApiRepository>());
    expect(
      container.read(clientPlatformCapabilitiesProvider).platformFamily,
      isNotEmpty,
    );
  });
}
