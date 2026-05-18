import 'dart:typed_data';

import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wukong_im_app/modules/chat/chat_desktop_drop_target.dart';
import 'package:wukong_im_app/widgets/liquid_glass_tokens.dart';

void main() {
  test('maps desktop dropped files to chat dropped file selections', () async {
    final selections = await mapDesktopDropItemsToChatFiles([
      DropItemFile.fromData(
        Uint8List(2048),
        path: ' C:/drop/photo.png ',
        name: ' photo.png ',
        mimeType: 'image/png',
      ),
      DropItemDirectory('C:/drop/folder', const []),
      DropItemFile.fromData(
        Uint8List(8192),
        path: 'C:/drop/spec.pdf',
        name: '',
        mimeType: 'application/pdf',
      ),
    ]);

    expect(selections, hasLength(2));
    expect(selections[0].localPath, 'C:/drop/photo.png');
    expect(selections[0].name, 'photo.png');
    expect(selections[0].mimeType, 'image/png');
    expect(selections[0].size, 2048);
    expect(selections[1].localPath, 'C:/drop/spec.pdf');
    expect(selections[1].name, 'spec.pdf');
    expect(selections[1].mimeType, 'application/pdf');
    expect(selections[1].size, 8192);
  });

  test('skips dropped files whose metadata cannot be read', () async {
    final selections = await mapDesktopDropItemsToChatFiles([
      DropItemFile.fromData(
        Uint8List(128),
        path: 'C:/drop/ok-before.txt',
        name: 'ok-before.txt',
      ),
      DropItemFile(
        'C:/definitely-missing-wukong-drop/ghost.dat',
        name: 'ghost.dat',
      ),
      DropItemFile.fromData(
        Uint8List(256),
        path: 'C:/drop/ok-after.txt',
        name: 'ok-after.txt',
      ),
    ]);

    expect(selections.map((selection) => selection.name), <String>[
      'ok-before.txt',
      'ok-after.txt',
    ]);
    expect(selections.map((selection) => selection.size), <int>[128, 256]);
  });

  testWidgets('disabled desktop drop target skips the platform DropTarget', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ChatDesktopDropTarget(
          enabled: false,
          onFilesDropped: (_) {},
          child: const Text('Chat body'),
        ),
      ),
    );

    expect(find.text('Chat body'), findsOneWidget);
    expect(find.byType(DropTarget), findsNothing);
  });

  testWidgets('desktop drop overlay uses liquid glass prompt styling', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Stack(children: <Widget>[ChatDesktopDropOverlayForTesting()]),
        ),
      ),
    );

    final overlay = tester.widget<DecoratedBox>(
      find.byKey(const ValueKey<String>('chat-desktop-drop-overlay')),
    );
    final decoration = overlay.decoration as BoxDecoration;
    final border = decoration.border as Border;

    expect(
      decoration.color,
      LiquidGlassColors.primary2.withValues(alpha: 0.08),
    );
    expect(decoration.borderRadius, LiquidGlassRadii.xl);
    expect(border.top.color, LiquidGlassColors.primary2);
    expect(find.text('释放文件即可发送'), findsOneWidget);
  });
}
