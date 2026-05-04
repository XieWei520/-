import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../service/api/group_api.dart';
import '../../widgets/wk_avatar.dart';
import '../../widgets/wk_colors.dart';
import '../../widgets/wk_sub_page_scaffold.dart';

class GroupRemarkPage extends StatefulWidget {
  final String groupId;
  final String groupName;
  final String? groupAvatar;
  final String initialRemark;
  final Future<void> Function(String remark)? onSave;

  const GroupRemarkPage({
    super.key,
    required this.groupId,
    required this.groupName,
    this.groupAvatar,
    this.initialRemark = '',
    this.onSave,
  });

  @override
  State<GroupRemarkPage> createState() => _GroupRemarkPageState();
}

class _GroupRemarkPageState extends State<GroupRemarkPage> {
  late final TextEditingController _controller;
  bool _isSaving = false;
  bool _hasChanges = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: widget.initialRemark,
    )..selection = TextSelection.collapsed(offset: widget.initialRemark.length);
    _controller.addListener(_handleTextChanged);
  }

  @override
  void dispose() {
    _controller.removeListener(_handleTextChanged);
    _controller.dispose();
    super.dispose();
  }

  void _handleTextChanged() {
    final hasChanges = _controller.text != widget.initialRemark;
    if (hasChanges != _hasChanges) {
      setState(() => _hasChanges = hasChanges);
    }
  }

  void _fillGroupName() {
    final groupName = widget.groupName.trim();
    _controller
      ..text = groupName
      ..selection = TextSelection.collapsed(offset: groupName.length);
  }

  Future<void> _save() async {
    if (_isSaving || !_hasChanges) {
      return;
    }

    setState(() => _isSaving = true);
    try {
      final remark = _controller.text.trim();
      if (widget.onSave != null) {
        await widget.onSave!(remark);
      } else {
        await GroupApi.instance.updateGroupSetting(
          widget.groupId,
          'remark',
          remark,
        );
      }
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop(remark);
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('保存失败，请重试：$error')));
      setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final groupName = widget.groupName.trim();

    return WKSubPageScaffold(
      title: '',
      body: SingleChildScrollView(
        child: Column(
          children: [
            const SizedBox(height: 30),
            const Text(
              '备注',
              style: TextStyle(
                fontSize: 30,
                fontWeight: FontWeight.w700,
                color: WKColors.colorDark,
              ),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(15, 20, 15, 0),
              child: Text(
                '群聊的备注仅自己可见',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: WKColors.colorDark),
              ),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 20, 20, 0),
              child: Divider(
                height: 1,
                thickness: 1,
                color: WKColors.colorLine,
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
              child: Row(
                children: [
                  WKAvatar(
                    url: widget.groupAvatar,
                    name: groupName,
                    size: 40,
                    isGroup: true,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      autofocus: true,
                      minLines: 1,
                      maxLines: 2,
                      style: const TextStyle(
                        fontSize: 16,
                        color: WKColors.colorDark,
                      ),
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        isCollapsed: true,
                        hintText: '备注',
                        hintStyle: TextStyle(color: WKColors.color999),
                      ),
                      inputFormatters: [LengthLimitingTextInputFormatter(40)],
                    ),
                  ),
                ],
              ),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 10, 20, 0),
              child: Divider(
                height: 1,
                thickness: 1,
                color: WKColors.colorLine,
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
              child: Row(
                children: [
                  const Text(
                    '群聊名称：',
                    style: TextStyle(fontSize: 14, color: WKColors.color999),
                  ),
                  Expanded(
                    child: Text(
                      groupName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14,
                        color: WKColors.color999,
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: _fillGroupName,
                    child: const Padding(
                      padding: EdgeInsets.only(left: 10),
                      child: Text(
                        '填入',
                        style: TextStyle(
                          fontSize: 14,
                          color: WKColors.brand500,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Container(
              width: double.infinity,
              margin: const EdgeInsets.fromLTRB(30, 50, 30, 0),
              child: ElevatedButton(
                onPressed: _hasChanges && !_isSaving ? _save : null,
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size.fromHeight(44),
                  elevation: 0,
                  backgroundColor: WKColors.brand500,
                  disabledBackgroundColor: WKColors.brand500.withAlpha(51),
                  foregroundColor: WKColors.white,
                  disabledForegroundColor: WKColors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                ),
                child: _isSaving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            WKColors.white,
                          ),
                        ),
                      )
                    : const Text(
                        '保存',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
