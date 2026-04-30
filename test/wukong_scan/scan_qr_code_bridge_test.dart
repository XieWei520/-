import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wukong_im_app/wukong_base/endpoint/entity/scan_result_menu.dart';
import 'package:wukong_im_app/wukong_base/endpoint/endpoint_manager.dart';
import 'package:wukong_im_app/wukong_base/endpoint/menu/endpoint_menu.dart';
import 'package:wukong_im_app/wukong_scan/scan_qr_code_bridge.dart';
import 'package:wukong_im_app/wukong_scan/scan_result_page.dart';
import 'package:wukong_im_app/wukong_scan/scan_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    EndpointManager.getInstance().clear();
  });

  tearDown(() {
    EndpointManager.getInstance().clear();
  });

  test(
    'parse_qr_code bridge returns parsed content through callback',
    () async {
      final bridge = ScanQrCodeBridge(
        endpointManager: EndpointManager.getInstance(),
        analyzeImageBytes: (_) async => 'https://example.com/parsed',
        processScanResult: (content) async =>
            ScanServiceResult.rawText(content),
      )..ensureRegistered();

      String? parsedContent;
      final result = await EndpointManager.getInstance().invoke(
        ChatMenuIDs.parseQrCode,
        ParseQrCodeMenu(
          isJump: false,
          imageBytes: Uint8List.fromList(<int>[1, 2, 3]),
          onResult: (codeContent) {
            parsedContent = codeContent;
          },
        ),
      );

      expect(parsedContent, 'https://example.com/parsed');
      expect(result, 'https://example.com/parsed');
      expect(bridge.isRegistered, isTrue);
    },
  );

  test('ScanQrCodeBridge source does not import dart io directly', () {
    final source = File(
      'lib/wukong_scan/scan_qr_code_bridge.dart',
    ).readAsStringSync();

    expect(source, isNot(contains("import 'dart:io'")));
  });

  testWidgets('parse_qr_code bridge routes jump requests to ScanResultPage', (
    tester,
  ) async {
    final navigatorKey = GlobalKey<NavigatorState>();
    ScanQrCodeBridge(
        endpointManager: EndpointManager.getInstance(),
        analyzeImageBytes: (_) async => 'resolved-qr-content',
        processScanResult: (_) async =>
            ScanServiceResult.fromJson(<String, dynamic>{
              'forward': 'native',
              'type': 'group',
              'data': <String, dynamic>{'group_no': 'g_1001'},
            }, 'resolved-qr-content'),
      )
      ..bindNavigator(navigatorKey)
      ..ensureRegistered();

    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigatorKey,
        home: const Scaffold(body: Text('root')),
      ),
    );

    await EndpointManager.getInstance().invoke(
      ChatMenuIDs.parseQrCode,
      ParseQrCodeMenu(
        isJump: true,
        imageBytes: Uint8List.fromList(<int>[1, 2, 3]),
      ),
    );
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.byType(ScanResultPage), findsOneWidget);
    expect(
      find.byKey(const ValueKey('scan_group_chat_button')),
      findsOneWidget,
    );
  });
}
