import 'package:flutter/material.dart';

import 'wk_colors.dart';
import 'wk_design_tokens.dart';
import 'wk_reference_assets.dart';

class WKScreenPopupMenuItem<T> {
  final T value;
  final String title;
  final String? assetIcon;
  final IconData? icon;
  final Color? color;
  final bool enabled;

  const WKScreenPopupMenuItem({
    required this.value,
    required this.title,
    this.assetIcon,
    this.icon,
    this.color,
    this.enabled = true,
  }) : assert(
         assetIcon != null || icon != null,
         'WKScreenPopupMenuItem requires an icon.',
       );
}

Future<T?> showWKScreenPopupMenu<T>({
  required BuildContext context,
  required BuildContext anchorContext,
  required List<WKScreenPopupMenuItem<T>> items,
}) async {
  final overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
  final anchor = anchorContext.findRenderObject() as RenderBox;
  final offset = anchor.localToGlobal(Offset.zero, ancestor: overlay);
  final position = RelativeRect.fromLTRB(
    offset.dx - 150 + anchor.size.width,
    offset.dy + (anchor.size.height * 0.3),
    overlay.size.width - (offset.dx + anchor.size.width) + 15,
    overlay.size.height - offset.dy,
  );

  return showMenu<T>(
    context: context,
    position: position,
    color: WKColors.surface,
    elevation: 8,
    surfaceTintColor: Colors.transparent,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    items: [
      for (final item in items)
        PopupMenuItem<T>(
          value: item.value,
          enabled: item.enabled,
          padding: EdgeInsets.zero,
          height: 48,
          child: _WKScreenPopupMenuRow(item: item),
        ),
    ],
  );
}

class _WKScreenPopupMenuRow<T> extends StatelessWidget {
  final WKScreenPopupMenuItem<T> item;

  const _WKScreenPopupMenuRow({required this.item});

  @override
  Widget build(BuildContext context) {
    final color = item.enabled
        ? (item.color ?? WKColors.colorDark)
        : WKColors.textTertiary;

    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 150, maxWidth: 240),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 15),
        child: Row(
          children: [
            if (item.assetIcon != null)
              WKReferenceAssets.image(
                item.assetIcon!,
                width: 20,
                height: 20,
                tint: color,
              )
            else
              Icon(item.icon, size: 20, color: color),
            const SizedBox(width: 12),
            Flexible(
              child: Text(
                item.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: WKFontFamily.primary,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: color,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
