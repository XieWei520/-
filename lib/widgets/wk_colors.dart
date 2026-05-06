import 'package:flutter/material.dart';

/// Unified semantic color tokens for the app.
class WKColors {
  WKColors._();

  // Brand
  static const Color brand50 = Color(0x22F65835);
  static const Color brand100 = Color(0x95F65835);
  static const Color brand200 = Color(0x33F65835);
  static const Color brand300 = Color(0x66F65835);
  static const Color brand400 = Color(0x88F65835);
  static const Color brand500 = Color(0xFFF65835);
  static const Color brand600 = Color(0xFFF8937B);
  static const Color brand700 = Color(0xFFB84D34);

  // Accent / state
  static const Color info = Color(0xFF2196F3);
  static const Color success = Color(0xFFF65835);
  static const Color warning = Color(0xFFF59E0B);
  static const Color danger = Color(0xFFF80303);
  static const Color badge = Color(0xFFFF5353);

  // Neutral
  static const Color white = Color(0xFFFFFFFF);
  static const Color black = Color(0xFF000000);
  static const Color pageBackground = Color(0xFFF6F6F6);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceSoft = Color(0xFFF5F5F5);
  static const Color surfaceMuted = Color(0xFFF3F3F3);
  static const Color surfaceStrong = Color(0xFFE8E7E7);
  static const Color textPrimary = Color(0xFF313131);
  static const Color textSecondary = Color(0xFF999999);
  static const Color textTertiary = Color(0xFFB6B5B5);
  static const Color outline = Color(0xFFCCCCCC);
  static const Color outlineStrong = Color(0xFFB6B5B5);
  static const Color shadow = Color(0x2A000000);

  // Web B warm social theme
  static const Color webPageWarm = Color(0xFFFFF4E6);
  static const Color webSurfaceSoft = Color(0xFFFFF0E1);
  static const Color webBorderWarm = Color(0xFFFDBA74);
  static const Color webAction = Color(0xFFC2410C);
  static const Color webActionSoft = Color(0xFFFFD8B0);
  static const Color webOnline = Color(0xFF0D9488);
  static const Color webTextPrimary = Color(0xFF172033);
  static const Color webTextSecondary = Color(0xFF475569);

  // Chat
  static const Color chatOutgoing = Color(0xFFFDDED6);
  static const Color chatOutgoingPressed = Color(0xFFF8937B);
  static const Color chatIncoming = surface;
  static const Color chatIncomingPressed = Color(0xFFCCCCCC);

  // Backward-compatible aliases
  static const Color primary = brand500;
  static const Color primaryLight = brand100;
  static const Color primaryDisabled = textTertiary;

  static const Color screenBg = surface;
  static const Color screenBgSelected = surfaceMuted;
  static const Color homeBg = pageBackground;
  static const Color homeBgSelected = surfaceMuted;
  static const Color layoutColor = surface;
  static const Color layoutColorSelected = surfaceStrong;

  static const Color colorDark = textPrimary;
  static const Color color999 = textSecondary;
  static const Color colorCCC = outlineStrong;
  static const Color popupText = textSecondary;
  static const Color dialogText = textSecondary;
  static const Color sendText = white;
  static const Color receiveText = textPrimary;

  static const Color colorLine = outline;
  static const Color borderColor = outline;
  static const Color chatBorderColor = outlineStrong;

  static const Color chatReceivedBg = chatIncoming;
  static const Color chatReceivedBgSelected = chatIncomingPressed;
  static const Color chatSendBg = chatOutgoing;
  static const Color chatSendBgSelected = chatOutgoingPressed;
  static const Color chatSendBgNormal = chatOutgoing;

  static const Color transparent = Color(0x00000000);
  static const Color red = danger;
  static const Color reminderColor = badge;
  static const Color redDisable = Color(0xFFF3A5AA);
  static const Color blue = info;
  static const Color gary = surfaceMuted;
  static const Color colorF5F5F5 = surfaceSoft;
  static const Color colorE8E7E7 = surfaceStrong;
  static const Color colorB6B5B5 = outlineStrong;
  static const Color colord8d5d5 = outlineStrong;

  static const Color systemBg = Color(0x26000000);
  static const Color defaultShadow = shadow;
  static const Color defaultShadowBack = white;

  static const Color bottomDrawerOutsideBg = Color(0x80000000);
  static const Color bottomDrawerBg = surface;
  static const Color bottomDrawerHandle = Color(0xFFD9DEE7);

  static const Color titleBarIcon = textSecondary;
  static const Color tipMessageCellBg = Color(0xCCF8FAFD);

  static const List<Color> nameColors = [
    Color(0xFF8C8DFF),
    Color(0xFF7983C2),
    Color(0xFF6D8DDE),
    Color(0xFF5979F0),
    Color(0xFF6695DF),
    Color(0xFF8F7AC5),
    Color(0xFF9D77A5),
    Color(0xFF8A64D0),
    Color(0xFFAA66C3),
    Color(0xFFA75C96),
    Color(0xFFC8697D),
    Color(0xFFB74D62),
    Color(0xFFBD637C),
    Color(0xFFB3798E),
    Color(0xFF9B6D77),
    Color(0xFFB87F7F),
    Color(0xFFC5595A),
    Color(0xFFAA4848),
    Color(0xFFB0665E),
    Color(0xFFB76753),
    Color(0xFFBB5334),
    Color(0xFFC97B46),
    Color(0xFFBE6C2C),
    Color(0xFFCB7F40),
    Color(0xFFA47758),
    Color(0xFFB69370),
    Color(0xFFA49373),
    Color(0xFFAA8A46),
    Color(0xFFAA8220),
    Color(0xFF76A048),
    Color(0xFF9CAD23),
    Color(0xFFA19431),
    Color(0xFFAA9100),
    Color(0xFFA09555),
    Color(0xFFC49B4B),
    Color(0xFF5FB05F),
    Color(0xFF6AB48F),
    Color(0xFF71B15C),
    Color(0xFFB3B357),
    Color(0xFFA3B561),
    Color(0xFF909F45),
    Color(0xFF93B289),
    Color(0xFF3D98D0),
    Color(0xFF429AB6),
    Color(0xFF4EABAA),
    Color(0xFF6BC0CE),
    Color(0xFF64B5D9),
    Color(0xFF3E9CCB),
    Color(0xFF2887C4),
    Color(0xFF52A98B),
  ];

  static Color getNameColor(int index) {
    return nameColors[index % nameColors.length];
  }

  static Color getNameColorFromString(String name) {
    if (name.isEmpty) return nameColors[0];
    var hash = name.hashCode;
    if (hash < 0) {
      hash = -hash;
    }
    return nameColors[hash % nameColors.length];
  }
}
