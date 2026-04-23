import 'package:flutter/material.dart';

/// Emoji picker widget
class WKEmojiPicker extends StatelessWidget {
  final Function(String)? onEmojiSelected;

  const WKEmojiPicker({super.key, this.onEmojiSelected});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 200,
      child: GridView.builder(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 8,
        ),
        itemCount: 50,
        itemBuilder: (context, index) {
          return GestureDetector(
            onTap: () => onEmojiSelected?.call(String.fromCharCode(0x1F600 + index)),
            child: Center(
              child: Text(
                String.fromCharCode(0x1F600 + index),
                style: const TextStyle(fontSize: 24),
              ),
            ),
          );
        },
      ),
    );
  }
}
