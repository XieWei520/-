import 'call_realtime_client.dart';
import 'call_realtime_client_factory_io.dart'
    if (dart.library.html) 'call_realtime_client_factory_web.dart'
    as platform;

CallRealtimeClient createPlatformCallRealtimeClient() {
  return platform.createPlatformCallRealtimeClient();
}
