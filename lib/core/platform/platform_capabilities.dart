import 'package:flutter/foundation.dart';

class ClientPlatformCapabilities {
  const ClientPlatformCapabilities({
    required this.platformFamily,
    required this.supportsLocalSqlite,
    required this.supportsIndexedDbCache,
    required this.supportsSystemTray,
    required this.supportsDragDrop,
    required this.supportsBrowserNotification,
  });

  final String platformFamily;
  final bool supportsLocalSqlite;
  final bool supportsIndexedDbCache;
  final bool supportsSystemTray;
  final bool supportsDragDrop;
  final bool supportsBrowserNotification;
}

ClientPlatformCapabilities defaultPlatformCapabilities() {
  if (kIsWeb) {
    return const ClientPlatformCapabilities(
      platformFamily: 'web',
      supportsLocalSqlite: false,
      supportsIndexedDbCache: true,
      supportsSystemTray: false,
      supportsDragDrop: true,
      supportsBrowserNotification: true,
    );
  }

  return switch (defaultTargetPlatform) {
    TargetPlatform.android => const ClientPlatformCapabilities(
      platformFamily: 'android',
      supportsLocalSqlite: true,
      supportsIndexedDbCache: false,
      supportsSystemTray: false,
      supportsDragDrop: false,
      supportsBrowserNotification: false,
    ),
    TargetPlatform.iOS => const ClientPlatformCapabilities(
      platformFamily: 'ios',
      supportsLocalSqlite: true,
      supportsIndexedDbCache: false,
      supportsSystemTray: false,
      supportsDragDrop: false,
      supportsBrowserNotification: false,
    ),
    TargetPlatform.macOS => const ClientPlatformCapabilities(
      platformFamily: 'macos',
      supportsLocalSqlite: true,
      supportsIndexedDbCache: false,
      supportsSystemTray: true,
      supportsDragDrop: true,
      supportsBrowserNotification: false,
    ),
    TargetPlatform.windows => const ClientPlatformCapabilities(
      platformFamily: 'windows',
      supportsLocalSqlite: true,
      supportsIndexedDbCache: false,
      supportsSystemTray: true,
      supportsDragDrop: true,
      supportsBrowserNotification: false,
    ),
    TargetPlatform.linux => const ClientPlatformCapabilities(
      platformFamily: 'linux',
      supportsLocalSqlite: true,
      supportsIndexedDbCache: false,
      supportsSystemTray: true,
      supportsDragDrop: true,
      supportsBrowserNotification: false,
    ),
    TargetPlatform.fuchsia => const ClientPlatformCapabilities(
      platformFamily: 'fuchsia',
      supportsLocalSqlite: true,
      supportsIndexedDbCache: false,
      supportsSystemTray: false,
      supportsDragDrop: false,
      supportsBrowserNotification: false,
    ),
  };
}
