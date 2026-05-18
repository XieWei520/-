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
import '../../widgets/liquid_glass_tokens.dart';
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
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: LiquidGlassSizes.pageContentMaxWidth,
              ),
              child: ListView(
                padding: const EdgeInsets.symmetric(
                  horizontal: LiquidGlassSizes.pageContentPadding,
                ),
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
                  _UserMenuSection(entries: visibleMenuEntries),
                  const SizedBox(height: 30),
                ],
              ),
            ),
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
            constraints: const BoxConstraints(
              maxWidth: LiquidGlassSizes.pageContentMaxWidth,
            ),
            child: WKWebPanel(
              margin: const EdgeInsets.all(LiquidGlassSizes.pageContentPadding),
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
        final contentHorizontalPadding = headerWidth < 280
            ? WKSpace.md
            : WKSpace.lg;
        final avatarSize = headerWidth < 320 ? 68.0 : 76.0;
        final accentHeight = headerWidth < 320 ? 58.0 : 64.0;

        return Padding(
          padding: const EdgeInsets.fromLTRB(
            0,
            8,
            0,
            LiquidGlassSizes.sectionGap,
          ),
          child: Container(
            key: const ValueKey<String>('user-profile-card'),
            width: double.infinity,
            constraints: const BoxConstraints(minHeight: 190),
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: WKWebColors.surface,
              borderRadius: BorderRadius.circular(WKWebRadius.panel),
              border: Border.all(color: WKWebColors.borderWarm),
              boxShadow: LiquidGlassShadows.sm,
            ),
            child: Stack(
              children: [
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  height: accentHeight,
                  child: Container(
                    key: const ValueKey<String>('user-profile-accent'),
                    decoration: const BoxDecoration(
                      color: WKWebColors.actionSoft,
                      borderRadius: BorderRadius.vertical(
                        top: Radius.circular(WKWebRadius.panel),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: WKSpace.lg,
                  right: WKSpace.lg,
                  child: GestureDetector(
                    key: const ValueKey<String>('user_profile_qr'),
                    behavior: HitTestBehavior.opaque,
                    onTap: onQrTap,
                    child: Container(
                      width: 36,
                      height: 36,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: WKWebColors.surface,
                        borderRadius: BorderRadius.circular(
                          WKWebRadius.control,
                        ),
                        border: Border.all(color: WKWebColors.borderWarm),
                      ),
                      child: WKReferenceAssets.image(
                        WKReferenceAssets.qrCode,
                        width: 20,
                        height: 20,
                        tint: WKWebColors.textPrimary,
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    contentHorizontalPadding,
                    accentHeight - 24,
                    contentHorizontalPadding,
                    WKSpace.lg,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      GestureDetector(
                        key: const ValueKey<String>('user_profile_avatar'),
                        behavior: HitTestBehavior.opaque,
                        onTap: onAvatarTap,
                        child: Container(
                          padding: const EdgeInsets.all(3),
                          decoration: BoxDecoration(
                            color: WKWebColors.surface,
                            border: Border.all(color: WKWebColors.borderWarm),
                            shape: BoxShape.circle,
                          ),
                          child: WKAvatar(
                            url: avatarUrl,
                            name: name,
                            size: avatarSize,
                          ),
                        ),
                      ),
                      const SizedBox(height: WKSpace.md),
                      LayoutBuilder(
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
                            spacing: WKSpace.xs,
                            runSpacing: WKSpace.xs,
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
                                    color: WKWebColors.textPrimary,
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
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _UserMenuSection extends StatelessWidget {
  const _UserMenuSection({required this.entries});

  final List<UserPageMenuEntry> entries;

  @override
  Widget build(BuildContext context) {
    final groups = <List<UserPageMenuEntry>>[];
    var currentGroup = <UserPageMenuEntry>[];
    for (final entry in entries) {
      currentGroup.add(entry);
      if (entry.showBottomGap) {
        groups.add(currentGroup);
        currentGroup = <UserPageMenuEntry>[];
      }
    }
    if (currentGroup.isNotEmpty) {
      groups.add(currentGroup);
    }

    return Column(
      children: [
        for (var groupIndex = 0; groupIndex < groups.length; groupIndex++) ...[
          _UserMenuGroup(entries: groups[groupIndex]),
          if (groupIndex != groups.length - 1)
            const SizedBox(height: LiquidGlassSizes.sectionGap),
        ],
      ],
    );
  }
}

class _UserMenuGroup extends StatelessWidget {
  const _UserMenuGroup({required this.entries});

  final List<UserPageMenuEntry> entries;

  @override
  Widget build(BuildContext context) {
    return Material(
      key: ValueKey<String>('user-menu-group-${entries.first.sid}'),
      color: WKWebColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(WKWebRadius.panel),
        side: const BorderSide(color: WKWebColors.borderWarm),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (var index = 0; index < entries.length; index++) ...[
            _UserMenuItem(
              key: ValueKey('user_menu_${entries[index].sid}'),
              sid: entries[index].sid,
              iconAsset: entries[index].iconAsset,
              title: entries[index].title,
              showNewVersionBadge: entries[index].showNewVersionBadge,
              onTap: entries[index].onTap,
            ),
            if (index != entries.length - 1)
              const Divider(
                height: 1,
                thickness: 1,
                indent: 68,
                color: WKWebColors.borderWarm,
              ),
          ],
        ],
      ),
    );
  }
}

class _UserMenuItem extends StatelessWidget {
  final String sid;
  final String iconAsset;
  final String title;
  final bool showNewVersionBadge;
  final VoidCallback onTap;

  const _UserMenuItem({
    super.key,
    required this.sid,
    required this.iconAsset,
    required this.title,
    required this.onTap,
    this.showNewVersionBadge = false,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      highlightColor: WKWebColors.action.withValues(alpha: 0.05),
      splashColor: WKWebColors.action.withValues(alpha: 0.07),
      child: SizedBox(
        height: LiquidGlassSizes.listRowHeight,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              buildUserMenuLeadingIcon(sid: sid, iconAsset: iconAsset),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: WKFontFamily.primary,
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: WKWebColors.textPrimary,
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
                tint: WKWebColors.textTertiary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
