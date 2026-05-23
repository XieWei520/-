# Server SDK analysis notes

## Reading Status
First cross-language pass completed for:

- `server-sdk.js`
- `server-sdk-go`
- `server-sdk-python`

Focus:

- SDK role in the WildfireChat architecture
- Admin API authentication/signature protocol
- Robot and Channel API authentication
- module coverage
- language-specific differences
- relationship to `app-server`

Source cache:

```text
C:\Users\COLORFUL\Desktop\WuKong\.codex_tmp\wildfirechat
```

Clone metadata:

- `server-sdk.js`: branch `master`, commit `2b79963`
- `server-sdk-go`: branch `main`, commit `6c989f6`
- `server-sdk-python`: branch `main`, commit `a27e02b`

## Repository Roles
The server SDK repositories are language wrappers around `im-server` HTTP APIs.

They do not implement IM storage, MQTT, message routing, or login. They help a business server call `im-server` APIs.

Main use cases:

- create/update/query users
- generate IM tokens for clients
- send, recall, update, broadcast, or multicast messages from a server
- manage groups, friends, blacklists, chatrooms, channels, conferences, sensitive words, files, devices, and system settings
- build robot services
- build channel/public-account services

`app-server` uses the Java SDK bundled inside its `src/lib` directory. The JS/Go/Python SDKs mirror that Java SDK for non-Java business servers.

## Common Admin API Protocol
All three SDKs follow the same Admin API initialization model:

```text
adminUrl = http://<im-server-host>:18080
adminSecret = value of im-server http.admin.secret_key
```

Representative initialization:

```javascript
init('http://localhost:18080', '123456')
```

```go
wfc.InitAdmin("http://localhost:18080", "123456")
```

```python
AdminConfig.init_admin("http://localhost:18080", "123456")
```

Admin POST request signature:

```text
sign = sha1(nonce + "|" + adminSecret + "|" + timestampMillis)
```

Headers:

```text
nonce: random integer string
timestamp: current Unix time in milliseconds
sign: SHA-1 hex digest
Content-Type: application/json; charset=utf-8
Connection: Keep-Alive
```

The Admin API response shape is consistently modeled as:

```json
{
  "code": 0,
  "msg": "success",
  "result": {}
}
```

SDK wrapper result type:

- JavaScript: `IMResult`
- Go: `utilities.IMResult`
- Python: `IMResult`

Important errors handled by SDKs:

- `ERROR_CODE_AUTH_FAILURE`: secret or endpoint mismatch
- `ERROR_CODE_SIGN_EXPIRED`: local server time and IM server time not synchronized

## Admin API Modules
All three SDKs expose the same broad Admin module set:

- `UserAdmin`
- `MessageAdmin`
- `GroupAdmin`
- `RelationAdmin`
- `ChatroomAdmin`
- `ChannelAdmin`
- `GeneralAdmin`
- `ConferenceAdmin`
- `SensitiveAdmin`
- `MomentsAdmin`
- `RobotService`

Go additionally exposes:

- `MeshAdmin`
- `ChannelServiceApi`

Python exposes:

- channel service wrapper
- robot service wrapper
- dataclass-style models

JavaScript exports a large set of model and message content classes from `src/index.js`.

## Key Admin API Paths
The JS SDK's `APIPath` is a compact map of the API surface. These paths correspond to constants in Go/Python too.

User:

- `/admin/user/create`
- `/admin/user/update`
- `/admin/user/destroy`
- `/admin/user/get_info`
- `/admin/user/batch_get_infos`
- `/admin/user/get_token`
- `/admin/user/update_block_status`
- `/admin/user/check_block_status`
- `/admin/user/onlinestatus`
- `/admin/user/kickoff_client`
- `/admin/user/online_count`
- `/admin/user/online_list`
- `/admin/user/session_list`

Message:

- `/admin/message/send`
- `/admin/message/publish`
- `/admin/message/recall`
- `/admin/message/delete`
- `/admin/message/update`
- `/admin/message/get_one`
- `/admin/message/broadcast`
- `/admin/message/multicast`
- `/admin/message/conv_read`
- `/admin/message/delivery`

Group:

- `/admin/group/create`
- `/admin/group/del`
- `/admin/group/transfer`
- `/admin/group/get_info`
- `/admin/group/batch_infos`
- `/admin/group/modify`
- `/admin/group/member/list`
- `/admin/group/member/add`
- `/admin/group/member/del`
- `/admin/group/member/quit`
- `/admin/group/manager/set`
- `/admin/group/manager/mute`
- `/admin/group/manager/allow`

Relation:

- `/admin/friend/status`
- `/admin/friend/list`
- `/admin/blacklist/status`
- `/admin/blacklist/list`
- `/admin/friend/send_request`
- `/admin/relation/get`

Chatroom:

- `/admin/chatroom/create`
- `/admin/chatroom/del`
- `/admin/chatroom/info`
- `/admin/chatroom/members`
- `/admin/chatroom/set_black_status`
- `/admin/chatroom/get_black_status`
- `/admin/chatroom/set_manager`
- `/admin/chatroom/mute_all`

Channel:

- `/admin/channel/create`
- `/admin/channel/destroy`
- `/admin/channel/get`
- `/admin/channel/subscribe`
- `/admin/channel/is_subscribed`

General/system/files:

- `/admin/system/get_setting`
- `/admin/system/put_setting`
- `/admin/health`
- `/admin/file/conversation_files`
- `/admin/file/user_files`
- `/admin/file/message_file`
- `/admin/oss/get_upload_url`

Conference:

- `/admin/conference/list`
- `/admin/conference/exist`
- `/admin/conference/list_participant`
- `/admin/conference/create`
- `/admin/conference/destroy`
- `/admin/conference/recording`
- `/admin/conference/rtp_forward`
- `/admin/conference/stop_rtp_forward`
- `/admin/conference/list_rtp_forward`

Sensitive words:

- `/admin/sensitive/add`
- `/admin/sensitive/del`
- `/admin/sensitive/query`

## Token Generation API
The login-critical API is:

```text
POST /admin/user/get_token
```

SDK wrappers:

- JavaScript: `UserAdmin.getUserToken(userId, clientId, platform)`
- Go: `NewUserAdmin().GetUserToken(userId, clientId, platform)`
- Python: `UserAdmin.get_user_token(user_id, client_id, platform)`

This is the same API `app-server` calls after SMS/password/LDAP/PC login. The returned token is for the client to connect to `im-server`, not for authenticating back to the business server.

## Server-Side Message Sending
Server-side send path:

```text
business server -> SDK MessageAdmin -> /admin/message/send -> im-server
```

SDK wrappers:

- JavaScript: `MessageAdmin.sendMessage(sender, conversation, payload)`
- Go: `NewMessageAdmin().SendMessage(sender, conversation, payload)`
- Python: `MessageAdmin.send_message(sender, conversation, payload)`

This bypasses MQTT client publish and injects a message through Admin API. It is suitable for system messages, business notifications, robots, app-server share-extension sends, and operational workflows.

## Robot API Protocol
Robot APIs use public IM URL/HTTP port, not the Admin port.

Representative Go README warning:

- Robot service uses the IM public port, usually `80`, not admin port `18080`.

Robot signature:

```text
sign = sha1(nonce + "|" + robotSecret + "|" + timestampMillis)
```

Headers:

```text
rid: robotId
nonce: random integer string
timestamp: current Unix time in milliseconds
sign: SHA-1 hex digest
```

Robot paths include:

- `/robot/user_info`
- `/robot/profile`
- `/robot/message/send`
- `/robot/message/reply`
- `/robot/message/recall`
- `/robot/message/update`
- `/robot/set_callback`
- `/robot/get_callback`
- `/robot/delete_callback`
- `/robot/group/create`
- `/robot/group/member/add`
- `/robot/conference/request`
- `/robot/oss/get_upload_url`
- `/robot/moments/...`

Robot application signature for app authorization uses:

```text
sha1(nonce + "|" + robotId + "|" + timestampSeconds + "|" + robotSecret)
```

The app signature returns an `appId`, `appType`, `timestamp`, `nonceStr`, and `signature`.

## Channel API Protocol
Channel service APIs also use the public IM URL/HTTP port and a channel-specific secret.

Channel request signature:

```text
sign = sha1(nonce + "|" + channelSecret + "|" + timestampMillis)
```

Headers:

```text
cid: channelId
nonce: random integer string
timestamp: current Unix time in milliseconds
sign: SHA-1 hex digest
```

Channel service paths include:

- `/channel/user_info`
- `/channel/update_profile`
- `/channel/get_profile`
- `/channel/message/send`
- `/channel/message/recall`
- `/channel/message/republish`
- `/channel/subscribe`
- `/channel/subscriber_list`
- `/channel/is_subscriber`
- `/channel/application/get_user_info`

Channel application signature uses:

```text
sha1(nonce + "|" + channelId + "|" + timestampSeconds + "|" + channelSecret)
```

## Language-Specific Notes

### JavaScript SDK
Repository:

```text
C:\Users\COLORFUL\Desktop\WuKong\.codex_tmp\wildfirechat\server-sdk.js
```

Package:

- name: `@wildfirechat/server-sdk`
- version: `1.0.2`
- module type: ES modules
- Node engine: `>=14.0.0`
- runtime dependencies: `base64-arraybuffer`, `long`

Exports:

- `init`
- `getConfig`
- all Admin classes
- `RobotService`
- `APIPath`, `IMResult`, `ErrorCode`
- model classes
- message content classes

Implementation style:

- singleton `httpUtils`
- async/await Promise API
- native `http`/`https`
- Admin GET currently does not attach signature headers in `server-sdk.js`, while POST does. Most Admin APIs use POST; confirm before adding GET-only admin endpoints.

### Go SDK
Repository:

```text
C:\Users\COLORFUL\Desktop\WuKong\.codex_tmp\wildfirechat\server-sdk-go
```

Module:

- `github.com/wildfirechat/server-sdk-go`
- Go `1.21`
- dependency: `google.golang.org/protobuf`

Implementation style:

- `InitAdmin` configures singleton `AdminHttpUtils`.
- Admin wrappers are constructed with `NewUserAdmin`, `NewMessageAdmin`, etc.
- HTTP client has timeout and retry logic.
- JSON decoder uses `UseNumber()` to avoid numeric precision loss.
- Includes generated protobuf files and message content encoding helpers.
- Includes `MeshAdmin`.
- Includes `ChannelServiceApi` and `RobotService` with separate auth helpers.

### Python SDK
Repository:

```text
C:\Users\COLORFUL\Desktop\WuKong\.codex_tmp\wildfirechat\server-sdk-python
```

Dependencies:

- `requests>=2.31.0`
- `urllib3>=2.0.0`

Implementation style:

- `AdminConfig.init_admin` configures class-level `AdminHttpUtils`.
- Uses `requests.Session` with retry adapter.
- Models are implemented primarily as Python classes/dataclasses.
- Serializes dataclasses to dictionaries before request.
- Converts `result` payloads to specified model classes when wrappers provide a type.

Potential implementation issue to verify:

- `AdminHttpUtils.init(url, secret, timeout)` accepts a timeout argument but the request methods use class default connect/read timeout values rather than the supplied timeout value in the inspected code.

## Relationship to app-server
`app-server` uses the Java SDK, not these three repositories, but the semantic contract is the same.

Examples from `app-server`:

- `UserAdmin.getUserByMobile`
- `UserAdmin.createUser`
- `UserAdmin.getUserToken`
- `UserAdmin.checkUserBlockStatus`
- `MessageAdmin.sendMessage`
- `RelationAdmin.setUserFriend`
- `GeneralAdmin.subscribeChannel`
- `GroupAdmin.getGroupMembers`
- `ConferenceAdmin.createRoom`

If replacing `app-server` with a Node/Go/Python business service, these SDKs provide the equivalent server-side API surface.

## Secondary Development Guidance
Use server SDKs when:

- building a custom app server in Node/Go/Python
- integrating enterprise identity, CRM, payment, moderation, or workflow systems
- provisioning users/groups externally
- sending business/system notifications
- building robots or channel/public-account services
- building management/operations tools

Do not use server SDKs for:

- client MQTT connection logic
- client local database/cache logic
- custom IM wire protocol
- replacing client SDK APIs

The server SDKs are trusted backend tools and must not be embedded in untrusted clients because they require admin, robot, or channel secrets.

## Security Notes
- Keep `adminSecret`, robot secrets, and channel secrets server-side only.
- Time synchronization with `im-server` matters; expired signatures fail.
- Default sample secret `123456` is not production-safe.
- Admin APIs are powerful enough to create users, issue tokens, send messages, and change groups; isolate network access to the admin port.
- Robot and channel APIs use different headers and secrets from Admin APIs.
