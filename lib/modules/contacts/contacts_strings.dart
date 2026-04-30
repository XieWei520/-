import 'dart:ui' show Locale;

import 'package:flutter/foundation.dart';

@immutable
class ContactsStrings {
  const ContactsStrings({
    required this.newFriends,
    required this.savedGroups,
    required this.contactsTitle,
    required this.contactsLoading,
    required this.contactsLoadFailed,
    required this.setRemark,
    required this.sendMessage,
    required this.remarkDialogTitle,
    required this.remarkDialogHint,
    required this.cancel,
    required this.save,
    required this.newFriendsTitle,
    required this.newFriendsLoading,
    required this.newFriendsLoadFailed,
    required this.newFriendsEmpty,
    required this.newFriendsEmptyHint,
    required this.requestAddFriend,
    required this.approve,
    required this.processing,
    required this.processed,
    required this.delete,
    required this.selectContactsTitle,
    required this.searchPlaceholder,
    required this.confirm,
    required this.createGroupFailedPrefix,
    required this.contactsEmpty,
    required this.contactsEmptyHint,
  });

  final String newFriends;
  final String savedGroups;
  final String contactsTitle;
  final String contactsLoading;
  final String contactsLoadFailed;
  final String setRemark;
  final String sendMessage;
  final String remarkDialogTitle;
  final String remarkDialogHint;
  final String cancel;
  final String save;
  final String newFriendsTitle;
  final String newFriendsLoading;
  final String newFriendsLoadFailed;
  final String newFriendsEmpty;
  final String newFriendsEmptyHint;
  final String requestAddFriend;
  final String approve;
  final String processing;
  final String processed;
  final String delete;
  final String selectContactsTitle;
  final String searchPlaceholder;
  final String confirm;
  final String createGroupFailedPrefix;
  final String contactsEmpty;
  final String contactsEmptyHint;

  String confirmWithCount(int count) => '$confirm($count)';

  String contactsCount(int count) => '$count位联系人';

  String createGroupFailed(Object error) => '$createGroupFailedPrefix: $error';

  String contactsLoadFailedMessage(Object error) =>
      '$contactsLoadFailed: $error';
}

ContactsStrings resolveContactsStrings({Locale? locale}) {
  final languageCode = locale?.languageCode.toLowerCase();
  switch (languageCode) {
    case 'zh':
      return _zhHansDefaults;
    default:
      return _zhHansDefaults;
  }
}

const ContactsStrings _zhHansDefaults = ContactsStrings(
  newFriends: '新朋友',
  savedGroups: '保存的群聊',
  contactsTitle: '联系人',
  contactsLoading: '加载通讯录中...',
  contactsLoadFailed: '通讯录加载失败',
  setRemark: '设置备注',
  sendMessage: '发消息',
  remarkDialogTitle: '设置备注',
  remarkDialogHint: '输入备注',
  cancel: '取消',
  save: '保存',
  newFriendsTitle: '新朋友',
  newFriendsLoading: '加载申请中...',
  newFriendsLoadFailed: '加载失败',
  newFriendsEmpty: '暂无新的好友申请',
  newFriendsEmptyHint: '新的请求会集中出现在这里。',
  requestAddFriend: '请求加好友',
  approve: '通过验证',
  processing: '处理中',
  processed: '已通过',
  delete: '删除',
  selectContactsTitle: '选择联系人',
  searchPlaceholder: '搜索',
  confirm: '确定',
  createGroupFailedPrefix: '创建群聊失败',
  contactsEmpty: '暂无联系人',
  contactsEmptyHint: '添加好友后会显示在这里。',
);
