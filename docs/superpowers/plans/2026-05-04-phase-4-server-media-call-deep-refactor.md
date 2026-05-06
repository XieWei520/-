# Phase 4 Server Media Call Deep Refactor Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Complete Phase 4 by decoupling message side effects with durable outbox plus Redis Streams, hardening multipart rich-media upload, and adding LiveKit call telemetry across client, remote services, and production rollout.

**Architecture:** Keep WuKongIM message ACK and DB persistence semantics unchanged. WuKongIM writes a durable local outbox after message persistence, a relay posts persisted-message events to TS-DD, and TS-DD publishes them to Redis Streams with stable consumer groups and idempotency. Multipart APIs remain under `/v1/file/multipart/*` with additive session reuse and validation. Call telemetry is reported by Flutter, validated and persisted by TS-DD, and verified in production smoke tests.

**Tech Stack:** Flutter/Dart, Dio, Go 1.20 TS-DD API, Go 1.23 WuKongIM core, go-redis v6/v8, MySQL migrations, Redis Streams, Docker Compose, Nginx, Python smoke tests.

---

## Pre-flight Constraints

- Local repo root: `C:\Users\COLORFUL\Desktop\WuKong`.
- Remote TS-DD source: `/opt/wukongim-prod/src`.
- Remote WuKongIM core source: `/home/ubuntu/wukongim-build-src-uploaded`.
- Remote production compose directory: `/opt/wukongim-prod/src/deploy/production`.
- Existing local Phase 3 dirty files must not be committed into Phase 4.
- Remote TS-DD is not a git repo, so every remote edit task starts with a timestamped backup.
- Remote WuKongIM core is a git repo but was already dirty before this phase, so never reset unrelated changes.

## File Structure Map

### Local Flutter worktree

- Worktree: `C:\Users\COLORFUL\Desktop\WuKong\.worktrees\phase-4-server-media-call`
- Modify: `lib\core\upload\multipart_upload_models.dart`
- Modify: `lib\data\upload\resumable_file_uploader.dart`
- Modify: `lib\service\api\file_multipart_upload_client.dart`
- Create: `lib\realtime\call\call_telemetry_models.dart`
- Create: `lib\realtime\call\call_telemetry_reporter.dart`
- Modify: `lib\service\api\call_api.dart`
- Modify: `lib\modules\video_call\media\call_media_engine.dart`
- Modify: `lib\modules\video_call\media\livekit_call_media_engine.dart`
- Modify: `lib\modules\video_call\call_session_service.dart`
- Tests:
  - `test\data\upload\resumable_file_uploader_test.dart`
  - `test\service\api\file_multipart_upload_client_test.dart`
  - `test\realtime\call\call_telemetry_reporter_test.dart`
  - `test\service\api\call_api_telemetry_test.dart`
  - `test\modules\video_call\livekit_call_media_engine_test.dart`
  - `test\modules\video_call\call_session_service_test.dart`

### Remote TS-DD

- Modify: `/opt/wukongim-prod/src/serverlib/pkg/redis/redis.go`
- Create directory: `/opt/wukongim-prod/src/modules/messageeffects`
- Create: `/opt/wukongim-prod/src/modules/messageeffects/1module.go`
- Create: `/opt/wukongim-prod/src/modules/messageeffects/models.go`
- Create: `/opt/wukongim-prod/src/modules/messageeffects/stream.go`
- Create: `/opt/wukongim-prod/src/modules/messageeffects/service.go`
- Create: `/opt/wukongim-prod/src/modules/messageeffects/api.go`
- Modify: `/opt/wukongim-prod/src/internal/modules.go`
- Modify: `/opt/wukongim-prod/src/modules/file/multipart_temp_store.go`
- Modify: `/opt/wukongim-prod/src/modules/file/service.go`
- Modify: `/opt/wukongim-prod/src/modules/file/api.go`
- Modify: `/opt/wukongim-prod/src/modules/extra/models.go`
- Modify: `/opt/wukongim-prod/src/modules/extra/db.go`
- Modify: `/opt/wukongim-prod/src/modules/extra/api.go`
- Create: `/opt/wukongim-prod/src/modules/extra/sql/extra-20260504-01.sql`
- Modify: `/opt/wukongim-prod/src/deploy/production/nginx/default.conf.template`
- Modify: `/opt/wukongim-prod/src/deploy/production/scripts/smoke_test.py`
- Modify: `/opt/wukongim-prod/src/deploy/production/scripts/call_stack_smoke.py`

### Remote WuKongIM core

- Create directory: `/home/ubuntu/wukongim-build-src-uploaded/internal/messageeffects`
- Create: `/home/ubuntu/wukongim-build-src-uploaded/internal/messageeffects/outbox.go`
- Create: `/home/ubuntu/wukongim-build-src-uploaded/internal/messageeffects/relay.go`
- Create: `/home/ubuntu/wukongim-build-src-uploaded/internal/messageeffects/options.go`
- Modify: `/home/ubuntu/wukongim-build-src-uploaded/internal/options/options.go`
- Create: `/home/ubuntu/wukongim-build-src-uploaded/internal/service/message_effects.go`
- Modify: `/home/ubuntu/wukongim-build-src-uploaded/internal/server/server.go`
- Modify: `/home/ubuntu/wukongim-build-src-uploaded/internal/channel/handler/event_persist.go`
- Modify: `/opt/wukongim-prod/src/deploy/production/config/wk.yaml.tpl`

---

## Task 0: Create Isolated Local Worktree

**Files:**
- No business code modified.

- [ ] **Step 1: Verify worktree ignore rule**

Run:

```powershell
cd C:\Users\COLORFUL\Desktop\WuKong
git check-ignore -v .worktrees/
```

Expected: output includes `.gitignore` and `.worktrees/`.

- [ ] **Step 2: Create isolated branch and worktree**

Run:

```powershell
cd C:\Users\COLORFUL\Desktop\WuKong
git worktree add .worktrees/phase-4-server-media-call -b codex/phase-4-server-media-call
```

Expected: `C:\Users\COLORFUL\Desktop\WuKong\.worktrees\phase-4-server-media-call` exists and the original workspace still contains the existing Phase 3 dirty files.

- [ ] **Step 3: Verify baseline status**

Run:

```powershell
git -C C:\Users\COLORFUL\Desktop\WuKong status --short
git -C C:\Users\COLORFUL\Desktop\WuKong\.worktrees\phase-4-server-media-call status --short
```

Expected: original workspace shows Phase 3 files; worktree is clean.

- [ ] **Step 4: Run targeted Flutter baseline**

Run:

```powershell
cd C:\Users\COLORFUL\Desktop\WuKong\.worktrees\phase-4-server-media-call
flutter test test/data/upload/resumable_file_uploader_test.dart test/service/api/file_multipart_upload_client_test.dart test/realtime/call/call_state_machine_test.dart test/modules/video_call/livekit_call_media_engine_test.dart test/modules/video_call/call_session_service_test.dart
```

Expected: pass. If it fails, capture exact output and pause before implementing.

---

## Task 1: TS-DD Redis Streams Primitives

**Files:**
- Modify: `/opt/wukongim-prod/src/serverlib/pkg/redis/redis.go`
- Test: `/opt/wukongim-prod/src/serverlib/pkg/redis/redis_stream_test.go`

- [ ] **Step 1: Backup TS-DD source**

Run:

```bash
ssh ubuntu@42.194.218.158 'set -euo pipefail; ts=$(date +%Y%m%d%H%M%S); mkdir -p /opt/wukongim-prod/src/deploy/production/backups/phase4-redis-$ts; cp -a /opt/wukongim-prod/src/serverlib/pkg/redis /opt/wukongim-prod/src/deploy/production/backups/phase4-redis-$ts/; echo /opt/wukongim-prod/src/deploy/production/backups/phase4-redis-$ts'
```

Expected: backup path printed.

- [ ] **Step 2: Write failing wrapper tests**

Create `/opt/wukongim-prod/src/serverlib/pkg/redis/redis_stream_test.go`:

```go
package redis

import "testing"

func TestStreamFieldAndMessageShapes(t *testing.T) {
	fields := StreamFields{
		"event_id":   "evt-1",
		"event_type": "message.persisted",
	}
	if fields["event_id"] != "evt-1" {
		t.Fatalf("event_id=%q", fields["event_id"])
	}
	msg := StreamMessage{ID: "1700000000000-0", Values: fields}
	if msg.ID == "" || msg.Values["event_type"] != "message.persisted" {
		t.Fatalf("unexpected message: %#v", msg)
	}
}
```

- [ ] **Step 3: Run test and verify red**

Run:

```bash
ssh ubuntu@42.194.218.158 'cd /opt/wukongim-prod/src && docker run --rm -v "$PWD":/src -w /src golang:1.20 go test ./serverlib/pkg/redis -run TestStreamFieldAndMessageShapes -count=1 -v'
```

Expected: fail with undefined `StreamFields` and `StreamMessage`.

- [ ] **Step 4: Implement wrappers**

Modify `/opt/wukongim-prod/src/serverlib/pkg/redis/redis.go` imports to include:

```go
import (
	"errors"
	"fmt"
	"strings"
	"time"

	rd "github.com/go-redis/redis"
)
```

Append these types and methods:

```go
type StreamFields map[string]string

type StreamMessage struct {
	ID     string
	Values map[string]string
}

func (rc *Conn) XAdd(stream string, fields StreamFields) (string, error) {
	values := make(map[string]interface{}, len(fields))
	for key, value := range fields {
		values[key] = value
	}
	return rc.client.XAdd(&rd.XAddArgs{
		Stream: stream,
		Values: values,
	}).Result()
}

func (rc *Conn) XGroupCreateMkStream(stream string, group string, start string) error {
	if start == "" {
		start = "0"
	}
	err := rc.client.XGroupCreateMkStream(stream, group, start).Err()
	if err != nil && strings.Contains(err.Error(), "BUSYGROUP") {
		return nil
	}
	return err
}

func (rc *Conn) XReadGroup(group string, consumer string, stream string, lastID string, count int64, block time.Duration) ([]StreamMessage, error) {
	if lastID == "" {
		lastID = ">"
	}
	result, err := rc.client.XReadGroup(&rd.XReadGroupArgs{
		Group:    group,
		Consumer: consumer,
		Streams:  []string{stream, lastID},
		Count:    count,
		Block:    block,
	}).Result()
	if err == rd.Nil {
		return nil, nil
	}
	if err != nil {
		return nil, err
	}
	messages := make([]StreamMessage, 0)
	for _, streamResult := range result {
		for _, raw := range streamResult.Messages {
			values := make(map[string]string, len(raw.Values))
			for key, value := range raw.Values {
				values[key] = fmt.Sprint(value)
			}
			messages = append(messages, StreamMessage{ID: raw.ID, Values: values})
		}
	}
	return messages, nil
}

func (rc *Conn) XAck(stream string, group string, ids ...string) error {
	if len(ids) == 0 {
		return nil
	}
	return rc.client.XAck(stream, group, ids...).Err()
}
```

- [ ] **Step 5: Run wrapper tests**

Run:

```bash
ssh ubuntu@42.194.218.158 'cd /opt/wukongim-prod/src && docker run --rm -v "$PWD":/src -w /src golang:1.20 go test ./serverlib/pkg/redis -run TestStreamFieldAndMessageShapes -count=1 -v'
```

Expected: pass.

---

## Task 2: TS-DD Message Effects Module

**Files:**
- Create: `/opt/wukongim-prod/src/modules/messageeffects/1module.go`
- Create: `/opt/wukongim-prod/src/modules/messageeffects/models.go`
- Create: `/opt/wukongim-prod/src/modules/messageeffects/stream.go`
- Create: `/opt/wukongim-prod/src/modules/messageeffects/service.go`
- Create: `/opt/wukongim-prod/src/modules/messageeffects/api.go`
- Modify: `/opt/wukongim-prod/src/internal/modules.go`
- Tests: `/opt/wukongim-prod/src/modules/messageeffects/stream_test.go`, `/opt/wukongim-prod/src/modules/messageeffects/service_test.go`

- [ ] **Step 1: Write failing stream contract tests**

Create `/opt/wukongim-prod/src/modules/messageeffects/stream_test.go`:

```go
package messageeffects

import "testing"

func TestMessagePersistedEventStreamFieldsRoundTrip(t *testing.T) {
	event := MessagePersistedEvent{
		EventID:     "message:ch-1:7:persisted",
		EventType:   EventTypeMessagePersisted,
		ChannelID:   "ch-1",
		ChannelType: 1,
		MessageID:   123,
		MessageSeq:  7,
		ClientMsgNo: "client-1",
		FromUID:     "u1",
		PayloadRef:  "db/message",
		CreatedAt:   1770000000000,
	}
	fields := event.StreamFields()
	parsed, err := MessagePersistedEventFromFields(fields)
	if err != nil {
		t.Fatalf("parse fields: %v", err)
	}
	if parsed.EventID != event.EventID || parsed.MessageSeq != event.MessageSeq || parsed.ChannelType != event.ChannelType {
		t.Fatalf("roundtrip mismatch: %#v", parsed)
	}
}

func TestConsumerGroupsAreStable(t *testing.T) {
	want := []string{"push-workers", "unread-workers", "reaction-workers"}
	got := ConsumerGroups()
	if len(got) != len(want) {
		t.Fatalf("groups=%#v", got)
	}
	for i := range want {
		if got[i] != want[i] {
			t.Fatalf("groups[%d]=%s want=%s", i, got[i], want[i])
		}
	}
}
```

Create `/opt/wukongim-prod/src/modules/messageeffects/service_test.go`:

```go
package messageeffects

import "testing"

type memoryIdempotencyStore struct {
	seen map[string]bool
}

func (s *memoryIdempotencyStore) MarkProcessed(group string, eventID string) (bool, error) {
	if s.seen == nil {
		s.seen = map[string]bool{}
	}
	key := group + ":" + eventID
	if s.seen[key] {
		return false, nil
	}
	s.seen[key] = true
	return true, nil
}

func TestProcessorSkipsDuplicateEventPerGroup(t *testing.T) {
	store := &memoryIdempotencyStore{}
	processor := NewProcessor(store)
	event := MessagePersistedEvent{EventID: "evt-1", EventType: EventTypeMessagePersisted}
	first, err := processor.Process("push-workers", event)
	if err != nil || !first {
		t.Fatalf("first process=(%v,%v), want true,nil", first, err)
	}
	second, err := processor.Process("push-workers", event)
	if err != nil || second {
		t.Fatalf("second process=(%v,%v), want false,nil", second, err)
	}
}
```

- [ ] **Step 2: Run tests and verify red**

Run:

```bash
ssh ubuntu@42.194.218.158 'cd /opt/wukongim-prod/src && docker run --rm -v "$PWD":/src -w /src golang:1.20 go test ./modules/messageeffects -count=1 -v'
```

Expected: fail because package does not exist.

- [ ] **Step 3: Implement models**

Create `/opt/wukongim-prod/src/modules/messageeffects/models.go`:

```go
package messageeffects

import (
	"errors"
	"strconv"

	serverredis "github.com/TangSengDaoDao/TangSengDaoDaoServerLib/pkg/redis"
)

const (
	StreamKey                 = "im:message:effects:v1"
	DLQStreamKey              = "im:message:effects:dlq:v1"
	EventTypeMessagePersisted = "message.persisted"
	ConsumerGroupPush         = "push-workers"
	ConsumerGroupUnread       = "unread-workers"
	ConsumerGroupReaction     = "reaction-workers"
)

type MessagePersistedEvent struct {
	EventID     string `json:"event_id"`
	EventType   string `json:"event_type"`
	ChannelID   string `json:"channel_id"`
	ChannelType int    `json:"channel_type"`
	MessageID   int64  `json:"message_id"`
	MessageSeq  uint64 `json:"message_seq"`
	ClientMsgNo string `json:"client_msg_no"`
	FromUID     string `json:"from_uid"`
	PayloadRef  string `json:"payload_ref"`
	CreatedAt   int64  `json:"created_at"`
}

func ConsumerGroups() []string {
	return []string{ConsumerGroupPush, ConsumerGroupUnread, ConsumerGroupReaction}
}

func (e MessagePersistedEvent) StreamFields() serverredis.StreamFields {
	return serverredis.StreamFields{
		"event_id":      e.EventID,
		"event_type":    e.EventType,
		"channel_id":    e.ChannelID,
		"channel_type":  strconv.Itoa(e.ChannelType),
		"message_id":    strconv.FormatInt(e.MessageID, 10),
		"message_seq":   strconv.FormatUint(e.MessageSeq, 10),
		"client_msg_no": e.ClientMsgNo,
		"from_uid":      e.FromUID,
		"payload_ref":   e.PayloadRef,
		"created_at":    strconv.FormatInt(e.CreatedAt, 10),
	}
}

func MessagePersistedEventFromFields(fields map[string]string) (MessagePersistedEvent, error) {
	if fields["event_id"] == "" {
		return MessagePersistedEvent{}, errors.New("event_id is required")
	}
	channelType, _ := strconv.Atoi(fields["channel_type"])
	messageID, _ := strconv.ParseInt(fields["message_id"], 10, 64)
	messageSeq, _ := strconv.ParseUint(fields["message_seq"], 10, 64)
	createdAt, _ := strconv.ParseInt(fields["created_at"], 10, 64)
	return MessagePersistedEvent{
		EventID:     fields["event_id"],
		EventType:   fields["event_type"],
		ChannelID:   fields["channel_id"],
		ChannelType: channelType,
		MessageID:   messageID,
		MessageSeq:  messageSeq,
		ClientMsgNo: fields["client_msg_no"],
		FromUID:     fields["from_uid"],
		PayloadRef:  fields["payload_ref"],
		CreatedAt:   createdAt,
	}, nil
}
```

- [ ] **Step 4: Implement stream and idempotency services**

Create `/opt/wukongim-prod/src/modules/messageeffects/stream.go`:

```go
package messageeffects

import (
	"time"

	serverredis "github.com/TangSengDaoDao/TangSengDaoDaoServerLib/pkg/redis"
)

type RedisConn interface {
	XAdd(stream string, fields serverredis.StreamFields) (string, error)
	XGroupCreateMkStream(stream string, group string, start string) error
	XReadGroup(group string, consumer string, stream string, lastID string, count int64, block time.Duration) ([]serverredis.StreamMessage, error)
	XAck(stream string, group string, ids ...string) error
	SetAndExpire(key string, value interface{}, expire time.Duration) error
	GetString(key string) (string, error)
}

type StreamStore struct {
	redis RedisConn
}

func NewStreamStore(redis RedisConn) *StreamStore {
	return &StreamStore{redis: redis}
}

func (s *StreamStore) EnsureGroups() error {
	for _, group := range ConsumerGroups() {
		if err := s.redis.XGroupCreateMkStream(StreamKey, group, "0"); err != nil {
			return err
		}
	}
	return nil
}

func (s *StreamStore) Publish(event MessagePersistedEvent) (string, error) {
	return s.redis.XAdd(StreamKey, event.StreamFields())
}
```

Create `/opt/wukongim-prod/src/modules/messageeffects/service.go`:

```go
package messageeffects

import "time"

type IdempotencyStore interface {
	MarkProcessed(group string, eventID string) (bool, error)
}

type redisIdempotencyStore struct {
	redis RedisConn
}

func NewRedisIdempotencyStore(redis RedisConn) IdempotencyStore {
	return &redisIdempotencyStore{redis: redis}
}

func (s *redisIdempotencyStore) MarkProcessed(group string, eventID string) (bool, error) {
	key := "im:message:effects:processed:" + group + ":" + eventID
	current, err := s.redis.GetString(key)
	if err != nil {
		return false, err
	}
	if current != "" {
		return false, nil
	}
	if err := s.redis.SetAndExpire(key, "1", 30*24*time.Hour); err != nil {
		return false, err
	}
	return true, nil
}

type Processor struct {
	idempotency IdempotencyStore
}

func NewProcessor(idempotency IdempotencyStore) *Processor {
	return &Processor{idempotency: idempotency}
}

func (p *Processor) Process(group string, event MessagePersistedEvent) (bool, error) {
	if event.EventID == "" {
		return false, nil
	}
	return p.idempotency.MarkProcessed(group, event.EventID)
}
```

- [ ] **Step 5: Implement internal ingest API and module registration**

Create `/opt/wukongim-prod/src/modules/messageeffects/api.go`:

```go
package messageeffects

import (
	"errors"
	"net/http"
	"strings"

	"github.com/TangSengDaoDao/TangSengDaoDaoServerLib/config"
	"github.com/TangSengDaoDao/TangSengDaoDaoServerLib/pkg/log"
	"github.com/TangSengDaoDao/TangSengDaoDaoServerLib/pkg/wkhttp"
	"github.com/gin-gonic/gin"
	"go.uber.org/zap"
)

type API struct {
	ctx   *config.Context
	Log   log.Log
	store *StreamStore
}

func NewAPI(ctx *config.Context) *API {
	return &API{ctx: ctx, Log: log.NewTLog("MessageEffects"), store: NewStreamStore(ctx.GetRedisConn())}
}

func (a *API) Route(r *wkhttp.WKHttp) {
	internal := r.Group("/v1/internal/message-effects")
	internal.POST("/persisted", a.persisted)
}

func (a *API) persisted(c *wkhttp.Context) {
	if strings.TrimSpace(c.GetHeader("X-Message-Effects-Token")) == "" {
		c.JSON(http.StatusUnauthorized, gin.H{"error": gin.H{"code": "unauthorized", "message": "message effects token is required"}})
		return
	}
	var req MessagePersistedEvent
	if err := c.BindJSON(&req); err != nil {
		c.ResponseError(errors.New("invalid message effects payload"))
		return
	}
	if req.EventID == "" || req.EventType != EventTypeMessagePersisted {
		c.ResponseError(errors.New("invalid message effects event"))
		return
	}
	if err := a.store.EnsureGroups(); err != nil {
		a.Error("ensure stream groups failed", zap.Error(err))
		c.ResponseError(err)
		return
	}
	if _, err := a.store.Publish(req); err != nil {
		a.Error("publish message effect failed", zap.Error(err))
		c.ResponseError(err)
		return
	}
	c.Response(map[string]bool{"ok": true})
}
```

Create `/opt/wukongim-prod/src/modules/messageeffects/1module.go`:

```go
package messageeffects

import (
	"github.com/TangSengDaoDao/TangSengDaoDaoServerLib/config"
	"github.com/TangSengDaoDao/TangSengDaoDaoServerLib/pkg/register"
)

func init() {
	register.AddModule(func(ctx interface{}) register.Module {
		api := NewAPI(ctx.(*config.Context))
		return register.Module{
			Name: "messageeffects",
			SetupAPI: func() register.APIRouter {
				return api
			},
		}
	})
}
```

Modify `/opt/wukongim-prod/src/internal/modules.go` and add this blank import:

```go
_ "github.com/TangSengDaoDao/TangSengDaoDaoServer/modules/messageeffects"
```

- [ ] **Step 6: Run tests and compile smoke**

Run:

```bash
ssh ubuntu@42.194.218.158 'cd /opt/wukongim-prod/src && docker run --rm -v "$PWD":/src -w /src golang:1.20 go test ./serverlib/pkg/redis ./modules/messageeffects -count=1 -v'
```

Expected: pass.

---

## Task 3: WuKongIM Core Outbox and Relay

**Files:**
- Create: `/home/ubuntu/wukongim-build-src-uploaded/internal/messageeffects/outbox.go`
- Create: `/home/ubuntu/wukongim-build-src-uploaded/internal/messageeffects/outbox_test.go`
- Create: `/home/ubuntu/wukongim-build-src-uploaded/internal/messageeffects/relay.go`
- Create: `/home/ubuntu/wukongim-build-src-uploaded/internal/messageeffects/relay_test.go`
- Create: `/home/ubuntu/wukongim-build-src-uploaded/internal/messageeffects/options.go`
- Modify: `/home/ubuntu/wukongim-build-src-uploaded/internal/options/options.go`
- Create: `/home/ubuntu/wukongim-build-src-uploaded/internal/service/message_effects.go`
- Modify: `/home/ubuntu/wukongim-build-src-uploaded/internal/server/server.go`
- Modify: `/home/ubuntu/wukongim-build-src-uploaded/internal/channel/handler/event_persist.go`

- [ ] **Step 1: Backup WuKongIM core**

Run:

```bash
ssh ubuntu@42.194.218.158 'set -euo pipefail; cd /home/ubuntu/wukongim-build-src-uploaded; ts=$(date +%Y%m%d%H%M%S); mkdir -p /home/ubuntu/wukongim-phase4-backups/$ts; git status --short > /home/ubuntu/wukongim-phase4-backups/$ts/pre-status.txt; git diff > /home/ubuntu/wukongim-phase4-backups/$ts/pre.diff; cp -a internal/channel/handler internal/options internal/server internal/service /home/ubuntu/wukongim-phase4-backups/$ts/; echo /home/ubuntu/wukongim-phase4-backups/$ts'
```

Expected: backup path printed.

- [ ] **Step 2: Write failing outbox test**

Create `/home/ubuntu/wukongim-build-src-uploaded/internal/messageeffects/outbox_test.go`:

```go
package messageeffects

import "testing"

func TestFileOutboxAppendReadMarkSent(t *testing.T) {
	outbox := NewFileOutbox(t.TempDir())
	event := Event{
		EventID:     "message:ch:1:persisted",
		EventType:   "message.persisted",
		ChannelID:   "ch",
		ChannelType: 1,
		MessageID:   10,
		MessageSeq:  1,
		FromUID:     "u1",
		PayloadRef:  "db/message",
		CreatedAt:   1770000000000,
	}
	if err := outbox.Append(event); err != nil {
		t.Fatalf("Append: %v", err)
	}
	batch, err := outbox.Pending(10)
	if err != nil {
		t.Fatalf("Pending: %v", err)
	}
	if len(batch) != 1 || batch[0].EventID != event.EventID {
		t.Fatalf("unexpected batch: %#v", batch)
	}
	if err := outbox.MarkSent(batch[0].OutboxID); err != nil {
		t.Fatalf("MarkSent: %v", err)
	}
	batch, err = outbox.Pending(10)
	if err != nil {
		t.Fatalf("Pending after sent: %v", err)
	}
	if len(batch) != 0 {
		t.Fatalf("sent event still pending: %#v", batch)
	}
}
```

- [ ] **Step 3: Run outbox test and verify red**

Run:

```bash
ssh ubuntu@42.194.218.158 'cd /home/ubuntu/wukongim-build-src-uploaded && docker run --rm -v "$PWD":/src -w /src golang:1.23 go test ./internal/messageeffects -run TestFileOutboxAppendReadMarkSent -count=1 -v'
```

Expected: fail because package does not exist.

- [ ] **Step 4: Implement durable file outbox**

Create `/home/ubuntu/wukongim-build-src-uploaded/internal/messageeffects/outbox.go`:

```go
package messageeffects

import (
	"encoding/json"
	"errors"
	"os"
	"path/filepath"
	"sort"
	"time"

	"github.com/google/uuid"
)

type Event struct {
	OutboxID    string `json:"outbox_id"`
	EventID     string `json:"event_id"`
	EventType   string `json:"event_type"`
	ChannelID   string `json:"channel_id"`
	ChannelType uint8  `json:"channel_type"`
	MessageID   int64  `json:"message_id"`
	MessageSeq  uint64 `json:"message_seq"`
	ClientMsgNo string `json:"client_msg_no"`
	FromUID     string `json:"from_uid"`
	PayloadRef  string `json:"payload_ref"`
	CreatedAt   int64  `json:"created_at"`
}

type FileOutbox struct {
	dir string
}

func NewFileOutbox(dir string) *FileOutbox {
	return &FileOutbox{dir: dir}
}

func (o *FileOutbox) Append(event Event) error {
	if event.EventID == "" {
		return errors.New("event_id is required")
	}
	if event.OutboxID == "" {
		event.OutboxID = time.Now().UTC().Format("20060102150405.000000000") + "-" + uuid.NewString()
	}
	if event.CreatedAt == 0 {
		event.CreatedAt = time.Now().UnixMilli()
	}
	if err := os.MkdirAll(o.pendingDir(), 0o755); err != nil {
		return err
	}
	data, err := json.Marshal(event)
	if err != nil {
		return err
	}
	tmp := filepath.Join(o.pendingDir(), event.OutboxID+".tmp")
	finalPath := filepath.Join(o.pendingDir(), event.OutboxID+".json")
	if err := os.WriteFile(tmp, data, 0o644); err != nil {
		return err
	}
	return os.Rename(tmp, finalPath)
}

func (o *FileOutbox) Pending(limit int) ([]Event, error) {
	if limit <= 0 {
		limit = 100
	}
	entries, err := os.ReadDir(o.pendingDir())
	if os.IsNotExist(err) {
		return nil, nil
	}
	if err != nil {
		return nil, err
	}
	sort.Slice(entries, func(i int, j int) bool { return entries[i].Name() < entries[j].Name() })
	events := make([]Event, 0, limit)
	for _, entry := range entries {
		if entry.IsDir() || filepath.Ext(entry.Name()) != ".json" {
			continue
		}
		data, err := os.ReadFile(filepath.Join(o.pendingDir(), entry.Name()))
		if err != nil {
			return nil, err
		}
		var event Event
		if err := json.Unmarshal(data, &event); err != nil {
			return nil, err
		}
		events = append(events, event)
		if len(events) >= limit {
			break
		}
	}
	return events, nil
}

func (o *FileOutbox) MarkSent(outboxID string) error {
	if outboxID == "" {
		return errors.New("outbox_id is required")
	}
	if err := os.MkdirAll(o.sentDir(), 0o755); err != nil {
		return err
	}
	return os.Rename(filepath.Join(o.pendingDir(), outboxID+".json"), filepath.Join(o.sentDir(), outboxID+".json"))
}

func (o *FileOutbox) pendingDir() string { return filepath.Join(o.dir, "pending") }
func (o *FileOutbox) sentDir() string    { return filepath.Join(o.dir, "sent") }
```

- [ ] **Step 5: Write relay test and implement relay**

Create `/home/ubuntu/wukongim-build-src-uploaded/internal/messageeffects/relay_test.go`:

```go
package messageeffects

import (
	"net/http"
	"net/http/httptest"
	"testing"
)

func TestRelayPostsEventAndMarksSent(t *testing.T) {
	outbox := NewFileOutbox(t.TempDir())
	if err := outbox.Append(Event{EventID: "message:ch:1:persisted", EventType: "message.persisted"}); err != nil {
		t.Fatal(err)
	}
	seenToken := ""
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		seenToken = r.Header.Get("X-Message-Effects-Token")
		if r.URL.Path != "/v1/internal/message-effects/persisted" {
			t.Fatalf("path=%s", r.URL.Path)
		}
		w.WriteHeader(http.StatusOK)
	}))
	defer server.Close()
	relay := NewRelay(outbox, RelayOptions{URL: server.URL + "/v1/internal/message-effects/persisted", Token: "secret", BatchSize: 10})
	if err := relay.FlushOnce(); err != nil {
		t.Fatalf("FlushOnce: %v", err)
	}
	if seenToken != "secret" {
		t.Fatalf("token=%q", seenToken)
	}
	pending, err := outbox.Pending(10)
	if err != nil || len(pending) != 0 {
		t.Fatalf("pending=(%#v,%v)", pending, err)
	}
}
```

Create `/home/ubuntu/wukongim-build-src-uploaded/internal/messageeffects/options.go`:

```go
package messageeffects

import "time"

type RelayOptions struct {
	URL       string
	Token     string
	Interval  time.Duration
	BatchSize int
}
```

Create `/home/ubuntu/wukongim-build-src-uploaded/internal/messageeffects/relay.go` implementing:

- `func NewRelay(outbox *FileOutbox, opts RelayOptions) *Relay`
- `func (r *Relay) Append(event Event) error`
- `func (r *Relay) FlushOnce() error`
- `func (r *Relay) Start()`
- `func (r *Relay) Stop()`

`FlushOnce` must read pending events, JSON POST each one to `opts.URL`, include `X-Message-Effects-Token`, mark sent only after HTTP 2xx, and keep files pending on any HTTP or non-2xx failure.

- [ ] **Step 6: Run core package tests**

Run:

```bash
ssh ubuntu@42.194.218.158 'cd /home/ubuntu/wukongim-build-src-uploaded && docker run --rm -v "$PWD":/src -w /src golang:1.23 go test ./internal/messageeffects -count=1 -v'
```

Expected: pass.

- [ ] **Step 7: Wire options, service global, server lifecycle, and persist hook**

Modify `/home/ubuntu/wukongim-build-src-uploaded/internal/options/options.go`:

- Add `MessageEffects` struct to `Options` with fields `On`, `OutboxDir`, `RelayURL`, `RelayToken`, `RelayInterval`, `RelayBatchSize`.
- Set defaults: `On=false`, `RelayInterval=2s`, `RelayBatchSize=100`.
- Read viper keys:
  - `messageEffects.on`
  - `messageEffects.outboxDir`
  - `messageEffects.relayURL`
  - `messageEffects.relayToken`
  - `messageEffects.relayInterval`
  - `messageEffects.relayBatchSize`
- If `OutboxDir` is empty, set it to `path.Join(o.DataDir, "message-effects-outbox")`.

Create `/home/ubuntu/wukongim-build-src-uploaded/internal/service/message_effects.go`:

```go
package service

import "github.com/WuKongIM/WuKongIM/internal/messageeffects"

type IMessageEffects interface {
	Append(messageeffects.Event) error
}

var MessageEffects IMessageEffects
```

Modify `/home/ubuntu/wukongim-build-src-uploaded/internal/server/server.go`:

- Import `github.com/WuKongIM/WuKongIM/internal/messageeffects`.
- Add `messageEffectsRelay *messageeffects.Relay` field to `Server`.
- In `New`, when `opts.MessageEffects.On` is true, create outbox and relay, assign `s.messageEffectsRelay`, and assign `service.MessageEffects = relay`.
- In `Start`, call `s.messageEffectsRelay.Start()` before event pools start when relay is not nil.
- In `Stop`, call `s.messageEffectsRelay.Stop()` when relay is not nil.

Modify `/home/ubuntu/wukongim-build-src-uploaded/internal/channel/handler/event_persist.go`:

- Add imports `fmt` and `github.com/WuKongIM/WuKongIM/internal/messageeffects`.
- After message sequences are filled and before plugin invoke, append an outbox event per persisted message:

```go
if service.MessageEffects != nil {
	for _, msg := range persists {
		if msg.MessageSeq == 0 {
			continue
		}
		eventID := fmt.Sprintf("message:%s:%d:persisted", msg.ChannelID, msg.MessageSeq)
		err := service.MessageEffects.Append(messageeffects.Event{
			EventID:     eventID,
			EventType:   "message.persisted",
			ChannelID:   msg.ChannelID,
			ChannelType: msg.ChannelType,
			MessageID:   msg.MessageID,
			MessageSeq:  uint64(msg.MessageSeq),
			ClientMsgNo: msg.ClientMsgNo,
			FromUID:     msg.FromUID,
			PayloadRef:  "db/message",
			CreatedAt:   time.Now().UnixMilli(),
		})
		if err != nil {
			h.Error("message effects outbox append failed", zap.Error(err), zap.String("eventID", eventID))
		}
	}
}
```

- [ ] **Step 8: Add deployment config**

Modify `/opt/wukongim-prod/src/deploy/production/config/wk.yaml.tpl`:

```yaml
messageEffects:
  on: true
  outboxDir: "/root/wukongim/data/message-effects-outbox"
  relayURL: "http://tsdd-api:8090/v1/internal/message-effects/persisted"
  relayToken: "{{WK_MANAGER_TOKEN}}"
  relayInterval: 2s
  relayBatchSize: 100
```

- [ ] **Step 9: Verify core compile and image build**

Run:

```bash
ssh ubuntu@42.194.218.158 'cd /home/ubuntu/wukongim-build-src-uploaded && docker run --rm -v "$PWD":/src -w /src golang:1.23 go test ./internal/messageeffects ./internal/options -count=1'
```

Expected: pass.

---

## Task 4: Server Multipart Hardening and Nginx Streaming

**Files:**
- Modify: `/opt/wukongim-prod/src/modules/file/multipart_temp_store.go`
- Modify: `/opt/wukongim-prod/src/modules/file/service.go`
- Modify: `/opt/wukongim-prod/src/modules/file/api.go`
- Modify: `/opt/wukongim-prod/src/deploy/production/nginx/default.conf.template`
- Tests: `/opt/wukongim-prod/src/modules/file/multipart_service_test.go`, `/opt/wukongim-prod/src/modules/file/multipart_temp_store_test.go`

- [ ] **Step 1: Write failing multipart tests**

Append to `/opt/wukongim-prod/src/modules/file/multipart_service_test.go`:

```go
func TestServiceMultipartInitReusesFingerprintSessionAndReturnsUploadedParts(t *testing.T) {
	service := &Service{uploadService: &captureUploadService{}, multipartStore: newTempMultipartStore(t.TempDir())}
	first, err := service.InitiateMultipartUploadWithFingerprint("chat/user-a/big.bin", "application/octet-stream", 9, 3, "fp-1")
	if err != nil {
		t.Fatalf("first init: %v", err)
	}
	uploadID := first["upload_id"].(string)
	if err := service.UploadMultipartPart("chat/user-a/big.bin", uploadID, 1, strings.NewReader("aaa")); err != nil {
		t.Fatal(err)
	}
	second, err := service.InitiateMultipartUploadWithFingerprint("chat/user-a/big.bin", "application/octet-stream", 9, 3, "fp-1")
	if err != nil {
		t.Fatalf("second init: %v", err)
	}
	if second["upload_id"] != uploadID {
		t.Fatalf("upload_id=%v want %s", second["upload_id"], uploadID)
	}
	parts := second["uploaded_parts"].([]int)
	if len(parts) != 1 || parts[0] != 1 {
		t.Fatalf("uploaded_parts=%#v", parts)
	}
}

func TestServiceMultipartCompleteRejectsMissingPart(t *testing.T) {
	service := &Service{uploadService: &captureUploadService{}, multipartStore: newTempMultipartStore(t.TempDir())}
	session, err := service.InitiateMultipartUpload("chat/user-a/big.bin", "application/octet-stream", 9, 3)
	if err != nil {
		t.Fatal(err)
	}
	uploadID := session["upload_id"].(string)
	if err := service.UploadMultipartPart("chat/user-a/big.bin", uploadID, 1, strings.NewReader("aaa")); err != nil {
		t.Fatal(err)
	}
	if _, err := service.CompleteMultipartUpload("chat/user-a/big.bin", "application/octet-stream", uploadID, []int{1, 2, 3}); err == nil {
		t.Fatal("CompleteMultipartUpload accepted missing parts")
	}
}
```

- [ ] **Step 2: Run multipart tests and verify red**

Run:

```bash
ssh ubuntu@42.194.218.158 'cd /opt/wukongim-prod/src && docker run --rm -v "$PWD":/src -w /src golang:1.20 go test ./modules/file -run Multipart -count=1 -v'
```

Expected: fail because `InitiateMultipartUploadWithFingerprint` does not exist.

- [ ] **Step 3: Implement fingerprint reuse and uploaded parts**

Modify `/opt/wukongim-prod/src/modules/file/multipart_temp_store.go`:

- Add to `multipartUploadSession`: `Fingerprint string`.
- Add `CreateWithFingerprint(filePath, contentType string, fileSize, chunkSize int64, fingerprint string)`.
- Add `FindReusable(filePath string, fileSize int64, chunkSize int64, fingerprint string)`.
- Add `UploadedParts(uploadID string) ([]int, error)` that calls existing `listMultipartParts`.

Exact matching rule for `FindReusable`: `FilePath`, `FileSize`, `ChunkSize`, and non-empty `Fingerprint` all match. Return `nil, nil` when no reusable session exists.

Modify `/opt/wukongim-prod/src/modules/file/service.go`:

- Add `InitiateMultipartUploadWithFingerprint`.
- Make existing `InitiateMultipartUpload` call it with empty fingerprint.
- Response map must include `uploaded_parts` as `[]int`.

Modify `/opt/wukongim-prod/src/modules/file/api.go`:

- Add `Fingerprint string` to `multipartInitReq`.
- Call `InitiateMultipartUploadWithFingerprint`.

- [ ] **Step 4: Add Nginx streaming location**

Insert before generic `/v1/` location in `/opt/wukongim-prod/src/deploy/production/nginx/default.conf.template`:

```nginx
    location = /v1/file/multipart/part {
        proxy_pass http://tsdd_api;
        proxy_http_version 1.1;
        proxy_request_buffering off;
        client_body_buffer_size 512k;
        proxy_read_timeout 300s;
        proxy_send_timeout 300s;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto https;
    }
```

- [ ] **Step 5: Verify multipart and config**

Run:

```bash
ssh ubuntu@42.194.218.158 'cd /opt/wukongim-prod/src && docker run --rm -v "$PWD":/src -w /src golang:1.20 go test ./modules/file -run Multipart -count=1 -v'
ssh ubuntu@42.194.218.158 'cd /opt/wukongim-prod/src/deploy/production && python3 scripts/render_config.py && docker compose config >/tmp/phase4-compose-config.txt'
```

Expected: both commands pass.

---

## Task 5: Flutter Multipart Concurrency, Retry, and Reconcile

**Files:**
- Modify: `C:\Users\COLORFUL\Desktop\WuKong\.worktrees\phase-4-server-media-call\lib\core\upload\multipart_upload_models.dart`
- Modify: `C:\Users\COLORFUL\Desktop\WuKong\.worktrees\phase-4-server-media-call\lib\data\upload\resumable_file_uploader.dart`
- Modify: `C:\Users\COLORFUL\Desktop\WuKong\.worktrees\phase-4-server-media-call\lib\service\api\file_multipart_upload_client.dart`
- Tests: `test\data\upload\resumable_file_uploader_test.dart`, `test\service\api\file_multipart_upload_client_test.dart`

- [ ] **Step 1: Write failing Flutter upload tests**

Append to `test\data\upload\resumable_file_uploader_test.dart`:

```dart
test('resumable uploader limits concurrent part uploads to three and retries failed parts', () async {
  final directory = await Directory.systemTemp.createTemp('resumable_concurrency_test_');
  addTearDown(() => directory.delete(recursive: true));
  final file = File('${directory.path}${Platform.pathSeparator}concurrent.bin');
  await file.writeAsBytes(List<int>.generate(12, (index) => index));

  final client = _RecordingMultipartClient(
    createdUploadId: 'upload-concurrent',
    completedUrl: 'https://cdn.example.com/concurrent.bin',
  )
    ..delayUploads = true
    ..failuresBeforeSuccess[2] = 1;
  final uploader = ResumableFileUploader(
    client: client,
    checkpointStore: MemoryResumableUploadStore(),
    chunkSizeBytes: 2,
    maxConcurrentParts: 3,
    retryBaseDelay: Duration.zero,
    fingerprintResolver: (_) async => 'fp-concurrent',
  );

  final result = await uploader.upload(
    filePath: file.path,
    fileType: 'chat',
    objectPath: '/chat/c1/concurrent.bin',
  );

  expect(result, 'https://cdn.example.com/concurrent.bin');
  expect(client.maxInFlightUploads, lessThanOrEqualTo(3));
  expect(client.uploadAttempts[2], 2);
  expect(client.completedUploadId, 'upload-concurrent');
});

test('resumable uploader reconciles uploaded parts returned by init when checkpoint exists', () async {
  final directory = await Directory.systemTemp.createTemp('resumable_reconcile_test_');
  addTearDown(() => directory.delete(recursive: true));
  final file = File('${directory.path}${Platform.pathSeparator}reconcile.bin');
  await file.writeAsBytes(<int>[1, 2, 3, 4, 5, 6]);
  final store = MemoryResumableUploadStore();
  await store.save(const ResumableUploadCheckpoint(
    fingerprint: 'fp-reconcile',
    uploadId: 'old-upload',
    objectPath: '/chat/c1/reconcile.bin',
    fileSizeBytes: 6,
    chunkSizeBytes: 2,
    uploadedPartNumbers: <int>{1},
  ));
  final client = _RecordingMultipartClient(
    createdUploadId: 'server-upload',
    completedUrl: 'https://cdn.example.com/reconcile.bin',
  )..serverUploadedParts = <int>{1, 2};
  final uploader = ResumableFileUploader(
    client: client,
    checkpointStore: store,
    chunkSizeBytes: 2,
    fingerprintResolver: (_) async => 'fp-reconcile',
  );

  await uploader.upload(filePath: file.path, fileType: 'chat', objectPath: '/chat/c1/reconcile.bin');

  expect(client.initCallCount, 1);
  expect(client.uploadedPartNumbers, <int>[3]);
});
```

Extend the fake client in the same test file:

```dart
bool delayUploads = false;
int inFlightUploads = 0;
int maxInFlightUploads = 0;
final Map<int, int> uploadAttempts = <int, int>{};
final Map<int, int> failuresBeforeSuccess = <int, int>{};
Set<int> serverUploadedParts = const <int>{};
```

In fake `initiate`, return `uploadedPartNumbers: serverUploadedParts`. In fake `uploadPart`, increment/decrement in-flight in `try/finally`, track attempts, throw until configured failures are consumed, then record bytes.

- [ ] **Step 2: Run red tests**

Run:

```powershell
cd C:\Users\COLORFUL\Desktop\WuKong\.worktrees\phase-4-server-media-call
flutter test test/data/upload/resumable_file_uploader_test.dart
```

Expected: fail because new constructor args and behavior do not exist.

- [ ] **Step 3: Implement additive model and API field**

Modify `MultipartUploadInitRequest`:

```dart
const MultipartUploadInitRequest({
  required this.fileType,
  required this.objectPath,
  required this.fileSizeBytes,
  required this.chunkSizeBytes,
  this.fingerprint = '',
});

final String fingerprint;
```

Modify `FileMultipartUploadClient.initiate` body:

```dart
'fingerprint': request.fingerprint,
```

Update `test\service\api\file_multipart_upload_client_test.dart` to pass `fingerprint: 'fp-api'` and assert:

```dart
expect(adapter.initBody['fingerprint'], 'fp-api');
```

- [ ] **Step 4: Implement uploader concurrency and retry**

Modify `ResumableFileUploader` constructor to add:

```dart
this.maxConcurrentParts = 3,
this.maxPartAttempts = 5,
this.retryBaseDelay = const Duration(milliseconds: 250),
Random? retryRandom,
```

Add fields:

```dart
final int maxConcurrentParts;
final int maxPartAttempts;
final Duration retryBaseDelay;
final Random _retryRandom;
```

Behavior changes:
- Always call `initiate` with fingerprint to reconcile server `uploadedPartNumbers`.
- Merge checkpoint uploaded parts and server uploaded parts.
- Upload pending parts with at most `maxConcurrentParts`.
- Retry each part up to `maxPartAttempts` with exponential delay; when `retryBaseDelay` is zero, do not sleep.
- Save checkpoint only after part upload succeeds.
- Progress counts confirmed parts only.

- [ ] **Step 5: Verify and commit local upload slice**

Run:

```powershell
cd C:\Users\COLORFUL\Desktop\WuKong\.worktrees\phase-4-server-media-call
flutter test test/data/upload/resumable_file_uploader_test.dart test/service/api/file_multipart_upload_client_test.dart
git add lib/core/upload/multipart_upload_models.dart lib/data/upload/resumable_file_uploader.dart lib/service/api/file_multipart_upload_client.dart test/data/upload/resumable_file_uploader_test.dart test/service/api/file_multipart_upload_client_test.dart
git commit -m "feat: harden resumable multipart uploads"
```

Expected: tests pass and commit contains only upload-related files.

---

## Task 6: TS-DD Call Telemetry API

**Files:**
- Modify: `/opt/wukongim-prod/src/modules/extra/models.go`
- Modify: `/opt/wukongim-prod/src/modules/extra/db.go`
- Modify: `/opt/wukongim-prod/src/modules/extra/api.go`
- Create: `/opt/wukongim-prod/src/modules/extra/sql/extra-20260504-01.sql`
- Test: `/opt/wukongim-prod/src/modules/extra/api_call_telemetry_test.go`

- [ ] **Step 1: Write failing telemetry tests**

Create `/opt/wukongim-prod/src/modules/extra/api_call_telemetry_test.go`:

```go
package extra

import "testing"

type fakeTelemetryStore struct {
	last *CallTelemetryModel
}

func (f *fakeTelemetryStore) InsertCallTelemetry(m *CallTelemetryModel) error {
	f.last = m
	return nil
}

func TestValidateCallTelemetryRejectsUnknownReason(t *testing.T) {
	req := CallTelemetryReq{RoomID: "room-1", CallID: "call-1", Event: "call.failed", State: "failed", Reason: "random-text", CreatedAt: 1770000000000}
	if err := validateCallTelemetry(req); err == nil {
		t.Fatal("validateCallTelemetry accepted unknown reason")
	}
}

func TestHandleCallTelemetryPersistsStablePayload(t *testing.T) {
	store := &fakeTelemetryStore{}
	api := &API{telemetryStore: store}
	req := CallTelemetryReq{
		RoomID:      "room-1",
		CallID:      "call-1",
		UID:         "u1",
		Event:       "call.livekit.connected",
		State:       "connected",
		DurationMS:  1234,
		NetworkType: "wifi",
		SDK:         "livekit_client",
		Platform:    "android",
		Stats:       map[string]interface{}{"participant_count": float64(2)},
		CreatedAt:   1770000000000,
	}
	if err := api.handleCallTelemetry("u1", req); err != nil {
		t.Fatalf("handleCallTelemetry: %v", err)
	}
	if store.last == nil || store.last.RoomID != "room-1" || store.last.Event != "call.livekit.connected" || store.last.State != "connected" {
		t.Fatalf("unexpected stored telemetry: %#v", store.last)
	}
}
```

- [ ] **Step 2: Run red tests**

Run:

```bash
ssh ubuntu@42.194.218.158 'cd /opt/wukongim-prod/src && docker run --rm -v "$PWD":/src -w /src golang:1.20 go test ./modules/extra -run CallTelemetry -count=1 -v'
```

Expected: fail because telemetry types/functions do not exist.

- [ ] **Step 3: Implement models, DB, validation, and route**

Add `CallTelemetryModel` and `CallTelemetryReq` to `/opt/wukongim-prod/src/modules/extra/models.go`.

Add repository interface to `/opt/wukongim-prod/src/modules/extra/api.go`:

```go
type telemetryRepository interface {
	InsertCallTelemetry(*CallTelemetryModel) error
}
```

Add `telemetryStore telemetryRepository` to `API`, initialize it in `NewAPI`, and register:

```go
auth.POST("/call/telemetry", a.createCallTelemetry)
```

Allowed states:

```go
var allowedCallTelemetryStates = map[string]bool{
	"idle": true, "ringing": true, "connecting": true, "connected": true,
	"reconnecting": true, "ended": true, "failed": true,
}
```

Allowed reasons:

```go
var allowedCallTelemetryReasons = map[string]bool{
	"": true, "declined": true, "cancelled": true, "timeout": true,
	"ice_failed": true, "token_invalid": true, "permission_denied": true,
	"network_lost": true, "livekit_connect_failed": true,
	"signaling_failed": true, "unknown": true,
}
```

Implement `createCallTelemetry`, `handleCallTelemetry`, and `validateCallTelemetry`. `createCallTelemetry` uses `c.GetLoginUID()`, binds JSON, calls handler, and responds with `map[string]bool{"ok": true}`.

Add to `/opt/wukongim-prod/src/modules/extra/db.go`:

```go
func (d *DB) InsertCallTelemetry(m *CallTelemetryModel) error {
	_, err := d.session.InsertInto("call_telemetry").
		Columns("room_id", "call_id", "uid", "event", "state", "reason", "duration_ms", "network_type", "sdk", "platform", "stats").
		Record(m).Exec()
	return err
}
```

Create SQL migration `/opt/wukongim-prod/src/modules/extra/sql/extra-20260504-01.sql`:

```sql
-- +migrate Up
CREATE TABLE IF NOT EXISTS `call_telemetry` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `room_id` varchar(128) NOT NULL DEFAULT '',
  `call_id` varchar(128) NOT NULL DEFAULT '',
  `uid` varchar(64) NOT NULL DEFAULT '',
  `event` varchar(64) NOT NULL DEFAULT '',
  `state` varchar(32) NOT NULL DEFAULT '',
  `reason` varchar(64) NOT NULL DEFAULT '',
  `duration_ms` bigint NOT NULL DEFAULT 0,
  `network_type` varchar(32) NOT NULL DEFAULT '',
  `sdk` varchar(64) NOT NULL DEFAULT '',
  `platform` varchar(32) NOT NULL DEFAULT '',
  `stats` json NULL,
  `created_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `call_telemetry_room_created_idx` (`room_id`, `created_at`),
  KEY `call_telemetry_call_created_idx` (`call_id`, `created_at`),
  KEY `call_telemetry_event_reason_idx` (`event`, `reason`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- +migrate Down
DROP TABLE IF EXISTS `call_telemetry`;
```

- [ ] **Step 4: Verify telemetry tests**

Run:

```bash
ssh ubuntu@42.194.218.158 'cd /opt/wukongim-prod/src && docker run --rm -v "$PWD":/src -w /src golang:1.20 go test ./modules/extra -run CallTelemetry -count=1 -v'
```

Expected: pass.

---

## Task 7: Flutter Call Telemetry Reporter and LiveKit State Stream

**Files:**
- Create: `C:\Users\COLORFUL\Desktop\WuKong\.worktrees\phase-4-server-media-call\lib\realtime\call\call_telemetry_models.dart`
- Create: `C:\Users\COLORFUL\Desktop\WuKong\.worktrees\phase-4-server-media-call\lib\realtime\call\call_telemetry_reporter.dart`
- Modify: `C:\Users\COLORFUL\Desktop\WuKong\.worktrees\phase-4-server-media-call\lib\service\api\call_api.dart`
- Modify: `C:\Users\COLORFUL\Desktop\WuKong\.worktrees\phase-4-server-media-call\lib\modules\video_call\media\call_media_engine.dart`
- Modify: `C:\Users\COLORFUL\Desktop\WuKong\.worktrees\phase-4-server-media-call\lib\modules\video_call\media\livekit_call_media_engine.dart`
- Modify: `C:\Users\COLORFUL\Desktop\WuKong\.worktrees\phase-4-server-media-call\lib\modules\video_call\call_session_service.dart`
- Tests: `test\realtime\call\call_telemetry_reporter_test.dart`, `test\modules\video_call\livekit_call_media_engine_test.dart`, `test\modules\video_call\call_session_service_test.dart`

- [ ] **Step 1: Write failing reporter test**

Create `test\realtime\call\call_telemetry_reporter_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:wukong_im_app/data/models/call.dart';
import 'package:wukong_im_app/realtime/call/call_state_machine.dart';
import 'package:wukong_im_app/realtime/call/call_store.dart';
import 'package:wukong_im_app/realtime/call/call_telemetry_models.dart';
import 'package:wukong_im_app/realtime/call/call_telemetry_reporter.dart';

void main() {
  test('reporter maps call store and media states to stable telemetry events', () async {
    final sent = <CallTelemetryPayload>[];
    final store = CallStore(machine: const CallStateMachine());
    addTearDown(store.dispose);
    final reporter = CallTelemetryReporter(store: store, send: (payload) async => sent.add(payload));
    addTearDown(reporter.dispose);

    store.apply(const CallEvent.localDial(roomId: 'room-1', peerUid: 'u2', peerName: 'Peer', callType: CallType.video));
    await reporter.recordMediaState(roomId: 'room-1', state: CallMediaConnectionState.connected, stats: const <String, dynamic>{'participant_count': 2});

    expect(sent.map((e) => e.event), containsAll(<String>['call.dial.started', 'call.livekit.connected']));
    expect(sent.last.state, CallTelemetryState.connected);
    expect(sent.last.stats['participant_count'], 2);
  });

  test('reporter swallows send failures and keeps bounded pending history', () async {
    final store = CallStore(machine: const CallStateMachine());
    addTearDown(store.dispose);
    final reporter = CallTelemetryReporter(
      store: store,
      maxPendingEvents: 2,
      send: (_) async => throw StateError('network'),
    );
    addTearDown(reporter.dispose);
    store.apply(const CallEvent.localDial(roomId: 'room-1', peerUid: 'u2', peerName: 'Peer', callType: CallType.audio));
    await reporter.recordFailure(roomId: 'room-1', reason: CallTelemetryFailureReason.networkLost);
    await reporter.recordFailure(roomId: 'room-1', reason: CallTelemetryFailureReason.livekitConnectFailed);
    expect(reporter.pendingCount, 2);
  });
}
```

- [ ] **Step 2: Run red test**

Run:

```powershell
cd C:\Users\COLORFUL\Desktop\WuKong\.worktrees\phase-4-server-media-call
flutter test test/realtime/call/call_telemetry_reporter_test.dart
```

Expected: fail because telemetry files do not exist.

- [ ] **Step 3: Implement telemetry models**

Create `lib\realtime\call\call_telemetry_models.dart`:

```dart
enum CallTelemetryState { idle, ringing, connecting, connected, reconnecting, ended, failed }

enum CallTelemetryFailureReason {
  declined,
  cancelled,
  timeout,
  iceFailed,
  tokenInvalid,
  permissionDenied,
  networkLost,
  livekitConnectFailed,
  signalingFailed,
  unknown,
}

enum CallMediaConnectionState { idle, connecting, connected, reconnecting, disconnected, failed }

extension CallTelemetryFailureReasonWire on CallTelemetryFailureReason {
  String get wireName => switch (this) {
    CallTelemetryFailureReason.iceFailed => 'ice_failed',
    CallTelemetryFailureReason.tokenInvalid => 'token_invalid',
    CallTelemetryFailureReason.permissionDenied => 'permission_denied',
    CallTelemetryFailureReason.networkLost => 'network_lost',
    CallTelemetryFailureReason.livekitConnectFailed => 'livekit_connect_failed',
    CallTelemetryFailureReason.signalingFailed => 'signaling_failed',
    _ => name,
  };
}

class CallTelemetryPayload {
  const CallTelemetryPayload({
    required this.roomId,
    required this.event,
    required this.state,
    this.callId = '',
    this.uid = '',
    this.reason,
    this.durationMs = 0,
    this.networkType = '',
    this.sdk = 'livekit_client',
    this.platform = '',
    this.stats = const <String, dynamic>{},
    this.createdAt = 0,
  });

  final String roomId;
  final String callId;
  final String uid;
  final String event;
  final CallTelemetryState state;
  final CallTelemetryFailureReason? reason;
  final int durationMs;
  final String networkType;
  final String sdk;
  final String platform;
  final Map<String, dynamic> stats;
  final int createdAt;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'room_id': roomId,
    'call_id': callId,
    'uid': uid,
    'event': event,
    'state': state.name,
    'reason': reason?.wireName ?? '',
    'duration_ms': durationMs,
    'network_type': networkType,
    'sdk': sdk,
    'platform': platform,
    'stats': stats,
    'created_at': createdAt == 0 ? DateTime.now().millisecondsSinceEpoch : createdAt,
  };
}
```

- [ ] **Step 4: Implement reporter, API method, and media state stream**

Create `lib\realtime\call\call_telemetry_reporter.dart`:

- Constructor: `CallTelemetryReporter({required CallStore store, required Future<void> Function(CallTelemetryPayload) send, int maxPendingEvents = 100})`.
- Subscribe to `store.events`.
- Map `LocalDialCallEvent` to `call.dial.started`.
- Map `InviteCallEvent` to `call.invite.received`.
- Add `recordMediaState({required String roomId, required CallMediaConnectionState state, Map<String, dynamic> stats = const <String, dynamic>{}})`.
- Add `recordFailure({required String roomId, required CallTelemetryFailureReason reason})`.
- Catch send failures and keep a bounded pending list.
- Expose `int get pendingCount`.
- Add `Future<void> dispose()`.

Modify `lib\service\api\call_api.dart`:

```dart
Future<void> sendTelemetry(CallTelemetryPayload payload) async {
  final response = await _client.post('/v1/extra/call/telemetry', data: payload.toJson());
  _resolveResponseData(response, fallbackMessage: '上报通话质量失败');
}
```

Modify `CallMediaEngine`:

```dart
Stream<CallMediaConnectionState> get connectionStates;
```

Modify `LiveKitCallMediaEngine`:
- Add a broadcast `StreamController<CallMediaConnectionState>`.
- Emit `connecting` before `room.connect`.
- Emit `connected` after microphone/camera setup.
- Emit `failed` in the catch path.
- Emit `disconnected` in `disconnect`.

- [ ] **Step 5: Verify and commit call telemetry slice**

Run:

```powershell
cd C:\Users\COLORFUL\Desktop\WuKong\.worktrees\phase-4-server-media-call
flutter test test/realtime/call/call_state_machine_test.dart test/realtime/call/call_telemetry_reporter_test.dart test/modules/video_call/livekit_call_media_engine_test.dart test/modules/video_call/call_session_service_test.dart
git add lib/realtime/call/call_telemetry_models.dart lib/realtime/call/call_telemetry_reporter.dart lib/service/api/call_api.dart lib/modules/video_call/media/call_media_engine.dart lib/modules/video_call/media/livekit_call_media_engine.dart lib/modules/video_call/call_session_service.dart test/realtime/call/call_telemetry_reporter_test.dart test/modules/video_call/livekit_call_media_engine_test.dart test/modules/video_call/call_session_service_test.dart
git commit -m "feat: add call telemetry reporting"
```

Expected: tests pass and commit contains only call-related files.

---

## Task 8: Build, Deploy, Smoke, and Rollback

**Files:**
- Modify: `/opt/wukongim-prod/src/deploy/production/scripts/smoke_test.py`
- Modify: `/opt/wukongim-prod/src/deploy/production/scripts/call_stack_smoke.py`
- Runtime artifacts: Docker images, rendered configs, backup folders.

- [ ] **Step 1: Extend production smoke tests**

In `/opt/wukongim-prod/src/deploy/production/scripts/smoke_test.py`, add a multipart smoke function that:
- Initializes `/v1/file/multipart/init` with `type=chat`, small body size, `chunk_size=8`, and sha256 fingerprint.
- Uploads one part with `PUT /v1/file/multipart/part`.
- Completes with `POST /v1/file/multipart/complete`.
- Requires `path` in response.

In `/opt/wukongim-prod/src/deploy/production/scripts/call_stack_smoke.py`, add telemetry POST only when these env values exist:
- `SMOKE_TOKEN`
- `SMOKE_APP_ID`
- `SMOKE_APP_KEY`
- `SMOKE_DEVICE_ID`
- `SMOKE_DEVICE_SESSION_ID`

If those env values are absent, keep current health-only call stack smoke.

- [ ] **Step 2: Run server tests before build**

Run:

```bash
ssh ubuntu@42.194.218.158 'cd /opt/wukongim-prod/src && docker run --rm -v "$PWD":/src -w /src golang:1.20 go test ./serverlib/pkg/redis ./modules/messageeffects ./modules/file ./modules/extra ./internal/callgateway -count=1'
ssh ubuntu@42.194.218.158 'cd /home/ubuntu/wukongim-build-src-uploaded && docker run --rm -v "$PWD":/src -w /src golang:1.23 go test ./internal/messageeffects ./internal/options -count=1'
```

Expected: both commands pass.

- [ ] **Step 3: Build Docker images with timestamped tags**

Run:

```bash
ssh ubuntu@42.194.218.158 'set -euo pipefail; ts=$(date +%Y%m%d%H%M%S); cd /opt/wukongim-prod/src; docker compose -f deploy/production/docker-compose.yaml build tsdd-api callgateway; docker tag wukongim/tsdd-api:production-local wukongim/tsdd-api:phase4-$ts; cd /home/ubuntu/wukongim-build-src-uploaded; docker build -t wukongim/wukongim:phase4-$ts .; echo $ts > /tmp/phase4-image-ts'
```

Expected: TS-DD and WuKongIM images build.

- [ ] **Step 4: Render and validate production config**

Run:

```bash
ssh ubuntu@42.194.218.158 'cd /opt/wukongim-prod/src/deploy/production && python3 scripts/render_config.py && docker compose config >/tmp/phase4-compose.yml'
```

Expected: command exits 0.

- [ ] **Step 5: Deploy in short window**

Capture current runtime:

```bash
ssh ubuntu@42.194.218.158 'cd /opt/wukongim-prod/src/deploy/production && docker compose ps --format json > /tmp/phase4-pre-ps.json && docker compose images > /tmp/phase4-pre-images.txt'
```

Deploy:

```bash
ssh ubuntu@42.194.218.158 'cd /opt/wukongim-prod/src/deploy/production && docker compose up -d tsdd-api callgateway wukongim nginx'
```

Expected: containers become healthy.

- [ ] **Step 6: Run production smoke**

Run:

```bash
ssh ubuntu@42.194.218.158 'cd /opt/wukongim-prod/src/deploy/production && python3 scripts/call_stack_smoke.py && python3 scripts/smoke_test.py --base-url "$(grep ^TSDD_BASE_URL= .env | cut -d= -f2-)"'
```

Expected: health, login, message, multipart, call stack, and telemetry smoke pass.

- [ ] **Step 7: Check Redis Streams health**

Run:

```bash
ssh ubuntu@42.194.218.158 'cd /opt/wukongim-prod/src/deploy/production && REDIS_PASSWORD=$(grep ^REDIS_PASSWORD= .env | cut -d= -f2-) docker compose exec -T redis redis-cli -a "$REDIS_PASSWORD" XINFO GROUPS im:message:effects:v1 || true'
```

Expected: groups exist after first event, or command reports no stream only when no persisted-message event has flowed. Pending count must not grow continuously after smoke.

- [ ] **Step 8: Roll back immediately on smoke failure**

Run this if smoke fails:

```bash
ssh ubuntu@42.194.218.158 'cd /opt/wukongim-prod/src/deploy/production && docker compose up -d tsdd-api callgateway wukongim nginx && docker compose ps'
```

If config rollback is also required, restore from the printed backup directory:

```bash
ssh ubuntu@42.194.218.158 'backup=/opt/wukongim-prod/src/deploy/production/backups/phase4-redis-YYYYMMDDHHMMSS; cp -a "$backup/redis" /opt/wukongim-prod/src/serverlib/pkg/; cd /opt/wukongim-prod/src/deploy/production && python3 scripts/render_config.py && docker compose up -d nginx wukongim tsdd-api callgateway'
```

Replace `YYYYMMDDHHMMSS` with the actual backup timestamp printed during the run.

---

## Self-Review Checklist

### Spec Coverage

- Redis Streams decoupling: Tasks 1, 2, and 3 cover stream key `im:message:effects:v1`, groups `push-workers`, `unread-workers`, `reaction-workers`, idempotency, durable WuKongIM outbox, TS-DD ingest, and relay.
- Multipart upload: Tasks 4 and 5 cover additive API compatibility, fingerprint reuse, `uploaded_parts`, confirmed progress, concurrency 3, retries, and Nginx `proxy_request_buffering off`.
- LiveKit telemetry: Tasks 6 and 7 cover server endpoint `/v1/extra/call/telemetry`, stable states/reasons, persistence, Flutter reporter, and media state stream.
- Production rollout: Task 8 covers Docker tests, builds, config render, compose deploy, smoke, stream health, and rollback.
- Isolation: Task 0 prevents Phase 3 local files from entering Phase 4 commits.

### Placeholder Scan

No task uses deferred implementation labels. Each task defines exact file paths, test names, commands, expected results, and concrete interfaces or code blocks for the implementation boundary.

### Type Consistency

- `MessagePersistedEvent` uses `event_id`, `event_type`, `channel_id`, `channel_type`, `message_id`, `message_seq`, `client_msg_no`, `from_uid`, `payload_ref`, and `created_at`.
- Call states are `idle`, `ringing`, `connecting`, `connected`, `reconnecting`, `ended`, and `failed`.
- Failure reasons are `declined`, `cancelled`, `timeout`, `ice_failed`, `token_invalid`, `permission_denied`, `network_lost`, `livekit_connect_failed`, `signaling_failed`, and `unknown`.
- Multipart API paths remain `/v1/file/multipart/init`, `/v1/file/multipart/part`, `/v1/file/multipart/complete`, and `/v1/file/multipart/abort`.

---

## Execution Handoff

Plan complete and saved to `docs/superpowers/plans/2026-05-04-phase-4-server-media-call-deep-refactor.md`.

Two execution options:

1. **Subagent-Driven (recommended)** - dispatch a fresh subagent per task, review between tasks, fast iteration.
2. **Inline Execution** - execute tasks in this session using `superpowers:executing-plans`, batch execution with checkpoints.

Which approach?
