import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wukong_im_app/widgets/wk_sub_page_scaffold.dart';

void main() {
  testWidgets('WKSettingsCell pins trailing controls to the row edge', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1000, 360);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: WKSettingsCell(
            title: 'Enable robot',
            showArrow: false,
            trailing: SizedBox(
              key: ValueKey('trailing-switch-slot'),
              width: 45,
              height: 40,
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    final cellRight = tester.getTopRight(find.byType(WKSettingsCell)).dx;
    final trailingRight = tester
        .getTopRight(find.byKey(const ValueKey('trailing-switch-slot')))
        .dx;

    expect(cellRight - trailingRight, lessThanOrEqualTo(16));
    expect(tester.takeException(), isNull);
  });

  testWidgets('WKSettingsCell constrains long custom trailing content', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(260, 360);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: WKSettingsCell(
            title: 'A very long settings row title',
            showArrow: false,
            trailing: Text(
              'A very long custom trailing value that must be constrained',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.end,
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
  });
}
