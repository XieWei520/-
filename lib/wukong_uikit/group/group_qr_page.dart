import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../core/utils/qr_export_utils.dart';
import '../../data/models/group.dart';
import '../../service/api/group_api.dart';
import '../../widgets/wk_avatar.dart';
import '../../widgets/wk_colors.dart';
import '../../widgets/wk_dialog.dart';
import '../../widgets/wk_reference_assets.dart';
import '../../widgets/wk_sub_page_scaffold.dart';

class GroupQrPage extends StatefulWidget {
  final String groupId;
  final bool autoLoad;

  const GroupQrPage({super.key, required this.groupId, this.autoLoad = true});

  @override
  State<GroupQrPage> createState() => _GroupQrPageState();
}

class _GroupQrPageState extends State<GroupQrPage> {
  final GlobalKey _cardKey = GlobalKey();

  GroupInfo? _group;
  String? _qrCode;
  int? _expireDays;
  String _expireText = '';
  bool _isLoading = true;
  bool _isSaving = false;

  bool get _inviteOnly => (_group?.invite ?? 0) == 1;

  String get _displayName {
    final name = (_group?.name ?? '').trim();
    return name.isEmpty ? '群聊' : name;
  }

  @override
  void initState() {
    super.initState();
    if (widget.autoLoad) {
      _loadQrCode();
    } else {
      _isLoading = false;
    }
  }

  Future<void> _loadQrCode() async {
    setState(() => _isLoading = true);

    GroupInfo? group;
    Object? qrError;
    Map<String, dynamic> qrPayload = const <String, dynamic>{};

    try {
      group = await GroupApi.instance.getGroupInfo(widget.groupId);
    } catch (_) {}

    try {
      qrPayload = await GroupApi.instance.getGroupQrCode(widget.groupId);
    } catch (error) {
      qrError = error;
    }

    if (!mounted) {
      return;
    }

    setState(() {
      _group = group;
      _qrCode = (qrPayload['qrcode'] ?? '').toString().trim();
      _expireDays = (qrPayload['day'] as num?)?.toInt();
      _expireText = (qrPayload['expire'] ?? '').toString().trim();
      _isLoading = false;
    });

    if (qrError != null && !_inviteOnly) {
      _showMessage('加载群二维码失败：$qrError');
    }
  }

  @override
  Widget build(BuildContext context) {
    return WKSubPageScaffold(
      title: '群二维码',
      trailing: _isLoading
          ? null
          : GestureDetector(
              onTap: _isSaving ? null : _showMoreActions,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                child: WKReferenceAssets.image(
                  WKReferenceAssets.topMore,
                  width: 18,
                  height: 18,
                  tint: _isSaving ? WKColors.color999 : WKColors.colorDark,
                ),
              ),
            ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: RepaintBoundary(
                    key: _cardKey,
                    child: Container(
                      width: double.infinity,
                      constraints: const BoxConstraints(maxWidth: 360),
                      decoration: BoxDecoration(
                        color: WKColors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withAlpha(20),
                            blurRadius: 14,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(20),
                            child: Row(
                              children: [
                                WKAvatar(
                                  url: _group?.avatar,
                                  name: _displayName,
                                  size: 45,
                                  isGroup: true,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    _displayName,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 16,
                                      color: WKColors.colorDark,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                            child: _buildQrArea(),
                          ),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                            child: Text(
                              _buildDescriptionText(),
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: _inviteOnly ? 22 : 14,
                                height: 1.45,
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
  }

  Widget _buildQrArea() {
    if (_inviteOnly) {
      return Stack(
        alignment: Alignment.center,
        children: [
          _buildQrPlaceholder(),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              '该群已开启进群验证\n只可通过邀请进群',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 22,
                height: 1.35,
                color: WKColors.color999,
              ),
            ),
          ),
        ],
      );
    }

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
        decoration: BoxDecoration(
          color: const Color(0xFFF3F4F6),
          borderRadius: BorderRadius.circular(4),
        ),
        child: const Center(
          child: Icon(Icons.qr_code_2, size: 96, color: WKColors.color999),
        ),
      ),
    );
  }

  String _buildDescriptionText() {
    if (_inviteOnly) {
      return '该群已开启进群验证\n只可通过邀请进群';
    }

    final day = _expireDays;
    final expire = _expireText.trim();
    if (day != null && day > 0 && expire.isNotEmpty) {
      return '该二维码$day天内($expire)有效，重新进入将更新';
    }
    if (day != null && day > 0) {
      return '该二维码$day天内有效，重新进入将更新';
    }
    return '重新进入将更新';
  }

  Future<void> _showMoreActions() async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => WKBottomSheet(
        title: '群二维码',
        items: [
          WKBottomSheetItem(
            title: '保存图片',
            icon: Icons.download_rounded,
            enabled: !_isSaving,
            onTap: _saveQrImage,
          ),
        ],
      ),
    );
  }

  Future<void> _saveQrImage() async {
    if (_isSaving) {
      return;
    }

    final boundary =
        _cardKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
    if (boundary == null) {
      _showMessage('当前二维码卡片还没有准备好');
      return;
    }

    setState(() => _isSaving = true);
    try {
      final image = await boundary.toImage(pixelRatio: 3);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      if (byteData == null) {
        throw Exception('生成群二维码图片失败');
      }

      final savedPath = await QrExportUtils.savePngBytes(
        bytes: Uint8List.fromList(byteData.buffer.asUint8List()),
        fileNamePrefix: 'group_qrcode_${widget.groupId}',
      );
      _showMessage('二维码图片已保存到 $savedPath');
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
