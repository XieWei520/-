import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:wukong_im_app/modules/chat/chat_mentions_controller.dart';
import 'package:wukong_im_app/wukong_base/views/mention_suggestion.dart';

void main() {
  test('mention controller filters by query and inserts selected mention', () async {
    final controller = ChatMentionsController(
      loadSuggestions: () async => <MentionSuggestion>[
        MentionSuggestion(id: 'u1', name: 'Alice'),
        MentionSuggestion(id: 'u2', name: 'Bob'),
      ],
    );
    addTearDown(controller.dispose);

    await controller.updateFromText('hello @a', cursorOffset: 8);

    expect(controller.state.isActive, isTrue);
    expect(controller.state.suggestions.first.name, 'Alice');

    final result = controller.applySelection('hello @a', cursorOffset: 8);

    expect(result.text, 'hello @Alice ');
    expect(result.mentionedUids, <String>['u1']);
  });

  test('mention controller closes suggestions when whitespace ends the query',
      () async {
    final controller = ChatMentionsController(
      loadSuggestions: () async => <MentionSuggestion>[
        MentionSuggestion(id: 'u1', name: 'Alice'),
      ],
    );
    addTearDown(controller.dispose);

    await controller.updateFromText('hello @a ', cursorOffset: 9);

    expect(controller.state.isActive, isFalse);
    expect(controller.state.query, isEmpty);
    expect(controller.state.suggestions, isEmpty);
  });

  test('mention controller ignores stale async suggestion responses', () async {
    final firstLoad = Completer<List<MentionSuggestion>>();
    final secondLoad = Completer<List<MentionSuggestion>>();
    var callCount = 0;
    final controller = ChatMentionsController(
      loadSuggestions: () {
        callCount++;
        if (callCount == 1) {
          return firstLoad.future;
        }
        return secondLoad.future;
      },
    );
    addTearDown(controller.dispose);

    final firstUpdate = controller.updateFromText('hello @a', cursorOffset: 8);
    final secondUpdate = controller.updateFromText('hello @b', cursorOffset: 8);

    secondLoad.complete(<MentionSuggestion>[
      MentionSuggestion(id: 'u2', name: 'Bob'),
    ]);
    await secondUpdate;

    expect(controller.state.query, 'b');
    expect(controller.state.suggestions.map((item) => item.name), <String>['Bob']);

    firstLoad.complete(<MentionSuggestion>[
      MentionSuggestion(id: 'u1', name: 'Alice'),
    ]);
    await firstUpdate;

    expect(controller.state.query, 'b');
    expect(controller.state.suggestions.map((item) => item.name), <String>['Bob']);
  });

  test('mention controller inserts the selected suggestion instead of always using the first item',
      () async {
    final controller = ChatMentionsController(
      loadSuggestions: () async => <MentionSuggestion>[
        MentionSuggestion(id: 'u1', name: 'Alice'),
        MentionSuggestion(id: 'u2', name: 'Bob'),
      ],
    );
    addTearDown(controller.dispose);

    await controller.updateFromText('hello @', cursorOffset: 7);

    final result = controller.applySelection(
      'hello @',
      cursorOffset: 7,
      suggestion: controller.state.suggestions[1],
    );

    expect(result.text, 'hello @Bob ');
    expect(result.mentionedUids, <String>['u2']);
  });
}
