import 'dart:io';
import 'dart:typed_data';

import 'package:crop_your_image/crop_your_image.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

import '../../widgets/wk_colors.dart';
import '../../widgets/wk_sub_page_scaffold.dart';

class AvatarCropPage extends StatefulWidget {
  const AvatarCropPage({
    super.key,
    required this.sourcePath,
  });

  final String sourcePath;

  @override
  State<AvatarCropPage> createState() => _AvatarCropPageState();
}

class _AvatarCropPageState extends State<AvatarCropPage> {
  final CropController _controller = CropController();

  Uint8List? _imageBytes;
  Object? _loadError;
  bool _isCropping = false;

  @override
  void initState() {
    super.initState();
    _loadImageBytes();
  }

  Future<void> _loadImageBytes() async {
    try {
      final bytes = await File(widget.sourcePath).readAsBytes();
      if (!mounted) {
        return;
      }
      setState(() {
        _imageBytes = bytes;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _loadError = error;
      });
    }
  }

  Future<void> _persistCroppedImage(Uint8List croppedImage) async {
    final directory = await getTemporaryDirectory();
    final extension = path.extension(widget.sourcePath).trim().toLowerCase();
    final normalizedExtension = extension.isEmpty ? '.png' : extension;
    final targetPath = path.join(
      directory.path,
      'avatar_crop_${DateTime.now().microsecondsSinceEpoch}$normalizedExtension',
    );
    final file = File(targetPath);
    await file.writeAsBytes(croppedImage, flush: true);
    if (!mounted) {
      return;
    }
    Navigator.of(context).pop(targetPath);
  }

  @override
  Widget build(BuildContext context) {
    return WKSubPageScaffold(
      title: '\u88c1\u526a\u5934\u50cf',
      body: ColoredBox(
        color: WKColors.black,
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_loadError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            '\u52a0\u8f7d\u56fe\u7247\u5931\u8d25',
            style: const TextStyle(color: WKColors.white),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    final imageBytes = _imageBytes;
    if (imageBytes == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return Column(
      children: [
        Expanded(
          child: Crop(
            image: imageBytes,
            controller: _controller,
            aspectRatio: 1,
            withCircleUi: true,
            baseColor: WKColors.black,
            maskColor: WKColors.bottomDrawerOutsideBg,
            radius: 20,
            onCropped: (result) async {
              try {
                switch (result) {
                  case CropSuccess(:final croppedImage):
                    await _persistCroppedImage(croppedImage);
                  case CropFailure():
                    if (mounted) {
                      Navigator.of(context).maybePop();
                    }
                }
              } finally {
                if (mounted) {
                  setState(() {
                    _isCropping = false;
                  });
                }
              }
            },
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _isCropping
                        ? null
                        : () => Navigator.of(context).maybePop(),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: WKColors.white,
                      side: const BorderSide(color: WKColors.white),
                    ),
                    child: const Text('\u53d6\u6d88'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: _isCropping
                        ? null
                        : () {
                            setState(() {
                              _isCropping = true;
                            });
                            _controller.crop();
                          },
                    style: FilledButton.styleFrom(
                      backgroundColor: WKColors.brand500,
                      foregroundColor: WKColors.white,
                    ),
                    child: Text(
                      _isCropping ? '\u5904\u7406\u4e2d...' : '\u5b8c\u6210',
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
