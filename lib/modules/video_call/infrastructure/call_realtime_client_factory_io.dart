import 'call_realtime_client.dart';
import 'call_realtime_client_io.dart';

CallRealtimeClient createPlatformCallRealtimeClient() {
  return IoCallRealtimeClient();
}
