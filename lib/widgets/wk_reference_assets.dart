import 'package:flutter/widgets.dart';

class WKReferenceAssets {
  WKReferenceAssets._();

  static const String _iconRoot = 'assets/reference_ui/icons';

  static const String tabChatNormal = '$_iconRoot/ic_chat_n.png';
  static const String tabChatSelected = '$_iconRoot/ic_chat_s.png';
  static const String tabContactsNormal = '$_iconRoot/ic_contacts_n.png';
  static const String tabContactsSelected = '$_iconRoot/ic_contacts_s.png';
  static const String tabMineNormal = '$_iconRoot/ic_mine_n.png';
  static const String tabMineSelected = '$_iconRoot/ic_mine_s.png';
  static const String loginBackground = '$_iconRoot/icon_login_bg.png';
  static const String loginArrowBottom =
      '$_iconRoot/icon_login_arrow_bottom.png';
  static const String passwordVisible = '$_iconRoot/ic_password_visible.png';
  static const String passwordInvisible =
      '$_iconRoot/ic_password_invisible.png';

  static const String search = '$_iconRoot/ic_ab_search.png';
  static const String topMore = '$_iconRoot/ic_ab_more.png';
  static const String add = '$_iconRoot/msg_add.png';
  static const String menuChats = '$_iconRoot/menu_chats.png';
  static const String menuInvite = '$_iconRoot/menu_invite.png';
  static const String menuScan = '$_iconRoot/menu_scan.png';
  static const String back = '$_iconRoot/ic_ab_back.png';
  static const String device = '$_iconRoot/menu_devices.png';
  static const String qrCode = '$_iconRoot/msg_qrcode.png';
  static const String scanLarge = '$_iconRoot/icon_scan.png';
  static const String myBackground = '$_iconRoot/icon_my_bg.png';
  static const String setting = '$_iconRoot/icon_setting.png';
  static const String notice = '$_iconRoot/icon_notice.png';
  static const String webLogin = '$_iconRoot/icon_web_login.png';
  static const String favorites = '$_iconRoot/msg_fave.png';
  static const String moments = '$_iconRoot/msg_gallery.png';
  static const String privacy = '$_iconRoot/lock_close.png';
  static const String accountSecurity = '$_iconRoot/device_web_other.png';
  static const String tag = '$_iconRoot/icon_maillist.png';
  static const String customerService = '$_iconRoot/msg_contacts.png';
  static const String newFriend = '$_iconRoot/icon_new_friend.png';
  static const String savedGroups = '$_iconRoot/icon_groups.png';
  static const String mailList = '$_iconRoot/icon_maillist.png';
  static const String arrowRight = '$_iconRoot/ic_arrow_right.png';
  static const String groupTag = '$_iconRoot/list_group.png';
  static const String listMute = '$_iconRoot/list_mute.png';
  static const String forbidden = '$_iconRoot/icon_forbidden.png';
  static const String chatAdd = '$_iconRoot/icon_chat_add.png';
  static const String chatDelete = '$_iconRoot/icon_chat_delete.png';
  static const String male = '$_iconRoot/icon_male.png';
  static const String female = '$_iconRoot/icon_famale.png';
  static const String newVersion = '$_iconRoot/icon_new_version.png';
  static const String check = '$_iconRoot/msg_check.png';
  static const String logo = '$_iconRoot/ic_logo.png';
  static const String roundCheck = '$_iconRoot/round_check2.png';
  static const String calling = '$_iconRoot/calls_menu_phone.png';
  static const String chatCallVoice = '$_iconRoot/chat_calls_voice.png';
  static const String chatCallVideo = '$_iconRoot/chat_calls_video.png';
  static const String chatMenu = '$_iconRoot/icon_menu.png';
  static const String chatMenuClose = '$_iconRoot/icon_menu_close.png';
  static const String chatSend = '$_iconRoot/icon_chat_send.png';
  static const String chatToolbarVoice =
      '$_iconRoot/icon_chat_toolbar_voice.png';
  static const String chatToolbarEmoji =
      '$_iconRoot/icon_chat_toolbar_emoji.png';
  static const String chatToolbarAlbum =
      '$_iconRoot/icon_chat_toolbar_album.png';
  static const String chatToolbarMention =
      '$_iconRoot/icon_chat_toolbar_aite.png';
  static const String chatToolbarMore = '$_iconRoot/icon_chat_toolbar_more.png';
  static const String chatFunctionAlbum = '$_iconRoot/icon_func_album.png';
  static const String chatFunctionFile = '$_iconRoot/msg_message.png';
  static const String chatFunctionLocation = '$_iconRoot/msg_share.png';
  static const String chatFunctionCard = '$_iconRoot/icon_func_card.png';
  static const String chatReminder = '$_iconRoot/icon_remind.png';
  static const String chatRichEdit = '$_iconRoot/ic_a.png';
  static const String flameSmall = '$_iconRoot/flame_small.png';
  static const String camera = '$_iconRoot/msg_camera.png';
  static const String sendSingle = '$_iconRoot/msg_seen_signle.png';
  static const String sendDouble = '$_iconRoot/msg_seen.png';
  static const String sendFail = '$_iconRoot/icon_send_fail.png';

  static Image image(
    String asset, {
    double? width,
    double? height,
    Color? tint,
    BoxFit fit = BoxFit.contain,
  }) {
    return Image.asset(
      asset,
      width: width,
      height: height,
      fit: fit,
      filterQuality: FilterQuality.high,
      color: tint,
      colorBlendMode: tint == null ? null : BlendMode.srcIn,
    );
  }
}
