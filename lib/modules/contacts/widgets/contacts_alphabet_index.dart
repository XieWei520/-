import 'package:flutter/material.dart';

import '../../../widgets/wk_colors.dart';
import '../../../widgets/wk_design_tokens.dart';

class ContactsAlphabetIndex extends StatelessWidget {
  const ContactsAlphabetIndex({
    super.key,
    required this.letters,
    required this.activeLetter,
    required this.isTouching,
    required this.onLetterTap,
    required this.onTouchingChanged,
  });

  final List<String> letters;
  final String? activeLetter;
  final bool isTouching;
  final ValueChanged<String> onLetterTap;
  final ValueChanged<bool> onTouchingChanged;

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            void pickLetter(Offset localPosition) {
              if (letters.isEmpty || constraints.maxHeight <= 0) {
                return;
              }
              final itemExtent = constraints.maxHeight / letters.length;
              final rawIndex = (localPosition.dy / itemExtent).floor();
              final index = rawIndex.clamp(0, letters.length - 1);
              onLetterTap(letters[index]);
            }

            return GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapDown: (details) {
                onTouchingChanged(true);
                pickLetter(details.localPosition);
              },
              onTapUp: (_) => onTouchingChanged(false),
              onTapCancel: () => onTouchingChanged(false),
              onVerticalDragDown: (details) {
                onTouchingChanged(true);
                pickLetter(details.localPosition);
              },
              onVerticalDragUpdate: (details) {
                onTouchingChanged(true);
                pickLetter(details.localPosition);
              },
              onVerticalDragEnd: (_) => onTouchingChanged(false),
              onVerticalDragCancel: () => onTouchingChanged(false),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (final letter in letters)
                    SizedBox(
                      width: 20,
                      height: 15,
                      child: Center(
                        child: Text(
                          letter,
                          style: TextStyle(
                            fontFamily: WKFontFamily.primary,
                            fontSize: activeLetter == letter ? 16 : 10,
                            fontWeight: activeLetter == letter
                                ? FontWeight.w700
                                : FontWeight.w500,
                            color: WKColors.brand500,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            );
          },
        ),
        if (isTouching && activeLetter != null)
          IgnorePointer(
            child: Container(
              key: const ValueKey('contacts-alphabet-bubble'),
              width: 45,
              height: 45,
              decoration: BoxDecoration(
                color: WKColors.brand500,
                borderRadius: BorderRadius.circular(12),
              ),
              alignment: Alignment.center,
              child: Text(
                activeLetter!,
                style: const TextStyle(
                  fontFamily: WKFontFamily.title,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: WKColors.white,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
