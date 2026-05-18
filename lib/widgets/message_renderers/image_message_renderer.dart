import 'package:flutter/material.dart';
import 'package:wukongimfluttersdk/model/wk_image_content.dart';

import '../../core/cache/media_cache_manager.dart';
import '../../core/config/api_config.dart';
import '../local_media_image_provider.dart';
import '../message_media_helpers.dart';
import '../message_renderer.dart';
import '../wk_design_tokens.dart';

class ImageMessageRenderer implements MessageRenderer {
  const ImageMessageRenderer();

  @override
  Widget build(BuildContext context, MessageRenderContext renderContext) {
    final message = renderContext.message;
    var url = '';
    var localPath = '';
    var intrinsicWidth = 0;
    var intrinsicHeight = 0;
    if (message.messageContent is WKImageContent) {
      final content = message.messageContent as WKImageContent;
      url = ApiConfig.resolveMediaUrl(content.url);
      localPath = content.localPath.trim();
      intrinsicWidth = content.width;
      intrinsicHeight = content.height;
    }
    if (url.isEmpty && isRemoteMediaPath(localPath)) {
      url = ApiConfig.resolveMediaUrl(localPath);
      localPath = '';
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final mediaSize = resolveAdaptiveMediaSize(
          constraints,
          preferredWidth: 200,
          preferredHeight: 200,
        );
        if (url.isEmpty && !isLocalMediaPath(localPath)) {
          return mediaFallback(
            icon: Icons.broken_image_outlined,
            width: mediaSize.width,
            height: mediaSize.height,
          );
        }
        final decodeRequest = resolveChatListMediaDecodeRequest(
          devicePixelRatio: MediaQuery.devicePixelRatioOf(context),
          logicalWidth: mediaSize.width,
          logicalHeight: mediaSize.height,
          intrinsicWidth: intrinsicWidth,
          intrinsicHeight: intrinsicHeight,
        );

        Widget buildRemoteImage() {
          if (url.isEmpty) {
            return mediaFallback(
              icon: Icons.broken_image_outlined,
              width: mediaSize.width,
              height: mediaSize.height,
            );
          }
          return CachedMediaImage(
            imageUrl: url,
            cacheKey: url,
            width: mediaSize.width,
            height: mediaSize.height,
            maxWidth: decodeRequest.cacheWidth,
            maxHeight: decodeRequest.cacheHeight,
            fit: BoxFit.cover,
            errorWidget: (context, url, error) => mediaFallback(
              icon: Icons.broken_image_outlined,
              width: mediaSize.width,
              height: mediaSize.height,
            ),
            placeholder: (context, url) => mediaFallback(
              width: mediaSize.width,
              height: mediaSize.height,
              child: const CircularProgressIndicator(),
            ),
          );
        }

        final localImageProvider = isLocalMediaPath(localPath)
            ? resolveLocalMediaImageProvider(localPath)
            : null;

        return ClipRRect(
          borderRadius: BorderRadius.circular(WKRadius.md),
          child: localImageProvider != null
              ? Image(
                  image: ResizeImage.resizeIfNeeded(
                    decodeRequest.cacheWidth,
                    decodeRequest.cacheHeight,
                    localImageProvider,
                  ),
                  width: mediaSize.width,
                  height: mediaSize.height,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) =>
                      buildRemoteImage(),
                )
              : buildRemoteImage(),
        );
      },
    );
  }
}
