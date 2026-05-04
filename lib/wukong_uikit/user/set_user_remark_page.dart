import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../service/api/friend_api.dart';
import '../../widgets/wk_colors.dart';
import '../../widgets/wk_sub_page_scaffold.dart';

class SetUserRemarkPage extends StatefulWidget {
  final String uid;
  final String initialValue;
  final Future<void> Function(String value)? onSave;

  const SetUserRemarkPage({
    super.key,
    required this.uid,
    this.initialValue = '',
    this.onSave,
  });

  @override
  State<SetUserRemarkPage> createState() => _SetUserRemarkPageState();
}

class _SetUserRemarkPageState extends State<SetUserRemarkPage> {
  late final TextEditingController _controller;
  late final String _initialValue;
  bool _hasChanges = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _initialValue = widget.initialValue;
    _controller = TextEditingController(text: _initialValue)
      ..selection = TextSelection.collapsed(offset: _initialValue.length);
    _controller.addListener(_handleTextChanged);
  }

  @override
  void dispose() {
    _controller.removeListener(_handleTextChanged);
    _controller.dispose();
    super.dispose();
  }

  void _handleTextChanged() {
    final hasChanges = _controller.text != _initialValue;
    if (hasChanges != _hasChanges) {
      setState(() => _hasChanges = hasChanges);
    }
  }

  Future<void> _save() async {
    if (_isSaving || !_hasChanges) {
      return;
    }

    final remark = _controller.text;
    setState(() => _isSaving = true);
    try {
      if (widget.onSave != null) {
        await widget.onSave!(remark);
      } else {
        await FriendApi.instance.updateFriendRemark(widget.uid, remark);
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
    return WKSubPageScaffold(
      title: '设置备注',
      trailingWidth: 60,
      trailing: _isSaving
          ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(WKColors.brand500),
              ),
            )
          : (_hasChanges
                ? WKSubPageAction(text: '确定', onTap: _save)
                : const SizedBox.shrink()),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(top: 20),
            color: WKColors.surface,
            child: Padding(
              padding: const EdgeInsets.all(15),
              child: TextField(
                key: const ValueKey('set_user_remark_input'),
                controller: _controller,
                autofocus: true,
                minLines: 1,
                maxLines: 20,
                style: const TextStyle(fontSize: 16, color: WKColors.colorDark),
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  isCollapsed: true,
                  hintText: '请输入备注',
                  hintStyle: TextStyle(color: WKColors.color999),
                ),
                inputFormatters: const [
                  _AndroidLengthLimitingTextInputFormatter(maxUnits: 20),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AndroidLengthLimitingTextInputFormatter extends TextInputFormatter {
  final int maxUnits;

  const _AndroidLengthLimitingTextInputFormatter({required this.maxUnits});

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final truncated = _truncateToMaxUnits(newValue.text);
    if (truncated == newValue.text) {
      return newValue;
    }

    return TextEditingValue(
      text: truncated,
      selection: TextSelection.collapsed(offset: truncated.length),
      composing: TextRange.empty,
    );
  }

  String _truncateToMaxUnits(String value) {
    final buffer = StringBuffer();
    var units = 0;

    for (final rune in value.runes) {
      final char = String.fromCharCode(rune);
      final nextUnits = units + _weightOfRune(rune);
      if (nextUnits > maxUnits) {
        break;
      }
      buffer.write(char);
      units = nextUnits;
    }

    return buffer.toString();
  }

  int _weightOfRune(int rune) {
    return rune < 128 ? 1 : 2;
  }
}
