import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wukong_im_app/modules/video_call/call_notification.dart';
import 'package:wukong_im_app/widgets/wk_web_ui_tokens.dart';

void main() {
  testWidgets(
    'incoming call overlay uses warm Web surface and stable action keys',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Overlay(
            initialEntries: [
              OverlayEntry(
                builder: (context) {
                  return Builder(
                    builder: (context) {
                      return TextButton(
                        onPressed: () {
                          CallNotificationOverlay.instance.showIncomingCall(
                            overlayState: Overlay.of(context),
                            data: CallNotificationData(
                              channelId: 'u_peer',
                              channelName: 'Alice',
                              type: CallNotificationType.incoming,
                              callType: 1,
                            ),
                            onAccept: () {},
                            onReject: () {},
                          );
                        },
                        child: const Text('show'),
                      );
                    },
                  );
                },
              ),
            ],
          ),
        ),
      );

      await tester.tap(find.text('show'));
      await tester.pump();

      final card = tester.widget<Container>(
        find.byKey(const ValueKey<String>('call-notification-card')),
      );
      final decoration = card.decoration! as BoxDecoration;
      expect(decoration.color, WKWebColors.surface);
      expect(
        find.byKey(const ValueKey<String>('call-notification-reject')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('call-notification-accept')),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'notification cards use the decorated container as the only visual surface',
    (tester) async {
      await _pumpCallNotificationHarness(tester);

      await tester.tap(find.byKey(const ValueKey<String>('show-incoming')));
      await tester.pump();

      final incomingMaterial = _cardMaterial(
        tester,
        const ValueKey<String>('call-notification-card'),
      );
      expect(incomingMaterial.type, MaterialType.transparency);
      expect(incomingMaterial.elevation, 0);
      expect(incomingMaterial.borderRadius, isNull);

      CallNotificationOverlay.instance.dismiss();
      await tester.pump();

      await tester.tap(find.byKey(const ValueKey<String>('show-outgoing')));
      await tester.pump();

      final outgoingMaterial = _cardMaterial(
        tester,
        const ValueKey<String>('call-outgoing-notification-card'),
      );
      expect(outgoingMaterial.type, MaterialType.transparency);
      expect(outgoingMaterial.elevation, 0);
      expect(outgoingMaterial.borderRadius, isNull);
    },
  );

  testWidgets('call action buttons meet AA color contrast', (tester) async {
    await _pumpCallNotificationHarness(tester);

    await tester.tap(find.byKey(const ValueKey<String>('show-incoming')));
    await tester.pump();

    final rejectContrast = _contrastRatio(
      _buttonForeground(
        tester,
        const ValueKey<String>('call-notification-reject'),
      ),
      _buttonBackground(
        tester,
        const ValueKey<String>('call-notification-reject'),
      ),
    );
    final acceptContrast = _contrastRatio(
      _buttonForeground(
        tester,
        const ValueKey<String>('call-notification-accept'),
      ),
      _buttonBackground(
        tester,
        const ValueKey<String>('call-notification-accept'),
      ),
    );

    expect(rejectContrast, greaterThanOrEqualTo(4.5));
    expect(acceptContrast, greaterThanOrEqualTo(4.5));
  });
}

Future<void> _pumpCallNotificationHarness(WidgetTester tester) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Overlay(
        initialEntries: [
          OverlayEntry(
            builder: (context) {
              return Builder(
                builder: (context) {
                  return Column(
                    children: [
                      TextButton(
                        key: const ValueKey<String>('show-incoming'),
                        onPressed: () {
                          CallNotificationOverlay.instance.showIncomingCall(
                            overlayState: Overlay.of(context),
                            data: CallNotificationData(
                              channelId: 'u_peer',
                              channelName: 'Alice',
                              type: CallNotificationType.incoming,
                              callType: 1,
                            ),
                            onAccept: () {},
                            onReject: () {},
                          );
                        },
                        child: const Text('show incoming'),
                      ),
                      TextButton(
                        key: const ValueKey<String>('show-outgoing'),
                        onPressed: () {
                          CallNotificationOverlay.instance.showOutgoingCall(
                            overlayState: Overlay.of(context),
                            data: CallNotificationData(
                              channelId: 'u_peer',
                              channelName: 'Alice',
                              type: CallNotificationType.outgoing,
                              callType: 1,
                            ),
                          );
                        },
                        child: const Text('show outgoing'),
                      ),
                    ],
                  );
                },
              );
            },
          ),
        ],
      ),
    ),
  );
}

Material _cardMaterial(WidgetTester tester, Key cardKey) {
  final materialFinder = find.ancestor(
    of: find.byKey(cardKey),
    matching: find.byType(Material),
  );
  expect(materialFinder, findsOneWidget);
  return tester.widget<Material>(materialFinder);
}

Color _buttonBackground(WidgetTester tester, Key buttonKey) {
  final button = tester.widget<ElevatedButton>(find.byKey(buttonKey));
  final color = button.style?.backgroundColor?.resolve(<WidgetState>{});
  expect(color, isNotNull);
  return color!;
}

Color _buttonForeground(WidgetTester tester, Key buttonKey) {
  final button = tester.widget<ElevatedButton>(find.byKey(buttonKey));
  final color = button.style?.foregroundColor?.resolve(<WidgetState>{});
  expect(color, isNotNull);
  return color!;
}

double _contrastRatio(Color foreground, Color background) {
  final lighter = math.max(
    foreground.computeLuminance(),
    background.computeLuminance(),
  );
  final darker = math.min(
    foreground.computeLuminance(),
    background.computeLuminance(),
  );
  return (lighter + 0.05) / (darker + 0.05);
}
