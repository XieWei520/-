import 'package:flutter_test/flutter_test.dart';
import 'package:wukong_im_app/modules/home/home_badge_snapshot.dart';
import 'package:wukong_im_app/modules/home/home_surface_contract.dart';

void main() {
  test('badge snapshot aggregates unread values by surface', () {
    final snapshot = HomeBadgeSnapshot(
      bySurface: <HomeSurfaceId, int>{
        HomeSurfaceId.conversations: 12,
        HomeSurfaceId.contacts: 3,
      },
    );

    expect(snapshot.badgeFor(HomeSurfaceId.conversations), 12);
    expect(snapshot.totalUnread, 15);
  });

  test('badge snapshot is immutable from external mutations', () {
    final source = <HomeSurfaceId, int>{HomeSurfaceId.conversations: 5};
    final snapshot = HomeBadgeSnapshot(bySurface: source);

    source[HomeSurfaceId.conversations] = 99;

    expect(snapshot.badgeFor(HomeSurfaceId.conversations), 5);
    expect(
      () => snapshot.bySurface[HomeSurfaceId.user] = 1,
      throwsUnsupportedError,
    );
  });
}
