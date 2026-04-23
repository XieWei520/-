import 'package:flutter/material.dart';

import 'wk_colors.dart';
import 'wk_design_tokens.dart';
import 'wk_reference_assets.dart';

class WKDialog extends StatelessWidget {
  final String title;
  final String content;
  final String? cancelText;
  final String? confirmText;
  final VoidCallback? onCancel;
  final VoidCallback? onConfirm;
  final bool showCancel;
  final Color confirmTextColor;

  const WKDialog({
    super.key,
    required this.title,
    required this.content,
    this.cancelText = '取消',
    this.confirmText = '确定',
    this.onCancel,
    this.onConfirm,
    this.showCancel = true,
    this.confirmTextColor = WKColors.brand500,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 30),
      child: Container(
        decoration: BoxDecoration(
          color: WKColors.surface,
          borderRadius: BorderRadius.circular(14),
        ),
        padding: const EdgeInsets.fromLTRB(22, 22, 22, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: WKFontFamily.title,
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: WKColors.colorDark,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              content,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: WKFontFamily.primary,
                fontSize: 15,
                height: 1.5,
                color: WKColors.dialogText,
              ),
            ),
            const SizedBox(height: 18),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (showCancel)
                  _WKDialogTextButton(
                    label: cancelText ?? '取消',
                    color: WKColors.color999,
                    onTap: () {
                      Navigator.of(context).pop(false);
                      onCancel?.call();
                    },
                  ),
                _WKDialogTextButton(
                  label: confirmText ?? '确定',
                  color: confirmTextColor,
                  onTap: () {
                    Navigator.of(context).pop(true);
                    onConfirm?.call();
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _WKDialogTextButton extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _WKDialogTextButton({
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Text(
            label,
            style: TextStyle(
              fontFamily: WKFontFamily.primary,
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: color,
            ),
          ),
        ),
      ),
    );
  }
}

Future<bool?> showWKConfirmDialog({
  required BuildContext context,
  required String title,
  required String content,
  String cancelText = '取消',
  String confirmText = '确定',
  bool showCancel = true,
  Color confirmTextColor = WKColors.brand500,
}) {
  return showDialog<bool>(
    context: context,
    builder: (dialogContext) => WKDialog(
      title: title,
      content: content,
      cancelText: cancelText,
      confirmText: confirmText,
      showCancel: showCancel,
      confirmTextColor: confirmTextColor,
    ),
  );
}

class WKBottomSheetItem {
  final String title;
  final String? assetIcon;
  final IconData? icon;
  final Color? color;
  final bool enabled;
  final VoidCallback? onTap;

  const WKBottomSheetItem({
    required this.title,
    this.assetIcon,
    this.icon,
    this.color,
    this.enabled = true,
    this.onTap,
  }) : assert(
         assetIcon != null || icon != null,
         'WKBottomSheetItem requires an icon.',
       );
}

class WKBottomSheet extends StatelessWidget {
  final String? title;
  final List<WKBottomSheetItem> items;
  final bool showCancel;
  final String cancelText;
  final VoidCallback? onCancel;

  const WKBottomSheet({
    super.key,
    this.title,
    required this.items,
    this.showCancel = true,
    this.cancelText = '取消',
    this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        decoration: const BoxDecoration(
          color: WKColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(
              width: 50,
              height: 3,
              decoration: BoxDecoration(
                color: WKColors.bottomDrawerHandle,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            if (title != null) ...[
              const SizedBox(height: 14),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 22),
                child: Text(
                  title!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontFamily: WKFontFamily.primary,
                    fontSize: 14,
                    color: WKColors.color999,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              const Divider(height: 1, thickness: 1, color: WKColors.homeBg),
            ] else
              const SizedBox(height: 10),
            for (final item in items) _WKBottomSheetRow(item: item),
            if (showCancel) ...[
              Container(height: 8, color: WKColors.homeBg),
              _WKBottomSheetCancelRow(
                title: cancelText,
                onTap: () {
                  Navigator.of(context).pop();
                  onCancel?.call();
                },
              ),
            ],
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

class _WKBottomSheetRow extends StatelessWidget {
  final WKBottomSheetItem item;

  const _WKBottomSheetRow({required this.item});

  @override
  Widget build(BuildContext context) {
    final color = item.enabled
        ? (item.color ?? WKColors.colorDark)
        : WKColors.textTertiary;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: item.enabled
            ? () {
                Navigator.of(context).pop();
                item.onTap?.call();
              }
            : null,
        child: SizedBox(
          height: 56,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                if (item.assetIcon != null)
                  WKReferenceAssets.image(
                    item.assetIcon!,
                    width: 22,
                    height: 22,
                    tint: color,
                  )
                else
                  Icon(item.icon, size: 22, color: color),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    item.title,
                    style: TextStyle(
                      fontFamily: WKFontFamily.primary,
                      fontSize: 16,
                      color: color,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _WKBottomSheetCancelRow extends StatelessWidget {
  final String title;
  final VoidCallback onTap;

  const _WKBottomSheetCancelRow({required this.title, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          height: 56,
          child: Center(
            child: Text(
              title,
              style: const TextStyle(
                fontFamily: WKFontFamily.primary,
                fontSize: 17,
                color: WKColors.colorDark,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

void showWKLoadingDialog(BuildContext context, {String message = '加载中...'}) {
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) => WKLoadingDialog(message: message),
  );
}

void hideWKLoadingDialog(BuildContext context) {
  Navigator.of(context, rootNavigator: true).pop();
}

class WKLoadingDialog extends StatelessWidget {
  final String message;

  const WKLoadingDialog({super.key, this.message = '加载中...'});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: WKColors.transparent,
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: WKColors.colorDark.withValues(alpha: 0.82),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(
                strokeWidth: 2.2,
                valueColor: AlwaysStoppedAnimation<Color>(WKColors.white),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              message,
              style: const TextStyle(
                fontFamily: WKFontFamily.primary,
                fontSize: 14,
                color: WKColors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
