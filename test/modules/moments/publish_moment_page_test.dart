import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wukong_im_app/modules/moments/moments_service.dart';
import 'package:wukong_im_app/modules/moments/publish_moment_page.dart';

void main() {
  testWidgets('publish page collects location and mentions before submit', (
    tester,
  ) async {
    MomentPublishRequest? submitted;
    final service = FakeMomentsComposerService(
      onPublish: (request) async {
        submitted = request;
        return _fakeMoment();
      },
    );

    await tester.pumpWidget(
      MaterialApp(
        home: PublishMomentPage(
          service: service,
          locationPicker: (_) async => <String, dynamic>{
            'title': '上海中心',
            'address': '上海市浦东新区银城中路501号',
            'latitude': 31.2397,
            'longitude': 121.4998,
          },
          mentionPicker: (_) async => const <MomentMention>[
            MomentMention(uid: 'u_bob', name: 'Bob'),
          ],
        ),
      ),
    );

    await tester.enterText(find.byType(TextField).first, '今晚继续压测');
    await tester.tap(find.byKey(const ValueKey('moment-pick-location-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('moment-pick-mention-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('moment-publish-button')));
    await tester.pumpAndSettle();

    expect(submitted?.location, '上海市浦东新区银城中路501号');
    expect(submitted?.mentions, <String>['u_bob']);
  });

  testWidgets('publish page action buttons wrap on narrow screens', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(260, 640);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    final service = FakeMomentsComposerService(
      onPublish: (request) async => _fakeMoment(),
    );

    await tester.pumpWidget(
      MaterialApp(home: PublishMomentPage(service: service)),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.text('相册'), findsOneWidget);
    expect(find.text('拍照'), findsOneWidget);
    expect(find.text('位置'), findsOneWidget);
    expect(find.text('@好友'), findsOneWidget);
  });
}

class FakeMomentsComposerService implements MomentsComposeService {
  FakeMomentsComposerService({required this.onPublish});

  final Future<Moment> Function(MomentPublishRequest request) onPublish;

  @override
  Future<Moment> publish(MomentPublishRequest request) {
    return onPublish(request);
  }
}

Moment _fakeMoment() {
  return Moment(
    id: 'm-1',
    uid: 'u-self',
    username: 'Self',
    content: '今晚继续压测',
    location: '上海市浦东新区银城中路501号',
    mentions: const <String>['u_bob'],
    createdAt: 1710000000,
  );
}
