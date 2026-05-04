# IM Route Preferred WSS Contract Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Formalize `/v1/users/{uid}/im` as a stable multi-transport contract
and make the Flutter client truly prefer `wss_addr` by adding structured route
selection in the app plus `ws/wss` transport support in the local IM SDK.

**Architecture:** The Go server stops proxying the upstream route payload as an
untyped map and instead returns a normalized response with explicit
`preferred_transport` and `preferred_addr` fields. The Flutter app parses that
payload into a dedicated route model, while the local WuKongIM Flutter SDK adds
a focused transport abstraction so TCP, WS, and WSS all feed the same packet,
heartbeat, reconnect, and ACK pipeline.

**Tech Stack:** Go, Gin, Swagger 2.0, Flutter, Dart, `dart:io` `Socket` and
`WebSocket`, `go test`, `flutter test`

---

## File Structure And Ownership

- Create: `/opt/wukongim-prod/src/modules/user/im_route_contract.go`
  Responsibility: define the public IM route response schema, normalize
  upstream fields, and derive the preferred transport
- Create: `/opt/wukongim-prod/src/modules/user/api_im_route_test.go`
  Responsibility: cover route normalization and `/v1/users/{uid}/im` handler
  behavior
- Modify: `/opt/wukongim-prod/src/modules/user/api.go`
  Responsibility: replace raw upstream pass-through with explicit response
  shaping
- Modify: `/opt/wukongim-prod/src/modules/user/swagger/api.yaml`
  Responsibility: document the formal route response schema

- Create: `C:\Users\COLORFUL\Desktop\TangSengDaoDao\WuKongIMFlutterSDK-master\lib\manager\connection_transport.dart`
  Responsibility: parse connection targets and abstract TCP vs WS/WSS byte
  transports
- Modify: `C:\Users\COLORFUL\Desktop\TangSengDaoDao\WuKongIMFlutterSDK-master\lib\manager\connect_manager.dart`
  Responsibility: switch the SDK connection layer from socket-only to
  transport-aware while preserving packet logic
- Create: `C:\Users\COLORFUL\Desktop\TangSengDaoDao\WuKongIMFlutterSDK-master\test\transport\connection_transport_test.dart`
  Responsibility: cover transport parsing and websocket byte-frame handling

- Create: `C:\Users\COLORFUL\Desktop\WuKong\lib\service\api\im_route_info.dart`
  Responsibility: parse, validate, and resolve preferred IM route data in the
  Flutter app
- Modify: `C:\Users\COLORFUL\Desktop\WuKong\lib\service\api\im_sync_api.dart`
  Responsibility: fetch `/v1/users/{uid}/im` into `ImRouteInfo`
- Modify: `C:\Users\COLORFUL\Desktop\WuKong\lib\service\im\im_service.dart`
  Responsibility: choose the best route and pass the selected address to the
  SDK
- Create: `C:\Users\COLORFUL\Desktop\WuKong\test\service\api\im_route_info_test.dart`
  Responsibility: cover route validation and fallback order
- Modify: `C:\Users\COLORFUL\Desktop\WuKong\test\service\api\im_sync_api_test.dart`
  Responsibility: cover HTTP parsing of the formal route contract
- Modify: `C:\Users\COLORFUL\Desktop\WuKong\test\service\im\im_service_test.dart`
  Responsibility: cover app-side route selection integration

## Task 1: Formalize The Server Route Contract

**Files:**
- Create: `/opt/wukongim-prod/src/modules/user/im_route_contract.go`
- Create: `/opt/wukongim-prod/src/modules/user/api_im_route_test.go`
- Modify: `/opt/wukongim-prod/src/modules/user/api.go`
- Modify: `/opt/wukongim-prod/src/modules/user/swagger/api.yaml`

- [ ] **Step 1: Back up the remote server files before editing**

Run:

```bash
ssh ubuntu@42.194.218.158 "cd /opt/wukongim-prod/src/modules/user && ts=\$(date +%Y%m%d%H%M%S) && cp api.go api.go.bak.\$ts && cp swagger/api.yaml swagger/api.yaml.bak.\$ts && printf '%s\n' \$ts"
```

Expected:
- Prints one timestamp such as `20260423143015`
- Leaves `api.go.bak.<timestamp>` and `swagger/api.yaml.bak.<timestamp>` on the
  server before any code edit

- [ ] **Step 2: Write the failing Go tests first**

Create `/opt/wukongim-prod/src/modules/user/api_im_route_test.go` with:

```go
package user

import (
	"net/http"
	"net/http/httptest"
	"testing"

	"github.com/TangSengDaoDao/TangSengDaoDaoServerLib/testutil"
	"github.com/stretchr/testify/assert"
)

func TestBuildIMRouteResponse_PrefersWSS(t *testing.T) {
	route := buildIMRouteResponse(map[string]interface{}{
		"tcp_addr": "wemx.cc:5100",
		"ws_addr":  "ws://wemx.cc:5200",
		"wss_addr": "wss://wemx.cc/ws",
	})

	assert.Equal(t, imRouteResponse{
		TCPAddr:            "wemx.cc:5100",
		WSAddr:             "ws://wemx.cc:5200",
		WSSAddr:            "wss://wemx.cc/ws",
		PreferredTransport: "wss",
		PreferredAddr:      "wss://wemx.cc/ws",
	}, route)
}

func TestBuildIMRouteResponse_FallsBackToTCPWhenOnlyTCPIsValid(t *testing.T) {
	route := buildIMRouteResponse(map[string]interface{}{
		"tcp_addr": "wemx.cc:5100",
		"ws_addr":  "http://wemx.cc:5200",
		"wss_addr": "wss://",
	})

	assert.Equal(t, imRouteResponse{
		TCPAddr:            "wemx.cc:5100",
		WSAddr:             "",
		WSSAddr:            "",
		PreferredTransport: "tcp",
		PreferredAddr:      "wemx.cc:5100",
	}, route)
}

func TestUserIM_ReturnsFormalContract(t *testing.T) {
	s, ctx := testutil.NewTestServer()

	upstream := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		assert.Equal(t, "/route", r.URL.Path)
		assert.Equal(t, "u_self", r.URL.Query().Get("uid"))
		w.Header().Set("Content-Type", "application/json")
		_, _ = w.Write([]byte(`{"tcp_addr":"wemx.cc:5100","ws_addr":"ws://wemx.cc:5200","wss_addr":"wss://wemx.cc/ws"}`))
	}))
	defer upstream.Close()

	ctx.GetConfig().WuKongIM.APIURL = upstream.URL

	w := httptest.NewRecorder()
	req, _ := http.NewRequest(http.MethodGet, "/v1/users/u_self/im", nil)
	s.GetRoute().ServeHTTP(w, req)

	assert.Equal(t, http.StatusOK, w.Code)
	assert.JSONEq(t, `{
		"tcp_addr":"wemx.cc:5100",
		"ws_addr":"ws://wemx.cc:5200",
		"wss_addr":"wss://wemx.cc/ws",
		"preferred_transport":"wss",
		"preferred_addr":"wss://wemx.cc/ws"
	}`, w.Body.String())
}
```

- [ ] **Step 3: Run the targeted Go tests and verify they fail**

Run:

```bash
ssh ubuntu@42.194.218.158 "cd /opt/wukongim-prod/src && go test ./modules/user -run 'TestBuildIMRouteResponse|TestUserIM_ReturnsFormalContract' -count=1"
```

Expected:
- Fails with undefined identifiers such as `buildIMRouteResponse` and
  `imRouteResponse`

- [ ] **Step 4: Implement the route normalizer and use it in the handler**

Create `/opt/wukongim-prod/src/modules/user/im_route_contract.go` with:

```go
package user

import (
	"fmt"
	"net"
	"net/url"
	"strconv"
	"strings"
)

type imRouteResponse struct {
	TCPAddr            string `json:"tcp_addr"`
	WSAddr             string `json:"ws_addr"`
	WSSAddr            string `json:"wss_addr"`
	PreferredTransport string `json:"preferred_transport"`
	PreferredAddr      string `json:"preferred_addr"`
}

func buildIMRouteResponse(raw map[string]interface{}) imRouteResponse {
	resp := imRouteResponse{
		TCPAddr: normalizeTCPAddr(raw["tcp_addr"]),
		WSAddr:  normalizeWebSocketAddr(raw["ws_addr"], "ws"),
		WSSAddr: normalizeWebSocketAddr(raw["wss_addr"], "wss"),
	}

	switch {
	case resp.WSSAddr != "":
		resp.PreferredTransport = "wss"
		resp.PreferredAddr = resp.WSSAddr
	case resp.WSAddr != "":
		resp.PreferredTransport = "ws"
		resp.PreferredAddr = resp.WSAddr
	case resp.TCPAddr != "":
		resp.PreferredTransport = "tcp"
		resp.PreferredAddr = resp.TCPAddr
	}

	return resp
}

func normalizeTCPAddr(value interface{}) string {
	raw := toRouteString(value)
	if raw == "" {
		return ""
	}
	host, port, err := net.SplitHostPort(raw)
	if err != nil || strings.TrimSpace(host) == "" {
		return ""
	}
	portNum, err := strconv.Atoi(port)
	if err != nil || portNum <= 0 {
		return ""
	}
	return net.JoinHostPort(host, strconv.Itoa(portNum))
}

func normalizeWebSocketAddr(value interface{}, expectedScheme string) string {
	raw := toRouteString(value)
	if raw == "" {
		return ""
	}
	parsed, err := url.Parse(raw)
	if err != nil {
		return ""
	}
	if parsed.Scheme != expectedScheme || strings.TrimSpace(parsed.Host) == "" {
		return ""
	}
	return parsed.String()
}

func toRouteString(value interface{}) string {
	if value == nil {
		return ""
	}
	return strings.TrimSpace(fmt.Sprint(value))
}
```

Update `/opt/wukongim-prod/src/modules/user/api.go` so `userIM()` ends with:

```go
func (u *User) userIM(c *wkhttp.Context) {
	uid := c.Param("uid")
	resp, err := network.Get(fmt.Sprintf("%s/route?uid=%s", u.ctx.GetConfig().WuKongIM.APIURL, uid), nil, nil)
	if err != nil {
		u.Error("IM route request failed", zap.Error(err))
		c.ResponseError(errors.New("IM route request failed"))
		return
	}

	var resultMap map[string]interface{}
	err = util.ReadJsonByByte([]byte(resp.Body), &resultMap)
	if err != nil {
		c.ResponseError(err)
		return
	}

	c.JSON(resp.StatusCode, buildIMRouteResponse(resultMap))
}
```

- [ ] **Step 5: Document the response schema in swagger**

Replace the existing `/users/{uid}/im` `200` response in
`/opt/wukongim-prod/src/modules/user/swagger/api.yaml` with:

```yaml
  /users/{uid}/im:
    get:
      tags:
        - "user"
      summary: "Get the IM route for a user"
      description: "Get the IM route for a user"
      operationId: "uid im"
      consumes:
        - "application/json"
      produces:
        - "application/json"
      parameters:
        - in: "path"
          name: "uid"
          type: string
          description: "User ID"
          required: true
      responses:
        200:
          description: "Success"
          schema:
            $ref: "#/definitions/imRouteResponse"
        400:
          description: "Error"
          schema:
            $ref: "#/definitions/response"
```

Add this definition under `definitions:` in the same file:

```yaml
  imRouteResponse:
    type: object
    required:
      - tcp_addr
      - ws_addr
      - wss_addr
      - preferred_transport
      - preferred_addr
    properties:
      tcp_addr:
        type: string
        description: "TCP connect address in host:port format"
      ws_addr:
        type: string
        description: "Cleartext WebSocket address"
      wss_addr:
        type: string
        description: "TLS WebSocket address"
      preferred_transport:
        type: string
        description: "Recommended transport: wss, ws, or tcp"
      preferred_addr:
        type: string
        description: "Recommended address matching preferred_transport"
```

- [ ] **Step 6: Re-run the targeted server tests and commit the remote source**

Run:

```bash
ssh ubuntu@42.194.218.158 "cd /opt/wukongim-prod/src && go test ./modules/user -run 'TestBuildIMRouteResponse|TestUserIM_ReturnsFormalContract' -count=1"
```

Expected:
- Targeted `go test` passes

Commit:

```bash
ssh ubuntu@42.194.218.158 "cd /opt/wukongim-prod/src && git add modules/user/api.go modules/user/im_route_contract.go modules/user/api_im_route_test.go modules/user/swagger/api.yaml && git commit -m 'feat: formalize IM route contract'"
```

## Task 2: Add TCP, WS, And WSS Transport Support To The Local SDK

**Files:**
- Create: `C:\Users\COLORFUL\Desktop\TangSengDaoDao\WuKongIMFlutterSDK-master\lib\manager\connection_transport.dart`
- Modify: `C:\Users\COLORFUL\Desktop\TangSengDaoDao\WuKongIMFlutterSDK-master\lib\manager\connect_manager.dart`
- Create: `C:\Users\COLORFUL\Desktop\TangSengDaoDao\WuKongIMFlutterSDK-master\test\transport\connection_transport_test.dart`

- [ ] **Step 1: Write the failing SDK transport tests first**

Create `C:\Users\COLORFUL\Desktop\TangSengDaoDao\WuKongIMFlutterSDK-master\test\transport\connection_transport_test.dart` with:

```dart
import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:wukongimfluttersdk/manager/connection_transport.dart';

void main() {
  test('parseConnectTarget reads host:port as tcp', () {
    final target = WKConnectTarget.parse('wemx.cc:5100');

    expect(target, isNotNull);
    expect(target!.kind, WKTransportKind.tcp);
    expect(target.host, 'wemx.cc');
    expect(target.port, 5100);
  });

  test('parseConnectTarget reads wss uri as secure websocket', () {
    final target = WKConnectTarget.parse('wss://wemx.cc/ws');

    expect(target, isNotNull);
    expect(target!.kind, WKTransportKind.wss);
    expect(target.uri!.toString(), 'wss://wemx.cc/ws');
  });

  test('parseConnectTarget rejects malformed websocket uri', () {
    expect(WKConnectTarget.parse('wss://'), isNull);
    expect(WKConnectTarget.parse('http://wemx.cc/ws'), isNull);
  });

  test('connectWKTransport receives binary websocket frames', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => server.close(force: true));

    server.listen((request) async {
      if (request.uri.path != '/ws') {
        request.response.statusCode = HttpStatus.notFound;
        await request.response.close();
        return;
      }
      final socket = await WebSocketTransformer.upgrade(request);
      socket.add(Uint8List.fromList(const <int>[1, 2, 3]));
    });

    final target = WKConnectTarget.parse(
      'ws://127.0.0.1:${server.port}/ws',
    )!;
    final transport = await connectWKTransport(target);
    final completer = Completer<Uint8List>();

    transport.listen(
      (data) => completer.complete(data),
      onError: (_) {},
      onDone: () {},
    );

    expect(
      await completer.future.timeout(const Duration(seconds: 2)),
      Uint8List.fromList(const <int>[1, 2, 3]),
    );
  });
}
```

- [ ] **Step 2: Run the SDK tests and verify they fail**

Run:

```powershell
flutter test .\test\transport\connection_transport_test.dart
```

Working directory:

```text
C:\Users\COLORFUL\Desktop\TangSengDaoDao\WuKongIMFlutterSDK-master
```

Expected:
- Fails because `connection_transport.dart`, `WKConnectTarget`, and
  `connectWKTransport` do not exist yet

- [ ] **Step 3: Add the transport parser and transport connection abstraction**

Create `C:\Users\COLORFUL\Desktop\TangSengDaoDao\WuKongIMFlutterSDK-master\lib\manager\connection_transport.dart` with:

```dart
import 'dart:io';
import 'dart:typed_data';

enum WKTransportKind { tcp, ws, wss }

class WKConnectTarget {
  const WKConnectTarget._({
    required this.kind,
    required this.host,
    this.port,
    this.uri,
  });

  final WKTransportKind kind;
  final String host;
  final int? port;
  final Uri? uri;

  static WKConnectTarget? parse(String raw) {
    final normalized = raw.trim();
    if (normalized.isEmpty) {
      return null;
    }

    final parsedUri = Uri.tryParse(normalized);
    if (parsedUri != null &&
        (parsedUri.scheme == 'ws' || parsedUri.scheme == 'wss') &&
        parsedUri.host.trim().isNotEmpty) {
      return WKConnectTarget._(
        kind: parsedUri.scheme == 'wss'
            ? WKTransportKind.wss
            : WKTransportKind.ws,
        host: parsedUri.host,
        port: parsedUri.hasPort ? parsedUri.port : null,
        uri: parsedUri,
      );
    }

    final separator = normalized.lastIndexOf(':');
    if (separator <= 0 || separator >= normalized.length - 1) {
      return null;
    }
    final host = normalized.substring(0, separator).trim();
    final port = int.tryParse(normalized.substring(separator + 1).trim());
    if (host.isEmpty || port == null || port <= 0) {
      return null;
    }

    return WKConnectTarget._(
      kind: WKTransportKind.tcp,
      host: host,
      port: port,
    );
  }
}

abstract class WKTransportConnection {
  void listen(
    void Function(Uint8List data) onData, {
    required void Function(Object error) onError,
    required void Function() onDone,
  });

  Future<void> send(Uint8List data);
  Future<void> close();
}

class WKSocketConnection implements WKTransportConnection {
  WKSocketConnection(this._socket);

  final Socket _socket;

  @override
  void listen(
    void Function(Uint8List data) onData, {
    required void Function(Object error) onError,
    required void Function() onDone,
  }) {
    _socket.listen(
      onData,
      onError: onError,
      onDone: onDone,
      cancelOnError: true,
    );
  }

  @override
  Future<void> send(Uint8List data) async {
    _socket.add(data);
    await _socket.flush();
  }

  @override
  Future<void> close() async {
    await _socket.close();
  }
}

class WKWebSocketConnection implements WKTransportConnection {
  WKWebSocketConnection(this._socket);

  final WebSocket _socket;

  @override
  void listen(
    void Function(Uint8List data) onData, {
    required void Function(Object error) onError,
    required void Function() onDone,
  }) {
    _socket.listen((event) {
      if (event is Uint8List) {
        onData(event);
        return;
      }
      if (event is List<int>) {
        onData(Uint8List.fromList(event));
      }
    }, onError: onError, onDone: onDone, cancelOnError: true);
  }

  @override
  Future<void> send(Uint8List data) async {
    _socket.add(data);
  }

  @override
  Future<void> close() async {
    await _socket.close();
  }
}

Future<WKTransportConnection> connectWKTransport(
  WKConnectTarget target, {
  Duration timeout = const Duration(seconds: 5),
}) async {
  switch (target.kind) {
    case WKTransportKind.tcp:
      final socket = await Socket.connect(
        target.host,
        target.port!,
        timeout: timeout,
      );
      return WKSocketConnection(socket);
    case WKTransportKind.ws:
    case WKTransportKind.wss:
      final socket = await WebSocket.connect(
        target.uri.toString(),
      ).timeout(timeout);
      return WKWebSocketConnection(socket);
  }
}
```

- [ ] **Step 4: Switch the SDK connection manager to the new transport abstraction**

Update `C:\Users\COLORFUL\Desktop\TangSengDaoDao\WuKongIMFlutterSDK-master\lib\manager\connect_manager.dart` so the transport-specific pieces become:

```dart
import 'connection_transport.dart';

class WKConnectionManager {
  WKTransportConnection? _transport;

  connect() {
    final addr = WKIM.shared.options.addr;
    if ((addr == null || addr == '') && WKIM.shared.options.getAddr == null) {
      Logs.info('no IM connect address configured');
      return;
    }
    if (WKIM.shared.options.uid == '' ||
        WKIM.shared.options.uid == null ||
        WKIM.shared.options.token == '' ||
        WKIM.shared.options.token == null) {
      Logs.error('missing uid or token');
      return;
    }
    if (isNetworkUnavailable) {
      return;
    }

    disconnect(false);
    isDisconnection = false;

    if (WKIM.shared.options.getAddr != null) {
      WKIM.shared.options.getAddr!((String resolvedAddr) {
        _connectToTarget(resolvedAddr);
      });
    } else {
      _connectToTarget(addr!);
    }
  }

  Future<void> _connectToTarget(String addr) async {
    final target = WKConnectTarget.parse(addr);
    if (target == null) {
      _connectFail(StateError('invalid connect address: $addr'));
      return;
    }

    try {
      setConnectionStatus(WKConnectStatus.connecting);
      _transport = await connectWKTransport(target);
      _connectSuccess();
    } catch (error) {
      _connectFail(error);
    }
  }

  _connectSuccess() {
    _transport?.listen(
      (Uint8List data) {
        _cutDatas(data);
      },
      onError: (Object error) {
        if (!isDisconnection) {
          _scheduleReconnect();
        }
      },
      onDone: () {
        if (!isDisconnection) {
          _scheduleReconnect();
        }
      },
    );
    _sendConnectPacket();
  }

  disconnect(bool isLogout) {
    isDisconnection = true;
    unawaited(_transport?.close());
    _transport = null;
    if (isLogout) {
      WKIM.shared.options.uid = '';
      WKIM.shared.options.token = '';
      WKIM.shared.messageManager.updateSendingMsgFail();
      WKDBHelper.shared.close();
    }
    _closeAll();
    WKIM.shared.connectionManager.setConnectionStatus(WKConnectStatus.fail);
  }

  _closeAll() {
    _stopCheckNetworkTimer();
    _stopHeartTimer();
    _packetBuffer.clear();
    unawaited(_transport?.close());
    _transport = null;
  }

  _sendPacket(Packet packet) async {
    final data = WKIM.shared.options.proto.encode(packet);
    if (!isReconnection) {
      await _transport?.send(data);
    }
  }
}
```

- [ ] **Step 5: Re-run the SDK tests and commit the SDK changes**

Run:

```powershell
flutter test .\test\transport\connection_transport_test.dart .\test\db\message_identity_test.dart
```

Working directory:

```text
C:\Users\COLORFUL\Desktop\TangSengDaoDao\WuKongIMFlutterSDK-master
```

Expected:
- Both targeted SDK tests pass

Commit:

```powershell
git add .\lib\manager\connection_transport.dart .\lib\manager\connect_manager.dart .\test\transport\connection_transport_test.dart
git commit -m "feat: add websocket IM transport support"
```

## Task 3: Parse And Use The Formal Route Contract In Flutter

**Files:**
- Create: `C:\Users\COLORFUL\Desktop\WuKong\lib\service\api\im_route_info.dart`
- Modify: `C:\Users\COLORFUL\Desktop\WuKong\lib\service\api\im_sync_api.dart`
- Modify: `C:\Users\COLORFUL\Desktop\WuKong\lib\service\im\im_service.dart`
- Create: `C:\Users\COLORFUL\Desktop\WuKong\test\service\api\im_route_info_test.dart`
- Modify: `C:\Users\COLORFUL\Desktop\WuKong\test\service\api\im_sync_api_test.dart`
- Modify: `C:\Users\COLORFUL\Desktop\WuKong\test\service\im\im_service_test.dart`

- [ ] **Step 1: Write the failing Flutter tests first**

Create `C:\Users\COLORFUL\Desktop\WuKong\test\service\api\im_route_info_test.dart` with:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:wukong_im_app/service/api/im_route_info.dart';

void main() {
  test('resolvePreferredAddr prefers preferred_addr when valid', () {
    final route = ImRouteInfo(
      tcpAddr: 'wemx.cc:5100',
      wsAddr: 'ws://wemx.cc:5200',
      wssAddr: 'wss://wemx.cc/ws',
      preferredTransport: 'wss',
      preferredAddr: 'wss://wemx.cc/ws',
    );

    expect(
      route.resolvePreferredAddr(fallbackAddr: 'fallback.example:5100'),
      'wss://wemx.cc/ws',
    );
  });

  test('resolvePreferredAddr falls back from invalid preferred_addr to wss', () {
    final route = ImRouteInfo(
      tcpAddr: 'wemx.cc:5100',
      wsAddr: 'ws://wemx.cc:5200',
      wssAddr: 'wss://wemx.cc/ws',
      preferredTransport: 'wss',
      preferredAddr: 'https://wemx.cc/ws',
    );

    expect(
      route.resolvePreferredAddr(fallbackAddr: 'fallback.example:5100'),
      'wss://wemx.cc/ws',
    );
  });

  test('resolvePreferredAddr falls back to tcp then local fallback', () {
    final tcpOnly = ImRouteInfo(
      tcpAddr: 'wemx.cc:5100',
      wsAddr: '',
      wssAddr: '',
      preferredTransport: '',
      preferredAddr: '',
    );

    expect(
      tcpOnly.resolvePreferredAddr(fallbackAddr: 'fallback.example:5100'),
      'wemx.cc:5100',
    );

    const emptyRoute = ImRouteInfo.empty();
    expect(
      emptyRoute.resolvePreferredAddr(
        fallbackAddr: 'fallback.example:5100',
      ),
      'fallback.example:5100',
    );
  });
}
```

Append this test to
`C:\Users\COLORFUL\Desktop\WuKong\test\service\api\im_sync_api_test.dart`:

```dart
test('fetchUserConnectRoute parses preferred transport contract', () async {
  final adapter = _RecordingPlainAdapter(
    payload: const <String, dynamic>{
      'tcp_addr': 'wemx.cc:5100',
      'ws_addr': 'ws://wemx.cc:5200',
      'wss_addr': 'wss://wemx.cc/ws',
      'preferred_transport': 'wss',
      'preferred_addr': 'wss://wemx.cc/ws',
    },
  );
  ApiClient.instance.dio.httpClientAdapter = adapter;

  final route = await IMSyncApi.instance.fetchUserConnectRoute(uid: 'u_self');

  expect(adapter.lastRequestOptions?.path, '/v1/users/u_self/im');
  expect(route.tcpAddr, 'wemx.cc:5100');
  expect(route.wsAddr, 'ws://wemx.cc:5200');
  expect(route.wssAddr, 'wss://wemx.cc/ws');
  expect(route.preferredTransport, 'wss');
  expect(route.preferredAddr, 'wss://wemx.cc/ws');
});
```

Add this import to
`C:\Users\COLORFUL\Desktop\WuKong\test\service\im\im_service_test.dart`:

```dart
import 'package:wukong_im_app/service/api/im_route_info.dart';
```

Append this test to the same file:

```dart
test('selectImConnectAddr uses preferred_addr then transport fallbacks', () {
  final route = ImRouteInfo(
    tcpAddr: 'wemx.cc:5100',
    wsAddr: 'ws://wemx.cc:5200',
    wssAddr: 'wss://wemx.cc/ws',
    preferredTransport: 'wss',
    preferredAddr: 'wss://wemx.cc/ws',
  );

  expect(
    selectImConnectAddr(route, fallbackAddr: 'fallback.example:5100'),
    'wss://wemx.cc/ws',
  );

  final invalidPreferred = ImRouteInfo(
    tcpAddr: 'wemx.cc:5100',
    wsAddr: 'ws://wemx.cc:5200',
    wssAddr: 'wss://wemx.cc/ws',
    preferredTransport: 'wss',
    preferredAddr: 'https://wemx.cc/ws',
  );

  expect(
    selectImConnectAddr(
      invalidPreferred,
      fallbackAddr: 'fallback.example:5100',
    ),
    'wss://wemx.cc/ws',
  );
});
```

- [ ] **Step 2: Run the targeted Flutter tests and verify they fail**

Run:

```powershell
flutter test .\test\service\api\im_route_info_test.dart .\test\service\api\im_sync_api_test.dart .\test\service\im\im_service_test.dart
```

Working directory:

```text
C:\Users\COLORFUL\Desktop\WuKong
```

Expected:
- Fails because `ImRouteInfo`, `fetchUserConnectRoute`, and
  `selectImConnectAddr` do not exist yet

- [ ] **Step 3: Add the typed route model and app-side route selection**

Create `C:\Users\COLORFUL\Desktop\WuKong\lib\service\api\im_route_info.dart`
with:

```dart
import 'package:flutter/foundation.dart';

@immutable
class ImRouteInfo {
  const ImRouteInfo({
    required this.tcpAddr,
    required this.wsAddr,
    required this.wssAddr,
    required this.preferredTransport,
    required this.preferredAddr,
  });

  const ImRouteInfo.empty()
      : tcpAddr = '',
        wsAddr = '',
        wssAddr = '',
        preferredTransport = '',
        preferredAddr = '';

  final String tcpAddr;
  final String wsAddr;
  final String wssAddr;
  final String preferredTransport;
  final String preferredAddr;

  factory ImRouteInfo.fromMap(Map<String, dynamic> raw) {
    return ImRouteInfo(
      tcpAddr: _readString(raw['tcp_addr']),
      wsAddr: _readString(raw['ws_addr']),
      wssAddr: _readString(raw['wss_addr']),
      preferredTransport: _readString(raw['preferred_transport']),
      preferredAddr: _readString(raw['preferred_addr']),
    );
  }

  String resolvePreferredAddr({required String fallbackAddr}) {
    final normalizedFallback = fallbackAddr.trim();
    if (_matchesPreferredTransport(preferredTransport, preferredAddr)) {
      return preferredAddr.trim();
    }
    if (isValidWebSocketConnectUri(wssAddr, expectedScheme: 'wss')) {
      return wssAddr.trim();
    }
    if (isValidWebSocketConnectUri(wsAddr, expectedScheme: 'ws')) {
      return wsAddr.trim();
    }
    if (isValidTcpConnectAddr(tcpAddr)) {
      return tcpAddr.trim();
    }
    return normalizedFallback;
  }
}

bool isValidTcpConnectAddr(String value) {
  final normalized = value.trim();
  final separator = normalized.lastIndexOf(':');
  if (separator <= 0 || separator >= normalized.length - 1) {
    return false;
  }
  final host = normalized.substring(0, separator).trim();
  final port = int.tryParse(normalized.substring(separator + 1).trim());
  return host.isNotEmpty && port != null && port > 0;
}

bool isValidWebSocketConnectUri(
  String value, {
  required String expectedScheme,
}) {
  final normalized = value.trim();
  if (normalized.isEmpty) {
    return false;
  }
  final uri = Uri.tryParse(normalized);
  if (uri == null) {
    return false;
  }
  return uri.scheme == expectedScheme && uri.host.trim().isNotEmpty;
}

bool _matchesPreferredTransport(String transport, String addr) {
  switch (transport.trim().toLowerCase()) {
    case 'wss':
      return isValidWebSocketConnectUri(addr, expectedScheme: 'wss');
    case 'ws':
      return isValidWebSocketConnectUri(addr, expectedScheme: 'ws');
    case 'tcp':
      return isValidTcpConnectAddr(addr);
    default:
      return false;
  }
}

String _readString(dynamic value) => value?.toString().trim() ?? '';
```

Update `C:\Users\COLORFUL\Desktop\WuKong\lib\service\api\im_sync_api.dart`
with:

```dart
import 'im_route_info.dart';

class IMSyncApi {
  Future<ImRouteInfo> fetchUserConnectRoute({required String uid}) async {
    final normalizedUid = uid.trim();
    if (normalizedUid.isEmpty) {
      return const ImRouteInfo.empty();
    }

    final response = await _client.get(
      '/v1/users/${Uri.encodeComponent(normalizedUid)}/im',
    );
    final data = _unwrapMap(response.data);
    return ImRouteInfo.fromMap(data);
  }
}
```

Update `C:\Users\COLORFUL\Desktop\WuKong\lib\service\im\im_service.dart`
with:

```dart
import '../api/im_route_info.dart';

String selectImConnectAddr(
  ImRouteInfo route, {
  required String fallbackAddr,
}) {
  return route.resolvePreferredAddr(fallbackAddr: fallbackAddr);
}

class IMService extends StateNotifier<IMServiceState>
    with WidgetsBindingObserver {
  Future<String> _resolveConnectAddr(String uid) async {
    final route = await IMSyncApi.instance.fetchUserConnectRoute(uid: uid);
    return selectImConnectAddr(route, fallbackAddr: IMConfig.connectAddr);
  }
}
```

- [ ] **Step 4: Re-run the Flutter tests, analyze the touched files, and commit**

Run:

```powershell
flutter test .\test\service\api\im_route_info_test.dart .\test\service\api\im_sync_api_test.dart .\test\service\im\im_service_test.dart
dart analyze .\lib\service\api\im_route_info.dart .\lib\service\api\im_sync_api.dart .\lib\service\im\im_service.dart .\test\service\api\im_route_info_test.dart .\test\service\api\im_sync_api_test.dart .\test\service\im\im_service_test.dart
```

Expected:
- All targeted Flutter tests pass
- `dart analyze` reports no errors in the touched files

Commit:

```powershell
git add .\lib\service\api\im_route_info.dart .\lib\service\api\im_sync_api.dart .\lib\service\im\im_service.dart .\test\service\api\im_route_info_test.dart .\test\service\api\im_sync_api_test.dart .\test\service\im\im_service_test.dart
git commit -m "feat: prefer secure IM route contract"
```

## Task 4: Verify End-To-End Behavior And Roll Out Safely

**Files:**
- Uses the files from Tasks 1-3
- No new source files in this task

- [ ] **Step 1: Re-run the three targeted verification suites before any restart**

Run:

```powershell
flutter test .\test\service\api\im_route_info_test.dart .\test\service\api\im_sync_api_test.dart .\test\service\im\im_service_test.dart
```

Working directory:

```text
C:\Users\COLORFUL\Desktop\WuKong
```

Run:

```powershell
flutter test .\test\transport\connection_transport_test.dart .\test\db\message_identity_test.dart
```

Working directory:

```text
C:\Users\COLORFUL\Desktop\TangSengDaoDao\WuKongIMFlutterSDK-master
```

Run:

```bash
ssh ubuntu@42.194.218.158 "cd /opt/wukongim-prod/src && go test ./modules/user -run 'TestBuildIMRouteResponse|TestUserIM_ReturnsFormalContract' -count=1"
```

Expected:
- All three targeted verification suites pass before any production restart

- [ ] **Step 2: Present the restart plan and wait for the user to reply `Approve`**

Show this plan exactly before any restart:

```text
Restart scope:
1. Rebuild and recreate only the tsdd-api service in /opt/wukongim-prod/src/deploy/production
2. Do not restart nginx, wukongim, mysql, or redis in this slice
3. Verify https://wemx.cc/v1/users/final_verify_probe/im returns tcp_addr, ws_addr, wss_addr, preferred_transport, and preferred_addr
```

Expected:
- Stop here until the user replies with the exact word `Approve`

- [ ] **Step 3: After approval, rebuild and restart only `tsdd-api`**

Run:

```bash
ssh ubuntu@42.194.218.158 "cd /opt/wukongim-prod/src/deploy/production && docker compose up -d --build --force-recreate tsdd-api"
```

Expected:
- Only `tsdd-api` is rebuilt and recreated
- `nginx`, `wukongim`, `mysql`, and `redis` are not restarted in this slice

- [ ] **Step 4: Verify the production route contract over HTTPS**

Run:

```bash
ssh ubuntu@42.194.218.158 "curl -s https://wemx.cc/v1/users/final_verify_probe/im"
```

Expected response contains:

```json
{
  "tcp_addr": "wemx.cc:5100",
  "ws_addr": "ws://wemx.cc:5200",
  "wss_addr": "wss://wemx.cc/ws",
  "preferred_transport": "wss",
  "preferred_addr": "wss://wemx.cc/ws"
}
```

- [ ] **Step 5: Record the verification evidence in the handoff**

Capture this summary:

```text
- go test ./modules/user -run 'TestBuildIMRouteResponse|TestUserIM_ReturnsFormalContract' : pass
- flutter test (route contract set) : pass
- flutter test (SDK transport set) : pass
- production /v1/users/{uid}/im now returns the formal preferred-wss contract over HTTPS
```
