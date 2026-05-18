import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wukong_im_app/modules/monitor_center/monitor_center_page_scaffold.dart';
import 'package:wukong_im_app/modules/monitor_center/monitor_center_section_models.dart';

void main() {
  testWidgets('shared scaffold renders core monitor sections', (tester) async {
    var configured = false;

    await tester.pumpWidget(
      MaterialApp(
        home: MonitorCenterPageScaffold(
          title: 'Test Center',
          status: const MonitorCenterStatusViewData(
            shellState: 'online',
            loginState: 'logged_in',
            captureState: 'running',
            summaryLines: <String>['ok'],
          ),
          routesSection: const MonitorCenterRoutesViewData(
            emptyHint: 'no routes',
            routeLines: <String>['route-a'],
            actionRows: <MonitorCenterRouteActionRow>[
              MonitorCenterRouteActionRow(
                key: ValueKey('route-action-a'),
                title: 'Source A',
                subtitle: 'Not configured',
                actionLabel: 'Configure',
                onPressed: null,
              ),
            ],
          ),
          logsSection: const MonitorCenterLogsViewData(
            logLines: <String>['log-a'],
          ),
          controlsSection: const MonitorCenterControlsViewData(
            startLabel: '启动',
            stopLabel: '停止',
            reloadLabel: '重载',
            loginHint: 'manual login required',
          ),
        ),
      ),
    );

    expect(find.text('Test Center'), findsOneWidget);
    expect(find.text('manual login required'), findsOneWidget);
    expect(find.text('route-a'), findsOneWidget);
    expect(find.text('Source A'), findsOneWidget);
    expect(find.text('Configure'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('log-a'), 200);
    expect(find.text('log-a'), findsOneWidget);

    await tester.pumpWidget(
      MaterialApp(
        home: MonitorCenterPageScaffold(
          title: 'Test Center',
          status: const MonitorCenterStatusViewData(
            shellState: 'online',
            loginState: 'logged_in',
            captureState: 'running',
          ),
          routesSection: MonitorCenterRoutesViewData(
            emptyHint: 'no routes',
            actionRows: <MonitorCenterRouteActionRow>[
              MonitorCenterRouteActionRow(
                key: const ValueKey('route-action-b'),
                title: 'Source B',
                subtitle: 'Ready',
                actionLabel: 'Configure',
                onPressed: () {
                  configured = true;
                },
              ),
            ],
          ),
          logsSection: const MonitorCenterLogsViewData(),
          controlsSection: const MonitorCenterControlsViewData(
            startLabel: '启动',
            stopLabel: '停止',
            reloadLabel: '重载',
            loginHint: 'manual login required',
          ),
        ),
      ),
    );
    await tester.tap(find.byKey(const ValueKey('route-action-b')));

    expect(configured, isTrue);
  });
}
