import 'call_realtime_client.dart';
import 'call_realtime_client_web.dart';

CallRealtimeClient createPlatformCallRealtimeClient() {
  return WebCallRealtimeClient();
}
