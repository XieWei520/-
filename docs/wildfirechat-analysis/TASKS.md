# WildfireChat Analysis Task List

## Phase 1: Organization Map
- [x] Task: Create durable analysis workspace
  - Acceptance: `SPEC.md`, `TASKS.md`, and `PROJECT-NOTES.md` exist in a stable location.
  - Verify: files exist under `C:\Users\COLORFUL\Desktop\WuKong\docs\wildfirechat-analysis`.
  - Files: analysis docs only.

- [x] Task: Inventory GitHub organization repositories
  - Acceptance: captured repository list and grouped likely responsibilities.
  - Verify: repository names saved in `repo-list.txt` and summarized in `PROJECT-NOTES.md`.
  - Files: `repo-list.txt`, `PROJECT-NOTES.md`.

## Phase 2: Core Servers
- [x] Task: Deep analyze `im-server`
  - Acceptance: record tech stack, modules, startup path, config, MQTT/HTTP entry points, message send path, storage, DB migrations, risks.
  - Verify: cross-check README, Maven files, source entry points, config, migrations.
  - Files: `repos/im-server.md`.

- [x] Task: Deep analyze `app-server`
  - Acceptance: record relation to `im-server`, login/token model, Shiro session model, PC QR login, callbacks, media, conference, local JPA model, risks.
  - Verify: cross-check Maven file, config, controllers, service implementation, Shiro config, JPA entities.
  - Files: `repos/app-server.md`, `PROJECT-NOTES.md`.

## Phase 3: Server SDKs
- [x] Task: Analyze server SDKs
  - Acceptance: document JS/Go/Python SDK responsibilities, Admin API auth/signing, route coverage, usage examples.
  - Verify: inspect SDK README, package/module definitions, request helpers, representative API wrappers.
  - Files: `repos/server-sdk.md`.

## Phase 4: Clients
- [x] Task: Analyze Web/PC clients
  - Acceptance: explain `vue-chat` and `vue-pc-chat` tech stack, login calls, app-server config, IM SDK initialization, PC QR flow.
  - Verify: inspect build config, env/config files, login modules, SDK initialization.
  - Files: `repos/vue-chat.md`, `repos/vue-pc-chat.md`.

- [x] Task: Analyze mobile/cross-platform clients
  - Acceptance: explain Android/iOS/Flutter client roles and how they obtain/use IM token.
  - Verify: inspect README/build files/config/login and connect entry points.
  - Files: `repos/android-chat.md`, `repos/ios-chat.md`, `repos/flutter-chat.md`.

## Phase 5: Platform and Peripheral Repos
- [x] Task: Analyze admin/open/platform repos
  - Acceptance: distinguish admin UI/API responsibilities and whether each talks to app-server, im-server Admin API, or both.
  - Verify: inspect build config, API clients, environment config.
  - Files: per-repo notes.

- [x] Task: Analyze push, robot, archive, and media/conference adjunct repos
  - Acceptance: document extension points and deployment relationships.
  - Progress: `push_server`, `robot_server`, `robot-gateway`, `archive-server`, `minutes-server`, `wf-janus`, `wf-oss-gateway`, `ServerVoipDemo`, `android-conference`, `ios-conference`, `voip-uni`, `wf-conference-record-player`, and GitHub placeholder `asr-api` are analyzed.
  - Verify: inspect README/build files/config and server entry points.
  - Files: per-repo notes and `PROJECT-NOTES.md`.

## Cross-Cutting Topics
- [x] Task: Login and token chain
  - Acceptance: clarify client/app-server/im-server credentials and boundaries.
  - Verify: source-supported from `ServiceImpl`, Admin SDK calls, `im-server` token verification path.
  - Files: `PROJECT-NOTES.md`, `repos/app-server.md`, `repos/im-server.md`.

- [x] Task: Message send path
  - Acceptance: clarify direct client MQTT send path and app-server server-side send path.
  - Verify: source-supported from `SendMessageHandler`, MQTT handlers, `ServiceImpl.sendUserMessage`.
  - Files: `PROJECT-NOTES.md`, `repos/im-server.md`, `repos/app-server.md`.

- [x] Task: Push and audio/video chain
  - Acceptance: identify which repos own offline push, VoIP, conference, recording, Janus, and media storage.
  - Progress: offline push ownership is confirmed in `push_server`; Janus media relay is confirmed in `wf-janus`; server-side AV SDK demo is confirmed in `ServerVoipDemo`; meeting minutes are confirmed in `minutes-server`; custom media upload gateway is confirmed in `wf-oss-gateway`; Android/iOS/mini-program conference clients and Janus recording post-processing are documented. GitHub `asr-api` is only a placeholder pointing to Gitee, whose clone timed out in this environment.
  - Verify: source-supported from relevant repos.
  - Files: `PROJECT-NOTES.md` and per-repo notes.

- [x] Task: Analyze official docs repository
  - Acceptance: validate deployment and extension guidance against official WildfireChat docs.
  - Verify: inspect docs repo structure and pages for server deployment, app-server integration, AV/Janus, push, robot, and object storage topics.
  - Files: `repos/docs.md`, `PROJECT-NOTES.md`.

- [x] Task: Analyze integration adjuncts
  - Acceptance: document `mesh-bridge`, `github_webhook`, and `wx_mp_assistant` responsibilities and deployment relationships.
  - Verify: inspect README/build/config/source entry points.
  - Files: per-repo notes and `PROJECT-NOTES.md`.

- [x] Task: Analyze additional client variants
  - Acceptance: classify and source-check PC/Web/React/Uni/Harmony/WeChat variants enough to know which are current, legacy, wrappers, or demos.
  - Verify: inspected README/build/config/login/connect entry points, including shallow sparse Harmony checkouts and targeted `git show` reads.
  - Files: `repos/client-variants.md`, `PROJECT-NOTES.md`.

- [x] Task: Analyze SDK and tooling repositories
  - Acceptance: classify Windows/Swift SDK demos, performance-test docs, C1000K long-connection guide, and UDP port diagnostics by responsibility and production relevance.
  - Verify: inspected README/build/config/source entry points for `CS-Client-SDK`, `WFSwiftDemo`, `Performance_Test`, `C1000K_Test`, `udp_port_detecter`, and `udpPortChecker-android`.
  - Files: `repos/sdk-and-tools.md`, `PROJECT-NOTES.md`.

- [x] Task: Analyze auxiliary/content repositories
  - Acceptance: classify Moments UI repos, open-platform demo app, anti-fraud callback service, WildfireChat MinIO packaging, screenshot gallery, AMR build helper, and non-core community/demo repos.
  - Verify: inspected README/build/config/source entry points for `android-momentkit`, `ios-momentkit`, `wf-gallery`, `daily-report`, `anti-fraud`, `WF-minio`, `libopencore-amr-ios-build`, `996.ICU`, and `java_bullshitarticle`.
  - Files: `repos/auxiliary-repos.md`, `PROJECT-NOTES.md`.

## Checkpoints
- [x] Checkpoint: Core architecture after `im-server` and `app-server`.
- [x] Checkpoint: Server SDKs before client deep dive.
- [x] Checkpoint: Web/PC client flows before mobile client deep dive.
- [x] Checkpoint: Final synthesis after core clients and SDKs.
- [x] Checkpoint: First-pass organization coverage after SDK/tooling and auxiliary repos.
