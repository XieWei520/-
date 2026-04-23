import 'package:flutter/material.dart';

/// Bottom sheet item
class BottomSheetItem {
  final String title;
  final IconData? icon;
  final Color? color;
  final VoidCallback? onTap;
  final bool isDivider;

  const BottomSheetItem({
    this.title = '',
    this.icon,
    this.color,
    this.onTap,
    this.isDivider = false,
  });

  BottomSheetItem.divider() : this(isDivider: true);
}

/// Show custom bottom sheet
Future<T?> showCustomBottomSheet<T>({
  required BuildContext context,
  required List<BottomSheetItem> items,
  String? title,
  double? height,
  bool showCancel = true,
  Color? backgroundColor,
}) {
  return showModalBottomSheet<T>(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (context) => CustomBottomSheet(
      items: items,
      title: title,
      height: height,
      showCancel: showCancel,
      backgroundColor: backgroundColor,
    ),
  );
}

/// Custom bottom sheet widget
class CustomBottomSheet extends StatelessWidget {
  final List<BottomSheetItem> items;
  final String? title;
  final double? height;
  final bool showCancel;
  final Color? backgroundColor;

  const CustomBottomSheet({
    super.key,
    required this.items,
    this.title,
    this.height,
    this.showCancel = true,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final sheetHeight = height ?? (screenHeight * 0.6);

    return Container(
      height: sheetHeight,
      decoration: BoxDecoration(
        color: backgroundColor ?? Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Column(
        children: [
          // Handle bar
          Container(
            margin: const EdgeInsets.symmetric(vertical: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[400],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          
          // Title
          if (title != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(
                title!,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          
          // Items
          Expanded(
            child: ListView.builder(
              padding: EdgeInsets.zero,
              itemCount: items.length,
              itemBuilder: (context, index) {
                final item = items[index];
                
                if (item.isDivider) {
                  return const Divider(height: 1);
                }
                
                return ListTile(
                  leading: item.icon != null
                      ? Icon(item.icon, color: item.color)
                      : null,
                  title: Text(
                    item.title,
                    style: TextStyle(color: item.color),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    item.onTap?.call();
                  },
                );
              },
            ),
          ),
          
          // Cancel button
          if (showCancel)
            SafeArea(
              child: Container(
                margin: const EdgeInsets.all(16),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: const Text('取消'),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Action bottom sheet with icon and title
Future<T?> showActionBottomSheet<T>({
  required BuildContext context,
  required String title,
  required List<BottomSheetAction> actions,
  String? subtitle,
}) {
  return showModalBottomSheet<T>(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (context) => ActionBottomSheet(
      title: title,
      actions: actions,
      subtitle: subtitle,
    ),
  );
}

/// Action bottom sheet widget
class ActionBottomSheet extends StatelessWidget {
  final String title;
  final String? subtitle;
  final List<BottomSheetAction> actions;

  const ActionBottomSheet({
    super.key,
    required this.title,
    this.subtitle,
    required this.actions,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Container(
              margin: const EdgeInsets.symmetric(vertical: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[400],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            
            // Title
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      subtitle!,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            
            const Divider(height: 1),
            
            // Actions
            ...actions.map((action) => ListTile(
              leading: Icon(action.icon, color: action.color),
              title: Text(action.title),
              onTap: () {
                Navigator.pop(context, action.value);
              },
            )),
            
            const SizedBox(height: 8),
            
            // Cancel
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('取消'),
                ),
              ),
            ),
            
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

/// Bottom sheet action
class BottomSheetAction {
  final String title;
  final IconData icon;
  final Color? color;
  final dynamic value;

  const BottomSheetAction({
    required this.title,
    required this.icon,
    this.color,
    this.value,
  });
}
