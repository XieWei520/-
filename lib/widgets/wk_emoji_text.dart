import 'package:flutter/material.dart';

import '../wukong_base/emoji/android_emoji_catalog.dart';

class WKEmojiText extends StatelessWidget {
  const WKEmojiText({
    super.key,
    required this.text,
    required this.style,
    this.maxLines,
    this.overflow,
    this.textAlign,
    this.softWrap,
  });

  final String text;
  final TextStyle style;
  final int? maxLines;
  final TextOverflow? overflow;
  final TextAlign? textAlign;
  final bool? softWrap;

  static bool containsAndroidEmoji(String text) {
    var index = 0;
    while (index < text.length) {
      if (androidEmojiCatalog.longestMatchAt(text, index) != null) {
        return true;
      }
      index += _codePointLengthAt(text, index);
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final emojiSize = style.fontSize ?? 14;
    return Text.rich(
      TextSpan(style: style, children: _buildSpans(text, style, emojiSize)),
      maxLines: maxLines,
      overflow: overflow ?? TextOverflow.clip,
      textAlign: textAlign ?? TextAlign.start,
      softWrap: softWrap,
    );
  }

  static List<InlineSpan> _buildSpans(
    String text,
    TextStyle style,
    double emojiSize,
  ) {
    final spans = <InlineSpan>[];
    var index = 0;
    var textStart = 0;

    while (index < text.length) {
      final match = androidEmojiCatalog.longestMatchAt(text, index);
      if (match != null) {
        if (textStart < index) {
          spans.add(TextSpan(text: text.substring(textStart, index)));
        }
        spans.add(
          WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: Image.asset(
              match.assetPath,
              width: emojiSize,
              height: emojiSize,
              fit: BoxFit.contain,
              errorBuilder: (_, _, _) => Text(
                match.tag,
                style: style.copyWith(fontSize: emojiSize, height: 1),
              ),
            ),
          ),
        );
        index += match.tag.length;
        textStart = index;
        continue;
      }

      index += _codePointLengthAt(text, index);
    }

    if (textStart < text.length) {
      spans.add(TextSpan(text: text.substring(textStart)));
    }

    return spans;
  }

  static int _codePointLengthAt(String text, int index) {
    final currentUnit = text.codeUnitAt(index);
    const highSurrogateStart = 0xD800;
    const highSurrogateEnd = 0xDBFF;
    const lowSurrogateStart = 0xDC00;
    const lowSurrogateEnd = 0xDFFF;

    final isHighSurrogate =
        currentUnit >= highSurrogateStart && currentUnit <= highSurrogateEnd;
    if (!isHighSurrogate || index + 1 >= text.length) {
      return 1;
    }

    final nextUnit = text.codeUnitAt(index + 1);
    final isLowSurrogate =
        nextUnit >= lowSurrogateStart && nextUnit <= lowSurrogateEnd;
    return isLowSurrogate ? 2 : 1;
  }
}
