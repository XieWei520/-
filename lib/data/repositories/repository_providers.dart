import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/platform/platform_capabilities.dart';
import '../../core/repositories/file_repository.dart';
import '../../core/repositories/message_repository.dart';
import 'file_api_repository.dart';
import 'wk_message_repository.dart';

final messageRepositoryProvider = Provider<MessageRepository>(
  (ref) => WkMessageRepository(),
);

final fileRepositoryProvider = Provider<FileRepository>(
  (ref) => FileApiRepository(),
);

final clientPlatformCapabilitiesProvider = Provider<ClientPlatformCapabilities>(
  (ref) => defaultPlatformCapabilities(),
);
