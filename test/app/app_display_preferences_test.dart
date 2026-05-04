import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wukong_im_app/app/app_display_preferences.dart';
import 'package:wukong_im_app/core/utils/storage_utils.dart';
import 'package:wukong_im_app/wukong_uikit/setting/setting_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await StorageUtils.init();
  });

  testWidgets(
    'AppDisplayPreferences applies the stored font scale to descendant MediaQuery text scaling',
    (tester) async {
      await WKSettingPreferences.setFontScale(1.25);

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: AppDisplayPreferences(child: _ScaleProbe())),
        ),
      );

      expect(find.text('20.0'), findsOneWidget);
    },
  );
}

class _ScaleProbe extends StatelessWidget {
  const _ScaleProbe();

  @override
  Widget build(BuildContext context) {
    final scaled = MediaQuery.textScalerOf(context).scale(16);
    return Text(scaled.toStringAsFixed(1));
  }
}
