import 'base_endpoint.dart';

/// Contacts menu
/// 
/// Used for contacts tab menu items
class ContactsMenu extends BaseEndpoint {
  /// Badge number to display
  final int badgeNum;

  /// Whether to show red dot
  final bool showRedDot;

  /// User ID
  final String? uid;

  ContactsMenu({
    required super.sid,
    super.imgResource,
    super.text,
    super.onClick,
    this.badgeNum = 0,
    this.showRedDot = false,
    this.uid,
  });
}
