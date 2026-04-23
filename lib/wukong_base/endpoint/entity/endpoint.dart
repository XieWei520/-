/// Callback interface for menu click events
typedef MenuClickCallback = void Function();

/// Endpoint base entity with common properties
class BaseEndpoint {
  /// Unique identifier for this endpoint
  final String sid;

  /// Image resource ID or path
  final String? imgResource;

  /// Display text
  final String? text;

  /// Click callback
  MenuClickCallback? onClick;

  BaseEndpoint({
    this.sid = '',
    this.imgResource,
    this.text,
    this.onClick,
  });

  @override
  String toString() => 'BaseEndpoint(sid: $sid, text: $text)';
}
