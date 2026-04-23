class AppRouteLocation {
  static const String root = '/';
  static const String boot = '/boot';
  static const String login = '/login';
  static const String register = '/auth/register';
  static const String resetPassword = '/auth/reset-password';
  static const String loginVerification = '/auth/login-verification';
  static const String loginVerificationCode = '/auth/login-verification/code';
  static const String profileCompletion = '/auth/profile-completion';
  static const String authThirdLogin = '/auth/third-login';
  static const String authDeviceSessions = '/auth/device-sessions';
  static const String authWebLoginConfirm = '/auth/web-login-confirm';
  static const String home = '/home';
  static const String chatBase = '/chat';
  static const String chatPath = '$chatBase/:channelType/:channelId';

  static String chat({
    required String channelId,
    required int channelType,
    String? channelName,
  }) {
    final encodedChannelId = Uri.encodeComponent(channelId);
    final location = '$chatBase/$channelType/$encodedChannelId';
    final normalizedName = channelName?.trim();
    if (normalizedName == null || normalizedName.isEmpty) {
      return location;
    }

    final query = Uri(
      queryParameters: <String, String>{'name': normalizedName},
    ).query;
    return '$location?$query';
  }
}
