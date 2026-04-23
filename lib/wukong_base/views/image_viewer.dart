import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Image viewer arguments
class ImageViewerArgs {
  /// List of image URLs or file paths
  final List<String> images;
  
  /// Initial index to show
  final int initialIndex;
  
  /// Optional hero tag for animation
  final String? heroTag;
  
  /// Optional caption
  final String? caption;

  /// Optional contextual actions shown for the current image.
  final List<ImageViewerAction> actions;

  /// Whether the built-in long-press share/save/copy sheet is enabled.
  final bool enableLongPressOptions;

  ImageViewerArgs({
    required this.images,
    this.initialIndex = 0,
    this.heroTag,
    this.caption,
    this.actions = const <ImageViewerAction>[],
    this.enableLongPressOptions = true,
  });
}

typedef ImageViewerActionCallback =
    Future<void> Function(BuildContext context, int index);

class ImageViewerAction {
  final String key;
  final IconData icon;
  final String label;
  final ImageViewerActionCallback onPressed;

  const ImageViewerAction({
    required this.key,
    required this.icon,
    required this.label,
    required this.onPressed,
  });
}

/// Full-screen image viewer widget
class ImageViewer extends StatefulWidget {
  final ImageViewerArgs args;

  const ImageViewer({
    super.key,
    required this.args,
  });

  @override
  State<ImageViewer> createState() => _ImageViewerState();
}

class _ImageViewerState extends State<ImageViewer>
    with SingleTickerProviderStateMixin {
  late PageController _pageController;
  late int _currentIndex;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  // Transform state for each image
  final Map<int, TransformationController> _transformControllers = {};

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.args.initialIndex;
    _pageController = PageController(initialPage: _currentIndex);

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _fadeAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );

    // Hide system UI
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    
    _animationController.forward();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _animationController.dispose();
    for (final controller in _transformControllers.values) {
      controller.dispose();
    }
    
    // Restore system UI
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  TransformationController _getTransformController(int index) {
    return _transformControllers.putIfAbsent(
      index,
      () => TransformationController(),
    );
  }

  void _onPageChanged(int index) {
    setState(() => _currentIndex = index);
    
    // Reset transform for new page
    _getTransformController(index).value = Matrix4.identity();
  }

  Future<void> _close() async {
    await _animationController.reverse();
    if (mounted) {
      Navigator.of(context).pop(_currentIndex);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: [
            // Image page view
            GestureDetector(
              onLongPress: widget.args.enableLongPressOptions
                  ? () => _showOptions(context)
                  : null,
              child: PageView.builder(
                controller: _pageController,
                onPageChanged: _onPageChanged,
                itemCount: widget.args.images.length,
                itemBuilder: (context, index) {
                  return _ImagePage(
                    url: widget.args.images[index],
                    heroTag: widget.args.heroTag != null
                        ? '${widget.args.heroTag}_$index'
                        : null,
                    transformationController: _getTransformController(index),
                    onTap: _close,
                  );
                },
              ),
            ),

            // Top bar
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: _TopBar(
                currentIndex: _currentIndex,
                totalCount: widget.args.images.length,
                onClose: _close,
              ),
            ),

            // Bottom bar with caption and indicator
            if (widget.args.caption != null || widget.args.images.length > 1)
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: _BottomBar(
                  caption: widget.args.caption,
                  currentIndex: _currentIndex,
                  totalCount: widget.args.images.length,
                  actions: widget.args.actions,
                ),
              ),
            if (widget.args.actions.isNotEmpty &&
                widget.args.caption == null &&
                widget.args.images.length <= 1)
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: _BottomBar(
                  currentIndex: _currentIndex,
                  totalCount: widget.args.images.length,
                  actions: widget.args.actions,
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _showOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.share),
                title: const Text('分享'),
                onTap: () {
                  Navigator.pop(context);
                  _shareImage();
                },
              ),
              ListTile(
                leading: const Icon(Icons.save_alt),
                title: const Text('保存图片'),
                onTap: () {
                  Navigator.pop(context);
                  _saveImage();
                },
              ),
              ListTile(
                leading: const Icon(Icons.link),
                title: const Text('复制链接'),
                onTap: () {
                  Navigator.pop(context);
                  _copyLink();
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  void _shareImage() {
    // TODO: Implement share
  }

  void _saveImage() {
    // TODO: Implement save
  }

  void _copyLink() {
    Clipboard.setData(ClipboardData(text: widget.args.images[_currentIndex]));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('已复制到剪贴板')),
    );
  }
}

/// Single image page with zoom
class _ImagePage extends StatelessWidget {
  final String url;
  final String? heroTag;
  final TransformationController transformationController;
  final VoidCallback? onTap;

  const _ImagePage({
    required this.url,
    this.heroTag,
    required this.transformationController,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    Widget imageWidget;

    // Check if local file
    if (url.startsWith('/') || url.startsWith('file://') || File(url).existsSync()) {
      imageWidget = Image.file(
        File(url.startsWith('file://') ? url.substring(7) : url),
        fit: BoxFit.contain,
        errorBuilder: (context, error, stack) => _ErrorWidget(),
      );
    } else {
      imageWidget = Image.network(
        url,
        fit: BoxFit.contain,
        loadingBuilder: (context, child, progress) {
          if (progress == null) return child;
          return Center(
            child: CircularProgressIndicator(
              value: progress.expectedTotalBytes != null
                  ? progress.cumulativeBytesLoaded / progress.expectedTotalBytes!
                  : null,
            ),
          );
        },
        errorBuilder: (context, error, stack) => _ErrorWidget(),
      );
    }

    Widget content = InteractiveViewer(
      transformationController: transformationController,
      minScale: 0.5,
      maxScale: 4.0,
      child: Center(child: imageWidget),
    );

    if (heroTag != null) {
      content = Hero(tag: heroTag!, child: content);
    }

    return GestureDetector(
      onTap: onTap,
      child: Container(
        color: Colors.black,
        child: content,
      ),
    );
  }
}

/// Error widget
class _ErrorWidget extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          Icons.broken_image,
          size: 64,
          color: Colors.grey[600],
        ),
        const SizedBox(height: 16),
        Text(
          '图片加载失败',
          style: TextStyle(
            color: Colors.grey[500],
            fontSize: 14,
          ),
        ),
      ],
    );
  }
}

/// Top bar
class _TopBar extends StatelessWidget {
  final int currentIndex;
  final int totalCount;
  final VoidCallback onClose;

  const _TopBar({
    required this.currentIndex,
    required this.totalCount,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.black.withValues(alpha: 0.6),
            Colors.transparent,
          ],
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: onClose,
              ),
              const Spacer(),
              if (totalCount > 1)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.black45,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${currentIndex + 1} / $totalCount',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Bottom bar
class _BottomBar extends StatelessWidget {
  final String? caption;
  final int currentIndex;
  final int totalCount;
  final List<ImageViewerAction> actions;

  const _BottomBar({
    this.caption,
    required this.currentIndex,
    required this.totalCount,
    this.actions = const <ImageViewerAction>[],
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [
            Colors.black.withValues(alpha: 0.7),
            Colors.transparent,
          ],
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (caption != null)
                Text(
                  caption!,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                  ),
                  textAlign: TextAlign.center,
                ),
              if (actions.isNotEmpty) ...[
                if (caption != null || totalCount > 1) const SizedBox(height: 12),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 24,
                  runSpacing: 12,
                  children: actions
                      .map(
                        (action) => _ImageViewerActionButton(
                          action: action,
                          currentIndex: currentIndex,
                        ),
                      )
                      .toList(growable: false),
                ),
              ],
              if (totalCount > 1) ...[
                const SizedBox(height: 8),
                _PageIndicator(
                  currentIndex: currentIndex,
                  totalCount: totalCount,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ImageViewerActionButton extends StatelessWidget {
  const _ImageViewerActionButton({
    required this.action,
    required this.currentIndex,
  });

  final ImageViewerAction action;
  final int currentIndex;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      key: ValueKey<String>('image-viewer-action-${action.key}'),
      borderRadius: BorderRadius.circular(12),
      onTap: () => action.onPressed(context, currentIndex),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(action.icon, color: Colors.white, size: 22),
            const SizedBox(height: 6),
            Text(
              action.label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Page indicator dots
class _PageIndicator extends StatelessWidget {
  final int currentIndex;
  final int totalCount;

  const _PageIndicator({
    required this.currentIndex,
    required this.totalCount,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(totalCount, (index) {
        final isActive = index == currentIndex;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.symmetric(horizontal: 3),
          width: isActive ? 8 : 6,
          height: isActive ? 8 : 6,
          decoration: BoxDecoration(
            color: isActive ? Colors.white : Colors.white54,
            shape: BoxShape.circle,
          ),
        );
      }),
    );
  }
}

/// Image viewer helper
class ImageViewerHelper {
  /// Open image viewer
  static Future<int?> show(
    BuildContext context, {
    required List<String> images,
    int initialIndex = 0,
    String? heroTag,
    String? caption,
    List<ImageViewerAction> actions = const <ImageViewerAction>[],
    bool enableLongPressOptions = true,
  }) async {
    return Navigator.of(context).push<int>(
      PageRouteBuilder(
        opaque: false,
        pageBuilder: (context, animation, secondaryAnimation) {
          return ImageViewer(
            args: ImageViewerArgs(
              images: images,
              initialIndex: initialIndex,
              heroTag: heroTag,
              caption: caption,
              actions: actions,
              enableLongPressOptions: enableLongPressOptions,
            ),
          );
        },
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
  }

  /// Open single image viewer
  static Future<int?> showImage(
    BuildContext context, {
    required String image,
    String? heroTag,
    String? caption,
    List<ImageViewerAction> actions = const <ImageViewerAction>[],
    bool enableLongPressOptions = true,
  }) {
    return show(
      context,
      images: [image],
      heroTag: heroTag,
      caption: caption,
      actions: actions,
      enableLongPressOptions: enableLongPressOptions,
    );
  }
}
