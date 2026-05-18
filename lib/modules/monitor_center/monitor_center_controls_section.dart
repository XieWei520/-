import 'package:flutter/material.dart';

import '../../widgets/wk_colors.dart';
import '../../widgets/wk_design_tokens.dart';
import 'monitor_center_section_models.dart';

class MonitorCenterControlsSection extends StatelessWidget {
  const MonitorCenterControlsSection({super.key, required this.data});

  final MonitorCenterControlsViewData data;

  @override
  Widget build(BuildContext context) {
    return _MonitorCenterCard(
      title: '运行控制',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(data.loginHint),
          const SizedBox(height: WKSpace.sm),
          Wrap(
            spacing: WKSpace.sm,
            runSpacing: WKSpace.xs,
            children: [
              OutlinedButton(
                onPressed: data.onStart,
                child: Text(data.startLabel),
              ),
              OutlinedButton(
                onPressed: data.onStop,
                child: Text(data.stopLabel),
              ),
              OutlinedButton(
                onPressed: data.onReload,
                child: Text(data.reloadLabel),
              ),
            ],
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
