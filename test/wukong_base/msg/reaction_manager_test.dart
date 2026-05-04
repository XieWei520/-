import 'package:flutter_test/flutter_test.dart';
import 'package:wukong_im_app/wukong_base/msg/reaction_manager.dart';

void main() {
  group('ReactionManager', () {
    test('default reactions are real emoji, not mojibake placeholders', () {
      expect(ReactionManager.defaultReactions, contains('\u{1F44D}'));
      expect(ReactionManager.defaultReactions, contains('\u2764\uFE0F'));
      expect(ReactionManager.defaultReactions, contains('\u{1F600}'));
      expect(
        ReactionManager.defaultReactions.every(_containsOnlyRealEmojiGlyphs),
        isTrue,
      );
    });
  });
}

bool _containsOnlyRealEmojiGlyphs(String value) {
  return !value.contains('馃') && !value.contains('鉂') && !value.contains('笍');
}
