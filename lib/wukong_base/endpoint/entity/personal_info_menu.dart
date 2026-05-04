import 'base_endpoint.dart';

/// Used for personal center menu items
class PersonalInfoMenu extends BaseEndpoint {
  /// Whether to show new version indicator
  final bool isNewVersion;

  PersonalInfoMenu({
    required super.sid,
    super.imgResource,
    super.text,
    super.onClick,
    this.isNewVersion = false,
  });
}
