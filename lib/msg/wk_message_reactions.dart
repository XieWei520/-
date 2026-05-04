import 'package:flutter/material.dart';

/// Message reactions widget
class WKMessageReactions extends StatelessWidget {
  final List<dynamic> reactions;

  const WKMessageReactions({super.key, required this.reactions});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 4,
      children: reactions.map((r) => Chip(label: Text(r.toString()))).toList(),
    );
  }
}
