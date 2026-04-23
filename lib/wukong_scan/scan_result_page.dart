import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:wukongimfluttersdk/entity/channel_member.dart';
import 'package:wukongimfluttersdk/type/const.dart';
import 'package:wukongimfluttersdk/wkim.dart';

import '../core/utils/storage_utils.dart';
import '../modules/auth/presentation/pages/auth_web_login_confirm_page.dart';
import '../modules/chat/chat_page.dart';
import '../wukong_uikit/group/group_scan_join_page.dart';
import '../wukong_uikit/user/user_detail_page.dart';
import 'scan_service.dart';
import 'scan_webview_page.dart';

typedef ScanResultGroupMemberResolver =
    Future<WKChannelMember?> Function(String groupNo);
typedef ScanResultChatPageBuilder = Widget Function(String groupNo);
typedef ScanResultGroupScanJoinPageBuilder =
    Widget Function(String groupNo, String authCode);
typedef ScanResultWebviewPageBuilder = Widget Function(String url);
typedef ScanResultUrlLauncher = Future<bool> Function(Uri uri);

@visibleForTesting
Widget buildDefaultScanGroupChatPage(String groupNo) {
  return ChatPage(channelId: groupNo, channelType: WKChannelType.group);
}

@visibleForTesting
Widget buildDefaultScanGroupScanJoinPage(String groupNo, String authCode) {
  return GroupScanJoinPage(groupNo: groupNo, authCode: authCode);
}

@visibleForTesting
Widget buildDefaultScanWebviewPage(String url) {
  return ScanWebviewPage(initialUrl: url);
}

@visibleForTesting
bool isRemovedGroupMember(WKChannelMember member) => member.isDeleted == 1;

class ScanResultPage extends StatefulWidget {
  final ScanServiceResult result;
  final ScanResultGroupMemberResolver? resolveGroupMember;
  final ScanResultChatPageBuilder? buildChatPage;
  final ScanResultGroupScanJoinPageBuilder? buildGroupScanJoinPage;
  final ScanResultWebviewPageBuilder? buildWebviewPage;
  final ScanResultUrlLauncher? launchUrlExternally;

  const ScanResultPage({
    super.key,
    required this.result,
    this.resolveGroupMember,
    this.buildChatPage,
    this.buildGroupScanJoinPage,
    this.buildWebviewPage,
    this.launchUrlExternally,
  });

  @override
  State<ScanResultPage> createState() => _ScanResultPageState();
}

class _ScanResultPageState extends State<ScanResultPage> {
  Future<WKChannelMember?>? _groupMemberFuture;

  ScanResultGroupMemberResolver get _resolveGroupMember =>
      widget.resolveGroupMember ?? _defaultResolveGroupMember;
  ScanResultChatPageBuilder get _buildChatPage =>
      widget.buildChatPage ?? buildDefaultScanGroupChatPage;
  ScanResultGroupScanJoinPageBuilder get _buildGroupScanJoinPage =>
      widget.buildGroupScanJoinPage ?? buildDefaultScanGroupScanJoinPage;
  ScanResultWebviewPageBuilder get _buildWebviewPage =>
      widget.buildWebviewPage ?? buildDefaultScanWebviewPage;
  ScanResultUrlLauncher get _launchUrlExternally =>
      widget.launchUrlExternally ?? _defaultLaunchUrlExternally;

  @override
  void initState() {
    super.initState();
    _syncGroupMemberFuture();
  }

  @override
  void didUpdateWidget(covariant ScanResultPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.result != widget.result ||
        oldWidget.resolveGroupMember != widget.resolveGroupMember) {
      _syncGroupMemberFuture();
    }
  }

  void _syncGroupMemberFuture() {
    final groupNo = widget.result.groupId?.trim() ?? '';
    if (widget.result.type == 'group' && groupNo.isNotEmpty) {
      _groupMemberFuture = _resolveGroupMember(groupNo);
      return;
    }
    _groupMemberFuture = null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('扫码结果')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: _buildContent(context),
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    switch (widget.result.type) {
      case 'loginConfirm':
        return _buildLoginConfirm(context);
      case 'userInfo':
        return _buildUserInfo(context);
      case 'group':
        return _buildGroup(context);
      case 'webview':
        return _buildWebview(context);
      default:
        return _buildText(context);
    }
  }

  Widget _buildLoginConfirm(BuildContext context) {
    final authCode = widget.result.authCode ?? '';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Spacer(),
        Icon(Icons.verified_user_outlined, size: 80, color: Colors.blue[700]),
        const SizedBox(height: 24),
        const Text(
          '检测到登录确认',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 12),
        Text(
          authCode.isEmpty
              ? '二维码已解析，但认证码缺失。'
              : '认证码: $authCode',
          style: TextStyle(fontSize: 14, color: Colors.grey[700]),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 32),
        ElevatedButton(
          onPressed: authCode.isEmpty
              ? null
              : () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => AuthWebLoginConfirmPage(
                        authCode: authCode,
                        encrypt: widget.result.pubKey,
                      ),
                    ),
                  );
                },
          child: const Text('确认登录'),
        ),
        const Spacer(),
      ],
    );
  }

  Widget _buildUserInfo(BuildContext context) {
    final uid = widget.result.uid ?? '';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Spacer(),
        CircleAvatar(
          radius: 48,
          backgroundColor: Colors.blue[100],
          child: const Icon(Icons.person, size: 48, color: Colors.blue),
        ),
        const SizedBox(height: 24),
        const Text(
          '检测到用户二维码',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 12),
        Text(
          uid.isEmpty ? '未识别到用户 UID' : 'UID: $uid',
          style: TextStyle(fontSize: 14, color: Colors.grey[700]),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 32),
        ElevatedButton(
          onPressed: uid.isEmpty
              ? null
              : () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => UserDetailPage(uid: uid)),
                  );
                },
          child: const Text('打开用户资料'),
        ),
        const Spacer(),
      ],
    );
  }

  Widget _buildGroup(BuildContext context) {
    final groupNo = widget.result.groupId?.trim() ?? '';
    if (groupNo.isEmpty) {
      return _buildGroupUnavailable('未识别到群号。');
    }

    final memberFuture = _groupMemberFuture;
    if (memberFuture == null) {
      return _buildGroupUnavailable('无法校验群成员状态。');
    }

    return FutureBuilder<WKChannelMember?>(
      future: memberFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final member = snapshot.data;
        if (member != null && isRemovedGroupMember(member)) {
          return _buildGroupRemoved(groupNo);
        }

        return _buildGroupActive(context, groupNo);
      },
    );
  }

  Widget _buildGroupActive(BuildContext context, String groupNo) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Spacer(),
        Icon(Icons.group_outlined, size: 80, color: Colors.blue[700]),
        const SizedBox(height: 24),
        const Text(
          '检测到群二维码',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 12),
        Text(
          '群号: $groupNo',
          style: TextStyle(fontSize: 14, color: Colors.grey[700]),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 32),
        ElevatedButton(
          key: const ValueKey('scan_group_chat_button'),
          onPressed: () {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => _buildChatPage(groupNo)),
            );
          },
          child: const Text('进入群聊'),
        ),
        const Spacer(),
      ],
    );
  }

  Widget _buildGroupRemoved(String groupNo) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Spacer(),
        Icon(Icons.group_off_outlined, size: 80, color: Colors.red[400]),
        const SizedBox(height: 24),
        const Text(
          '检测到群二维码',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 12),
        Text(
          '群号: $groupNo',
          style: TextStyle(fontSize: 14, color: Colors.grey[700]),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 12),
        const Text(
          '你已被移出该群。',
          key: ValueKey('scan_group_removed_hint'),
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 14, color: Colors.redAccent),
        ),
        const SizedBox(height: 32),
        ElevatedButton(
          key: const ValueKey('scan_group_chat_button'),
          onPressed: null,
          child: const Text('进入群聊'),
        ),
        const Spacer(),
      ],
    );
  }

  Widget _buildGroupUnavailable(String message) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Spacer(),
        Icon(Icons.group_off_outlined, size: 80, color: Colors.grey[600]),
        const SizedBox(height: 24),
        const Text(
          '检测到群二维码',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 12),
        Text(
          message,
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 14, color: Colors.grey[700]),
        ),
        const SizedBox(height: 32),
        ElevatedButton(
          key: const ValueKey('scan_group_chat_button'),
          onPressed: null,
          child: const Text('进入群聊'),
        ),
        const Spacer(),
      ],
    );
  }

  Widget _buildWebview(BuildContext context) {
    if (widget.result.isInternalJoinGroupUrl) {
      return _buildInternalJoinGroup(context);
    }

    final url = widget.result.url ?? widget.result.rawContent;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Spacer(),
        Icon(Icons.language, size: 80, color: Colors.blue[700]),
        const SizedBox(height: 24),
        const Text(
          '检测到网页跳转',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 12),
        Text(
          url,
          style: TextStyle(fontSize: 14, color: Colors.grey[700], height: 1.5),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 32),
        ElevatedButton(
          key: const ValueKey('scan_open_in_app_button'),
          onPressed: () {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => _buildWebviewPage(url)),
            );
          },
          child: const Text('打开链接'),
        ),
        const SizedBox(height: 12),
        OutlinedButton(
          key: const ValueKey('scan_open_link_button'),
          onPressed: () => _openUrl(context, url),
          child: const Text('浏览器打开'),
        ),
        const SizedBox(height: 12),
        OutlinedButton(
          key: const ValueKey('scan_copy_link_button'),
          onPressed: () => _copyToClipboard(context, url),
          child: const Text('复制链接'),
        ),
        const Spacer(),
      ],
    );
  }

  Widget _buildInternalJoinGroup(BuildContext context) {
    final groupNo = widget.result.joinGroupNo?.trim() ?? '';
    final authCode = widget.result.joinGroupAuthCode?.trim() ?? '';
    final canOpenJoinPage = groupNo.isNotEmpty && authCode.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Spacer(),
        Icon(Icons.group_add_outlined, size: 80, color: Colors.blue[700]),
        const SizedBox(height: 24),
        const Text(
          '扫码加群',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 12),
        Text(
          canOpenJoinPage
              ? '群号: $groupNo'
              : '入群参数不完整。',
          style: TextStyle(fontSize: 14, color: Colors.grey[700]),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 32),
        ElevatedButton(
          key: const ValueKey('scan_internal_join_button'),
          onPressed: canOpenJoinPage
              ? () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => _buildGroupScanJoinPage(groupNo, authCode),
                    ),
                  );
                }
              : null,
          child: const Text('打开入群确认'),
        ),
        const Spacer(),
      ],
    );
  }

  Widget _buildText(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Spacer(),
        Icon(Icons.text_snippet_outlined, size: 80, color: Colors.grey[700]),
        const SizedBox(height: 24),
        const Text(
          '文本内容',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 12),
        Text(
          widget.result.rawContent,
          style: TextStyle(fontSize: 14, color: Colors.grey[700], height: 1.5),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 32),
        ElevatedButton(
          onPressed: () => _copyToClipboard(context, widget.result.rawContent),
          child: const Text('复制内容'),
        ),
        const Spacer(),
      ],
    );
  }

  Future<WKChannelMember?> _defaultResolveGroupMember(String groupNo) async {
    final uid = StorageUtils.getUid()?.trim() ?? '';
    if (uid.isEmpty) {
      return null;
    }

    try {
      return await WKIM.shared.channelMemberManager.getMember(
        groupNo,
        WKChannelType.group,
        uid,
      );
    } catch (_) {
      return null;
    }
  }

  Future<bool> _defaultLaunchUrlExternally(Uri uri) {
    return launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _openUrl(BuildContext context, String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) {
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('链接格式不正确。')));
      return;
    }

    final opened = await _launchUrlExternally(uri);
    if (!opened && context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('无法打开链接。')));
    }
  }

  Future<void> _copyToClipboard(BuildContext context, String text) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (!context.mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('已复制到剪贴板。')));
  }
}

class ScanOtherResultPage extends StatelessWidget {
  final String content;

  const ScanOtherResultPage({super.key, required this.content});

  @override
  Widget build(BuildContext context) {
    return ScanResultPage(result: ScanServiceResult.rawText(content));
  }
}
