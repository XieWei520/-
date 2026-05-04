import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../service/api/group_api.dart';
import '../../widgets/wk_colors.dart';
import '../../widgets/wk_sub_page_scaffold.dart';

class GroupNoticePage extends StatefulWidget {
  final String groupId;
  final String? initialNotice;
  final bool canEdit;

  const GroupNoticePage({
    super.key,
    required this.groupId,
    this.initialNotice,
    this.canEdit = true,
  });

  @override
  State<GroupNoticePage> createState() => _GroupNoticePageState();
}

class _GroupNoticePageState extends State<GroupNoticePage> {
  late final TextEditingController _controller;
  bool _isSaving = false;
  bool _hasChanges = false;

  String get _initialNotice => widget.initialNotice ?? '';

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: _initialNotice)
      ..selection = TextSelection.collapsed(offset: _initialNotice.length);
    _controller.addListener(_handleTextChanged);
  }

  @override
  void dispose() {
    _controller.removeListener(_handleTextChanged);
    _controller.dispose();
    super.dispose();
  }

  void _handleTextChanged() {
    final hasChanges = _controller.text != _initialNotice;
    if (hasChanges != _hasChanges) {
      setState(() => _hasChanges = hasChanges);
    }
  }

  Future<void> _saveNotice() async {
    if (!widget.canEdit || _isSaving || !_hasChanges) {
      return;
    }

    setState(() => _isSaving = true);
    try {
      final content = _controller.text.trim();
      await GroupApi.instance.updateGroupNotice(widget.groupId, content);
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop(content);
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('保存失败，请重试：$error')));
      setState(() => _isSaving = false);
      return;
    }

    if (mounted) {
      setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return WKSubPageScaffold(
      title: '群公告',
      trailing: widget.canEdit
          ? _isSaving
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        WKColors.brand500,
                      ),
                    ),
                  )
                : WKSubPageAction(text: '保存', onTap: _saveNotice)
          : null,
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
                child: TextField(
                  controller: _controller,
                  readOnly: !widget.canEdit,
                  autofocus: widget.canEdit,
                  maxLines: null,
                  minLines: 16,
                  textAlignVertical: TextAlignVertical.top,
                  style: const TextStyle(
                    fontSize: 16,
                    height: 1.35,
                    color: WKColors.colorDark,
                  ),
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    isCollapsed: true,
                  ),
                  inputFormatters: [LengthLimitingTextInputFormatter(300)],
                ),
              ),
            ),
          ),
          if (!widget.canEdit) _buildBottomHint(),
        ],
      ),
    );
  }

  Widget _buildBottomHint() {
    return Container(
      margin: const EdgeInsets.fromLTRB(0, 50, 0, 30),
      child: Row(
        children: const [
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(left: 10),
              child: Divider(height: 1, color: Color(0xFFE5E5E5)),
            ),
          ),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 10),
            child: Text(
              '只有群主及管理员可以编辑',
              style: TextStyle(fontSize: 14, color: WKColors.colorDark),
            ),
          ),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(right: 10),
              child: Divider(height: 1, color: Color(0xFFE5E5E5)),
            ),
          ),
        ],
      ),
    );
  }
}
