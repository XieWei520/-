import 'package:flutter/material.dart';

import '../../widgets/wk_colors.dart';
import '../../widgets/wk_design_tokens.dart';
import 'monitor_center_section_models.dart';

class MonitorCenterRoutesSection extends StatelessWidget {
  const MonitorCenterRoutesSection({super.key, required this.data});

  final MonitorCenterRoutesViewData data;

  @override
  Widget build(BuildContext context) {
    final lines = data.routeLines;
    final actionRows = data.actionRows;
    return _MonitorCenterCard(
      title: '转发路由',
      child: lines.isEmpty && actionRows.isEmpty
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
                if (lines.isNotEmpty && actionRows.isNotEmpty)
                  const Divider(height: WKSpace.lg),
                for (final row in actionRows)
                  Padding(
                    padding: const EdgeInsets.only(bottom: WKSpace.xs),
                    child: _RouteActionRow(row: row),
                  ),
              ],
            ),
    );
  }
}

class _RouteActionRow extends StatelessWidget {
  const _RouteActionRow({required this.row});

  final MonitorCenterRouteActionRow row;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(WKSpace.sm),
      decoration: BoxDecoration(
        color: WKColors.surfaceSoft,
        borderRadius: BorderRadius.circular(WKRadius.md),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  row.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: WKColors.colorDark,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  row.subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    color: WKColors.color999,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: WKSpace.sm),
          TextButton(
            key: row.key,
            onPressed: row.onPressed,
            child: Text(row.actionLabel),
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
