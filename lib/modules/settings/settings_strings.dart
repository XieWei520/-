import 'dart:ui' show Locale;

import 'package:flutter/foundation.dart';

@immutable
class SettingsStrings {
  const SettingsStrings({
    required this.generalMenu,
    required this.notificationsMenu,
    required this.favoritesMenu,
    required this.privacyMenu,
    required this.accountSecurityMenu,
    required this.pcLoginMenu,
    required this.guestUser,
    required this.settingsTitle,
    required this.darkMode,
    required this.language,
    required this.fontSize,
    required this.chatBackground,
    required this.clearImageCache,
    required this.clearAllChatHistory,
    required this.messageBackup,
    required this.messageRecovery,
    required this.appModules,
    required this.thirdPartySharing,
    required this.errorLogs,
    required this.about,
    required this.logout,
    required this.save,
    required this.cancel,
    required this.clear,
    required this.confirm,
    required this.enabled,
    required this.disabled,
    required this.followSystem,
    required this.simplifiedChinese,
    required this.englishDisplay,
    required this.clearImageCacheMessage,
    required this.clearImageCacheSuccess,
    required this.logoutMessage,
    required this.logoutAction,
    required this.logoutFailedPrefix,
    required this.clearAllChatHistoryMessage,
    required this.clearAllChatHistorySuccess,
    required this.notificationSettingsTitle,
    required this.notificationMasterSwitchTitle,
    required this.notificationMasterSwitchDescription,
    required this.showMessageDetailsTitle,
    required this.sound,
    required this.vibration,
    required this.notificationSoundDescription,
    required this.openMessageNotificationSettings,
    required this.openCallInvitationNotificationSettings,
    required this.openSettingsFailedSuffix,
    required this.notificationPermissionHint,
    required this.callPermissionHint,
    required this.notificationSaveSuccess,
    required this.notificationSaveFailedPrefix,
    required this.privacySettingsTitle,
    required this.privacyHeroTitle,
    required this.privacyHeroSubtitle,
    required this.visibilitySectionTitle,
    required this.disablePhoneSearchTitle,
    required this.disablePhoneSearchSubtitle,
    required this.showOnlineStatusTitle,
    required this.showOnlineStatusSubtitle,
    required this.showMessagePreviewTitle,
    required this.showMessagePreviewSubtitle,
    required this.securitySectionTitle,
    required this.deviceLockTitle,
    required this.deviceLockSubtitle,
    required this.blacklistTitle,
    required this.blacklistSubtitle,
    required this.settingsSaved,
    required this.saveFailedPrefix,
    required this.setDeviceLock,
    required this.enterPassword,
    required this.passwordHint6Digits,
    required this.confirmPassword,
    required this.deviceLockPasswordMustBe6Digits,
    required this.passwordsDoNotMatch,
    required this.enableDeviceLockFailedPrefix,
    required this.disableDeviceLockFailedPrefix,
    required this.accountSecurityTitle,
    required this.accountAndDevicesTitle,
    required this.accountAndDevicesSubtitlePrefix,
    required this.accountAndDevicesSubtitleSuffix,
    required this.signedInDevicesSection,
    required this.accountActionsSection,
    required this.deviceListTitle,
    required this.devicesCountSuffix,
    required this.destroyAccountTitle,
    required this.destroyAccountSubtitle,
    required this.destroyAccountDialogTitle,
    required this.destroyAccountDialogMessage,
    required this.destroyAccountVerificationHint,
    required this.destroyAccountSendCode,
    required this.destroyAccountSending,
    required this.destroyAccountConfirmAction,
    required this.destroyAccountSuccess,
    required this.destroyAccountCodeRequired,
    required this.destroyAccountSendCodeFailedPrefix,
    required this.destroyAccountFailedPrefix,
    required this.signedInDevicesTitle,
    required this.loading,
    required this.noDevices,
    required this.removeDeviceTitle,
    required this.removeDeviceMessage,
    required this.remove,
    required this.removeFailedPrefix,
    required this.unknownDevice,
    required this.currentDevice,
    required this.blacklistPageTitle,
    required this.blacklistEmpty,
    required this.blacklistEmptyHint,
    required this.userIdCannotBeEmpty,
    required this.removedFromBlacklist,
    required this.operationFailedPrefix,
    required this.unknownUser,
    required this.pcLoginPageTitle,
    required this.loadingWebLoginAddress,
    required this.pcLoginGuideDescription,
    required this.copyAddress,
    required this.copyWebLoginUrl,
    required this.webLoginAddressCopied,
    required this.scanQrCode,
    required this.useMobileScanToConfirmLogin,
    required this.pcLoginStatus,
    required this.openManagementControls,
    required this.phoneMute,
    required this.muted,
    required this.fileHelper,
    required this.openChat,
    required this.lock,
    required this.locked,
    required this.unlocked,
    required this.exitAllPcWebLogin,
    required this.pcLoginLockedNotice,
    required this.phoneNotificationsMuted,
    required this.phoneNotificationsEnabled,
    required this.pcLoginHeroTitle,
    required this.generalHeroTitle,
    required this.generalHeroSubtitle,
    required this.generalAppearanceSectionTitle,
    required this.generalStorageSectionTitle,
    required this.generalMessagesSectionTitle,
    required this.generalModulesSectionTitle,
    required this.generalSupportSectionTitle,
    required this.generalAccountSectionTitle,
    required this.notificationHeroTitle,
    required this.notificationHeroSubtitle,
    required this.notificationPreferencesSectionTitle,
    required this.notificationSystemSectionTitle,
    required this.notificationHelpSectionTitle,
    required this.notificationDisabledHint,
    required this.notificationSystemSettingsHint,
    required this.favoritesPageTitle,
    required this.favoritesHeroTitle,
    required this.favoritesHeroSubtitle,
    required this.favoritesSearchHint,
    required this.favoritesLoadingHint,
    required this.favoritesEmptyTitle,
    required this.favoritesEmptySubtitle,
    required this.favoritesLoadFailed,
    required this.favoritesRefreshFailed,
    required this.favoritesRetry,
    required this.favoritesDeleteTitle,
    required this.favoritesDeleteMessage,
    required this.favoritesDeleteAction,
    required this.favoritesDeleteTooltip,
    required this.favoritesDeleteFailed,
    required this.favoritesOpenFailed,
    required this.favoritesUnsupportedOpen,
    required this.appModulesPageTitle,
    required this.appModulesSaveAction,
    required this.appModulesHeroTitle,
    required this.appModulesHeroSubtitle,
    required this.appModulesStatusTitle,
    required this.appModulesListSectionTitle,
    required this.appModulesHelpCopy,
    required this.appModulesLoadingHint,
    required this.appModulesEmptyHint,
    required this.appModulesFallbackModuleName,
    required this.appModulesSaveSuccess,
    required this.appModulesSyncedStatus,
    required this.appModulesLoadFailedPrefix,
    required this.appModulesSaveFailedPrefix,
    required this.appModulesRetry,
    required this.workplaceCatalogEntryTitle,
    required this.workplaceCatalogEntrySubtitle,
    required this.workplaceCatalogBrowseAction,
    required this.workplaceCatalogPageTitle,
    required this.workplaceCatalogHeroTitle,
    required this.workplaceCatalogHeroSubtitle,
    required this.workplaceCatalogBannersSectionTitle,
    required this.workplaceCatalogMyAppsSectionTitle,
    required this.workplaceCatalogRecentSectionTitle,
    required this.workplaceCatalogCategoriesSectionTitle,
    required this.workplaceCatalogCategoryAppsSectionTitle,
    required this.workplaceCatalogEmptyHint,
    required this.workplaceCatalogAddAction,
    required this.workplaceCatalogRemoveAction,
    required this.workplaceCatalogOpenAction,
    required this.workplaceCatalogOpenFailedPrefix,
    required this.workplaceCatalogPendingNativeRoutePrefix,
    required this.workplaceCatalogNoLaunchRoute,
  });

  final String generalMenu;
  final String notificationsMenu;
  final String favoritesMenu;
  final String privacyMenu;
  final String accountSecurityMenu;
  final String pcLoginMenu;
  final String guestUser;
  final String settingsTitle;
  final String darkMode;
  final String language;
  final String fontSize;
  final String chatBackground;
  final String clearImageCache;
  final String clearAllChatHistory;
  final String messageBackup;
  final String messageRecovery;
  final String appModules;
  final String thirdPartySharing;
  final String errorLogs;
  final String about;
  final String logout;
  final String save;
  final String cancel;
  final String clear;
  final String confirm;
  final String enabled;
  final String disabled;
  final String followSystem;
  final String simplifiedChinese;
  final String englishDisplay;
  final String clearImageCacheMessage;
  final String clearImageCacheSuccess;
  final String logoutMessage;
  final String logoutAction;
  final String logoutFailedPrefix;
  final String clearAllChatHistoryMessage;
  final String clearAllChatHistorySuccess;
  final String notificationSettingsTitle;
  final String notificationMasterSwitchTitle;
  final String notificationMasterSwitchDescription;
  final String showMessageDetailsTitle;
  final String sound;
  final String vibration;
  final String notificationSoundDescription;
  final String openMessageNotificationSettings;
  final String openCallInvitationNotificationSettings;
  final String openSettingsFailedSuffix;
  final String notificationPermissionHint;
  final String callPermissionHint;
  final String notificationSaveSuccess;
  final String notificationSaveFailedPrefix;
  final String privacySettingsTitle;
  final String privacyHeroTitle;
  final String privacyHeroSubtitle;
  final String visibilitySectionTitle;
  final String disablePhoneSearchTitle;
  final String disablePhoneSearchSubtitle;
  final String showOnlineStatusTitle;
  final String showOnlineStatusSubtitle;
  final String showMessagePreviewTitle;
  final String showMessagePreviewSubtitle;
  final String securitySectionTitle;
  final String deviceLockTitle;
  final String deviceLockSubtitle;
  final String blacklistTitle;
  final String blacklistSubtitle;
  final String settingsSaved;
  final String saveFailedPrefix;
  final String setDeviceLock;
  final String enterPassword;
  final String passwordHint6Digits;
  final String confirmPassword;
  final String deviceLockPasswordMustBe6Digits;
  final String passwordsDoNotMatch;
  final String enableDeviceLockFailedPrefix;
  final String disableDeviceLockFailedPrefix;
  final String accountSecurityTitle;
  final String accountAndDevicesTitle;
  final String accountAndDevicesSubtitlePrefix;
  final String accountAndDevicesSubtitleSuffix;
  final String signedInDevicesSection;
  final String accountActionsSection;
  final String deviceListTitle;
  final String devicesCountSuffix;
  final String destroyAccountTitle;
  final String destroyAccountSubtitle;
  final String destroyAccountDialogTitle;
  final String destroyAccountDialogMessage;
  final String destroyAccountVerificationHint;
  final String destroyAccountSendCode;
  final String destroyAccountSending;
  final String destroyAccountConfirmAction;
  final String destroyAccountSuccess;
  final String destroyAccountCodeRequired;
  final String destroyAccountSendCodeFailedPrefix;
  final String destroyAccountFailedPrefix;
  final String signedInDevicesTitle;
  final String loading;
  final String noDevices;
  final String removeDeviceTitle;
  final String removeDeviceMessage;
  final String remove;
  final String removeFailedPrefix;
  final String unknownDevice;
  final String currentDevice;
  final String blacklistPageTitle;
  final String blacklistEmpty;
  final String blacklistEmptyHint;
  final String userIdCannotBeEmpty;
  final String removedFromBlacklist;
  final String operationFailedPrefix;
  final String unknownUser;
  final String pcLoginPageTitle;
  final String loadingWebLoginAddress;
  final String pcLoginGuideDescription;
  final String copyAddress;
  final String copyWebLoginUrl;
  final String webLoginAddressCopied;
  final String scanQrCode;
  final String useMobileScanToConfirmLogin;
  final String pcLoginStatus;
  final String openManagementControls;
  final String phoneMute;
  final String muted;
  final String fileHelper;
  final String openChat;
  final String lock;
  final String locked;
  final String unlocked;
  final String exitAllPcWebLogin;
  final String pcLoginLockedNotice;
  final String phoneNotificationsMuted;
  final String phoneNotificationsEnabled;
  final String pcLoginHeroTitle;
  final String generalHeroTitle;
  final String generalHeroSubtitle;
  final String generalAppearanceSectionTitle;
  final String generalStorageSectionTitle;
  final String generalMessagesSectionTitle;
  final String generalModulesSectionTitle;
  final String generalSupportSectionTitle;
  final String generalAccountSectionTitle;
  final String notificationHeroTitle;
  final String notificationHeroSubtitle;
  final String notificationPreferencesSectionTitle;
  final String notificationSystemSectionTitle;
  final String notificationHelpSectionTitle;
  final String notificationDisabledHint;
  final String notificationSystemSettingsHint;
  final String favoritesPageTitle;
  final String favoritesHeroTitle;
  final String favoritesHeroSubtitle;
  final String favoritesSearchHint;
  final String favoritesLoadingHint;
  final String favoritesEmptyTitle;
  final String favoritesEmptySubtitle;
  final String favoritesLoadFailed;
  final String favoritesRefreshFailed;
  final String favoritesRetry;
  final String favoritesDeleteTitle;
  final String favoritesDeleteMessage;
  final String favoritesDeleteAction;
  final String favoritesDeleteTooltip;
  final String favoritesDeleteFailed;
  final String favoritesOpenFailed;
  final String favoritesUnsupportedOpen;
  final String appModulesPageTitle;
  final String appModulesSaveAction;
  final String appModulesHeroTitle;
  final String appModulesHeroSubtitle;
  final String appModulesStatusTitle;
  final String appModulesListSectionTitle;
  final String appModulesHelpCopy;
  final String appModulesLoadingHint;
  final String appModulesEmptyHint;
  final String appModulesFallbackModuleName;
  final String appModulesSaveSuccess;
  final String appModulesSyncedStatus;
  final String appModulesLoadFailedPrefix;
  final String appModulesSaveFailedPrefix;
  final String appModulesRetry;
  final String workplaceCatalogEntryTitle;
  final String workplaceCatalogEntrySubtitle;
  final String workplaceCatalogBrowseAction;
  final String workplaceCatalogPageTitle;
  final String workplaceCatalogHeroTitle;
  final String workplaceCatalogHeroSubtitle;
  final String workplaceCatalogBannersSectionTitle;
  final String workplaceCatalogMyAppsSectionTitle;
  final String workplaceCatalogRecentSectionTitle;
  final String workplaceCatalogCategoriesSectionTitle;
  final String workplaceCatalogCategoryAppsSectionTitle;
  final String workplaceCatalogEmptyHint;
  final String workplaceCatalogAddAction;
  final String workplaceCatalogRemoveAction;
  final String workplaceCatalogOpenAction;
  final String workplaceCatalogOpenFailedPrefix;
  final String workplaceCatalogPendingNativeRoutePrefix;
  final String workplaceCatalogNoLaunchRoute;

  String darkModeStatus(bool isEnabled) => isEnabled ? enabled : disabled;

  String logoutFailed(Object error) => '$logoutFailedPrefix$error';

  String notificationSaveFailed(Object error) =>
      '$notificationSaveFailedPrefix$error';

  String openNotificationSettingsFailed(String title) =>
      '$title$openSettingsFailedSuffix';

  String saveFailed(Object error) => '$saveFailedPrefix$error';

  String enableDeviceLockFailed(Object error) =>
      '$enableDeviceLockFailedPrefix$error';

  String disableDeviceLockFailed(Object error) =>
      '$disableDeviceLockFailedPrefix$error';

  String accountAndDevicesSubtitleWithCount(int count) =>
      '$accountAndDevicesSubtitlePrefix$count$accountAndDevicesSubtitleSuffix';

  String devicesCount(int count) => '$count$devicesCountSuffix';

  String destroyAccountSendCodeFailed(Object error) =>
      '$destroyAccountSendCodeFailedPrefix$error';

  String destroyAccountFailed(Object error) =>
      '$destroyAccountFailedPrefix$error';

  String removeFailed(Object error) => '$removeFailedPrefix$error';

  String operationFailed(Object error) => '$operationFailedPrefix$error';

  String appModulesLoadFailed(Object error) =>
      '$appModulesLoadFailedPrefix$error';

  String appModulesSaveFailed(Object error) =>
      '$appModulesSaveFailedPrefix$error';

  String workplaceCatalogOpenFailed(Object error) =>
      '$workplaceCatalogOpenFailedPrefix$error';

  String workplaceCatalogPendingNativeRoute(Object route) =>
      '$workplaceCatalogPendingNativeRoutePrefix$route';
}

SettingsStrings resolveSettingsStrings({Locale? locale}) {
  if (locale?.languageCode.toLowerCase() == 'en' &&
      locale?.countryCode?.toUpperCase() == 'US') {
    return _enUsSettingsStrings;
  }
  return _zhHansSettingsStrings;
}

const SettingsStrings zhHansSettingsStrings = _zhHansSettingsStrings;
final SettingsStrings enUsSettingsStrings = _enUsSettingsStrings;

const SettingsStrings _zhHansSettingsStrings = SettingsStrings(
  generalMenu: '通用',
  notificationsMenu: '新消息通知',
  favoritesMenu: '收藏',
  privacyMenu: '隐私',
  accountSecurityMenu: '账号与安全',
  pcLoginMenu: '电脑端登录',
  guestUser: '未登录用户',
  settingsTitle: '设置',
  darkMode: '深色模式',
  language: '语言',
  fontSize: '字体大小',
  chatBackground: '聊天背景',
  clearImageCache: '清理图片缓存',
  clearAllChatHistory: '清空全部聊天记录',
  messageBackup: '消息备份',
  messageRecovery: '消息恢复',
  appModules: '企业模块',
  thirdPartySharing: '第三方信息共享清单',
  errorLogs: '开发日志',
  about: '关于',
  logout: '退出登录',
  save: '保存',
  cancel: '取消',
  clear: '清理',
  confirm: '确认',
  enabled: '已开启',
  disabled: '已关闭',
  followSystem: '跟随系统',
  simplifiedChinese: '简体中文',
  englishDisplay: 'English',
  clearImageCacheMessage: '确认清理当前设备上的图片缓存吗？',
  clearImageCacheSuccess: '图片缓存已清理',
  logoutMessage: '确定退出当前账号吗？',
  logoutAction: '退出登录',
  logoutFailedPrefix: '退出登录失败：',
  clearAllChatHistoryMessage: '确认清空当前账号的全部聊天记录吗？',
  clearAllChatHistorySuccess: '聊天记录已清空',
  notificationSettingsTitle: '新消息通知',
  notificationMasterSwitchTitle: '新消息通知总开关',
  notificationMasterSwitchDescription: '关闭后，应用内仍会正常同步消息，但不再弹出新消息提醒。',
  showMessageDetailsTitle: '显示消息详情',
  sound: '声音',
  vibration: '震动',
  notificationSoundDescription: '声音和震动还会受到系统通知权限以及设备层级限制影响。',
  openMessageNotificationSettings: '打开新消息通知设置',
  openCallInvitationNotificationSettings: '打开通话邀请通知设置',
  openSettingsFailedSuffix: '失败，请前往系统设置查看。',
  notificationPermissionHint: '如果应用内通知已开启但仍收不到提醒，请检查本应用的系统通知权限。',
  callPermissionHint: '如果通话邀请没有提醒，请检查系统通知权限和后台运行限制。',
  notificationSaveSuccess: '通知设置已保存。',
  notificationSaveFailedPrefix: '保存失败：',
  privacySettingsTitle: '隐私设置',
  privacyHeroTitle: '隐私与安全',
  privacyHeroSubtitle: '管理账号可被发现方式、设备保护、在线状态以及通知预览。',
  visibilitySectionTitle: '可见性',
  disablePhoneSearchTitle: '关闭手机号搜索',
  disablePhoneSearchSubtitle: '开启后，其他人无法通过手机号搜索到你的账号。',
  showOnlineStatusTitle: '显示在线状态',
  showOnlineStatusSubtitle: '关闭后，好友将无法看到你的在线状态。',
  showMessagePreviewTitle: '通知中显示消息详情',
  showMessagePreviewSubtitle: '关闭后，推送通知将隐藏具体消息内容。',
  securitySectionTitle: '安全',
  deviceLockTitle: '设备锁',
  deviceLockSubtitle: '打开应用时需要额外验证。',
  blacklistTitle: '黑名单',
  blacklistSubtitle: '管理被你拉黑的联系人。',
  settingsSaved: '设置已保存。',
  saveFailedPrefix: '保存失败：',
  setDeviceLock: '设置设备锁',
  enterPassword: '输入密码',
  passwordHint6Digits: '6位数字密码',
  confirmPassword: '确认密码',
  deviceLockPasswordMustBe6Digits: '设备锁密码必须为6位数字。',
  passwordsDoNotMatch: '两次输入的密码不一致。',
  enableDeviceLockFailedPrefix: '开启设备锁失败：',
  disableDeviceLockFailedPrefix: '关闭设备锁失败：',
  accountSecurityTitle: '账号与安全',
  accountAndDevicesTitle: '账号与设备',
  accountAndDevicesSubtitlePrefix: '当前共有',
  accountAndDevicesSubtitleSuffix: '台已登录设备。',
  signedInDevicesSection: '已登录设备',
  accountActionsSection: '账号操作',
  deviceListTitle: '设备列表',
  devicesCountSuffix: '台设备',
  destroyAccountTitle: '注销账号',
  destroyAccountSubtitle: '发送短信验证码后可永久注销当前账号。',
  destroyAccountDialogTitle: '确认注销账号',
  destroyAccountDialogMessage: '注销后将退出当前账号，且该操作不可撤销。',
  destroyAccountVerificationHint: '请输入短信验证码',
  destroyAccountSendCode: '发送验证码',
  destroyAccountSending: '发送中...',
  destroyAccountConfirmAction: '确认注销',
  destroyAccountSuccess: '账号已注销',
  destroyAccountCodeRequired: '请输入短信验证码',
  destroyAccountSendCodeFailedPrefix: '发送注销验证码失败: ',
  destroyAccountFailedPrefix: '注销账号失败: ',
  signedInDevicesTitle: '已登录设备',
  loading: '加载中...',
  noDevices: '暂无设备',
  removeDeviceTitle: '移除设备',
  removeDeviceMessage: '确认移除该设备吗？',
  remove: '移除',
  removeFailedPrefix: '移除失败：',
  unknownDevice: '未知设备',
  currentDevice: '当前设备',
  blacklistPageTitle: '黑名单',
  blacklistEmpty: '黑名单为空',
  blacklistEmptyHint: '当前没有被拉黑的联系人。',
  userIdCannotBeEmpty: '用户 ID 不能为空。',
  removedFromBlacklist: '已从黑名单移除。',
  operationFailedPrefix: '操作失败：',
  unknownUser: '未知用户',
  pcLoginPageTitle: '电脑端登录',
  loadingWebLoginAddress: '正在加载电脑端登录地址...',
  pcLoginGuideDescription: '你可以使用下方地址在 Web/PC 端登录，也可以在登录页扫描二维码完成确认。',
  copyAddress: '复制地址',
  copyWebLoginUrl: '复制电脑端登录地址',
  webLoginAddressCopied: '电脑端登录地址已复制',
  scanQrCode: '扫描二维码',
  useMobileScanToConfirmLogin: '使用手机扫码确认登录',
  pcLoginStatus: '电脑端登录状态',
  openManagementControls: '打开管理控制页',
  phoneMute: '手机静音',
  muted: '已静音',
  fileHelper: '文件传输助手',
  openChat: '打开聊天',
  lock: '锁定',
  locked: '已锁定',
  unlocked: '未锁定',
  exitAllPcWebLogin: '退出全部电脑端/网页端登录',
  pcLoginLockedNotice: '电脑端登录已锁定。',
  phoneNotificationsMuted: '手机通知已静音。',
  phoneNotificationsEnabled: '手机通知已开启。',
  pcLoginHeroTitle: '悟空 IM 电脑端登录',
  generalHeroTitle: '通用设置',
  generalHeroSubtitle: '调整外观、存储、消息、模块与账号相关选项。',
  generalAppearanceSectionTitle: '外观',
  generalStorageSectionTitle: '存储',
  generalMessagesSectionTitle: '消息',
  generalModulesSectionTitle: '模块',
  generalSupportSectionTitle: '支持',
  generalAccountSectionTitle: '账号',
  notificationHeroTitle: '通知与提醒',
  notificationHeroSubtitle: '管理提醒、应用内行为与系统通知访问。',
  notificationPreferencesSectionTitle: '偏好设置',
  notificationSystemSectionTitle: '系统访问',
  notificationHelpSectionTitle: '使用帮助',
  notificationDisabledHint: '关闭后，应用仍会同步消息，但不会再显示新消息提醒。',
  notificationSystemSettingsHint: '若仍收不到提醒，请前往系统设置检查通知权限。',
  favoritesPageTitle: '收藏',
  favoritesHeroTitle: '收藏消息',
  favoritesHeroSubtitle: '快速查找、打开并管理你保存的消息内容。',
  favoritesSearchHint: '搜索收藏',
  favoritesLoadingHint: '正在加载收藏...',
  favoritesEmptyTitle: '暂无收藏',
  favoritesEmptySubtitle: '你收藏的消息会显示在这里，方便快速访问。',
  favoritesLoadFailed: '加载收藏失败，下拉重试。',
  favoritesRefreshFailed: '刷新失败，请稍后重试。',
  favoritesRetry: '重试',
  favoritesDeleteTitle: '移除收藏',
  favoritesDeleteMessage: '确定从收藏中移除该条目吗？这不会删除原消息。',
  favoritesDeleteAction: '移除',
  favoritesDeleteTooltip: '从收藏中移除',
  favoritesDeleteFailed: '移除收藏失败：',
  favoritesOpenFailed: '打开收藏失败：',
  favoritesUnsupportedOpen: '当前平台暂不支持打开此收藏。',
  appModulesPageTitle: '应用模块',
  appModulesSaveAction: '保存更改',
  appModulesHeroTitle: '应用模块',
  appModulesHeroSubtitle: '选择显示的模块，并保持模块列表同步。',
  appModulesStatusTitle: '当前状态',
  appModulesListSectionTitle: '模块列表',
  appModulesHelpCopy: '更改将在保存后生效。账号无权限的模块会自动禁用。',
  appModulesLoadingHint: '正在加载模块...',
  appModulesEmptyHint: '当前暂无可用模块。',
  appModulesFallbackModuleName: '未知模块',
  appModulesSaveSuccess: '模块设置已保存。',
  appModulesSyncedStatus: '已同步',
  appModulesLoadFailedPrefix: '加载应用模块失败：',
  appModulesSaveFailedPrefix: '保存应用模块失败：',
  appModulesRetry: '重试',
  workplaceCatalogEntryTitle: '工作台应用',
  workplaceCatalogEntrySubtitle: '浏览 Banner、最近使用和分类应用。',
  workplaceCatalogBrowseAction: '浏览',
  workplaceCatalogPageTitle: '工作台应用',
  workplaceCatalogHeroTitle: '工作台应用',
  workplaceCatalogHeroSubtitle: '从已添加应用、最近使用和分类目录中快速进入工作台。',
  workplaceCatalogBannersSectionTitle: '精选推荐',
  workplaceCatalogMyAppsSectionTitle: '已添加应用',
  workplaceCatalogRecentSectionTitle: '最近使用',
  workplaceCatalogCategoriesSectionTitle: '应用分类',
  workplaceCatalogCategoryAppsSectionTitle: '分类应用',
  workplaceCatalogEmptyHint: '当前暂无可显示的工作台应用。',
  workplaceCatalogAddAction: '添加',
  workplaceCatalogRemoveAction: '移除',
  workplaceCatalogOpenAction: '打开',
  workplaceCatalogOpenFailedPrefix: '打开工作台应用失败：',
  workplaceCatalogPendingNativeRoutePrefix: '该原生路由暂未接入：',
  workplaceCatalogNoLaunchRoute: '当前应用没有可打开的链接。',
);

final SettingsStrings _enUsSettingsStrings = SettingsStrings(
  generalMenu: _zhHansSettingsStrings.generalMenu,
  notificationsMenu: _zhHansSettingsStrings.notificationsMenu,
  favoritesMenu: _zhHansSettingsStrings.favoritesMenu,
  privacyMenu: _zhHansSettingsStrings.privacyMenu,
  accountSecurityMenu: _zhHansSettingsStrings.accountSecurityMenu,
  pcLoginMenu: _zhHansSettingsStrings.pcLoginMenu,
  guestUser: _zhHansSettingsStrings.guestUser,
  settingsTitle: _zhHansSettingsStrings.settingsTitle,
  darkMode: _zhHansSettingsStrings.darkMode,
  language: _zhHansSettingsStrings.language,
  fontSize: _zhHansSettingsStrings.fontSize,
  chatBackground: _zhHansSettingsStrings.chatBackground,
  clearImageCache: _zhHansSettingsStrings.clearImageCache,
  clearAllChatHistory: _zhHansSettingsStrings.clearAllChatHistory,
  messageBackup: _zhHansSettingsStrings.messageBackup,
  messageRecovery: _zhHansSettingsStrings.messageRecovery,
  appModules: _zhHansSettingsStrings.appModules,
  thirdPartySharing: _zhHansSettingsStrings.thirdPartySharing,
  errorLogs: _zhHansSettingsStrings.errorLogs,
  about: _zhHansSettingsStrings.about,
  logout: _zhHansSettingsStrings.logout,
  save: _zhHansSettingsStrings.save,
  cancel: _zhHansSettingsStrings.cancel,
  clear: _zhHansSettingsStrings.clear,
  confirm: _zhHansSettingsStrings.confirm,
  enabled: _zhHansSettingsStrings.enabled,
  disabled: _zhHansSettingsStrings.disabled,
  followSystem: _zhHansSettingsStrings.followSystem,
  simplifiedChinese: _zhHansSettingsStrings.simplifiedChinese,
  englishDisplay: _zhHansSettingsStrings.englishDisplay,
  clearImageCacheMessage: _zhHansSettingsStrings.clearImageCacheMessage,
  clearImageCacheSuccess: _zhHansSettingsStrings.clearImageCacheSuccess,
  logoutMessage: _zhHansSettingsStrings.logoutMessage,
  logoutAction: _zhHansSettingsStrings.logoutAction,
  logoutFailedPrefix: _zhHansSettingsStrings.logoutFailedPrefix,
  clearAllChatHistoryMessage: _zhHansSettingsStrings.clearAllChatHistoryMessage,
  clearAllChatHistorySuccess: _zhHansSettingsStrings.clearAllChatHistorySuccess,
  notificationSettingsTitle: _zhHansSettingsStrings.notificationSettingsTitle,
  notificationMasterSwitchTitle:
      _zhHansSettingsStrings.notificationMasterSwitchTitle,
  notificationMasterSwitchDescription:
      _zhHansSettingsStrings.notificationMasterSwitchDescription,
  showMessageDetailsTitle: _zhHansSettingsStrings.showMessageDetailsTitle,
  sound: _zhHansSettingsStrings.sound,
  vibration: _zhHansSettingsStrings.vibration,
  notificationSoundDescription:
      _zhHansSettingsStrings.notificationSoundDescription,
  openMessageNotificationSettings:
      _zhHansSettingsStrings.openMessageNotificationSettings,
  openCallInvitationNotificationSettings:
      _zhHansSettingsStrings.openCallInvitationNotificationSettings,
  openSettingsFailedSuffix: _zhHansSettingsStrings.openSettingsFailedSuffix,
  notificationPermissionHint: _zhHansSettingsStrings.notificationPermissionHint,
  callPermissionHint: _zhHansSettingsStrings.callPermissionHint,
  notificationSaveSuccess: _zhHansSettingsStrings.notificationSaveSuccess,
  notificationSaveFailedPrefix:
      _zhHansSettingsStrings.notificationSaveFailedPrefix,
  privacySettingsTitle: _zhHansSettingsStrings.privacySettingsTitle,
  privacyHeroTitle: _zhHansSettingsStrings.privacyHeroTitle,
  privacyHeroSubtitle: _zhHansSettingsStrings.privacyHeroSubtitle,
  visibilitySectionTitle: _zhHansSettingsStrings.visibilitySectionTitle,
  disablePhoneSearchTitle: _zhHansSettingsStrings.disablePhoneSearchTitle,
  disablePhoneSearchSubtitle: _zhHansSettingsStrings.disablePhoneSearchSubtitle,
  showOnlineStatusTitle: _zhHansSettingsStrings.showOnlineStatusTitle,
  showOnlineStatusSubtitle: _zhHansSettingsStrings.showOnlineStatusSubtitle,
  showMessagePreviewTitle: _zhHansSettingsStrings.showMessagePreviewTitle,
  showMessagePreviewSubtitle: _zhHansSettingsStrings.showMessagePreviewSubtitle,
  securitySectionTitle: _zhHansSettingsStrings.securitySectionTitle,
  deviceLockTitle: _zhHansSettingsStrings.deviceLockTitle,
  deviceLockSubtitle: _zhHansSettingsStrings.deviceLockSubtitle,
  blacklistTitle: _zhHansSettingsStrings.blacklistTitle,
  blacklistSubtitle: _zhHansSettingsStrings.blacklistSubtitle,
  settingsSaved: _zhHansSettingsStrings.settingsSaved,
  saveFailedPrefix: _zhHansSettingsStrings.saveFailedPrefix,
  setDeviceLock: _zhHansSettingsStrings.setDeviceLock,
  enterPassword: _zhHansSettingsStrings.enterPassword,
  passwordHint6Digits: _zhHansSettingsStrings.passwordHint6Digits,
  confirmPassword: _zhHansSettingsStrings.confirmPassword,
  deviceLockPasswordMustBe6Digits:
      _zhHansSettingsStrings.deviceLockPasswordMustBe6Digits,
  passwordsDoNotMatch: _zhHansSettingsStrings.passwordsDoNotMatch,
  enableDeviceLockFailedPrefix:
      _zhHansSettingsStrings.enableDeviceLockFailedPrefix,
  disableDeviceLockFailedPrefix:
      _zhHansSettingsStrings.disableDeviceLockFailedPrefix,
  accountSecurityTitle: _zhHansSettingsStrings.accountSecurityTitle,
  accountAndDevicesTitle: _zhHansSettingsStrings.accountAndDevicesTitle,
  accountAndDevicesSubtitlePrefix:
      _zhHansSettingsStrings.accountAndDevicesSubtitlePrefix,
  accountAndDevicesSubtitleSuffix:
      _zhHansSettingsStrings.accountAndDevicesSubtitleSuffix,
  signedInDevicesSection: _zhHansSettingsStrings.signedInDevicesSection,
  accountActionsSection: _zhHansSettingsStrings.accountActionsSection,
  deviceListTitle: _zhHansSettingsStrings.deviceListTitle,
  devicesCountSuffix: _zhHansSettingsStrings.devicesCountSuffix,
  destroyAccountTitle: _zhHansSettingsStrings.destroyAccountTitle,
  destroyAccountSubtitle: _zhHansSettingsStrings.destroyAccountSubtitle,
  destroyAccountDialogTitle: _zhHansSettingsStrings.destroyAccountDialogTitle,
  destroyAccountDialogMessage:
      _zhHansSettingsStrings.destroyAccountDialogMessage,
  destroyAccountVerificationHint:
      _zhHansSettingsStrings.destroyAccountVerificationHint,
  destroyAccountSendCode: _zhHansSettingsStrings.destroyAccountSendCode,
  destroyAccountSending: _zhHansSettingsStrings.destroyAccountSending,
  destroyAccountConfirmAction:
      _zhHansSettingsStrings.destroyAccountConfirmAction,
  destroyAccountSuccess: _zhHansSettingsStrings.destroyAccountSuccess,
  destroyAccountCodeRequired: _zhHansSettingsStrings.destroyAccountCodeRequired,
  destroyAccountSendCodeFailedPrefix:
      _zhHansSettingsStrings.destroyAccountSendCodeFailedPrefix,
  destroyAccountFailedPrefix: _zhHansSettingsStrings.destroyAccountFailedPrefix,
  signedInDevicesTitle: _zhHansSettingsStrings.signedInDevicesTitle,
  loading: _zhHansSettingsStrings.loading,
  noDevices: _zhHansSettingsStrings.noDevices,
  removeDeviceTitle: _zhHansSettingsStrings.removeDeviceTitle,
  removeDeviceMessage: _zhHansSettingsStrings.removeDeviceMessage,
  remove: _zhHansSettingsStrings.remove,
  removeFailedPrefix: _zhHansSettingsStrings.removeFailedPrefix,
  unknownDevice: _zhHansSettingsStrings.unknownDevice,
  currentDevice: _zhHansSettingsStrings.currentDevice,
  blacklistPageTitle: _zhHansSettingsStrings.blacklistPageTitle,
  blacklistEmpty: _zhHansSettingsStrings.blacklistEmpty,
  blacklistEmptyHint: _zhHansSettingsStrings.blacklistEmptyHint,
  userIdCannotBeEmpty: _zhHansSettingsStrings.userIdCannotBeEmpty,
  removedFromBlacklist: _zhHansSettingsStrings.removedFromBlacklist,
  operationFailedPrefix: _zhHansSettingsStrings.operationFailedPrefix,
  unknownUser: _zhHansSettingsStrings.unknownUser,
  pcLoginPageTitle: _zhHansSettingsStrings.pcLoginPageTitle,
  loadingWebLoginAddress: _zhHansSettingsStrings.loadingWebLoginAddress,
  pcLoginGuideDescription: _zhHansSettingsStrings.pcLoginGuideDescription,
  copyAddress: _zhHansSettingsStrings.copyAddress,
  copyWebLoginUrl: _zhHansSettingsStrings.copyWebLoginUrl,
  webLoginAddressCopied: _zhHansSettingsStrings.webLoginAddressCopied,
  scanQrCode: _zhHansSettingsStrings.scanQrCode,
  useMobileScanToConfirmLogin:
      _zhHansSettingsStrings.useMobileScanToConfirmLogin,
  pcLoginStatus: _zhHansSettingsStrings.pcLoginStatus,
  openManagementControls: _zhHansSettingsStrings.openManagementControls,
  phoneMute: _zhHansSettingsStrings.phoneMute,
  muted: _zhHansSettingsStrings.muted,
  fileHelper: _zhHansSettingsStrings.fileHelper,
  openChat: _zhHansSettingsStrings.openChat,
  lock: _zhHansSettingsStrings.lock,
  locked: _zhHansSettingsStrings.locked,
  unlocked: _zhHansSettingsStrings.unlocked,
  exitAllPcWebLogin: _zhHansSettingsStrings.exitAllPcWebLogin,
  pcLoginLockedNotice: _zhHansSettingsStrings.pcLoginLockedNotice,
  phoneNotificationsMuted: _zhHansSettingsStrings.phoneNotificationsMuted,
  phoneNotificationsEnabled: _zhHansSettingsStrings.phoneNotificationsEnabled,
  pcLoginHeroTitle: _zhHansSettingsStrings.pcLoginHeroTitle,
  generalHeroTitle: 'General Settings',
  generalHeroSubtitle:
      'Adjust appearance, storage, messaging, modules, and account options.',
  generalAppearanceSectionTitle: 'Appearance',
  generalStorageSectionTitle: 'Storage',
  generalMessagesSectionTitle: 'Messages',
  generalModulesSectionTitle: 'Modules',
  generalSupportSectionTitle: 'Support',
  generalAccountSectionTitle: 'Account',
  notificationHeroTitle: 'Notifications',
  notificationHeroSubtitle:
      'Control alerts, in-app behavior, and system notification access.',
  notificationPreferencesSectionTitle: 'Preferences',
  notificationSystemSectionTitle: 'System Access',
  notificationHelpSectionTitle: 'Need Help?',
  notificationDisabledHint:
      'When disabled, the app still syncs messages but no new notification alerts are shown.',
  notificationSystemSettingsHint:
      'If alerts are still missing, open system settings to check notification permissions.',
  favoritesPageTitle: 'Favorites',
  favoritesHeroTitle: 'Favorite Messages',
  favoritesHeroSubtitle:
      'Quickly find, open, and manage your saved message collection.',
  favoritesSearchHint: 'Search favorites',
  favoritesLoadingHint: 'Loading favorites...',
  favoritesEmptyTitle: 'No Favorites Yet',
  favoritesEmptySubtitle:
      'Messages you save will appear here for quick access.',
  favoritesLoadFailed: 'Unable to load favorites. Pull down to retry.',
  favoritesRefreshFailed: 'Refresh failed. Please try again.',
  favoritesRetry: 'Retry',
  favoritesDeleteTitle: 'Remove Favorite',
  favoritesDeleteMessage:
      'Remove this item from favorites? This does not delete the original message.',
  favoritesDeleteAction: 'Remove',
  favoritesDeleteTooltip: 'Remove from favorites',
  favoritesDeleteFailed: 'Failed to remove favorite: ',
  favoritesOpenFailed: 'Unable to open favorite: ',
  favoritesUnsupportedOpen:
      'This favorite cannot be opened on the current platform.',
  appModulesPageTitle: 'App Modules',
  appModulesSaveAction: 'Save Changes',
  appModulesHeroTitle: 'App Modules',
  appModulesHeroSubtitle:
      'Choose which modules are visible and keep your module list synced.',
  appModulesStatusTitle: 'Current Status',
  appModulesListSectionTitle: 'Module List',
  appModulesHelpCopy:
      'Changes apply after saving. Modules unavailable to your account are disabled automatically.',
  appModulesLoadingHint: 'Loading modules...',
  appModulesEmptyHint: 'No modules available right now.',
  appModulesFallbackModuleName: 'Unknown Module',
  appModulesSaveSuccess: 'Module settings saved.',
  appModulesSyncedStatus: 'Synced',
  appModulesLoadFailedPrefix: 'Failed to load app modules: ',
  appModulesSaveFailedPrefix: 'Failed to save app modules: ',
  appModulesRetry: 'Retry',
  workplaceCatalogEntryTitle: _zhHansSettingsStrings.workplaceCatalogEntryTitle,
  workplaceCatalogEntrySubtitle:
      _zhHansSettingsStrings.workplaceCatalogEntrySubtitle,
  workplaceCatalogBrowseAction:
      _zhHansSettingsStrings.workplaceCatalogBrowseAction,
  workplaceCatalogPageTitle: _zhHansSettingsStrings.workplaceCatalogPageTitle,
  workplaceCatalogHeroTitle: _zhHansSettingsStrings.workplaceCatalogHeroTitle,
  workplaceCatalogHeroSubtitle:
      _zhHansSettingsStrings.workplaceCatalogHeroSubtitle,
  workplaceCatalogBannersSectionTitle:
      _zhHansSettingsStrings.workplaceCatalogBannersSectionTitle,
  workplaceCatalogMyAppsSectionTitle:
      _zhHansSettingsStrings.workplaceCatalogMyAppsSectionTitle,
  workplaceCatalogRecentSectionTitle:
      _zhHansSettingsStrings.workplaceCatalogRecentSectionTitle,
  workplaceCatalogCategoriesSectionTitle:
      _zhHansSettingsStrings.workplaceCatalogCategoriesSectionTitle,
  workplaceCatalogCategoryAppsSectionTitle:
      _zhHansSettingsStrings.workplaceCatalogCategoryAppsSectionTitle,
  workplaceCatalogEmptyHint: _zhHansSettingsStrings.workplaceCatalogEmptyHint,
  workplaceCatalogAddAction: _zhHansSettingsStrings.workplaceCatalogAddAction,
  workplaceCatalogRemoveAction:
      _zhHansSettingsStrings.workplaceCatalogRemoveAction,
  workplaceCatalogOpenAction: _zhHansSettingsStrings.workplaceCatalogOpenAction,
  workplaceCatalogOpenFailedPrefix:
      _zhHansSettingsStrings.workplaceCatalogOpenFailedPrefix,
  workplaceCatalogPendingNativeRoutePrefix:
      _zhHansSettingsStrings.workplaceCatalogPendingNativeRoutePrefix,
  workplaceCatalogNoLaunchRoute:
      _zhHansSettingsStrings.workplaceCatalogNoLaunchRoute,
);
