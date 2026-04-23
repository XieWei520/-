import 'package:flutter/material.dart';
import 'package:wukong_im_app/widgets/wk_colors.dart';
import 'package:wukong_im_app/widgets/wk_design_tokens.dart';
import 'package:wukong_im_app/widgets/wk_reference_assets.dart';

class GlobalSearchFindUserRow extends StatelessWidget {
  const GlobalSearchFindUserRow({
    super.key,
    required this.keyword,
    required this.onTap,
  });

  final String keyword;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: WKColors.surface,
      child: InkWell(
        key: const ValueKey<String>('global-search-find-user'),
        onTap: onTap,
        highlightColor: WKColors.screenBgSelected,
        splashColor: WKColors.screenBgSelected,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
          child: Row(
            children: [
              WKReferenceAssets.image(
                WKReferenceAssets.newFriend,
                width: 40,
                height: 40,
              ),
              const SizedBox(width: 10),
              const Text(
                'Find user:',
                style: TextStyle(
                  fontFamily: WKFontFamily.primary,
                  fontSize: 16,
                  color: WKColors.colorDark,
                ),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  keyword,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: WKFontFamily.primary,
                    fontSize: 14,
                    color: WKColors.brand500,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
