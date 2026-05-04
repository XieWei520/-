import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wukongimfluttersdk/entity/channel.dart';
import 'package:wukongimfluttersdk/type/const.dart';
import 'package:wukongimfluttersdk/wkim.dart';

import '../../data/models/chat_session.dart';
import '../../data/models/user.dart';
import '../../data/providers/conversation_provider.dart';
import '../../service/api/channel_api.dart';
import '../../service/api/message_api.dart';
import '../../service/api/user_api.dart';
import '../../widgets/wk_avatar.dart';
import '../../widgets/wk_colors.dart';
import '../../widgets/wk_dialog.dart';
import '../../widgets/wk_reference_assets.dart';
import '../../widgets/wk_sub_page_scaffold.dart';
import '../../wukong_uikit/setting/chat_background_settings_page.dart';
import '../../wukong_uikit/setting/setting_preferences.dart';
import '../../wukong_uikit/user/user_detail_page.dart';
import 'channel_settings_common.dart';
import '../report/report_page.dart';

const String _chatDetailsTitle = '聊天信息';
const String _chatDetailsSearchHistoryTitle = '查找聊天记录';
const String _chatDetailsMuteTitle = '消息免打扰';
const String _chatDetailsTopTitle = '置顶聊天';
const String _chatDetailsReportTitle = '投诉';
const String _chatDetailsClearHistoryTitle = '清空聊天记录';
const String _chatDetailsMuteEnabledMessage = '已开启消息免打扰';
const String _chatDetailsMuteDisabledMessage = '已关闭消息免打扰';
const String _chatDetailsTopEnabledMessage = '已置顶聊天';
const String _chatDetailsTopDisabledMessage = '已取消置顶聊天';
const String _chatDetailsActionFailedPrefix = '操作失败：';
const String _chatDetailsAddGroupHint = '拉人建群入口还在整理中，界面先按原版样式保留。';
const String _chatDetailsReportSubmittedMessage = '投诉已提交';
const String _chatDetailsClearHistoryPrompt = '确定要清空当前聊天记录吗？此操作不可恢复。';
const String _chatDetailsClearButton = '清空';
const String _chatDetailsClearHistorySuccessMessage = '聊天记录已清空';
const String _chatDetailsClearHistoryFailedPrefix = '清空聊天记录失败：';

const String _chatDetailsChatPasswordTitle = '聊天密码';
const String _chatDetailsAutoDeleteTitle = '消息自动删除';
const String _chatDetailsChatPasswordEnabledMessage = '已开启聊天密码';
const String _chatDetailsChatPasswordDisabledMessage = '已关闭聊天密码';
const String _chatDetailsAutoDeleteUpdatedMessage = '消息自动删除设置已更新';

const String _chatDetailsChatBackgroundTitle = '\u804a\u5929\u80cc\u666f';

class ChatDetailsPage extends ConsumerStatefulWidget {
  final String channelId;
  final int channelType;
  final String? channelName;
  final VoidCallback? onSearchChatHistory;

  const ChatDetailsPage({
    super.key,
    required this.channelId,
    required this.channelType,
    this.channelName,
    this.onSearchChatHistory,
  });

  @override
  ConsumerState<ChatDetailsPage> createState() => _ChatDetailsPageState();
}

class _ChatDetailsPageState extends ConsumerState<ChatDetailsPage> {
  String? _avatarUrl;
  String? _displayName;
  bool _isMuted = false;
  bool _isTop = false;
  bool _isChatPwdOn = false;
  int _messageAutoDeleteSeconds = 0;
  bool _isLoading = true;
  bool _isUpdating = false;

  ChatSession get _chatSession =>
      ChatSession(channelId: widget.channelId, channelType: widget.channelType);

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    if (!mounted) {
      return;
    }
    setState(() => _isLoading = true);

    try {
      final channel = await WKIM.shared.channelManager.getChannel(
        widget.channelId,
        widget.channelType,
      );

      User? user;
      ChannelInfo? channelInfo;
      if (widget.channelType == WKChannelType.personal) {
        try {
          user = await UserApi.instance.getUserInfo(widget.channelId);
        } catch (_) {}
      }
      try {
        channelInfo = await ChannelApi.instance.getChannelInfo(
          channelId: widget.channelId,
          channelType: widget.channelType,
        );
      } catch (_) {}

      final cachedRemoteChatPwdOn =
          readChannelExtraInt(channel?.remoteExtraMap, 'chat_pwd_on') == 1;
      final cachedLocalChatPwdOn =
          readChannelExtraInt(channel?.localExtra, 'chat_pwd_on') == 1;
      final resolvedChatPwdOn =
          (user?.chatPwdOn ??
              ((cachedRemoteChatPwdOn || cachedLocalChatPwdOn) ? 1 : 0)) ==
          1;
      final resolvedMessageAutoDelete = channelInfo?.msgAutoDelete != null
          ? channelInfo!.msgAutoDelete
          : _resolveCachedMessageAutoDelete(channel);

      if (!mounted) {
        return;
      }

      setState(() {
        _avatarUrl = _resolveAvatar(channel: channel, user: user);
        _displayName = _resolveName(channel: channel, user: user);
        _isMuted = channel?.mute == 1;
        _isTop = channel?.top == 1;
        _isChatPwdOn = resolvedChatPwdOn;
        _messageAutoDeleteSeconds = resolvedMessageAutoDelete;
        _isLoading = false;
      });
      await updateChannelExtraCache(
        channelId: widget.channelId,
        channelType: widget.channelType,
        channelName: _displayName,
        chatPwdOn: resolvedChatPwdOn ? 1 : 0,
        msgAutoDelete: resolvedMessageAutoDelete,
      );
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _displayName = widget.channelName ?? widget.channelId;
        _isChatPwdOn = false;
        _messageAutoDeleteSeconds = 0;
        _isLoading = false;
      });
    }
  }

  int _resolveCachedMessageAutoDelete(WKChannel? channel) {
    final remoteValue = readChannelExtraInt(
      channel?.remoteExtraMap,
      'msg_auto_delete',
    );
    if (remoteValue > 0) {
      return remoteValue;
    }
    return readChannelExtraInt(channel?.localExtra, 'msg_auto_delete');
  }

  String _resolveName({WKChannel? channel, User? user}) {
    final remark = channel?.channelRemark.trim() ?? '';
    final channelName = channel?.channelName.trim() ?? '';
    final userName = user?.name?.trim() ?? '';

    if (remark.isNotEmpty) {
      return remark;
    }
    if (userName.isNotEmpty) {
      return userName;
    }
    if (channelName.isNotEmpty) {
      return channelName;
    }
    if ((widget.channelName ?? '').trim().isNotEmpty) {
      return widget.channelName!.trim();
    }
    return widget.channelId;
  }

  String? _resolveAvatar({WKChannel? channel, User? user}) {
    final userAvatar = user?.avatar?.trim() ?? '';
    if (userAvatar.isNotEmpty) {
      return userAvatar;
    }
    final channelAvatar = channel?.avatar.trim() ?? '';
    return channelAvatar.isEmpty ? null : channelAvatar;
  }

  Future<void> _updateConversationSetting({
    required bool nextValue,
    required void Function(bool value) applyLocalValue,
    required Future<void> Function(bool value) persistChange,
    required String successMessage,
  }) async {
    if (_isUpdating) {
      return;
    }

    setState(() {
      _isUpdating = true;
      applyLocalValue(nextValue);
    });

    try {
      await persistChange(nextValue);
      _showMessage(successMessage);
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        applyLocalValue(!nextValue);
      });
      _showMessage('$_chatDetailsActionFailedPrefix$error');
    } finally {
      if (mounted) {
        setState(() => _isUpdating = false);
      }
    }
  }

  Future<void> _toggleMute(bool value) async {
    await _updateConversationSetting(
      nextValue: value,
      applyLocalValue: (next) => _isMuted = next,
      persistChange: (next) => ref
          .read(conversationProvider.notifier)
          .setMute(widget.channelId, widget.channelType, next),
      successMessage: value
          ? _chatDetailsMuteEnabledMessage
          : _chatDetailsMuteDisabledMessage,
    );
  }

  Future<void> _toggleTop(bool value) async {
    await _updateConversationSetting(
      nextValue: value,
      applyLocalValue: (next) => _isTop = next,
      persistChange: (next) => ref
          .read(conversationProvider.notifier)
          .setTop(widget.channelId, widget.channelType, next),
      successMessage: value
          ? _chatDetailsTopEnabledMessage
          : _chatDetailsTopDisabledMessage,
    );
  }

  Future<void> _toggleChatPassword(bool value) async {
    if (_isUpdating) {
      return;
    }

    final previousValue = _isChatPwdOn;
    setState(() {
      _isUpdating = true;
      _isChatPwdOn = value;
    });

    try {
      await UserApi.instance.updateUserSetting(
        widget.channelId,
        'chat_pwd_on',
        value ? 1 : 0,
      );
      await updateChannelExtraCache(
        channelId: widget.channelId,
        channelType: widget.channelType,
        channelName: _displayName,
        chatPwdOn: value ? 1 : 0,
      );
      _showMessage(
        value
            ? _chatDetailsChatPasswordEnabledMessage
            : _chatDetailsChatPasswordDisabledMessage,
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() => _isChatPwdOn = previousValue);
      await updateChannelExtraCache(
        channelId: widget.channelId,
        channelType: widget.channelType,
        channelName: _displayName,
        chatPwdOn: previousValue ? 1 : 0,
      );
      _showMessage('$_chatDetailsActionFailedPrefix$error');
    } finally {
      if (mounted) {
        setState(() => _isUpdating = false);
      }
    }
  }

  Future<void> _selectMessageAutoDelete() async {
    if (_isUpdating) {
      return;
    }

    final nextValue = await showChannelAutoDeletePicker(
      context: context,
      currentSeconds: _messageAutoDeleteSeconds,
      title: _chatDetailsAutoDeleteTitle,
    );
    if (nextValue == null || nextValue == _messageAutoDeleteSeconds) {
      return;
    }

    final previousValue = _messageAutoDeleteSeconds;
    setState(() {
      _isUpdating = true;
      _messageAutoDeleteSeconds = nextValue;
    });

    try {
      await ChannelApi.instance.setMessageAutoDelete(
        channelId: widget.channelId,
        channelType: widget.channelType,
        seconds: nextValue,
      );
      await updateChannelExtraCache(
        channelId: widget.channelId,
        channelType: widget.channelType,
        channelName: _displayName,
        msgAutoDelete: nextValue,
      );
      _showMessage(_chatDetailsAutoDeleteUpdatedMessage);
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() => _messageAutoDeleteSeconds = previousValue);
      await updateChannelExtraCache(
        channelId: widget.channelId,
        channelType: widget.channelType,
        channelName: _displayName,
        msgAutoDelete: previousValue,
      );
      _showMessage('$_chatDetailsActionFailedPrefix$error');
    } finally {
      if (mounted) {
        setState(() => _isUpdating = false);
      }
    }
  }

  Future<void> _openUserDetail() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => UserDetailPage(uid: widget.channelId)),
    );
    if (mounted) {
      await _loadData();
    }
  }

  void _showAddGroupHint() {
    _showMessage(_chatDetailsAddGroupHint);
  }

  Future<void> _openChatBackgroundSettings() async {
    await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => ChatBackgroundSettingsPage(
          channelId: widget.channelId,
          channelType: widget.channelType,
        ),
      ),
    );
  }

  Future<void> _openReportPage() async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => ReportPage(
          channelId: widget.channelId,
          channelType: widget.channelType,
          title: _chatDetailsReportTitle,
          targetName: _displayName,
        ),
      ),
    );
    if (result == true) {
      _showMessage(_chatDetailsReportSubmittedMessage);
    }
  }

  Future<void> _clearChatHistory() async {
    final confirmed = await showWKConfirmDialog(
      context: context,
      title: _chatDetailsClearHistoryTitle,
      content: _chatDetailsClearHistoryPrompt,
      confirmText: _chatDetailsClearButton,
      confirmTextColor: WKColors.danger,
    );

    if (confirmed != true) {
      return;
    }

    try {
      await MessageApi.instance.clearChannelMessages(
        channelId: widget.channelId,
        channelType: widget.channelType,
      );
      WKIM.shared.messageManager.clearWithChannel(
        widget.channelId,
        widget.channelType,
      );
      await ref.read(messageListProvider(_chatSession).notifier).loadMessages();
      _showMessage(_chatDetailsClearHistorySuccessMessage);
    } catch (error) {
      _showMessage('$_chatDetailsClearHistoryFailedPrefix$error');
    }
  }

  Widget _buildHeaderCard() {
    final displayName = (_displayName ?? widget.channelId).trim();

    return Container(
      color: WKColors.homeBg,
      padding: const EdgeInsets.all(15),
      child: Row(
        children: [
          InkWell(
            onTap: _openUserDetail,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                WKAvatar(
                  url: _avatarUrl,
                  name: displayName,
                  size: 64,
                  onTap: _openUserDetail,
                ),
                const SizedBox(height: 3),
                Text(
                  displayName,
                  style: const TextStyle(
                    fontSize: 14,
                    color: WKColors.colorDark,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 20),
          InkWell(
            onTap: _showAddGroupHint,
            child: SizedBox(
              width: 40,
              height: 40,
              child: WKReferenceAssets.image(
                WKReferenceAssets.chatAdd,
                width: 40,
                height: 40,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    return ListView(
      padding: const EdgeInsets.only(bottom: 30),
      children: [
        WKSettingsGroup(
          children: [
            _buildHeaderCard(),
            WKSettingsCell(
              title: _chatDetailsSearchHistoryTitle,
              onTap: widget.onSearchChatHistory,
            ),
            WKSettingsCell(
              key: const ValueKey<String>('chat_detail_chat_background_cell'),
              title: _chatDetailsChatBackgroundTitle,
              value: WKSettingPreferences.chatBackgroundLabel(
                locale: Localizations.localeOf(context),
                channelId: widget.channelId,
                channelType: widget.channelType,
              ),
              onTap: _openChatBackgroundSettings,
            ),
            const WKSectionGap(10),
            WKSettingsSwitchCell(
              title: _chatDetailsMuteTitle,
              value: _isMuted,
              padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 5),
              onChanged: _isUpdating ? null : _toggleMute,
            ),
            WKSettingsSwitchCell(
              title: _chatDetailsTopTitle,
              value: _isTop,
              padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 5),
              onChanged: _isUpdating ? null : _toggleTop,
            ),
            WKSettingsSwitchCell(
              key: const ValueKey<String>('chat_detail_chat_pwd_switch'),
              title: _chatDetailsChatPasswordTitle,
              value: _isChatPwdOn,
              padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 5),
              onChanged:
                  widget.channelType == WKChannelType.personal && !_isUpdating
                  ? _toggleChatPassword
                  : null,
            ),
            WKSettingsCell(
              key: const ValueKey<String>(
                'chat_detail_message_auto_delete_cell',
              ),
              title: _chatDetailsAutoDeleteTitle,
              value: formatChannelAutoDeleteLabel(
                _messageAutoDeleteSeconds,
                english: isEnglishLocale(context),
              ),
              onTap: _isUpdating ? null : _selectMessageAutoDelete,
            ),
            WKSettingsCell(
              title: _chatDetailsReportTitle,
              onTap: _openReportPage,
            ),
            const WKSectionGap(10),
            WKSettingsCell(
              title: _chatDetailsClearHistoryTitle,
              onTap: _clearChatHistory,
            ),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return WKSubPageScaffold(
      title: _chatDetailsTitle,
      body: Stack(
        children: [
          if (_isLoading)
            const Center(child: CircularProgressIndicator())
          else
            _buildBody(),
          if (_isUpdating)
            const Positioned(
              left: 0,
              right: 0,
              top: 0,
              child: LinearProgressIndicator(minHeight: 2),
            ),
        ],
      ),
    );
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
