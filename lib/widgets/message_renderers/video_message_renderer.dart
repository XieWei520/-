import 'package:flutter/material.dart';
import 'package:wukongimfluttersdk/model/wk_video_content.dart';

import '../../core/cache/media_cache_manager.dart';
import '../../core/config/api_config.dart';
import '../message_media_helpers.dart';
import '../message_renderer.dart';
import '../wk_colors.dart';
import '../wk_design_tokens.dart';

class VideoMessageRenderer implements MessageRenderer {
  const VideoMessageRenderer();

  @override
  Widget build(BuildContext context, MessageRenderContext renderContext) {
    final message = renderContext.message;
    var cover = '';
    var intrinsicWidth = 0;
    var intrinsicHeight = 0;
    if (message.messageContent is WKVideoContent) {
      final content = message.messageContent as WKVideoContent;
      cover = ApiConfig.resolveMediaUrl(content.cover);
      intrinsicWidth = content.width;
      intrinsicHeight = content.height;
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final mediaSize = resolveAdaptiveMediaSize(
          constraints,
          preferredWidth: 200,
          preferredHeight: 150,
        );
        final decodeRequest = resolveChatListMediaDecodeRequest(
          devicePixelRatio: MediaQuery.devicePixelRatioOf(context),
          logicalWidth: mediaSize.width,
          logicalHeight: mediaSize.height,
          intrinsicWidth: intrinsicWidth,
          intrinsicHeight: intrinsicHeight,
        );

        return Stack(
          alignment: Alignment.center,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(WKRadius.md),
              child: cover.isNotEmpty
                  ? CachedMediaImage(
                      imageUrl: cover,
                      cacheKey: cover,
                      width: mediaSize.width,
                      height: mediaSize.height,
                      maxWidth: decodeRequest.cacheWidth,
                      maxHeight: decodeRequest.cacheHeight,
                      fit: BoxFit.cover,
                      errorWidget: (context, url, error) => mediaFallback(
                        icon: Icons.videocam_rounded,
                        width: mediaSize.width,
                        height: mediaSize.height,
                        backgroundColor: WKColors.textSecondary,
                        iconColor: WKColors.white.withValues(alpha: 0.72),
                      ),
                      placeholder: (context, url) => mediaFallback(
                        width: mediaSize.width,
                        height: mediaSize.height,
                        backgroundColor: WKColors.textSecondary,
                        child: const CircularProgressIndicator(),
                      ),
                    )
                  : mediaFallback(
                      icon: Icons.videocam_rounded,
                      width: mediaSize.width,
                      height: mediaSize.height,
                      backgroundColor: WKColors.textSecondary,
                      iconColor: WKColors.white.withValues(alpha: 0.72),
                    ),
            ),
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: WKColors.black.withValues(alpha: 0.42),
                borderRadius: BorderRadius.circular(WKRadius.pill),
              ),
              child: const Icon(
                Icons.play_arrow_rounded,
                color: WKColors.white,
                size: 24,
              ),
            ),
          ],
        );
      },
    );
  }
}
