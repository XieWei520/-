abstract class SessionSocket {
  Stream<Object?> get stream;

  Future<void> ready();

  Future<void> close([int? code, String? reason]);
}

typedef SessionSocketConnector =
    SessionSocket Function(Uri uri, {Map<String, String>? headers});
