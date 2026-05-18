import 'package:flutter/material.dart';

@immutable
class MonitorCenterStatusViewData {
  const MonitorCenterStatusViewData({
    required this.shellState,
    required this.loginState,
    required this.captureState,
    this.summaryLines = const <String>[],
  });

  final String shellState;
  final String loginState;
  final String captureState;
  final List<String> summaryLines;
}

@immutable
class MonitorCenterRoutesViewData {
  const MonitorCenterRoutesViewData({
    required this.emptyHint,
    this.routeLines = const <String>[],
    this.actionRows = const <MonitorCenterRouteActionRow>[],
  });

  final String emptyHint;
  final List<String> routeLines;
  final List<MonitorCenterRouteActionRow> actionRows;
}

@immutable
class MonitorCenterRouteActionRow {
  const MonitorCenterRouteActionRow({
    required this.key,
    required this.title,
    required this.subtitle,
    required this.actionLabel,
    required this.onPressed,
  });

  final Key key;
  final String title;
  final String subtitle;
  final String actionLabel;
  final VoidCallback? onPressed;
}

@immutable
class MonitorCenterLogsViewData {
  const MonitorCenterLogsViewData({
    this.logLines = const <String>[],
    this.emptyHint = '暂无日志',
  });

  final List<String> logLines;
  final String emptyHint;
}

@immutable
class MonitorCenterControlsViewData {
  const MonitorCenterControlsViewData({
    required this.startLabel,
    required this.stopLabel,
    required this.reloadLabel,
    required this.loginHint,
    this.onStart,
    this.onStop,
    this.onReload,
  });

  final String startLabel;
  final String stopLabel;
  final String reloadLabel;
  final String loginHint;
  final VoidCallback? onStart;
  final VoidCallback? onStop;
  final VoidCallback? onReload;
}
