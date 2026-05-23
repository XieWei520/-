# robot_server

## Repository Snapshot

- Local source: `C:\Users\COLORFUL\Desktop\WuKong\.codex_tmp\wildfirechat\robot_server`
- Branch: `master`
- Commit inspected: `8f7a33b`
- Main parts:
  - Spring Boot demo robot service.
  - Robot callback receiver.
  - GitHub / GitLab / Gitee / general webhook adapters.
  - Bundled WildfireChat Java SDK jars under `src/lib`.

## Responsibility

`robot_server` is a demo robot application for WildfireChat robot APIs.

It is not a gateway and not the core IM server. It shows the direct robot integration pattern:

1. A robot identity exists in `im-server`.
2. The robot has a callback URL pointing to this service.
3. `im-server` posts incoming robot messages to `/robot/recvmsg`.
4. This service handles the message and calls `im-server` Robot API through `RobotService`.

The repository also demonstrates using a robot as a webhook relay. Users can ask the robot for a webhook URL, then external services can post GitHub/GitLab/Gitee/general webhook payloads to the generated callback and have them sent into the original conversation.

## Build and Run

Confirmed commands:

```text
mvn package
java -jar robot-XXXXX.jar
```

README says deployment should place these config files beside the jar:

```text
config/application.properties
config/robot.properties
```

Default app port:

```text
server.port=8883
```

## Backend Stack

- Java 8.
- Spring Boot `2.2.10.RELEASE`.
- Spring Web.
- WildfireChat Java SDK `1.4.2`.
- Gson.
- Apache HTTP clients.
- Protobuf `2.5.0`.
- Log4j2 `2.17.1`.

Startup entry:

```text
cn.wildfirechat.app.Application.main
```

## Configuration

`RobotConfig` loads external config from:

```text
file:config/robot.properties
```

Default sample:

```text
robot.im_id=FireRobot
robot.im_name=...
robot.im_url=http://localhost
robot.im_secret=123456
robot.public_addr=http://192.168.3.101:8883
```

Important distinction from the sample comments:

- `robot.im_url` is the public IM HTTP URL, not the Admin API `18080` URL.
- `robot.im_secret` is the robot secret, not `im.admin_secret`.

`ServiceImpl` initializes:

```text
new RobotService(robot.im_url, robot.im_id, robot.im_secret)
```

## HTTP Endpoints

```text
POST /robot/recvmsg
POST /robot/webhook/{app}/{token}
```

`/robot/recvmsg` accepts `OutputMessageData` from `im-server`.

`/robot/webhook/{app}/{token}` accepts external webhook payloads for registered webhook adapters. The inspected adapters are:

- general
- github
- gitlab
- gitee

## Message Behavior

`ServiceImpl.onReceiveMessage()` runs asynchronously through `@Async("asyncExecutor")`.

Response rules:

- Private conversation: respond directly.
- Group conversation: respond when the robot is explicitly mentioned.
- Group `@all`: intentionally does not respond.
- VoIP signal messages in the `400..500` range are mostly ignored or answered with demo text.
- Text messages with known keywords return hard-coded WildfireChat information.
- `/list` or `/` lists available webhook commands.
- Some responses are sent as streaming text using `StreamTextGeneratingMessageContent` and `StreamTextGeneratedMessageContent`.

Sending uses:

- `robotService.sendMessage(robotId, conversation, payload)`
- `robotService.replyMessage(messageId, payload, false)`
- `robotService.getUserInfo(userId)` for group mention display.

## Webhook URL Model

When a user invokes a webhook command, `WebhookService` generates:

```text
{robot.public_addr}/robot/webhook/{command}/{token}
```

The token encodes conversation and user data through `TokenUtils.webhookToken()`.

Webhook posts are mapped back to the original conversation and sent through the robot.

## Source-Confirmed Risks

- `TokenUtils` uses a hard-coded sign word and `DESUtil` uses hard-coded DES key/IV values. This is suitable as a demo, not a production webhook authorization model.
- `DESUtil.decrypt()` returns the original input on failure. Downstream parsing may then throw or behave unexpectedly.
- `/robot/recvmsg` and `/robot/webhook/{app}/{token}` do not add extra request authentication beyond possession of the generated URL/token.
- The demo robot replies with hard-coded marketing/support text and should be treated as sample behavior.
- `robot.im_secret=123456` is a demo value and must be replaced.
