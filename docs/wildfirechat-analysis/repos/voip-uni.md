# voip-uni

## Repository Snapshot

- Local source: `C:\Users\COLORFUL\Desktop\WuKong\.codex_tmp\wildfirechat\voip-uni`
- Branch: `wx`
- Commit inspected: `e946191`
- Main parts:
  - Vue 2 single-page AV runtime.
  - WildfireChat Web IM client code under `src/wfc`.
  - AV engine wrappers and minified AV engines under `src/wfc/av`.
  - Conference UI under `src/voip/conference`.
  - Build template that emits an inline `voip-dist.html`.

## Responsibility

`voip-uni` provides audio/video call and conference UI for uni-app / WeChat mini-program style deployments through a webview.

README states:

- Mini-program platform uses `webview` to implement audio/video features.
- Supports single-person, multi-person, and conference calls.
- Currently does not support inviting new members.
- The host `wx-chat` project points its `voip.js` `voipBaseWebUrl` to the deployed output.

This repository is the webview AV page, not a standalone IM business server.

## Build and Run

Requirements from README:

```text
node v14.18.1
npm install
npm run serve
npm run build
```

`vue.config.js`:

- Enables HTTPS dev server configuration comments for local/mobile debugging.
- Disables CSS extraction.
- Disables split chunks.
- Uses `HtmlWebpackPlugin` and `HtmlWebpackInlineSourcePlugin` to produce one inline HTML file:

```text
voip-dist.html
```

`build.sh` builds two variants:

```text
cp engine-conference.min.js engine.min.js
npm run build
cp dist/voip-dist.html voip-conference-<timestamp>.html

cp engine-multi.min.js engine.min.js
npm run build
cp dist/voip-dist.html voip-multi-<timestamp>.html
```

## Stack

- Vue 2.6.
- Vue CLI 4.
- axios.
- vConsole.
- WildfireChat Web IM client code.
- Minified WildfireChat AV browser engines.

AV engine files:

```text
engine-conference.min.js
engine-multi.min.js
engine.min.js
```

The internal README says ordinary and advanced AV libraries are different and not mutually interoperable. It also states `engine-conference.min.js` is the advanced/conference engine and `engine-multi.min.js` is the ordinary multi-call engine.

## Runtime Entry

`App.vue` reads URL parameters:

```text
type
appServer
authToken
server
userId
clientId
token
options
debug
```

It then:

- Requests camera/microphone with `navigator.mediaDevices.getUserMedia`.
- Sets `conferenceApi.appServer` from `appServer`.
- Sets `conferenceApi.authToken`.
- Reconstructs the token string after URL-safe character replacement.
- Calls `wfc.setupShortLink(imServerAddress, userId, clientId, token)`.
- Dispatches the decoded `options` into `window.msgFromUniapp(options)` after the page is mounted.

This means the host app is responsible for authenticating the user and passing a valid IM token/clientId pair plus app-server auth.

## App-Server APIs

`conferenceApi` wraps:

```text
POST /conference/get_my_id
POST /conference/create
POST /conference/info
POST /conference/destroy/{conferenceId}
POST /conference/fav/{conferenceId}
POST /conference/unfav/{conferenceId}
POST /conference/is_fav/{conferenceId}
POST /conference/fav_conferences
POST /conference/put_info
POST /conference/recording/{conferenceId}
POST /conference/focus/{conferenceId}
```

Requests include:

```text
Header: authToken
withCredentials: true
```

`appServerApi` also includes normal app-server login, PC session, favorite, and server-side send-message wrappers, but the webview AV path mainly receives auth/context from the host.

## Conference Controls

`conferenceManager.js` handles conference command messages and host controls:

- Mute all audio/video.
- Cancel mute all.
- Request one participant to mute/unmute audio/video.
- Participant apply-unmute flows.
- Hand-up and put-hand-down flows.
- Recording state.
- Focus/cancel-focus state.

Command messages are sent to:

```text
ConversationType.ChatRoom
target = conferenceId
line = 0
```

The webview uses `avenginekitproxy` to bridge events between the AV page and the host uni/mini-program environment. It emits events such as:

```text
pickGroupMembers
inviteConferenceParticipant
didCallEndWithReason
sendConferenceRequest
sendMessageResult
```

## Deployment Notes

- The deployed webview URL must use HTTPS and a real domain for mini-program production use.
- README warns not to use `localhost` for mobile testing.
- Mini-program backend/domain allowlists must include the deployed domain.
- The host `wx-chat`/uni app must pass IM server, userId, clientId, token, appServer, and authToken into the URL.

## Source-Confirmed Risks

- URL parameters include IM token and app-server authToken. Deploy only over HTTPS and avoid logging full URLs at proxies/CDNs.
- `debug=true` enables vConsole and extra logging; do not enable in production.
- The AV engine used at build time must match the deployment mode. Ordinary and advanced/conference AV engines are not interchangeable.
- README states inviting new members is not supported in the mini-program webview flow, even though some invite-related bridge code exists.
- Minified AV engine code limits source-level debugging inside this repository.
