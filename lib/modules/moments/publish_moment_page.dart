import 'package:flutter/material.dart';

import '../../widgets/local_media_image_provider.dart';
import '../../widgets/wk_button.dart';
import '../../widgets/wk_colors.dart';
import '../../widgets/wk_design_tokens.dart';
import 'moment_mention_picker_dialog.dart';
import 'moments_service.dart';

class PublishMomentPage extends StatefulWidget {
  const PublishMomentPage({
    super.key,
    this.service,
    this.locationPicker,
    this.mentionPicker,
  });

  final MomentsComposeService? service;
  final Future<Map<String, dynamic>?> Function(BuildContext context)?
  locationPicker;
  final Future<List<MomentMention>?> Function(BuildContext context)?
  mentionPicker;

  @override
  State<PublishMomentPage> createState() => _PublishMomentPageState();
}

class _PublishMomentPageState extends State<PublishMomentPage> {
  final TextEditingController _contentController = TextEditingController();
  final List<String> _selectedImages = <String>[];
  final MomentsService _momentsService = MomentsService.instance;

  Map<String, dynamic>? _selectedLocation;
  List<MomentMention> _selectedMentions = const <MomentMention>[];
  bool _isPublishing = false;

  MomentsComposeService get _composeService =>
      widget.service ?? _momentsService;

  @override
  void dispose() {
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _pickImages() async {
    final images = await _momentsService.pickImages(
      maxImages: 9 - _selectedImages.length,
    );
    if (!mounted || images.isEmpty) {
      return;
    }
    setState(() => _selectedImages.addAll(images));
  }

  Future<void> _takePhoto() async {
    try {
      final image = await _momentsService.takePhoto();
      if (!mounted || image == null || _selectedImages.length >= 9) {
        return;
      }
      setState(() => _selectedImages.add(image));
    } on UnsupportedError catch (error) {
      _showSnackBar(error.message?.toString() ?? '当前平台暂不支持拍照', isError: true);
    } catch (error) {
      _showSnackBar('拍照失败: $error', isError: true);
    }
  }

  Future<void> _pickLocation() async {
    final picker = widget.locationPicker ?? _defaultLocationPicker;
    final result = await picker(context);
    if (!mounted || result == null || result.isEmpty) {
      return;
    }
    setState(() => _selectedLocation = Map<String, dynamic>.from(result));
  }

  Future<void> _pickMentions() async {
    final picker = widget.mentionPicker ?? showMomentMentionPickerDialog;
    final result = await picker(context);
    if (!mounted || result == null) {
      return;
    }
    setState(() {
      _selectedMentions = List<MomentMention>.unmodifiable(result);
    });
  }

  Future<Map<String, dynamic>?> _defaultLocationPicker(
    BuildContext context,
  ) async {
    final controller = TextEditingController();
    try {
      return await showDialog<Map<String, dynamic>>(
        context: context,
        builder: (dialogContext) {
          return AlertDialog(
            title: const Text('填写位置'),
            content: TextField(
              controller: controller,
              autofocus: true,
              decoration: const InputDecoration(hintText: '输入位置名称或详细地址'),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('取消'),
              ),
              FilledButton(
                onPressed: () {
                  final address = controller.text.trim();
                  if (address.isEmpty) {
                    Navigator.of(dialogContext).pop();
                    return;
                  }
                  Navigator.of(dialogContext).pop(<String, dynamic>{
                    'title': address,
                    'address': address,
                  });
                },
                child: const Text('确定'),
              ),
            ],
          );
        },
      );
    } finally {
      controller.dispose();
    }
  }

  void _removeImage(int index) {
    setState(() => _selectedImages.removeAt(index));
  }

  Future<void> _publish() async {
    final content = _contentController.text.trim();
    if (content.isEmpty && _selectedImages.isEmpty) {
      _showSnackBar('请输入内容或选择图片', isError: true);
      return;
    }

    final mentions = _selectedMentions
        .map((item) => item.uid)
        .where((item) => item.trim().isNotEmpty)
        .toList(growable: false);
    final location =
        _selectedLocation?['address']?.toString().trim().isNotEmpty == true
        ? _selectedLocation!['address'].toString().trim()
        : _selectedLocation?['title']?.toString().trim();

    setState(() => _isPublishing = true);
    try {
      await _composeService.publish(
        MomentPublishRequest(
          content: content.isNotEmpty ? content : null,
          images: _selectedImages,
          mentions: mentions,
          location: location?.isEmpty == true ? null : location,
        ),
      );

      if (mounted) {
        Navigator.pop(context, {'success': true});
      }
    } catch (error) {
      _showSnackBar('发布失败: $error', isError: true);
    } finally {
      if (mounted) {
        setState(() => _isPublishing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final locationLabel =
        _selectedLocation?['address']?.toString().trim().isNotEmpty == true
        ? _selectedLocation!['address'].toString().trim()
        : _selectedLocation?['title']?.toString().trim();

    return Scaffold(
      appBar: AppBar(
        title: const Text('发布动态'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: WKSpace.md),
            child: Center(
              child: SizedBox(
                width: 96,
                child: WKButton(
                  key: const ValueKey<String>('moment-publish-button'),
                  text: '发布',
                  isLoading: _isPublishing,
                  onPressed: _isPublishing ? null : _publish,
                ),
              ),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          WKSpace.md,
          WKSpace.md,
          WKSpace.md,
          WKSpace.xxl,
        ),
        children: [
          Container(
            padding: const EdgeInsets.all(WKSpace.lg),
            decoration: BoxDecoration(
              color: WKColors.surface,
              borderRadius: BorderRadius.circular(WKRadius.xl),
              border: Border.all(color: WKColors.outline),
              boxShadow: WKShadows.card,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('这一刻想分享什么？', style: textTheme.headlineSmall),
                const SizedBox(height: WKSpace.xs),
                Text(
                  '支持图片、位置和@好友，让发布内容和参考项目保持一致。',
                  style: textTheme.bodyMedium,
                ),
                const SizedBox(height: WKSpace.lg),
                TextField(
                  controller: _contentController,
                  maxLines: 8,
                  minLines: 6,
                  maxLength: 500,
                  decoration: const InputDecoration(
                    hintText: '分享你的想法、此刻的心情或一段记录',
                    alignLabelWithHint: true,
                  ),
                ),
                const SizedBox(height: WKSpace.md),
                Wrap(
                  spacing: WKSpace.sm,
                  runSpacing: WKSpace.sm,
                  children: [
                    _ActionButton(
                      icon: Icons.photo_library_outlined,
                      label: '相册',
                      onTap: _pickImages,
                    ),
                    _ActionButton(
                      icon: Icons.camera_alt_outlined,
                      label: '拍照',
                      onTap: _takePhoto,
                    ),
                    _ActionButton(
                      key: const ValueKey<String>(
                        'moment-pick-location-button',
                      ),
                      icon: Icons.location_on_outlined,
                      label: '位置',
                      onTap: _pickLocation,
                    ),
                    _ActionButton(
                      key: const ValueKey<String>('moment-pick-mention-button'),
                      icon: Icons.alternate_email_rounded,
                      label: '@好友',
                      onTap: _pickMentions,
                    ),
                  ],
                ),
                if ((locationLabel ?? '').trim().isNotEmpty) ...[
                  const SizedBox(height: WKSpace.md),
                  Row(
                    children: [
                      const Icon(
                        Icons.location_on_outlined,
                        size: 16,
                        color: WKColors.textSecondary,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(locationLabel!, style: textTheme.bodySmall),
                      ),
                    ],
                  ),
                ],
                if (_selectedMentions.isNotEmpty) ...[
                  const SizedBox(height: WKSpace.sm),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: _selectedMentions
                        .map((item) => Chip(label: Text('@${item.name}')))
                        .toList(growable: false),
                  ),
                ],
              ],
            ),
          ),
          if (_selectedImages.isNotEmpty) ...[
            const SizedBox(height: WKSpace.md),
            Text(
              '已选图片 (${_selectedImages.length}/9)',
              style: textTheme.titleSmall,
            ),
            const SizedBox(height: WKSpace.sm),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _selectedImages.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
              ),
              itemBuilder: (context, index) {
                final imageProvider = resolveLocalMediaImageProvider(
                  _selectedImages[index],
                );
                return Stack(
                  fit: StackFit.expand,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(WKRadius.lg),
                      child: imageProvider == null
                          ? const _MomentImagePreviewFallback()
                          : Image(
                              image: imageProvider,
                              fit: BoxFit.cover,
                              errorBuilder: (_, _, _) =>
                                  const _MomentImagePreviewFallback(),
                            ),
                    ),
                    Positioned(
                      top: 6,
                      right: 6,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(WKRadius.pill),
                        onTap: () => _removeImage(index),
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: WKColors.black.withValues(alpha: 0.55),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.close_rounded,
                            size: 14,
                            color: WKColors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ],
        ],
      ),
    );
  }

  void _showSnackBar(String message, {bool isError = false}) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? WKColors.danger : null,
      ),
    );
  }
}

class _MomentImagePreviewFallback extends StatelessWidget {
  const _MomentImagePreviewFallback();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: WKColors.surfaceSoft,
      alignment: Alignment.center,
      child: const Icon(
        Icons.image_not_supported_outlined,
        color: WKColors.textSecondary,
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    super.key,
    required this.icon,
    required this.label,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(WKRadius.lg),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: WKSpace.md,
          vertical: WKSpace.sm,
        ),
        decoration: BoxDecoration(
          color: WKColors.surfaceSoft,
          borderRadius: BorderRadius.circular(WKRadius.lg),
          border: Border.all(color: WKColors.outline),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: WKColors.textSecondary),
            const SizedBox(width: WKSpace.xs),
            Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
    );
  }
}
