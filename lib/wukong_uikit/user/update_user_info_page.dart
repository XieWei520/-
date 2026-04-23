import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:wukongimfluttersdk/type/const.dart';
import 'package:wukongimfluttersdk/wkim.dart';

import '../../core/utils/storage_utils.dart';
import '../../service/api/user_api.dart';
import '../../widgets/wk_colors.dart';
import '../../widgets/wk_sub_page_scaffold.dart';

enum UserInfoUpdateType { name, shortNo }

class UpdateUserInfoPage extends StatefulWidget {
  final UserInfoUpdateType type;
  final String initialValue;
  final Future<void> Function(String value)? onSave;

  const UpdateUserInfoPage({
    super.key,
    required this.type,
    this.initialValue = '',
    this.onSave,
  });

  @override
  State<UpdateUserInfoPage> createState() => _UpdateUserInfoPageState();
}

class _UpdateUserInfoPageState extends State<UpdateUserInfoPage> {
  late final TextEditingController _controller;
  late final String _initialValue;
  bool _hasChanges = false;
  bool _isSaving = false;

  bool get _isName => widget.type == UserInfoUpdateType.name;
  String get _pageTitle => _isName ? '修改名称' : '修改悟空号';

  @override
  void initState() {
    super.initState();
    _initialValue = _sanitizeValue(widget.initialValue);
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
    final value = _sanitizeValue(_controller.text);
    final hasChanges = value.isNotEmpty && value != _initialValue;
    if (hasChanges != _hasChanges) {
      setState(() => _hasChanges = hasChanges);
    }
  }

  Future<void> _save() async {
    if (_isSaving || !_hasChanges) {
      return;
    }

    final value = _sanitizeValue(_controller.text);
    if (value.isEmpty) {
      return;
    }

    setState(() => _isSaving = true);
    try {
      if (widget.onSave != null) {
        await widget.onSave!(value);
      } else if (_isName) {
        await UserApi.instance.updateUserInfo(name: value);
      } else {
        await UserApi.instance.updateUserInfo(shortNo: value);
      }
      if (_isName) {
        await _syncCurrentPersonalChannelName(value);
      }

      if (!mounted) {
        return;
      }
      Navigator.of(context).pop(value);
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

  String _sanitizeValue(String value) {
    return value.replaceAll('\n', '');
  }

  Future<void> _syncCurrentPersonalChannelName(String value) async {
    final uid = StorageUtils.getUid()?.trim() ?? WKIM.shared.options.uid?.trim() ?? '';
    if (uid.isEmpty) {
      return;
    }

    final channel = await WKIM.shared.channelManager.getChannel(
      uid,
      WKChannelType.personal,
    );
    if (channel == null) {
      return;
    }
    channel.channelName = value;
    WKIM.shared.channelManager.addOrUpdateChannel(channel);
  }

  @override
  Widget build(BuildContext context) {
    return WKSubPageScaffold(
      title: _pageTitle,
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
                ? WKSubPageAction(
                    key: const ValueKey('update_user_info_complete_action'),
                    text: '完成',
                    onTap: _save,
                  )
                : const SizedBox.shrink()),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(top: 20),
            color: WKColors.surface,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(15, 5, 15, 5),
              child: TextField(
                key: const ValueKey('update_user_info_input'),
                controller: _controller,
                autofocus: true,
                minLines: 1,
                maxLines: 1,
                textInputAction: TextInputAction.done,
                style: const TextStyle(fontSize: 14, color: WKColors.colorDark),
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  isCollapsed: true,
                  hintText: '请输入…',
                  hintStyle: TextStyle(color: WKColors.color999),
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.deny(RegExp(r'[\r\n]')),
                  _AndroidLengthLimitingTextInputFormatter(maxUnits: 10),
                ],
                onSubmitted: (_) => _save(),
              ),
            ),
          ),
          if (!_isName)
            const Padding(
              padding: EdgeInsets.fromLTRB(15, 5, 15, 0),
              child: Text(
                '悟空号只允许修改一次',
                style: TextStyle(fontSize: 14, color: WKColors.color999),
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
