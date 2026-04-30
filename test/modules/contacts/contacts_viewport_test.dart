import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wukong_im_app/data/models/friend.dart';
import 'package:wukong_im_app/modules/customer_service/customer_service_badge.dart';
import 'package:wukong_im_app/modules/contacts/contacts_directory_controller.dart';
import 'package:wukong_im_app/modules/contacts/contacts_presence_controller.dart';
import 'package:wukong_im_app/modules/contacts/contacts_strings.dart';
import 'package:wukong_im_app/modules/contacts/widgets/contacts_alphabet_index.dart';
import 'package:wukong_im_app/modules/contacts/widgets/contacts_list_viewport.dart';
import 'package:wukong_im_app/widgets/wk_avatar.dart';

void main() {
  final strings = resolveContactsStrings();

  setUp(() {
    WKAvatar.setBytesLoaderForTesting((_) async => null);
  });

  tearDown(() {
    WKAvatar.setBytesLoaderForTesting(null);
  });

  testWidgets('contacts list viewport shows empty state and repaint boundary', (
    tester,
  ) async {
    final directory = ContactsDirectoryData(
      sections: const [],
      letters: const [],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: ContactsListViewport(
          header: const Text('Header'),
          directory: directory,
          contactPresenceByUid: const <String, ContactPresenceState>{},
          currentTimestampSeconds: 0,
          onTapEntry: (_) {},
          onLongPressEntry: (_) {},
        ),
      ),
    );

    expect(find.text(strings.contactsEmpty), findsOneWidget);
    expect(
      find.byKey(const ValueKey('contacts-list-viewport-repaint')),
      findsOneWidget,
    );
  });

  testWidgets('contacts list viewport shows contacts count in non-empty list', (
    tester,
  ) async {
    final directory = ContactsDirectoryData(
      sections: [
        ContactsDirectorySection(
          letter: 'A',
          entries: [
            ContactsDirectoryEntry(
              friend: Friend(uid: 'u_alice', name: 'Alice'),
              sortKey: 'Alice',
              sectionLetter: 'A',
            ),
          ],
        ),
      ],
      letters: const ['A'],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: ContactsListViewport(
          header: const SizedBox.shrink(),
          directory: directory,
          contactPresenceByUid: const <String, ContactPresenceState>{},
          currentTimestampSeconds: 0,
          onTapEntry: (_) {},
          onLongPressEntry: (_) {},
        ),
      ),
    );

    expect(find.text(strings.contactsCount(1)), findsOneWidget);
  });

  testWidgets('contacts list viewport uses a lazy builder delegate', (
    tester,
  ) async {
    final entries = List<ContactsDirectoryEntry>.generate(
      120,
      (index) => ContactsDirectoryEntry(
        friend: Friend(uid: 'u_$index', name: 'User $index'),
        sortKey: 'User $index',
        sectionLetter: 'U',
      ),
    );
    final directory = ContactsDirectoryData(
      sections: [ContactsDirectorySection(letter: 'U', entries: entries)],
      letters: const ['U'],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: ContactsListViewport(
          header: const SizedBox.shrink(),
          directory: directory,
          contactPresenceByUid: const <String, ContactPresenceState>{},
          currentTimestampSeconds: 0,
          onTapEntry: (_) {},
          onLongPressEntry: (_) {},
        ),
      ),
    );

    final listView = tester.widget<ListView>(find.byType(ListView));
    expect(listView.childrenDelegate, isA<SliverChildBuilderDelegate>());
  });

  testWidgets('contacts list shows prominent customer service badge', (
    tester,
  ) async {
    final directory = ContactsDirectoryData(
      sections: [
        ContactsDirectorySection(
          letter: 'K',
          entries: [
            ContactsDirectoryEntry(
              friend: Friend(
                uid: 'cs_001',
                name: 'Support',
                category: 'customerService',
              ),
              sortKey: 'Support',
              sectionLetter: 'K',
            ),
          ],
        ),
      ],
      letters: const ['K'],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: ContactsListViewport(
          header: const SizedBox.shrink(),
          directory: directory,
          contactPresenceByUid: const <String, ContactPresenceState>{},
          currentTimestampSeconds: 0,
          onTapEntry: (_) {},
          onLongPressEntry: (_) {},
        ),
      ),
    );

    expect(find.text('\u5ba2\u670d'), findsOneWidget);
    expect(
      find.byKey(
        const ValueKey<String>('contacts-customer-service-badge-cs_001'),
      ),
      findsOneWidget,
    );
    expect(find.byType(CustomerServiceBadge), findsOneWidget);
    expect(find.text('\u5b98\u65b9'), findsNothing);
  });

  testWidgets(
    'contacts row wraps badges instead of overflowing on narrow screens',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(240, 640);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);

      final directory = ContactsDirectoryData(
        sections: [
          ContactsDirectorySection(
            letter: 'S',
            entries: [
              ContactsDirectoryEntry(
                friend: Friend.fromJson({
                  'uid': 'cs_vip_robot',
                  'name': 'Support user with an extremely long display name',
                  'category': 'customerService',
                  'robot': 1,
                  'vip_level': 1,
                }),
                sortKey: 'Support user with an extremely long display name',
                sectionLetter: 'S',
              ),
            ],
          ),
        ],
        letters: const ['S'],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: ContactsListViewport(
            header: const SizedBox.shrink(),
            directory: directory,
            contactPresenceByUid: const <String, ContactPresenceState>{},
            currentTimestampSeconds: 0,
            onTapEntry: (_) {},
            onLongPressEntry: (_) {},
          ),
        ),
      );

      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('contacts alphabet index shows bubble while touching', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: SizedBox(
          height: 200,
          width: 80,
          child: ContactsAlphabetIndex(
            letters: ['A', 'B'],
            activeLetter: 'A',
            isTouching: true,
            onLetterTap: _noopLetterTap,
            onTouchingChanged: _noopTouchingChanged,
          ),
        ),
      ),
    );

    expect(
      find.byKey(const ValueKey('contacts-alphabet-bubble')),
      findsOneWidget,
    );
  });

  testWidgets('contacts alphabet index releases touching state after tap', (
    tester,
  ) async {
    String? tappedLetter;
    String? activeLetter;
    var isTouching = false;

    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (context, setState) {
            return SizedBox(
              height: 200,
              width: 80,
              child: ContactsAlphabetIndex(
                letters: const ['A', 'B'],
                activeLetter: activeLetter,
                isTouching: isTouching,
                onLetterTap: (letter) {
                  tappedLetter = letter;
                  setState(() {
                    activeLetter = letter;
                  });
                },
                onTouchingChanged: (value) {
                  setState(() {
                    isTouching = value;
                  });
                },
              ),
            );
          },
        ),
      ),
    );

    await tester.tap(find.text('A').first);
    await tester.pump();

    expect(tappedLetter, 'A');
    expect(isTouching, isFalse);
    expect(
      find.byKey(const ValueKey('contacts-alphabet-bubble')),
      findsNothing,
    );
  });
}

void _noopLetterTap(String _) {}

void _noopTouchingChanged(bool _) {}
