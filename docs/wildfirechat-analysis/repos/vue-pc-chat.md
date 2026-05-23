# Repository Note: vue-pc-chat

## Snapshot
- Repository: `wildfirechat/vue-pc-chat`
- Local cache: `C:\Users\COLORFUL\Desktop\WuKong\.codex_tmp\wildfirechat\vue-pc-chat`
- Branch/commit inspected: `master` / `631fbf3`
- Primary role: Electron desktop chat client built from a Vue UI plus a native IM protocol addon.
- Main stack: Vue 3, Vue CLI, Electron 22, electron-builder plugin, Pinia, Vue Router, axios, native `marswrapper.node` protocol addon.

## Responsibility
`vue-pc-chat` is the desktop client. It shares much of the UI and app-server API shape with `vue-chat`, but adds Electron process management, native tray/window/screenshot/file handling, cross-platform packaging, and an IPC bridge to a native IM protocol stack.

It still uses `app-server` for login and app business APIs. The main desktop difference is that IM protocol operations are handled through the native `marswrapper.node` addon instead of only a browser WebSocket/minified Web SDK path.

## Build and Run Commands
Confirmed from `package.json`:

```powershell
npm run dev
npm run package
npm run validate
npm run electron:dev
npm run cross-package-win
npm run cross-package-win32
npm run cross-package-linux
npm run cross-package-linux-arm64
npm run cross-package-all
```

The main packaging commands run:

```powershell
node scripts/validate.js
node scripts/del.js ./marswrapper.node
node scripts/copy-proto.js
vue-cli-service electron:build -p never
```

## Native Protocol Addon
Confirmed from `package.json`, `scripts/copy-proto.js`, `src/background.js`, and `src/wfc/proto`:

- Native addon variants live under `proto_addon/` and are named by platform/architecture, for example `marswrapper.win64.node`, `marswrapper.linux.node`, `marswrapper.mac.node`.
- `scripts/copy-proto.js` selects the correct platform file and copies it to project root as `marswrapper.node`.
- `src/background.js` imports `proto` from `../marswrapper.node`.
- On Electron `app.ready`, `background.js` calls `initProtoMain(proto)`.
- `src/wfc/proto/proto_main.js` exposes native protocol methods to renderer windows through Electron IPC.
- `src/wfc/proto/proto_renderer_proxy.js` sends synchronous and asynchronous IPC calls such as `invokeProtoMethod`, `invokeProtoMethodAsync`, and `sendMessage`.

Desktop IM stack shape:

```mermaid
flowchart LR
  Vue["Vue renderer"] -->|"wfc API"| Proxy["proto_renderer_proxy"]
  Proxy -->|"Electron IPC"| Main["proto_main in main process"]
  Main -->|"native calls"| Mars["marswrapper.node"]
  Mars -->|"IM protocol"| IM["im-server"]
```

## Key Configuration
Confirmed from `src/config.js`:

- `APP_SERVER = 'https://app.wildfirechat.net'` by default.
- `QR_CODE_PREFIX_PC_SESSION = "wildfirechat://pcsession/"`.
- `ICE_SERVERS` defaults to WildfireChat test TURN credentials.
- `OPEN_PLATFORM_WORK_SPACE_URL = 'https://open.wildfirechat.cn/work.html'`.
- `OPEN_PLATFORM_SERVE_PORT = 7983`.
- `SECRET_CHAT_MEDIA_DECODE_SERVER_PORT = 7982`.
- `AMR_TO_MP3_SERVER_ADDRESS = Config.APP_SERVER + '/amr2mp3?path='`.
- `getWFCPlatform()` maps Electron platform to Windows `3`, macOS `4`, Linux `7`; browser fallback is Web `5`.

The PC config lacks the Web repo's explicit `USE_WSS`, `ROUTE_PORT`, and `CLIENT_ID_STRATEGY` definitions in the inspected top-level config; those Web-specific values should not be assumed for the Electron native path.

## App-Server API Usage
Confirmed from `src/api/appServerApi.js`; it is effectively the same shape as `vue-chat`:

- `/send_code`
- `/login_pwd`
- `/login`
- `/pc_session`
- `/session_login/{appToken}`
- password reset/change APIs
- group announcement APIs
- favorites APIs
- slide captcha APIs

Login requests pass `platform = Config.getWFCPlatform()` and `clientId = wfc.getClientId()`. The successful app-server response header `authToken` is persisted under a host-scoped key, while the returned `token` is used as the IM token for the native protocol stack.

## Login and Connection Flow
Confirmed from `src/ui/main/LoginPage.vue` and `src/wfc/client/wfc.js`:

- Auto-login reads cached `userId` and `token`, then calls `wfc.connect(userId, token)`.
- Password login calls `appServerApi.loinWithPassword(...)`, then `wfc.connect(userId, token)`.
- SMS-code login calls `appServerApi.loginWithAuthCode(...)`, then `wfc.connect(userId, token)`.
- PC scan login creates a `/pc_session`, renders `wildfirechat://pcsession/{token}`, polls `/session_login/{token}`, and connects after receiving `userId` plus IM token.
- `WfcManager.connect(userId, token)` returns the native protocol result from `impl.connect(userId, token)`.

Important invariant: `wfc.getClientId()` must be called before requesting token from `app-server`; comments in `LoginPage.vue` warn not to change app name/client identity after creating a PC login session without redesigning the logic.

## Renderer/Main Window Initialization
Confirmed from `src/main.js`:

- Main/login/home renderer path calls `wfc.init()` and registers custom messages.
- Secondary Electron windows call `wfc.attach()` and initialize a reduced store depending on the route.
- Browser fallback path still exists, but this repository is primarily packaged as Electron.
- `main.js` also installs an auto-recovery reload guard for the main home route after renderer errors/unhandled rejections.

Confirmed from `src/background.js`:

- Main process owns native addon initialization, window creation, tray behavior, shortcuts, local resource protocol, screenshots, file protocol handling, and other desktop integrations.

## Relationship to Other Repositories
- Uses `app-server` for login and app-layer APIs.
- Connects to `im-server` through the native `marswrapper.node` IM protocol stack.
- Uses the same PC session QR scheme as web/mobile clients: `wildfirechat://pcsession/`.
- Integrates with optional open platform workspace through `OPEN_PLATFORM_WORK_SPACE_URL` and a local serve port.

## Security and Deployment Notes
- Replace default `APP_SERVER`, TURN credentials, and open-platform URLs for self-hosted deployments.
- The native addon is platform-specific. Packaging must run `scripts/validate.js` and select the correct `proto_addon` artifact.
- The PC client stores tokens in local storage in Electron mode through the shared storage helper.
- IPC is a major trust boundary. Renderer content should be treated as untrusted; the current design exposes many protocol methods through IPC.
- `marswrapper.node` integrity matters. The validation script prints addon MD5 hashes for comparison with expected values.

## Open Questions
- Need deeper review of `proto_main.js` method exposure and Electron security flags before making a security-hardening recommendation.
- Need compare with older `pc-chat` or `qt-pc-chat` to decide which PC client is the current primary recommendation.
