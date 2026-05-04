import 'package:flutter/material.dart';

/// Custom bottom sheet
class CustomBottomSheet extends StatelessWidget {
  final Widget child;

  const CustomBottomSheet({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(child: child);
  }
}
