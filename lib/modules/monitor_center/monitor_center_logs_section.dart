import 'package:flutter/material.dart';

import '../../widgets/wk_colors.dart';
import '../../widgets/wk_design_tokens.dart';
import 'monitor_center_section_models.dart';

class MonitorCenterLogsSection extends StatelessWidget {
  const MonitorCenterLogsSection({super.key, required this.data});

  final MonitorCenterLogsViewData data;

  @override
  Widget build(BuildContext context) {
    final lines = data.logLines;
    return _MonitorCenterCard(
      title: '最近事件',
      child: lines.isEmpty
          ? Text(
              data.emptyHint,
              style: const TextStyle(color: WKColors.color999),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final line in lines)
                  Padding(
                    padding: const EdgeInsets.only(bottom: WKSpace.xs),
                    child: Text(line),
                  ),
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
