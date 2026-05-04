import 'entity/base_endpoint.dart';

/// Menu endpoint entity
class WKMenu extends WKEndpoint {
  final String title;
  final int order;
  final MenuClickCallback? onClick;

  WKMenu({
    required super.sid,
    required this.title,
    this.order = 0,
    this.onClick,
    super.type = 0,
  });
}
