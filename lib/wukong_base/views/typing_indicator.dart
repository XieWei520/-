import 'dart:async';
import 'package:flutter/material.dart';

/// Typing indicator widget
class TypingIndicator extends StatefulWidget {
  /// Channel ID for this conversation
  final String channelId;
  
  /// Typing user names (comma separated for multiple)
  final String? userNames;
  
  /// Animation color (defaults to grey)
  final Color? color;
  
  /// Dot count (1-3)
  final int dotCount;
  
  /// Animation duration in milliseconds
  final int animationDuration;

  const TypingIndicator({
    super.key,
    required this.channelId,
    this.userNames,
    this.color,
    this.dotCount = 3,
    this.animationDuration = 600,
  });

  @override
  State<TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<TypingIndicator>
    with TickerProviderStateMixin {
  late List<AnimationController> _controllers;
  late List<Animation<double>> _animations;

  @override
  void initState() {
    super.initState();
    _initAnimations();
  }

  void _initAnimations() {
    _controllers = List.generate(
      widget.dotCount,
      (index) => AnimationController(
        vsync: this,
        duration: Duration(milliseconds: widget.animationDuration),
      ),
    );

    _animations = _controllers.map((controller) {
      return Tween<double>(begin: 0, end: 1).animate(
        CurvedAnimation(parent: controller, curve: Curves.easeInOut),
      );
    }).toList();

    // Start animations with delay
    for (int i = 0; i < _controllers.length; i++) {
      Future.delayed(Duration(milliseconds: i * 100), () {
        if (mounted) {
          _controllers[i].repeat(reverse: true);
        }
      });
    }
  }

  @override
  void dispose() {
    for (final controller in _controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dotColor = widget.color ?? Colors.grey[400]!;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Avatar placeholder
          CircleAvatar(
            radius: 12,
            backgroundColor: Colors.grey[300],
            child: Icon(
              Icons.person,
              size: 14,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(width: 8),

          // Text and dots
          AnimatedBuilder(
            animation: Listenable.merge(_controllers),
            builder: (context, child) {
              return Text.rich(
                TextSpan(
                  children: [
                    if (widget.userNames != null)
                      TextSpan(
                        text: '${widget.userNames}',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 13,
                        ),
                      ),
                    TextSpan(
                      text: _getTypingText(),
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 13,
                      ),
                    ),
                    // Animated dots
                    ...List.generate(widget.dotCount, (index) {
                      return WidgetSpan(
                        alignment: PlaceholderAlignment.baseline,
                        baseline: TextBaseline.alphabetic,
                        child: Transform.translate(
                          offset: Offset(0, -4 * _animations[index].value),
                          child: Text(
                            '•',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: dotColor.withValues(
                                alpha: 0.4 + 0.6 * _animations[index].value,
                              ),
                            ),
                          ),
                        ),
                      );
                    }),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  String _getTypingText() {
    final userNames = widget.userNames;
    if (userNames == null || userNames.isEmpty) {
      return 'typing  ';
    }
    
    // Handle multiple users
    if (userNames.contains(',')) {
      return '  are typing  ';
    }
    return '  is typing  ';
  }
}

/// Typing indicator bubble
class TypingIndicatorBubble extends StatelessWidget {
  /// Whether to show avatar
  final bool showAvatar;
  
  /// Avatar widget
  final Widget? avatar;
  
  /// Background color
  final Color? backgroundColor;

  const TypingIndicatorBubble({
    super.key,
    this.showAvatar = true,
    this.avatar,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 200),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: backgroundColor ?? Colors.grey[200],
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Animated dots
          _AnimatedDots(),
        ],
      ),
    );
  }
}

/// Animated dots widget
class _AnimatedDots extends StatefulWidget {
  @override
  State<_AnimatedDots> createState() => _AnimatedDotsState();
}

class _AnimatedDotsState extends State<_AnimatedDots>
    with TickerProviderStateMixin {
  late List<AnimationController> _controllers;
  late List<Animation<double>> _animations;

  @override
  void initState() {
    super.initState();
    _controllers = List.generate(
      3,
      (index) => AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 600),
      ),
    );

    _animations = _controllers.map((controller) {
      return Tween<double>(begin: 0, end: 1).animate(
        CurvedAnimation(parent: controller, curve: Curves.easeInOut),
      );
    }).toList();

    // Start animations with delay
    for (int i = 0; i < _controllers.length; i++) {
      Future.delayed(Duration(milliseconds: i * 200), () {
        if (mounted) {
          _controllers[i].repeat(reverse: true);
        }
      });
    }
  }

  @override
  void dispose() {
    for (final controller in _controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge(_controllers),
      builder: (context, child) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (index) {
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 2),
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: Colors.grey[500]!.withValues(
                  alpha: 0.4 + 0.6 * _animations[index].value,
                ),
                shape: BoxShape.circle,
              ),
            );
          }),
        );
      },
    );
  }
}

/// Typing indicator provider
class TypingProvider extends ChangeNotifier {
  final Map<String, Set<String>> _typingUsers = {};
  final Map<String, Timer> _typingTimers = {};

  // Default timeout for typing indicator (5 seconds)
  static const int typingTimeout = 5;

  /// Check if anyone is typing in this channel
  bool isTyping(String channelId) {
    return _typingUsers[channelId]?.isNotEmpty ?? false;
  }

  /// Get typing users in this channel
  Set<String> getTypingUsers(String channelId) {
    return _typingUsers[channelId] ?? {};
  }

  /// Get typing user names (formatted)
  String? getTypingUserNames(String channelId) {
    final users = _typingUsers[channelId];
    if (users == null || users.isEmpty) return null;

    if (users.length == 1) {
      return users.first;
    } else if (users.length == 2) {
      return '${users.elementAt(0)} and ${users.elementAt(1)}';
    } else {
      return '${users.elementAt(0)} and ${users.length - 1} others';
    }
  }

  /// Set user typing
  void setTyping(String channelId, String userId) {
    _typingUsers.putIfAbsent(channelId, () => {}).add(userId);

    // Cancel existing timer for this user
    final timerKey = '${channelId}_$userId';
    _typingTimers[timerKey]?.cancel();

    // Set new timer
    _typingTimers[timerKey] = Timer(
      const Duration(seconds: typingTimeout),
      () => clearTyping(channelId, userId),
    );

    notifyListeners();
  }

  /// Clear user typing
  void clearTyping(String channelId, String userId) {
    _typingUsers[channelId]?.remove(userId);

    final timerKey = '${channelId}_$userId';
    _typingTimers[timerKey]?.cancel();
    _typingTimers.remove(timerKey);

    notifyListeners();
  }

  /// Clear all typing for channel
  void clearChannel(String channelId) {
    final users = _typingUsers.remove(channelId) ?? {};
    for (final userId in users) {
      final timerKey = '${channelId}_$userId';
      _typingTimers[timerKey]?.cancel();
      _typingTimers.remove(timerKey);
    }
    notifyListeners();
  }

  /// Clear all typing
  void clearAll() {
    _typingUsers.clear();
    for (final timer in _typingTimers.values) {
      timer.cancel();
    }
    _typingTimers.clear();
    notifyListeners();
  }

  @override
  void dispose() {
    clearAll();
    super.dispose();
  }
}
