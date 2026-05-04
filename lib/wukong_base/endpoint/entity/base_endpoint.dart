/// Base class for all endpoint menu entities.
class WKEndpoint {
  /// Endpoint identifier
  final String sid;

  /// Endpoint type
  final int type;

  WKEndpoint({
    required this.sid,
    this.type = 0,
  });

  /// Convert to map
  Map<String, dynamic> toMap() {
    return {
      'sid': sid,
      'type': type,
    };
  }
}

/// Menu click callback type
typedef MenuClickCallback = void Function(String sid);

/// Base class for menu endpoints with click handler
class BaseEndpoint extends WKEndpoint {
  final String? text;
  final String? imgResource;
  final MenuClickCallback? onClick;

  BaseEndpoint({
    required super.sid,
    super.type,
    this.text,
    this.imgResource,
    this.onClick,
  });
}
