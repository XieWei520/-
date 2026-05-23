# github_webhook

## Repository Snapshot

- Local source: `C:\Users\COLORFUL\Desktop\WuKong\.codex_tmp\wildfirechat\github_webhook`
- Branch: `master`
- Commit inspected: `4eefa30`
- Main entry: `cn.wildfirechat.app.Application`

## Responsibility

`github_webhook` is a small Spring Boot robot integration demo. It receives GitHub and Gitee webhook events, formats them as text, and sends them into a configured WildfireChat conversation using a robot identity.

It is a reference for "external webhook system -> WildfireChat robot message" integrations, not a core IM component.

## Tech Stack

- Java 8
- Spring Boot `2.7.3`
- Spring MVC
- Gson
- Apache HttpClient dependencies
- Bundled WildfireChat Java SDK/common jars `0.21`

## Configuration

Main config in `src/main/resources/application.properties`:

```properties
server.port=8890

robot.im_id=FireRobot
robot.im_url=http://192.168.2.15:80
robot.im_secret=123456

forward.github.conversation_type=1
forward.github.conversation_target=tR16v6xx

forward.gitee.conversation_type=1
forward.gitee.conversation_target=728qmws2k
```

Important boundary: `robot.im_url` is the public IM HTTP URL and port, not `18080`.

## HTTP Entry Points

`Controller` exposes:

- `POST /github/payload`
  - Requires request header `X-GitHub-Event`.
  - Body is the raw GitHub webhook JSON.

- `POST /gitee/payload`
  - Requires request header `X-Gitee-Event`.
  - Body is the raw Gitee webhook JSON.

Both return `RestResult.ok()` regardless of whether message sending succeeds.

## Send Path

`GithubServiceImpl` and `GiteeServiceImpl` both call:

```java
ChatConfig.initRobot(mImUrl, mRobotId, mRobotSecret)
RobotService.sendMessage(mRobotId, conversation, payload)
```

Messages are sent as built-in text payload type `1` with `searchableContent` set to the formatted webhook text.

Supported GitHub events in inspected source:

- `push`
- `issues`
- `star`
- `issue_comment`
- `fork`
- `watch`
- `ping`
- `pull_request`

Supported Gitee events in inspected source:

- `Push Hook`
- `Issue Hook`
- `Note Hook`

Unknown GitHub events cause it to send a summary message and then the raw payload. Unknown Gitee events are sent as raw payload text with a generic prefix.

## Build and Run

```powershell
cd C:\Users\COLORFUL\Desktop\WuKong\.codex_tmp\wildfirechat\github_webhook
mvn package
java -jar target\github_webhook-0.1.jar
```

README says the public webhook URL is:

```text
http://<host>:8090/github/payload
```

Inspected `application.properties` uses `server.port=8890`, so deployment docs/config should be reconciled before use.

## Source-Confirmed Risks

- No visible verification of GitHub `X-Hub-Signature-256` or Gitee webhook password/signature in inspected controller/service code. Anyone who can reach the endpoint can cause robot messages.
- Raw webhook payloads are logged. GitHub/Gitee payloads can include private repository metadata, issue bodies, comments, commit messages, and user data.
- Unknown events may be forwarded as full raw JSON into chat, which can leak more data than intended.
- Robot secret is a production credential. Anyone with it can act as that robot through the Robot API.
- Bundled SDK/common jars are old (`0.21`) relative to newer repos in this analysis; verify API compatibility with the target IM server.
- There is no visible rate limiting, replay protection, idempotency handling, or deduplication.
