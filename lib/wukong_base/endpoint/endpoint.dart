import 'endpoint_handler.dart';

/// Endpoint represents a single endpoint/menu item in the application.
/// 
/// Each endpoint has:
/// - [sid]: unique identifier for the endpoint
/// - [category]: category for grouping endpoints
/// - [sort]: sort order within the category
/// - [handler]: the handler to invoke when the endpoint is called
class Endpoint {
  /// Unique identifier for this endpoint
  final String sid;
  
  /// Category for grouping endpoints (e.g., 'chat', 'user', 'group')
  final String category;
  
  /// Sort order within the category (lower values appear first)
  final int sort;
  
  /// The handler that will be invoked when this endpoint is called
  final EndpointHandler handler;

  Endpoint({
    required this.sid,
    this.category = '',
    this.sort = 0,
    required this.handler,
  });

  @override
  String toString() => 'Endpoint(sid: $sid, category: $category, sort: $sort)';
}

/// Endpoint extensions for Dart-side functionality
extension EndpointExtension on Endpoint {
  /// Invoke this endpoint with the given parameter
  dynamic invoke([dynamic param]) {
    return handler.invoke(param);
  }
}
