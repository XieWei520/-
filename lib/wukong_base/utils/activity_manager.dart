import 'package:flutter/material.dart';

/// Navigation manager for managing app navigation
class WKActivityManager {
  static WKActivityManager? _instance;
  final List<NavigationItem> _navigationStack = [];

  WKActivityManager._();

  static WKActivityManager get instance {
    _instance ??= WKActivityManager._();
    return _instance!;
  }

  /// Get current navigation item
  NavigationItem? get currentItem => 
      _navigationStack.isNotEmpty ? _navigationStack.last : null;

  /// Get navigation stack
  List<NavigationItem> get stack => List.unmodifiable(_navigationStack);

  /// Get stack size
  int get stackSize => _navigationStack.length;

  /// Push a new page onto the stack
  void push(NavigationItem item) {
    _navigationStack.add(item);
  }

  /// Pop the current page
  NavigationItem? pop() {
    if (_navigationStack.isEmpty) return null;
    return _navigationStack.removeLast();
  }

  /// Pop to a specific route
  void popUntil(String routeName) {
    while (_navigationStack.isNotEmpty && 
           _navigationStack.last.routeName != routeName) {
      _navigationStack.removeLast();
    }
  }

  /// Clear all pages and go to root
  void clear() {
    _navigationStack.clear();
  }

  /// Check if a route exists in stack
  bool contains(String routeName) {
    return _navigationStack.any((item) => item.routeName == routeName);
  }

  /// Get page count
  int count(String routeName) {
    return _navigationStack.where((item) => item.routeName == routeName).length;
  }
}

/// Navigation item representing a page in the stack
class NavigationItem {
  final String routeName;
  final Map<String, dynamic>? arguments;
  final DateTime timestamp;

  NavigationItem({
    required this.routeName,
    this.arguments,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();
}

/// Navigation observer for tracking navigation
class WKNavigatorObserver extends NavigatorObserver {
  final WKActivityManager _manager = WKActivityManager.instance;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _manager.push(NavigationItem(
      routeName: route.settings.name ?? 'unknown',
      arguments: route.settings.arguments as Map<String, dynamic>?,
    ));
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _manager.pop();
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _manager.pop();
  }
}
