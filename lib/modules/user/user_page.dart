import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config/app_config.dart';
import '../../data/providers/auth_provider.dart';
import '../../service/api/common_api.dart';
import '../../widgets/wk_avatar.dart';
import '../../widgets/wk_branded_icon.dart';
import '../../widgets/wk_colors.dart';
import '../../widgets/wk_design_tokens.dart';
import '../../widgets/wk_main_top_bar.dart';
import '../../widgets/wk_reference_assets.dart';
import '../../widgets/wk_web_ui_tokens.dart';
import '../../wk_endpoint/core/slot_registry.dart';
import '../../wk_endpoint/providers/slot_registry_provider.dart';
import '../../wk_endpoint/slots/personal_center_slots.dart';
import '../../wukong_base/endpoint/entity/personal_info_menu.dart';
import '../../wukong_login/pc_login_page.dart';
import '../../wukong_uikit/setting/setting_page.dart';
import '../../wukong_uikit/user/my_info_page.dart';
import '../../wukong_uikit/user/user_qr_page.dart';
import '../favorites/favorite_record_navigation.dart';
import '../favorites/favorites_page.dart';
import '../customer_service/customer_service_badge.dart';
import '../settings/account_security_page.dart';
import '../settings/notification_settings_page.dart';
import '../settings/privacy_settings_page.dart';
import '../settings/settings_strings.dart';
import '../vip/vip_badge.dart';
import '../vip/vip_management_page.dart';
import 'user_slot_assembly.dart';

typedef UserPageVersionLoader = Future<AppVersionInfo?> Function();

final userPageVersionLoaderProvider = Provider<UserPageVersionLoader>((ref) {
  return () => CommonApi.instance.getAppNewVersion(AppConfig.appVersion);
});

@visibleForTesting
WKBrandedIconSpec? resolveUserMenuLeadingIconSpec(String sid) {
  switch (sid) {
    case 'personal_center_currency':
      return const WKBrandedIconSpec(
        icon: Icons.settings_rounded,
        startColor: Color(0xFF3ED8C6),
        endColor: Color(0xFF1FB19A),
      );
    case 'personal_center_new_msg_notice':
      return const WKBrandedIconSpec(
        icon: Icons.notifications_rounded,
        startColor: Color(0xFF67B8FF),
        endColor: Color(0xFF418BFF),
      );
    case 'personal_center_favorites':
      return const WKBrandedIconSpec(
        icon: Icons.star_rounded,
        startColor: Color(0xFFFFC760),
        endColor: Color(0xFFF39A35),
      );
    case 'personal_center_privacy':
      return const WKBrandedIconSpec(
        icon: Icons.lock_rounded,
        startColor: Color(0xFF5FD38E),
        endColor: Color(0xFF2FAF64),
      );
    case 'personal_center_account_security':
      return const WKBrandedIconSpec(
        icon: Icons.verified_user_rounded,
        startColor: Color(0xFF58C7F7),
        endColor: Color(0xFF2788E8),
      );
    case 'personal_center_web_login':
      return const WKBrandedIconSpec(
        icon: Icons.desktop_windows_rounded,
        startColor: Color(0xFF8DB2FF),
        endColor: Color(0xFF5B77E6),
      );
    default:
      return null;
  }
}

@visibleForTesting
Widget buildUserMenuLeadingIcon({
  required String sid,
  required String iconAsset,
}) {
  final brandedSpec = resolveUserMenuLeadingIconSpec(sid);
  if (brandedSpec != null) {
    return buildWKBrandedIcon(brandedSpec);
  }

  const iconContainerSize = 40.0;
  const iconPadding = 8.0;
  final decoration = BoxDecoration(
    color: const Color(0xFFF4F6F8),
    borderRadius: BorderRadius.circular(14),
  );
  if (iconAsset.trim().isEmpty) {
    return Container(
      width: iconContainerSize,
      height: iconContainerSize,
      decoration: decoration,
      alignment: Alignment.center,
      child: const Icon(Icons.apps_rounded, size: 18, color: WKColors.color999),
    );
  }
  return Container(
    width: iconContainerSize,
    height: iconContainerSize,
    padding: const EdgeInsets.all(iconPadding),
    decoration: decoration,
    child: WKReferenceAssets.image(iconAsset, fit: BoxFit.contain),
  );
}

@visibleForTesting
List<UserPageMenuEntry> buildAndroidUserMenuEntries({
  required bool hasNewVersion,
  required bool showWebLoginEntry,
  required VoidCallback onOpenSettings,
  required VoidCallback onOpenNotifications,
  required VoidCallback onOpenFavorites,
  required VoidCallback onOpenPrivacySettings,
  required VoidCallback onOpenAccountSecurity,
  required VoidCallback onOpenWebLogin,
  SlotRegistry? registry,
}) {
  final slotRegistry = registry ?? SlotRegistry();
  final items = resolvePersonalCenterMenus(
    slotRegistry,
    PersonalCenterSlotContext(
      hasNewVersion: hasNewVersion,
      strings: zhHansSettingsStrings,
    ),
    openSettings: onOpenSettings,
    openNotifications: onOpenNotifications,
    openFavorites: onOpenFavorites,
    openPrivacySettings: onOpenPrivacySettings,
    openAccountSecurity: onOpenAccountSecurity,
    openWebLogin: onOpenWebLogin,
    showWebLoginEntry: showWebLoginEntry,
  );
  return mapPersonalCenterMenusToUserPageEntries(items);
}

class UserPageMenuEntry {
  final String sid;
  final String iconAsset;
  final String title;
  final bool showNewVersionBadge;
  final bool showBottomGap;
  final VoidCallback onTap;

  const UserPageMenuEntry({
    required this.sid,
    required this.iconAsset,
    required this.title,
    required this.onTap,
    this.showNewVersionBadge = false,
    this.showBottomGap = false,
  });
}

class UserPage extends ConsumerStatefulWidget {
  const UserPage({super.key, this.forceWebFrameForTesting = false});

  final bool forceWebFrameForTesting;

  @override
  ConsumerState<UserPage> createState() => _UserPageState();
}

class _UserPageState extends ConsumerState<UserPage> {
  bool _hasNewVersion = false;

  @override
  void initState() {
    super.initState();
    _loadVersionIndicator();
  }

  bool _canLoadVersionIndicator() {
    return ref.read(authProvider).isLoggedIn;
  }

  Future<void> _loadVersionIndicator() async {
    if (!_canLoadVersionIndicator()) {
      if (mounted && _hasNewVersion) {
        setState(() => _hasNewVersion = false);
      }
      return;
    }

    try {
      final version = await ref.read(userPageVersionLoaderProvider).call();
      if (!mounted) {
        return;
      }
      if (!_canLoadVersionIndicator()) {
        if (_hasNewVersion) {
          setState(() => _hasNewVersion = false);
        }
        return;
      }
      setState(() => _hasNewVersion = version?.hasDownloadUrl == true);
    } catch (error, stackTrace) {
      if (!mounted || !_canLoadVersionIndicator()) {
        return;
      }
      debugPrint('UserPage version check failed: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  Future<void> _pushPage(Widget page) async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));
    if (mounted) {
      await _loadVersionIndicator();
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final userInfo = authState.userInfo;
    final isVipUser = userInfo?.vipLevel == 1;
    final isCustomerServiceUser = userInfo?.isCustomerService == true;
    final strings = resolveSettingsStrings(
      locale: Localizations.localeOf(context),
    );
    final displayName = userInfo?.name?.trim().isNotEmpty == true
        ? userInfo!.name!.trim()
        : strings.guestUser;
    final slotRegistry = ref.read(slotRegistryProvider);
    const showWebLoginEntry = true;
    final menuEntries = mapPersonalCenterMenusToUserPageEntries(
      resolvePersonalCenterMenus(
        slotRegistry,
        PersonalCenterSlotContext(
          hasNewVersion: _hasNewVersion,
          strings: strings,
        ),
        openSettings: () => _pushPage(const SettingPage()),
        openNotifications: () => _pushPage(const NotificationSettingsPage()),
        openFavorites: () => _pushPage(
          FavoritesPage(
            onOpenRecord: (record) =>
                openFavoriteRecordInContext(context, record),
          ),
        ),
        openPrivacySettings: () => _pushPage(const PrivacySettingsPage()),
        openAccountSecurity: () => _pushPage(const AccountSecurityPage()),
        openWebLogin: () => _pushPage(const PCLoginPage()),
        showWebLoginEntry: showWebLoginEntry,
      ),
    );
    final visibleMenuEntries = isVipUser
        ? <UserPageMenuEntry>[
            ...menuEntries,
            UserPageMenuEntry(
              sid: 'vip_management',
              iconAsset: '',
              title: '管理系统',
              onTap: () => _pushPage(const VipManagementPage()),
              showBottomGap: true,
            ),
          ]
        : menuEntries;

    final body = Column(
      children: [
        const WKMainTopBar(title: Text('我的')),
        Expanded(
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              _ProfileHeader(
                name: displayName,
                showVipBadge: isVipUser,
                showCustomerServiceBadge: isCustomerServiceUser,
                avatarUrl: userInfo?.avatar,
                onAvatarTap: () => _pushPage(const MyInfoPage()),
                onQrTap: () => _pushPage(
                  UserQrPage(
                    uid: userInfo?.uid,
                    username: displayName,
                    avatarUrl: userInfo?.avatar,
                  ),
                ),
              ),
              for (final entry in visibleMenuEntries)
                _UserMenuItem(
                  key: ValueKey('user_menu_${entry.sid}'),
                  sid: entry.sid,
                  iconAsset: entry.iconAsset,
                  title: entry.title,
                  showNewVersionBadge: entry.showNewVersionBadge,
                  showBottomGap: entry.showBottomGap,
                  onTap: entry.onTap,
                ),
              const SizedBox(height: 30),
            ],
          ),
        ),
      ],
    );

    final useWebFrame =
        widget.forceWebFrameForTesting ||
        (kIsWeb &&
            MediaQuery.sizeOf(context).width >= WKWebBreakpoints.desktopMin);

    if (useWebFrame) {
      return Scaffold(
        key: const ValueKey<String>('user-web-frame'),
        backgroundColor: WKWebColors.pageWarm,
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 920),
            child: WKWebPanel(
              margin: const EdgeInsets.all(WKSpace.md),
              child: body,
            ),
          ),
        ),
      );
    }

    return Scaffold(backgroundColor: WKColors.homeBg, body: body);
  }
}

@visibleForTesting
List<UserPageMenuEntry> mapPersonalCenterMenusToUserPageEntries(
  List<PersonalInfoMenu> items,
) {
  final lastVisibleSid = items.isEmpty ? null : items.last.sid;
  final hasWebLoginEntry = items.any(
    (entry) => entry.sid == 'personal_center_web_login',
  );
  return items
      .map(
        (entry) => UserPageMenuEntry(
          sid: entry.sid,
          iconAsset: entry.imgResource ?? '',
          title: entry.text ?? '',
          onTap: entry.onClick == null
              ? () {}
              : () => entry.onClick?.call(entry.sid),
          showNewVersionBadge:
              entry.sid == 'personal_center_currency' && entry.isNewVersion,
          showBottomGap: shouldShowPersonalCenterBottomGap(
            sid: entry.sid,
            lastVisibleSid: lastVisibleSid,
            hasWebLoginEntry: hasWebLoginEntry,
          ),
        ),
      )
      .toList(growable: false);
}

@visibleForTesting
bool shouldShowPersonalCenterBottomGap({
  required String sid,
  required String? lastVisibleSid,
  required bool hasWebLoginEntry,
}) {
  if (sid == 'personal_center_new_msg_notice' ||
      sid == 'personal_center_favorites') {
    return true;
  }
  if (sid == 'personal_center_web_login') {
    return true;
  }
  if (!hasWebLoginEntry && sid == 'personal_center_account_security') {
    return true;
  }
  return sid == lastVisibleSid;
}

class _ProfileHeader extends StatelessWidget {
  final String name;
  final bool showVipBadge;
  final bool showCustomerServiceBadge;
  final String? avatarUrl;
  final VoidCallback onAvatarTap;
  final VoidCallback onQrTap;

  const _ProfileHeader({
    required this.name,
    required this.showVipBadge,
    required this.showCustomerServiceBadge,
    required this.avatarUrl,
    required this.onAvatarTap,
    required this.onQrTap,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final headerWidth = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : MediaQuery.sizeOf(context).width;
        final contentHorizontalPadding = headerWidth < 280 ? 16.0 : 24.0;

        return ConstrainedBox(
          constraints: BoxConstraints(minHeight: 245, minWidth: headerWidth),
          child: Stack(
            children: [
              Positioned.fill(
                child: Align(
                  alignment: Alignment.topCenter,
                  child: WKReferenceAssets.image(
                    WKReferenceAssets.myBackground,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              Positioned(
                top: 50,
                right: 30,
                child: GestureDetector(
                  key: const ValueKey<String>('user_profile_qr'),
                  behavior: HitTestBehavior.opaque,
                  onTap: onQrTap,
                  child: WKReferenceAssets.image(
                    WKReferenceAssets.qrCode,
                    width: 22,
                    height: 22,
                    tint: WKColors.popupText,
                  ),
                ),
              ),
              SizedBox(
                width: double.infinity,
                child: SafeArea(
                  bottom: false,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 18),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const SizedBox(height: 100),
                        GestureDetector(
                          key: const ValueKey<String>('user_profile_avatar'),
                          behavior: HitTestBehavior.opaque,
                          onTap: onAvatarTap,
                          child: WKAvatar(url: avatarUrl, name: name, size: 90),
                        ),
                        const SizedBox(height: 15),
                        Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: contentHorizontalPadding,
                          ),
                          child: LayoutBuilder(
                            builder: (context, identityConstraints) {
                              final textScale = MediaQuery.textScalerOf(
                                context,
                              ).scale(1);
                              final useCompactBadges =
                                  identityConstraints.maxWidth < 300 ||
                                  textScale > 1.2;

                              return Wrap(
                                alignment: WrapAlignment.center,
                                runAlignment: WrapAlignment.center,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                spacing: 8,
                                runSpacing: 5,
                                children: [
                                  ConstrainedBox(
                                    constraints: BoxConstraints(
                                      maxWidth: identityConstraints.maxWidth,
                                    ),
                                    child: Text(
                                      name,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                        fontFamily: WKFontFamily.title,
                                        fontSize: 20,
                                        fontWeight: FontWeight.w700,
                                        color: WKColors.colorDark,
                                      ),
                                    ),
                                  ),
                                  if (showVipBadge)
                                    VipBadge(compact: useCompactBadges),
                                  if (showCustomerServiceBadge)
                                    CustomerServiceBadge(
                                      key: const ValueKey<String>(
                                        'user-profile-customer-service-badge',
                                      ),
                                      compact: useCompactBadges,
                                    ),
                                ],
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _UserMenuItem extends StatelessWidget {
  final String sid;
  final String iconAsset;
  final String title;
  final bool showNewVersionBadge;
  final bool showBottomGap;
  final VoidCallback onTap;

  const _UserMenuItem({
    super.key,
    required this.sid,
    required this.iconAsset,
    required this.title,
    required this.onTap,
    this.showNewVersionBadge = false,
    this.showBottomGap = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Material(
          color: WKColors.surface,
          child: InkWell(
            onTap: onTap,
            highlightColor: WKColors.screenBgSelected,
            splashColor: WKColors.screenBgSelected,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 15),
              child: Row(
                children: [
                  buildUserMenuLeadingIcon(sid: sid, iconAsset: iconAsset),
                  const SizedBox(width: 15),
                  Expanded(
                    child: Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: WKFontFamily.primary,
                        fontSize: 16,
                        color: WKColors.colorDark,
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 30,
                    height: 30,
                    child: Opacity(
                      opacity: showNewVersionBadge ? 1 : 0,
                      child: WKReferenceAssets.image(
                        WKReferenceAssets.newVersion,
                        width: 30,
                        height: 30,
                      ),
                    ),
                  ),
                  WKReferenceAssets.image(
                    WKReferenceAssets.arrowRight,
                    width: 14,
                    height: 14,
                  ),
                ],
              ),
            ),
          ),
        ),
        if (showBottomGap) Container(height: 15, color: WKColors.homeBg),
      ],
    );
  }
}
