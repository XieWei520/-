import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/chat_session.dart';
import '../../../widgets/liquid_glass_panel.dart';
import '../../../widgets/liquid_glass_tokens.dart';
import '../../../widgets/wk_colors.dart';
import '../../../widgets/wk_main_top_bar.dart';
import '../../../widgets/wk_reference_assets.dart';
import '../../../widgets/wk_web_ui_tokens.dart';
import '../../../modules/vip/vip_badge.dart';
import '../../../widgets/wk_avatar.dart';
import '../chat_scene_providers.dart';
import '../chat_search_mode_controller.dart';
import '../widgets/chat_search_mode_bar.dart';

@immutable
class ChatHeaderPaneState {
  const ChatHeaderPaneState({
    required this.title,
    this.subtitle,
    this.secondarySubtitle,
    this.avatarUrl,
    this.vipLevel = 0,
    this.tags = const <String>[],
    this.tagWidgets = const <Widget>[],
    this.isGroup = false,
    this.showSearchAction = true,
  });

  final String title;
  final String? subtitle;
  final String? secondarySubtitle;
  final String? avatarUrl;
  final int vipLevel;
  final List<String> tags;
  final List<Widget> tagWidgets;
  final bool isGroup;
  final bool showSearchAction;
}

class ChatHeaderPane extends ConsumerWidget implements PreferredSizeWidget {
  const ChatHeaderPane({
    super.key,
    required this.session,
    required this.state,
    this.onBack,
    this.onOpenSearch,
    this.onSearchKeywordChanged,
    this.onSearchSubmitted,
    this.onCloseSearch,
    this.onOpenDetails,
    this.height = kToolbarHeight,
    this.productionChrome = false,
    this.isMobileWarmStyle = false,
    this.useLiquidShell = false,
    this.enableIdentityTap = false,
    this.onIdentityTap,
  });

  final ChatSession session;
  final ChatHeaderPaneState state;
  final VoidCallback? onBack;
  final VoidCallback? onOpenSearch;
  final ValueChanged<String>? onSearchKeywordChanged;
  final ValueChanged<String>? onSearchSubmitted;
  final VoidCallback? onCloseSearch;
  final VoidCallback? onOpenDetails;
  final double height;
  final bool productionChrome;
  final bool isMobileWarmStyle;
  final bool useLiquidShell;
  final bool enableIdentityTap;
  final VoidCallback? onIdentityTap;

  @override
  Size get preferredSize => Size.fromHeight(_effectiveHeight);

  double get _effectiveHeight {
    if (!productionChrome || height != kToolbarHeight) {
      return height;
    }
    if (isMobileWarmStyle) {
      return 74;
    }
    if (useLiquidShell) {
      return 68;
    }
    return kToolbarHeight;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final searchMode = ref.watch(chatSearchModeControllerProvider(session));
    if (productionChrome) {
      return _buildProductionAppBar(context, searchMode);
    }
    return AppBar(
      key: const ValueKey<String>('chat-header-pane'),
      toolbarHeight: _effectiveHeight,
      leading: IconButton(
        key: const ValueKey<String>('chat-header-back'),
        onPressed: onBack ?? () => Navigator.of(context).maybePop(),
        icon: const Icon(Icons.arrow_back),
        tooltip: MaterialLocalizations.of(context).backButtonTooltip,
      ),
      title: searchMode.isActive
          ? _HeaderSearchField(
              keyword: searchMode.keyword,
              onChanged: onSearchKeywordChanged,
              onSubmitted: onSearchSubmitted,
              onClose: onCloseSearch,
            )
          : _HeaderIdentity(state: state),
      actions: searchMode.isActive
          ? const <Widget>[]
          : <Widget>[
              if (state.showSearchAction)
                IconButton(
                  key: const ValueKey<String>('chat-header-search'),
                  onPressed: onOpenSearch,
                  icon: const Icon(Icons.search),
                  tooltip: '搜索',
                ),
              IconButton(
                key: const ValueKey<String>('chat-header-details'),
                onPressed: onOpenDetails,
                icon: const Icon(Icons.more_horiz),
                tooltip: '详情',
              ),
            ],
    );
  }

  PreferredSizeWidget _buildProductionAppBar(
    BuildContext context,
    ChatSearchModeState searchMode,
  ) {
    final liquidTokens = LiquidGlassTokens.of(context);
    final isDarkTheme = Theme.of(context).brightness == Brightness.dark;
    final mobileWarmSurfaceColor = isDarkTheme
        ? liquidTokens.surface
        : const Color(0xFFFFFFFF);
    final mobileWarmPrimaryColor = isDarkTheme
        ? liquidTokens.text
        : WKWebColors.textPrimary;
    final mobileWarmSecondaryColor = isDarkTheme
        ? liquidTokens.textSecondary
        : WKColors.color999;
    final mobileWarmActionColor = isDarkTheme
        ? liquidTokens.text
        : WKWebColors.action;
    final mobileWarmBorderColor = isDarkTheme
        ? liquidTokens.border
        : WKWebColors.borderWarm;
    final appBarBackgroundColor = isMobileWarmStyle
        ? mobileWarmSurfaceColor
        : useLiquidShell
        ? liquidTokens.surface
        : WKColors.homeBg;
    final headerPrimaryColor = isMobileWarmStyle
        ? mobileWarmPrimaryColor
        : useLiquidShell
        ? liquidTokens.text
        : WKColors.colorDark;
    final headerSecondaryColor = isMobileWarmStyle
        ? mobileWarmSecondaryColor
        : useLiquidShell
        ? liquidTokens.textSecondary
        : WKColors.color999;
    final headerActionTint = isMobileWarmStyle
        ? mobileWarmActionColor
        : useLiquidShell
        ? liquidTokens.text
        : WKColors.popupText;

    return AppBar(
      key: const ValueKey<String>('chat-header-pane'),
      toolbarHeight: _effectiveHeight,
      leadingWidth: isMobileWarmStyle ? 48 : null,
      backgroundColor: appBarBackgroundColor,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      shape: useLiquidShell
          ? RoundedRectangleBorder(
              borderRadius: const BorderRadius.vertical(
                bottom: Radius.circular(20),
              ),
              side: BorderSide(color: liquidTokens.border),
            )
          : null,
      shadowColor: Colors.transparent,
      leading: IconButton(
        key: const ValueKey<String>('chat-back-button'),
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints.tightFor(width: 48, height: 48),
        onPressed: onBack ?? () => Navigator.of(context).maybePop(),
        icon: WKReferenceAssets.image(
          WKReferenceAssets.back,
          width: 22,
          height: 22,
          tint: headerPrimaryColor,
        ),
      ),
      titleSpacing: 0,
      title: searchMode.isActive
          ? ChatSearchModeBar(
              initialKeyword: searchMode.keyword,
              onChanged: onSearchKeywordChanged ?? (_) {},
              onSubmitted: onSearchSubmitted ?? (_) {},
              onClose: onCloseSearch ?? () {},
            )
          : InkWell(
              onTap: enableIdentityTap ? (onIdentityTap ?? () {}) : null,
              child: ChatHeaderIdentityPane(
                title: state.title,
                subtitle: state.subtitle,
                secondarySubtitle: state.secondarySubtitle,
                avatarUrl: state.avatarUrl,
                isGroup: state.isGroup,
                avatarSize: isMobileWarmStyle ? 48 : 40,
                primaryColor: headerPrimaryColor,
                secondaryColor: headerSecondaryColor,
                vipLevel: state.vipLevel,
                tags: _identityTags,
              ),
            ),
      actions: searchMode.isActive
          ? const <Widget>[]
          : <Widget>[
              if (state.showSearchAction)
                IconButton(
                  key: const ValueKey<String>('chat-open-search'),
                  onPressed: onOpenSearch,
                  icon: WKReferenceAssets.image(
                    WKReferenceAssets.search,
                    width: 20,
                    height: 20,
                    tint: headerActionTint,
                  ),
                ),
              if (isMobileWarmStyle)
                isDarkTheme
                    ? Padding(
                        padding: const EdgeInsets.only(right: 16),
                        child: SizedBox(
                          width: 38,
                          height: 38,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: mobileWarmSurfaceColor,
                              borderRadius: BorderRadius.circular(
                                WKWebRadius.control,
                              ),
                              border: Border.all(
                                color: mobileWarmBorderColor,
                                width: 1.2,
                              ),
                            ),
                            child: IconButton(
                              key: const ValueKey<String>('chat-open-more'),
                              tooltip: '\u66F4\u591A',
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints.tightFor(
                                width: 38,
                                height: 38,
                              ),
                              onPressed: onOpenDetails,
                              icon: WKReferenceAssets.image(
                                WKReferenceAssets.topMore,
                                width: 18,
                                height: 18,
                                tint: mobileWarmActionColor,
                              ),
                            ),
                          ),
                        ),
                      )
                    : WKTopBarActionButton(
                        key: const ValueKey<String>('chat-open-more'),
                        tooltip: '\u66F4\u591A',
                        onTap: onOpenDetails,
                        padding: const EdgeInsets.only(right: 16),
                        variant: WKTopBarActionButtonVariant.warmSquare,
                        size: 38,
                        child: WKReferenceAssets.image(
                          WKReferenceAssets.topMore,
                          width: 18,
                          height: 18,
                          tint: mobileWarmActionColor,
                        ),
                      )
              else if (useLiquidShell)
                Padding(
                  padding: const EdgeInsets.only(right: 16),
                  child: LiquidGlassPillButton(
                    key: const ValueKey<String>('chat-open-more'),
                    label: '\u8be6\u60c5',
                    icon: Icons.more_horiz_rounded,
                    onPressed: onOpenDetails,
                  ),
                )
              else
                IconButton(
                  key: const ValueKey<String>('chat-open-more'),
                  onPressed: onOpenDetails,
                  icon: WKReferenceAssets.image(
                    WKReferenceAssets.topMore,
                    width: 20,
                    height: 20,
                    tint: WKColors.popupText,
                  ),
                ),
            ],
    );
  }

  List<Widget> get _identityTags {
    if (state.tagWidgets.isNotEmpty) {
      return state.tagWidgets;
    }
    return state.tags
        .map((tag) => ChatHeaderTag(label: tag))
        .toList(growable: false);
  }
}

class _HeaderIdentity extends StatelessWidget {
  const _HeaderIdentity({required this.state});

  final ChatHeaderPaneState state;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final avatarFallback = state.title.trim().isEmpty
        ? ''
        : state.title.characters.first;
    return Row(
      children: <Widget>[
        CircleAvatar(
          radius: 18,
          backgroundImage: state.avatarUrl == null || state.avatarUrl!.isEmpty
              ? null
              : NetworkImage(state.avatarUrl!),
          child: state.avatarUrl == null || state.avatarUrl!.isEmpty
              ? Text(avatarFallback)
              : null,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Flexible(
                    child: Text(
                      state.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium,
                    ),
                  ),
                  if (state.vipLevel > 0) ...<Widget>[
                    const SizedBox(width: 6),
                    const Icon(Icons.verified, size: 16),
                  ],
                  for (final tag in state.tags) ...<Widget>[
                    const SizedBox(width: 4),
                    Chip(
                      visualDensity: VisualDensity.compact,
                      label: Text(tag),
                    ),
                  ],
                ],
              ),
              if (state.subtitle != null || state.secondarySubtitle != null)
                Text(
                  <String>[
                    if (state.subtitle != null) state.subtitle!,
                    if (state.secondarySubtitle != null)
                      state.secondarySubtitle!,
                  ].join(' · '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall,
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class ChatHeaderIdentityPane extends StatelessWidget {
  const ChatHeaderIdentityPane({
    super.key,
    required this.title,
    required this.avatarSize,
    required this.primaryColor,
    required this.secondaryColor,
    this.subtitle,
    this.secondarySubtitle,
    this.avatarUrl,
    this.isGroup = false,
    this.vipLevel = 0,
    this.tags = const <Widget>[],
    this.animationDuration = const Duration(milliseconds: 180),
  });

  final String title;
  final String? subtitle;
  final String? secondarySubtitle;
  final String? avatarUrl;
  final bool isGroup;
  final double avatarSize;
  final Color primaryColor;
  final Color secondaryColor;
  final int vipLevel;
  final List<Widget> tags;
  final Duration animationDuration;

  @override
  Widget build(BuildContext context) {
    return AnimatedSize(
      duration: animationDuration,
      curve: Curves.easeInOut,
      alignment: Alignment.centerLeft,
      child: Row(
        children: <Widget>[
          WKAvatar(
            url: avatarUrl,
            name: title,
            isGroup: isGroup,
            size: avatarSize,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Flexible(
                      child: Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: primaryColor,
                        ),
                      ),
                    ),
                    if (vipLevel == 1) ...<Widget>[
                      const SizedBox(width: 6),
                      const VipBadge(
                        key: ValueKey<String>('chat-header-vip-badge'),
                      ),
                    ],
                    if (tags.isNotEmpty) const SizedBox(width: 4),
                    if (tags.isNotEmpty)
                      Wrap(spacing: 4, runSpacing: 2, children: tags),
                  ],
                ),
                if (subtitle != null || secondarySubtitle != null)
                  Row(
                    children: <Widget>[
                      if (subtitle != null)
                        Flexible(
                          child: Text(
                            subtitle!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12,
                              color: secondaryColor,
                            ),
                          ),
                        ),
                      if (secondarySubtitle != null) ...<Widget>[
                        if (subtitle != null) const SizedBox(width: 5),
                        Flexible(
                          child: Text(
                            secondarySubtitle!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12,
                              color: secondaryColor,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class ChatHeaderTag extends StatelessWidget {
  const ChatHeaderTag({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final tokens = LiquidGlassTokens.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      decoration: BoxDecoration(
        color: tokens.surface,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: tokens.border),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: tokens.text,
        ),
      ),
    );
  }
}

class _HeaderSearchField extends StatelessWidget {
  const _HeaderSearchField({
    required this.keyword,
    this.onChanged,
    this.onSubmitted,
    this.onClose,
  });

  final String keyword;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      key: const ValueKey<String>('chat-header-search-field'),
      initialValue: keyword,
      autofocus: true,
      textInputAction: TextInputAction.search,
      onChanged: onChanged,
      onFieldSubmitted: onSubmitted,
      decoration: InputDecoration(
        hintText: '搜索聊天记录',
        border: InputBorder.none,
        suffixIcon: IconButton(
          onPressed: onClose,
          icon: const Icon(Icons.close),
          tooltip: '关闭搜索',
        ),
      ),
    );
  }
}
