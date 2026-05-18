import 'package:flutter/material.dart';

import '../../widgets/wk_design_tokens.dart';
import '../../widgets/wk_sub_page_scaffold.dart';
import 'monitor_center_controls_section.dart';
import 'monitor_center_logs_section.dart';
import 'monitor_center_routes_section.dart';
import 'monitor_center_section_models.dart';
import 'monitor_center_status_section.dart';

class MonitorCenterPageScaffold extends StatelessWidget {
  const MonitorCenterPageScaffold({
    super.key,
    required this.title,
    required this.status,
    required this.routesSection,
    required this.logsSection,
    required this.controlsSection,
    this.trailing,
    this.trailingWidth = 48,
  });

  final String title;
  final MonitorCenterStatusViewData status;
  final MonitorCenterRoutesViewData routesSection;
  final MonitorCenterLogsViewData logsSection;
  final MonitorCenterControlsViewData controlsSection;
  final Widget? trailing;
  final double trailingWidth;

  @override
  Widget build(BuildContext context) {
    return WKSubPageScaffold(
      title: title,
      trailing: trailing,
      trailingWidth: trailingWidth,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
        children: [
          MonitorCenterStatusSection(data: status),
          const SizedBox(height: WKSpace.sm),
          MonitorCenterControlsSection(data: controlsSection),
          const SizedBox(height: WKSpace.sm),
          MonitorCenterRoutesSection(data: routesSection),
          const SizedBox(height: WKSpace.sm),
          MonitorCenterLogsSection(data: logsSection),
        ],
      ),
    );
  }
}
