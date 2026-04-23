import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../service/api/group_api.dart';
import '../../widgets/wk_colors.dart';
import '../../widgets/wk_sub_page_scaffold.dart';

class UpdateGroupNamePage extends StatefulWidget {
  final String groupId;
  final String initialName;
  final Future<void> Function(String name)? onSave;

  const UpdateGroupNamePage({
    super.key,
    required this.groupId,
    required this.initialName,
    this.onSave,
  });

  @override
  State<UpdateGroupNamePage> createState() => _UpdateGroupNamePageState();
}

class _UpdateGroupNamePageState extends State<UpdateGroupNamePage> {
  late final TextEditingController _controller;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialName)
      ..selection = TextSelection.collapsed(offset: widget.initialName.length);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_isSaving) {
      return;
    }

    final name = _controller.text.trim();
    if (widget.groupId.trim().isEmpty || name.isEmpty) {
      return;
    }
    if (name == widget.initialName.trim()) {
      Navigator.of(context).pop(name);
      return;
    }

    setState(() => _isSaving = true);
    try {
      if (widget.onSave != null) {
        await widget.onSave!(name);
      } else {
        await GroupApi.instance.updateGroupInfo(widget.groupId, name: name);
      }
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop(name);
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
    return WKSubPageScaffold(
      title: '群名片',
      trailing: _isSaving
          ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(WKColors.brand500),
              ),
            )
          : WKSubPageAction(text: '保存', onTap: _save),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(15, 20, 15, 10),
            child: Text(
              '群聊名称',
              style: TextStyle(fontSize: 14, color: WKColors.colorDark),
            ),
          ),
          Container(
            width: double.infinity,
            color: WKColors.surface,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(15, 10, 15, 10),
              child: TextField(
                controller: _controller,
                autofocus: true,
                maxLines: 1,
                style: const TextStyle(fontSize: 16, color: WKColors.colorDark),
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  isCollapsed: true,
                  hintText: '群聊名称',
                  hintStyle: TextStyle(color: WKColors.color999),
                ),
                inputFormatters: [LengthLimitingTextInputFormatter(30)],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
