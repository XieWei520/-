import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../core/config/app_config.dart';
import '../../core/utils/qr_export_utils.dart';
import '../../service/api/user_api.dart';
import '../../widgets/wk_avatar.dart';
import '../../widgets/wk_colors.dart';
import '../../widgets/wk_reference_assets.dart';
import '../../widgets/wk_screen_popup_menu.dart';
import '../../widgets/wk_sub_page_scaffold.dart';

enum _UserQrMenuAction { saveLocal }

class UserQrPage extends StatefulWidget {
  final String? uid;
  final String? qrData;
  final String? username;
  final String? avatarUrl;
  final String? title;
  final Future<void> Function(Uint8List bytes)? onSaveCardBytes;

  const UserQrPage({
    super.key,
    this.uid,
    this.qrData,
    this.username,
    this.avatarUrl,
    this.title,
    this.onSaveCardBytes,
  });

  @override
  State<UserQrPage> createState() => _UserQrPageState();
}

class _UserQrPageState extends State<UserQrPage> {
  final GlobalKey _cardKey = GlobalKey();

  String? _qrCode;
  String? _username;
  String? _avatar;
  bool _isLoading = true;
  bool _isSaving = false;

  String get _pageTitle {
    final customTitle = widget.title?.trim() ?? '';
    return customTitle.isEmpty ? '我的二维码' : customTitle;
  }

  String get _displayName {
    final name = _username?.trim() ?? '';
    return name.isEmpty ? '用户' : name;
  }

  String get _descriptionText => '扫一扫上面的二维码图案，加我${AppConfig.appName}';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    if (widget.qrData?.trim().isNotEmpty == true) {
      setState(() {
        _qrCode = widget.qrData!.trim();
        _username = widget.username?.trim();
        _avatar = widget.avatarUrl?.trim();
        _isLoading = false;
      });
      return;
    }

    try {
      final result = await UserApi.instance.getUserQrCode(widget.uid);
      if (!mounted) {
        return;
      }
      setState(() {
        _qrCode = _firstNonEmptyText([
          result['data']?.toString(),
          result['qrcode']?.toString(),
          result['qr_code']?.toString(),
        ]);
        _username = _firstNonEmptyText([
          result['username']?.toString(),
          result['name']?.toString(),
          widget.username,
        ]);
        _avatar = _firstNonEmptyText([
          result['avatar']?.toString(),
          widget.avatarUrl,
        ]);
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() => _isLoading = false);
      _showMessage('加载二维码失败：$error');
    }
  }

  @override
  Widget build(BuildContext context) {
    return WKSubPageScaffold(
      title: _pageTitle,
      trailing: _isLoading
          ? null
          : Builder(
              builder: (anchorContext) {
                return GestureDetector(
                  key: const ValueKey('user_qr_more_action'),
                  onTap: _isSaving
                      ? null
                      : () => _showMoreActions(anchorContext),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 6,
                    ),
                    child: WKReferenceAssets.image(
                      WKReferenceAssets.topMore,
                      width: 18,
                      height: 18,
                      tint: _isSaving ? WKColors.color999 : WKColors.colorDark,
                    ),
                  ),
                );
              },
            ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight,
                    ),
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: RepaintBoundary(
                          key: _cardKey,
                          child: Container(
                            key: const ValueKey('user_qr_card'),
                            width: double.infinity,
                            constraints: const BoxConstraints(maxWidth: 360),
                            decoration: BoxDecoration(
                              color: WKColors.white,
                              borderRadius: BorderRadius.circular(5),
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const SizedBox(height: 20),
                                WKAvatar(
                                  url: _avatar,
                                  name: _displayName,
                                  size: 60,
                                ),
                                const SizedBox(height: 10),
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 20,
                                  ),
                                  child: Text(
                                    _displayName,
                                    textAlign: TextAlign.center,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 16,
                                      color: WKColors.colorDark,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 20),
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 20,
                                  ),
                                  child: _buildQrArea(),
                                ),
                                const SizedBox(height: 10),
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(
                                    20,
                                    0,
                                    20,
                                    20,
                                  ),
                                  child: Text(
                                    _descriptionText,
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      fontSize: 14,
                                      color: WKColors.color999,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }

  Widget _buildQrArea() {
    final qrCode = _qrCode?.trim() ?? '';
    if (qrCode.isEmpty) {
      return _buildQrPlaceholder();
    }

    return SizedBox(
      width: 250,
      height: 250,
      child: QrImageView(
        data: qrCode,
        version: QrVersions.auto,
        size: 250,
        backgroundColor: WKColors.white,
        padding: EdgeInsets.zero,
      ),
    );
  }

  Widget _buildQrPlaceholder() {
    return SizedBox(
      width: 250,
      height: 250,
      child: DecoratedBox(
        decoration: const BoxDecoration(color: Color(0xFFF3F4F6)),
        child: const Center(
          child: Icon(Icons.qr_code_2, size: 96, color: WKColors.color999),
        ),
      ),
    );
  }

  Future<void> _showMoreActions(BuildContext anchorContext) async {
    final action = await showWKScreenPopupMenu<_UserQrMenuAction>(
      context: context,
      anchorContext: anchorContext,
      items: [
        WKScreenPopupMenuItem<_UserQrMenuAction>(
          value: _UserQrMenuAction.saveLocal,
          title: '保存到本地',
          icon: Icons.download_rounded,
          enabled: !_isSaving,
        ),
      ],
    );

    if (!mounted) {
      return;
    }
    if (action == _UserQrMenuAction.saveLocal) {
      await _saveQrCardImage();
    }
  }

  Future<void> _saveQrCardImage() async {
    if (_isSaving) {
      return;
    }

    setState(() => _isSaving = true);
    try {
      if (widget.onSaveCardBytes != null) {
        final overrideBytes = Uint8List.fromList(
          (_qrCode ?? _descriptionText).codeUnits,
        );
        await widget.onSaveCardBytes!(overrideBytes);
        _showMessage('已保存在相册');
        return;
      }

      await WidgetsBinding.instance.endOfFrame;
      var boundary =
          _cardKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary != null && boundary.debugNeedsPaint) {
        await WidgetsBinding.instance.endOfFrame;
        boundary =
            _cardKey.currentContext?.findRenderObject()
                as RenderRepaintBoundary?;
      }
      if (boundary == null) {
        _showMessage('当前二维码卡片还没有准备好');
        return;
      }

      final image = await boundary.toImage(pixelRatio: 3);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      if (byteData == null) {
        throw Exception('生成二维码图片失败');
      }

      final bytes = Uint8List.fromList(byteData.buffer.asUint8List());
      if (widget.onSaveCardBytes != null) {
        await widget.onSaveCardBytes!(bytes);
      } else {
        await QrExportUtils.savePngBytes(
          bytes: bytes,
          fileNamePrefix: widget.uid?.trim().isNotEmpty == true
              ? 'user_qrcode_${widget.uid!.trim()}'
              : 'user_qrcode',
        );
      }

      _showMessage('已保存在相册');
    } catch (error) {
      _showMessage('保存二维码图片失败：$error');
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  void _showMessage(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

String? _firstNonEmptyText(Iterable<String?> values) {
  for (final value in values) {
    final normalized = value?.trim() ?? '';
    if (normalized.isNotEmpty) {
      return normalized;
    }
  }
  return null;
}
