import '../proto/proto.dart';

class Options {
  String? uid, token;
  String? addr; // connect address IP:PORT
  String? deviceID;
  int protoVersion = 0x04; // protocol version
  int deviceFlag = 0;
  bool debug = true;
  Duration expireMsgCheckInterval = const Duration(seconds: 10);
  int expireMsgLimit = 50;
  Function(Function(String addr) complete)?
      getAddr; // async get connect address
  Proto proto = Proto();
  Options();

  Options.newDefault(this.uid, this.token, {this.addr});
}
