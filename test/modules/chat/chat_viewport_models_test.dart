import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:wukong_im_app/modules/chat/chat_viewport_models.dart';

void main() {
  group('roundFiniteViewportOffset', () {
    test('rounds finite viewport offsets', () {
      expect(roundFiniteViewportOffset(12.49), 12);
      expect(roundFiniteViewportOffset(12.5), 13);
      expect(roundFiniteViewportOffset(-1.5), -2);
    });

    test('rejects non-finite viewport offsets', () {
      expect(roundFiniteViewportOffset(double.nan), isNull);
      expect(roundFiniteViewportOffset(double.infinity), isNull);
      expect(roundFiniteViewportOffset(double.negativeInfinity), isNull);
      expect(roundFiniteViewportOffset(math.log(-1)), isNull);
    });
  });
}
