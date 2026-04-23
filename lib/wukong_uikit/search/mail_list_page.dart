import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/utils/storage_utils.dart';
import '../../data/models/mail_list_contact.dart';
import '../../modules/vip/vip_guard.dart';
import '../../service/api/friend_api.dart';
import '../../service/mail_list/mail_list_service.dart';
import '../../widgets/wk_avatar.dart';
import '../../widgets/wk_colors.dart';
import '../../widgets/wk_design_tokens.dart';
import '../../widgets/wk_reference_assets.dart';
import '../../widgets/wk_sub_page_scaffold.dart';
import '../../wukong_base/utils/pinyin_utils.dart';

export '../../data/models/mail_list_contact.dart';

class MailListPage extends StatefulWidget {
  final List<MailListContact>? initialContacts;
  final Future<List<MailListContact>> Function()? onLoadContacts;
  final Future<void> Function(MailListContact contact, String remark)?
  onApplyContact;
  final Future<void> Function(MailListContact contact)? onInviteContact;
  final String? currentUid;
  final MailListLoader? mailListLoader;

  const MailListPage({
    super.key,
    this.initialContacts,
    this.onLoadContacts,
    this.onApplyContact,
    this.onInviteContact,
    this.currentUid,
    this.mailListLoader,
  });

  @override
  State<MailListPage> createState() => _MailListPageState();
}

class _MailListPageState extends State<MailListPage> {
  final TextEditingController _searchController = TextEditingController();

  bool _isLoading = false;
  List<MailListContact> _allContacts = const <MailListContact>[];
  List<MailListContact> _visibleContacts = const <MailListContact>[];

  String get _currentUid {
    final injected = widget.currentUid?.trim() ?? '';
    if (injected.isNotEmpty) {
      return injected;
    }
    return StorageUtils.getUid()?.trim() ?? '';
  }

  @override
  void initState() {
    super.initState();
    final contacts = widget.initialContacts;
    if (contacts != null) {
      final sorted = _sortContacts(contacts);
      _allContacts = sorted;
      _visibleContacts = sorted;
    } else {
      _loadContacts();
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadContacts() async {
    final callback = widget.onLoadContacts;
    final loader = widget.mailListLoader ?? MailListService.instance;

    setState(() => _isLoading = true);
    try {
      final contacts = callback != null
          ? await callback()
          : await loader.loadContacts();
      if (!mounted) {
        return;
      }
      final sorted = _sortContacts(contacts);
      setState(() {
        _allContacts = sorted;
        _visibleContacts = sorted;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() => _isLoading = false);
      _showMessage('加载手机联系人失败: $error');
    }
  }

  @override
  Widget build(BuildContext context) {
    return WKSubPageScaffold(
      title: '手机联系人',
      body: Column(
        children: [
          Container(
            color: WKColors.homeBg,
            padding: const EdgeInsets.fromLTRB(15, 15, 15, 15),
            child: _buildSearchBar(),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _buildList(),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      height: 40,
      decoration: BoxDecoration(
        color: WKColors.surface,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 15, right: 5),
            child: WKReferenceAssets.image(
              WKReferenceAssets.search,
              width: 18,
              height: 18,
              tint: WKColors.color999,
            ),
          ),
          Expanded(
            child: TextField(
              controller: _searchController,
              textInputAction: TextInputAction.search,
              maxLines: 1,
              style: const TextStyle(
                fontFamily: WKFontFamily.primary,
                fontSize: 14,
                color: WKColors.colorDark,
              ),
              decoration: const InputDecoration(
                border: InputBorder.none,
                isCollapsed: true,
                hintText: '搜索',
                hintStyle: TextStyle(
                  fontFamily: WKFontFamily.primary,
                  fontSize: 14,
                  color: WKColors.color999,
                ),
              ),
              onChanged: _filterContacts,
            ),
          ),
          const SizedBox(width: 10),
        ],
      ),
    );
  }

  Widget _buildList() {
    final items = _buildListItems(_visibleContacts);
    if (items.isEmpty) {
      return const SizedBox.shrink();
    }

    return ListView.builder(
      padding: EdgeInsets.zero,
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        if (item.headerTitle != null) {
          return Container(
            color: WKColors.homeBg,
            padding: const EdgeInsets.fromLTRB(15, 10, 15, 10),
            alignment: Alignment.centerLeft,
            child: Text(
              item.headerTitle!,
              style: const TextStyle(
                fontFamily: WKFontFamily.primary,
                fontSize: 14,
                color: WKColors.colorDark,
              ),
            ),
          );
        }

        return _buildContactRow(item.contact!, sectionLabel: item.sectionLabel);
      },
    );
  }

  Widget _buildContactRow(
    MailListContact contact, {
    required String? sectionLabel,
  }) {
    return Container(
      color: WKColors.surface,
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
      child: Row(
        children: [
          SizedBox(
            width: 20,
            child: sectionLabel == null
                ? const SizedBox.shrink()
                : Text(
                    sectionLabel,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontFamily: WKFontFamily.title,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: WKColors.colorDark,
                    ),
                  ),
          ),
          const SizedBox(width: 10),
          WKAvatar(url: contact.avatarUrl, name: contact.displayName, size: 40),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  contact.displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: WKFontFamily.primary,
                    fontSize: 16,
                    color: WKColors.colorDark,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  contact.phone,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: WKFontFamily.primary,
                    fontSize: 14,
                    color: WKColors.color999,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          _buildAction(contact),
        ],
      ),
    );
  }

  Widget _buildAction(MailListContact contact) {
    if (contact.isFriend) {
      return const Text(
        '已添加',
        style: TextStyle(
          fontFamily: WKFontFamily.primary,
          fontSize: 14,
          color: WKColors.color999,
        ),
      );
    }

    if (contact.isRegistered &&
        _currentUid.isNotEmpty &&
        contact.normalizedUid == _currentUid) {
      return const SizedBox.shrink();
    }

    final title = contact.isRegistered ? '添加好友' : '邀请用户';
    return ElevatedButton(
      onPressed: () => contact.isRegistered
          ? _applyContact(contact)
          : _inviteContact(contact),
      style: ElevatedButton.styleFrom(
        minimumSize: const Size(72, 32),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        elevation: 0,
        shadowColor: Colors.transparent,
        backgroundColor: WKColors.brand500,
        foregroundColor: WKColors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      ),
      child: Text(
        title,
        style: const TextStyle(fontFamily: WKFontFamily.primary, fontSize: 14),
      ),
    );
  }

  List<MailListContact> _sortContacts(List<MailListContact> contacts) {
    final sorted = List<MailListContact>.from(contacts);
    sorted.sort((left, right) {
      if (left.isRegistered != right.isRegistered) {
        return left.isRegistered ? -1 : 1;
      }

      final leftSection = _sectionFor(left.displayName);
      final rightSection = _sectionFor(right.displayName);
      final sectionCompare = _sectionSortValue(
        leftSection,
      ).compareTo(_sectionSortValue(rightSection));
      if (sectionCompare != 0) {
        return sectionCompare;
      }

      final leftPinyin = PinyinUtils.toPinyin(left.displayName).toLowerCase();
      final rightPinyin = PinyinUtils.toPinyin(right.displayName).toLowerCase();
      final nameCompare = leftPinyin.compareTo(rightPinyin);
      if (nameCompare != 0) {
        return nameCompare;
      }
      return left.phone.compareTo(right.phone);
    });
    return sorted;
  }

  List<_MailListItem> _buildListItems(List<MailListContact> contacts) {
    final items = <_MailListItem>[];
    String? previousSection;
    var insertedUnregisteredHeader = false;

    for (final contact in contacts) {
      if (!contact.isRegistered && !insertedUnregisteredHeader) {
        if (items.any((item) => item.contact?.isRegistered == true)) {
          items.add(const _MailListItem.header('未注册联系人'));
        }
        insertedUnregisteredHeader = true;
        previousSection = null;
      }

      final section = _sectionFor(contact.displayName);
      final showSection = previousSection != section;
      items.add(
        _MailListItem.contact(
          contact,
          sectionLabel: showSection ? section : null,
        ),
      );
      previousSection = section;
    }

    return items;
  }

  int _sectionSortValue(String section) {
    if (section == '#') {
      return 999;
    }
    return section.codeUnitAt(0);
  }

  String _sectionFor(String text) {
    if (text.isEmpty) {
      return '#';
    }
    final firstLetter = PinyinUtils.getFirstLetter(text).toUpperCase();
    return RegExp(r'^[A-Z]$').hasMatch(firstLetter) ? firstLetter : '#';
  }

  void _filterContacts(String keyword) {
    final query = keyword.trim().toLowerCase();
    if (query.isEmpty) {
      setState(() => _visibleContacts = _allContacts);
      return;
    }

    final filtered = _allContacts
        .where((contact) {
          return contact.displayName.toLowerCase().contains(query) ||
              contact.phone.toLowerCase().contains(query);
        })
        .toList(growable: false);

    setState(() => _visibleContacts = filtered);
  }

  Future<void> _applyContact(MailListContact contact) async {
    if (!await guardVipFeature(context)) {
      return;
    }
    if (!mounted) {
      return;
    }
    if (widget.onApplyContact != null) {
      await widget.onApplyContact!(contact, '');
      return;
    }

    final controller = TextEditingController();
    final remark = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('申请'),
          content: TextField(
            controller: controller,
            autofocus: true,
            maxLength: 20,
            decoration: const InputDecoration(hintText: '输入备注'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () =>
                  Navigator.of(dialogContext).pop(controller.text.trim()),
              child: const Text('发送'),
            ),
          ],
        );
      },
    );

    if (remark == null) {
      return;
    }

    try {
      await FriendApi.instance.addFriend(
        contact.normalizedUid,
        remark: remark.isEmpty ? null : remark,
        vercode: contact.vercode,
      );
      if (!mounted) {
        return;
      }
      _showMessage('已发送好友申请');
    } catch (error) {
      _showMessage('发送好友申请失败: $error');
    }
  }

  Future<void> _inviteContact(MailListContact contact) async {
    if (widget.onInviteContact != null) {
      await widget.onInviteContact!(contact);
      return;
    }

    final uri = Uri(
      scheme: 'sms',
      path: contact.phone,
      queryParameters: const <String, String>{
        'body': '我正在使用【悟空IM】app，体验还不错。你也赶紧来下载玩玩吧！http://www.githubim.com',
      },
    );
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened && mounted) {
      _showMessage('无法打开短信邀请');
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

class _MailListItem {
  final MailListContact? contact;
  final String? sectionLabel;
  final String? headerTitle;

  const _MailListItem.contact(this.contact, {this.sectionLabel})
    : headerTitle = null;

  const _MailListItem.header(this.headerTitle)
    : contact = null,
      sectionLabel = null;
}
