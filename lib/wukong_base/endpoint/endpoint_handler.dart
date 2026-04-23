/// EndpointHandler is the interface for handling endpoint invocations.
/// 
/// Each endpoint has a handler that processes the invocation and returns a result.
/// This follows a similar pattern to Android's EndpointHandler interface.
abstract class EndpointHandler {
  /// Invoke this handler with the given parameter
  /// 
  /// [param] - The parameter passed when invoking this endpoint
  /// Returns the result of handling the invocation, or null if no result
  dynamic invoke([dynamic param]);

  /// Called when the endpoint is registered
  void onRegistered() {}

  /// Called when the endpoint is unregistered
  void onUnregistered() {}
}

/// SimpleFunctionHandler is a handler that wraps a simple function.
class SimpleFunctionHandler extends EndpointHandler {
  final dynamic Function([dynamic]) _function;

  SimpleFunctionHandler(this._function);

  @override
  dynamic invoke([dynamic param]) => _function(param);
}

/// AsyncFunctionHandler is a handler that wraps an async function.
class AsyncFunctionHandler extends EndpointHandler {
  final Future<dynamic> Function([dynamic]) _function;

  AsyncFunctionHandler(this._function);

  @override
  Future<dynamic> invoke([dynamic param]) => _function(param);
}

/// VoidFunctionHandler is a handler that wraps a void function.
class VoidFunctionHandler extends EndpointHandler {
  final void Function([dynamic]) _function;

  VoidFunctionHandler(this._function);

  @override
  dynamic invoke([dynamic param]) {
    _function(param);
    return null;
  }
}
