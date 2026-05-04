import 'base_endpoint.dart';

/// User detail menu
/// 
/// Used to navigate to user detail page
class UserDetailMenu extends BaseEndpoint {
  /// User ID
  final String uid;

  /// Group ID (optional)
  final String? groupId;

  UserDetailMenu({
    required this.uid,
    this.groupId,
    super.sid = 'show_user_detail_activity',
  });
}
