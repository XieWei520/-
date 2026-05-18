import 'package:flutter/material.dart';

import '../../widgets/wk_colors.dart';
import '../../widgets/wk_design_tokens.dart';
import 'monitor_center_section_models.dart';

class MonitorCenterStatusSection extends StatelessWidget {
  const MonitorCenterStatusSection({super.key, required this.data});

  final MonitorCenterStatusViewData data;

  @override
  Widget build(BuildContext context) {
    return _MonitorCenterCard(
      title: '运行状态',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _StatusLine('壳状态', data.shellState),
          _StatusLine('登录状态', data.loginState),
          _StatusLine('捕获状态', data.captureState),
          for (final line in data.summaryLines)
            Padding(
              padding: const EdgeInsets.only(top: WKSpace.xs),
              child: Text(line),
            ),
        ],
      ),
    );
  }
}

class _StatusLine extends StatelessWidget {
  const _StatusLine(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: WKSpace.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 76,
            child: Text(
              label,
              style: const TextStyle(color: WKColors.color999),
            ),
          ),
          Expanded(child: Text(value.trim().isEmpty ? '-' : value)),
        ],
      ),
    );
  }
}

class _MonitorCenterCard extends StatelessWidget {
  const _MonitorCenterCard({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(WKSpace.lg),
      decoration: BoxDecoration(
        color: WKColors.surface,
        borderRadius: BorderRadius.circular(WKRadius.lg),
        boxShadow: WKShadows.soft,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: WKColors.colorDark,
            ),
          ),
          const SizedBox(height: WKSpace.sm),
          child,
        ],
      ),
    );
  }
}
