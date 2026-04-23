/// Base endpoint entity
///
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
