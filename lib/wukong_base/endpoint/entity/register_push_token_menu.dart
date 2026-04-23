/// Register push token menu
/// 
/// Used for registering device push token
class RegisterPushTokenMenu {
  /// Push token
  final String token;

  /// Push type (FCM, HMS, MI, OPPO, VIVO)
  final String pushType;

  RegisterPushTokenMenu({
    required this.token,
    required this.pushType,
  });
}
