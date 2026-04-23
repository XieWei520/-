import 'endpoint.dart';
import 'endpoint_handler.dart';

/// EndpointManager is the core of the application's plugin-based architecture.
///
/// It manages the registration and invocation of various endpoints (menus, actions, 
/// services) throughout the application. This is similar to Android's EndpointManager
/// and provides a decoupled way to call functionality across modules.
///
/// Usage:
/// ```dart
/// // Register an endpoint
/// EndpointManager.getInstance().register(
///   'send_text',
///   'chat_action',
///   0,
///   SendTextHandler(),
/// );
/// 
/// // Invoke an endpoint
/// EndpointManager.getInstance().invoke('send_text', messageContent);
/// 
/// // Invoke all endpoints in a category
/// List results = EndpointManager.getInstance().invokes('chat_action', param);
/// ```
class EndpointManager {
  EndpointManager._();
  static final EndpointManager _instance = EndpointManager._();
  static EndpointManager getInstance() => _instance;

  /// Internal storage for registered endpoints
  final Map<String, List<Endpoint>> _endpointList = {};

  /// Register a method/endpoint with optional category and sort order
  /// 
  /// [sid] - Unique identifier for the endpoint
  /// [category] - Optional category for grouping (defaults to '')
  /// [sort] - Optional sort order within the category (defaults to 0)
  /// [handler] - The handler to invoke
  void setMethod(String sid, [String category = '', int sort = 0, EndpointHandler? handler]) {
    if (handler != null) {
      register(sid, category, sort, handler);
    }
  }

  /// Internal register method
  void register(String sid, String category, int sort, EndpointHandler handler) {
    List<Endpoint> endpoints = _endpointList[category] ?? [];
    endpoints.add(Endpoint(sid: sid, category: category, sort: sort, handler: handler));
    _endpointList[category] = endpoints;
    handler.onRegistered();
  }

  /// Remove an endpoint by its sid
  void remove(String sid) {
    for (String category in _endpointList.keys) {
      List<Endpoint> list = _endpointList[category]!;
      if (list.isNotEmpty) {
        for (int i = list.length - 1; i >= 0; i--) {
          if (list[i].sid == sid) {
            list[i].handler.onUnregistered();
            list.removeAt(i);
            break;
          }
        }
        if (list.isEmpty) {
          _endpointList.remove(category);
        } else {
          _endpointList[category] = list;
        }
      }
    }
  }

  /// Invoke a single endpoint by its sid
  /// 
  /// [sid] - The endpoint identifier
  /// [param] - Optional parameter to pass to the handler
  /// Returns the result from the handler, or null if not found
  dynamic invoke(String sid, [dynamic param]) {
    for (String category in _endpointList.keys) {
      List<Endpoint> list = _endpointList[category]!;
      if (list.isNotEmpty) {
        for (int i = list.length - 1; i >= 0; i--) {
          if (list[i].sid == sid) {
            return list[i].handler.invoke(param);
          }
        }
      }
    }
    return null;
  }

  /// Invoke all endpoints in a category
  /// 
  /// [category] - The category of endpoints to invoke
  /// [param] - Optional parameter to pass to all handlers
  /// Returns a list of results from all handlers in the category
  List<dynamic> invokes(String category, [dynamic param]) {
    if (!_endpointList.containsKey(category)) return [];
    
    List<Endpoint> tempList = List.from(_endpointList[category]!);
    tempList.sort((a, b) => a.sort.compareTo(b.sort));
    
    List<dynamic> results = [];
    for (Endpoint endpoint in tempList) {
      dynamic result = endpoint.handler.invoke(param);
      if (result != null) {
        results.add(result);
      }
    }
    return results;
  }

  /// Get all endpoints in a category
  List<Endpoint> getEndpoints(String category) {
    return _endpointList[category] ?? [];
  }

  /// Get all registered categories
  Set<String> get categories => _endpointList.keys.toSet();

  /// Check if an endpoint exists
  bool hasEndpoint(String sid) {
    for (String category in _endpointList.keys) {
      List<Endpoint> list = _endpointList[category]!;
      for (Endpoint endpoint in list) {
        if (endpoint.sid == sid) return true;
      }
    }
    return false;
  }

  /// Clear all endpoints (useful for testing)
  void clear() {
    _endpointList.clear();
  }
}
