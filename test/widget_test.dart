import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wukong_im_app/main.dart';
import 'package:wukong_im_app/data/providers/runtime_capabilities_provider.dart';
import 'package:wukong_im_app/service/api/common_api.dart';

void main() {
  testWidgets('WuKongIM app starts', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          runtimeCapabilitiesProvider.overrideWith(
            (ref) async => const AppRuntimeCapabilities(
              webLoginUrl: '',
              webLoginReachable: false,
              webLoginStatusMessage: 'Test override',
            ),
          ),
        ],
        child: const WuKongIMApp(),
      ),
    );

    // Verify that app starts
    await tester.pump();
  });
}
