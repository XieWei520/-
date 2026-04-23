import 'package:flutter/material.dart';

import 'wk_button.dart';
import 'wk_colors.dart';
import 'wk_design_tokens.dart';

class WKEmptyView extends StatelessWidget {
  final IconData? icon;
  final String message;
  final String? subMessage;
  final VoidCallback? onRefresh;
  final double? iconSize;

  const WKEmptyView({
    super.key,
    this.icon,
    this.message = '暂无数据',
    this.subMessage,
    this.onRefresh,
    this.iconSize,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(WKSpace.xxl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                color: WKColors.surfaceSoft,
                shape: BoxShape.circle,
                border: Border.all(color: WKColors.outline),
              ),
              child: Icon(
                icon ?? Icons.inbox_outlined,
                size: iconSize ?? 40,
                color: WKColors.textTertiary,
              ),
            ),
            const SizedBox(height: WKSpace.lg),
            Text(message, style: textTheme.titleMedium),
            if (subMessage != null) ...[
              const SizedBox(height: WKSpace.xs),
              Text(
                subMessage!,
                textAlign: TextAlign.center,
                style: textTheme.bodyMedium,
              ),
            ],
            if (onRefresh != null) ...[
              const SizedBox(height: WKSpace.xl),
              SizedBox(
                width: 160,
                child: WKButton(
                  text: '刷新',
                  onPressed: onRefresh,
                  leading: const Icon(Icons.refresh, size: 18),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class WKLoadingView extends StatelessWidget {
  final String? message;
  final Color? color;

  const WKLoadingView({super.key, this.message, this.color});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: color),
          if (message != null) ...[
            const SizedBox(height: WKSpace.md),
            Text(message!, style: textTheme.bodyMedium),
          ],
        ],
      ),
    );
  }
}

class WKErrorView extends StatelessWidget {
  final String message;
  final String? subMessage;
  final VoidCallback? onRetry;

  const WKErrorView({
    super.key,
    this.message = '加载失败',
    this.subMessage,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(WKSpace.xxl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                color: const Color(0xFFFDECEC),
                shape: BoxShape.circle,
                border: Border.all(
                  color: WKColors.danger.withValues(alpha: 0.16),
                ),
              ),
              child: const Icon(
                Icons.error_outline_rounded,
                size: 40,
                color: WKColors.danger,
              ),
            ),
            const SizedBox(height: WKSpace.lg),
            Text(message, style: textTheme.titleMedium),
            if (subMessage != null) ...[
              const SizedBox(height: WKSpace.xs),
              Text(
                subMessage!,
                textAlign: TextAlign.center,
                style: textTheme.bodyMedium,
              ),
            ],
            if (onRetry != null) ...[
              const SizedBox(height: WKSpace.xl),
              SizedBox(
                width: 160,
                child: WKButton(
                  text: '重试',
                  onPressed: onRetry,
                  leading: const Icon(Icons.refresh, size: 18),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class WKRefreshIndicator extends StatelessWidget {
  const WKRefreshIndicator({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(child: CircularProgressIndicator());
  }
}
