package extra

import (
	"errors"
	"reflect"
	"strings"
	"testing"
	"time"

	"github.com/TangSengDaoDao/TangSengDaoDaoServer/modules/group"
	"github.com/TangSengDaoDao/TangSengDaoDaoServerLib/common"
	"github.com/TangSengDaoDao/TangSengDaoDaoServerLib/pkg/log"
)

type fakeCallStore struct {
	room           *CallRoomModel
	pending        []*CallRoomModel
	signals        []*CallSignalModel
	lastStatusRoom string
	lastStatus     int
	lastSignal     *CallSignalModel
}

func (f *fakeCallStore) InsertCallRoom(r *CallRoomModel) error {
	f.room = r
	return nil
}

func (f *fakeCallStore) InsertCallSignal(s *CallSignalModel) error {
	f.lastSignal = s
	return nil
}

func (f *fakeCallStore) UpdateCallRoomStatus(roomId string, status int) error {
	f.lastStatusRoom = roomId
	f.lastStatus = status
	return nil
}

func (f *fakeCallStore) QueryCallRoomByID(roomId string) (*CallRoomModel, error) {
	return f.room, nil
}

func (f *fakeCallStore) QueryPendingCalls(callee string) ([]*CallRoomModel, error) {
	return f.pending, nil
}

func (f *fakeCallStore) QueryCallSignals(roomId string) ([]*CallSignalModel, error) {
	return f.signals, nil
}

type fakeRealtimeService struct {
	events []callEvent
}

type callEvent struct {
	uid         string
	kind        string
	aggregateID string
	payload     interface{}
}

func (f *fakeRealtimeService) Append(uid, kind, aggregateID string, payload interface{}) error {
	f.events = append(f.events, callEvent{
		uid:         uid,
		kind:        kind,
		aggregateID: aggregateID,
		payload:     payload,
	})
	return nil
}

type fakeGroupCallPolicyService struct {
	group       *group.InfoResp
	memberByUID map[string]*group.MemberResp
	groupErr    error
	memberErr   error
}

func (f *fakeGroupCallPolicyService) GetGroupWithGroupNo(groupNo string) (*group.InfoResp, error) {
	if f.groupErr != nil {
		return nil, f.groupErr
	}
	return f.group, nil
}

func (f *fakeGroupCallPolicyService) GetMember(groupNo, uid string) (*group.MemberResp, error) {
	if f.memberErr != nil {
		return nil, f.memberErr
	}
	if f.memberByUID == nil {
		return nil, nil
	}
	return f.memberByUID[uid], nil
}

func newTestAPI() (*API, *fakeCallStore, *fakeRealtimeService) {
	store := &fakeCallStore{}
	realtime := &fakeRealtimeService{}
	api := &API{
		Log:             log.NewTLog("extra-test"),
		callStore:       store,
		roomIDGenerator: func() string { return "call_static" },
		realtimeSvc:     realtime,
	}
	return api, store, realtime
}

func TestBuildCallInviteFrame(t *testing.T) {
	api, _, _ := newTestAPI()
	room := &CallRoomModel{
		RoomId:     "call_static",
		CallerUid:  "caller",
		CallerName: "Caller Name",
		CalleeUid:  "callee",
		CalleeName: "Callee Name",
		CallType:   2,
		Status:     0,
	}

	got := api.buildCallInviteFrame(room)
	expected := map[string]interface{}{
		"room_id":     "call_static",
		"caller_uid":  "caller",
		"caller_name": "Caller Name",
		"callee_uid":  "callee",
		"callee_name": "Callee Name",
		"call_type":   2,
		"status":      0,
		"created_at":  "",
	}

	if !reflect.DeepEqual(got, expected) {
		t.Fatalf("unexpected invite frame: %#v", got)
	}
}

func TestHandleCreateCallRoomEmitsInvite(t *testing.T) {
	api, store, realtime := newTestAPI()
	req := CreateCallRoomReq{
		CalleeUid:  "callee",
		CalleeName: "callee name",
		CallType:   1,
	}

	resp, err := api.handleCreateCallRoom("caller", req)
	if err != nil {
		t.Fatalf("handleCreateCallRoom error: %v", err)
	}
	if resp.RoomId != "call_static" {
		t.Fatalf("expected room id call_static, got %s", resp.RoomId)
	}
	if store.room == nil {
		t.Fatal("call room not persisted")
	}
	if len(realtime.events) != 1 {
		t.Fatalf("expected 1 event, got %d", len(realtime.events))
	}
	event := realtime.events[0]
	if event.uid != "callee" || event.kind != callInviteKind || event.aggregateID != "call_static" {
		t.Fatalf("unexpected event: %#v", event)
	}
	payload, ok := event.payload.(map[string]interface{})
	if !ok || payload["caller_uid"] != "caller" {
		t.Fatalf("unexpected payload: %#v", payload)
	}
}

func TestHandleCreateGroupCallRoomPersistsContextAndEmitsParticipantInvites(t *testing.T) {
	api, store, realtime := newTestAPI()
	api.groupService = &fakeGroupCallPolicyService{
		group: &group.InfoResp{GroupNo: "g_demo", Forbidden: 0},
		memberByUID: map[string]*group.MemberResp{
			"caller": {UID: "caller", GroupNo: "g_demo", Role: group.MemberRoleCommon},
		},
	}

	resp, err := api.handleCreateCallRoom("caller", CreateCallRoomReq{
		RoomName:    "demo group call",
		ChannelId:   "g_demo",
		ChannelType: int(common.ChannelTypeGroup.Uint8()),
		CallType:    1,
		Participants: []*CallParticipantReq{
			{Uid: "caller", Name: "Caller", Role: 1, InviteStatus: 1},
			{Uid: "u_alice", Name: "Alice", Role: 1, InviteStatus: 0},
			{Uid: "u_bob", Name: "Bob", Role: 1, InviteStatus: 0},
		},
	})
	if err != nil {
		t.Fatalf("handleCreateCallRoom error: %v", err)
	}

	if store.room == nil {
		t.Fatal("call room not persisted")
	}
	if store.room.ChannelId != "g_demo" || store.room.ChannelType != int(common.ChannelTypeGroup.Uint8()) {
		t.Fatalf("unexpected room context: %#v", store.room)
	}
	if resp.RoomName != "demo group call" || resp.ChannelId != "g_demo" {
		t.Fatalf("unexpected response context: %#v", resp)
	}
	if got := participantUIDs(resp.Participants); !reflect.DeepEqual(got, []string{"caller", "u_alice", "u_bob"}) {
		t.Fatalf("unexpected participants: %#v", got)
	}
	if len(realtime.events) != 2 {
		t.Fatalf("expected 2 participant invite events, got %d", len(realtime.events))
	}
	if realtime.events[0].uid != "u_alice" || realtime.events[1].uid != "u_bob" {
		t.Fatalf("unexpected participant invite targets: %#v", realtime.events)
	}
}

func TestEnsureCanCreateCallRoomRejectsNormalMemberWhenGroupMuted(t *testing.T) {
	api, _, _ := newTestAPI()
	api.groupService = &fakeGroupCallPolicyService{
		group: &group.InfoResp{GroupNo: "g_muted", Forbidden: 1},
		memberByUID: map[string]*group.MemberResp{
			"member": {UID: "member", GroupNo: "g_muted", Role: group.MemberRoleCommon},
		},
	}

	err := api.ensureCanCreateCallRoom("member", CreateCallRoomReq{
		ChannelId:   "g_muted",
		ChannelType: int(common.ChannelTypeGroup.Uint8()),
	})

	if err == nil || !containsText(err.Error(), "禁言") {
		t.Fatalf("expected mute rejection, got %v", err)
	}
}

func TestEnsureCanCreateCallRoomAllowsAdminWhenGroupMuted(t *testing.T) {
	api, _, _ := newTestAPI()
	api.groupService = &fakeGroupCallPolicyService{
		group: &group.InfoResp{GroupNo: "g_muted", Forbidden: 1},
		memberByUID: map[string]*group.MemberResp{
			"admin": {UID: "admin", GroupNo: "g_muted", Role: group.MemberRoleManager},
		},
	}

	err := api.ensureCanCreateCallRoom("admin", CreateCallRoomReq{
		ChannelId:   "g_muted",
		ChannelType: int(common.ChannelTypeGroup.Uint8()),
	})

	if err != nil {
		t.Fatalf("expected admin allowed, got %v", err)
	}
}

func TestEnsureCanCreateCallRoomRejectsMemberMute(t *testing.T) {
	api, _, _ := newTestAPI()
	api.groupService = &fakeGroupCallPolicyService{
		group: &group.InfoResp{GroupNo: "g_active", Forbidden: 0},
		memberByUID: map[string]*group.MemberResp{
			"member": {
				UID:                "member",
				GroupNo:            "g_active",
				Role:               group.MemberRoleCommon,
				ForbiddenExpirTime: time.Now().Add(time.Hour).Unix(),
			},
		},
	}

	err := api.ensureCanCreateCallRoom("member", CreateCallRoomReq{
		ChannelId:   "g_active",
		ChannelType: int(common.ChannelTypeGroup.Uint8()),
	})

	if err == nil || !containsText(err.Error(), "禁言") {
		t.Fatalf("expected member mute rejection, got %v", err)
	}
}

func TestEnsureCanCreateCallRoomPropagatesGroupPolicyErrors(t *testing.T) {
	api, _, _ := newTestAPI()
	api.groupService = &fakeGroupCallPolicyService{
		groupErr: errors.New("group unavailable"),
	}

	err := api.ensureCanCreateCallRoom("member", CreateCallRoomReq{
		ChannelId:   "g_active",
		ChannelType: int(common.ChannelTypeGroup.Uint8()),
	})

	if err == nil || err.Error() != "group unavailable" {
		t.Fatalf("expected group policy error, got %v", err)
	}
}

func TestIsCallRoomParticipantAllowsGroupParticipants(t *testing.T) {
	room := &CallRoomModel{
		RoomId:      "call_static",
		CallerUid:   "caller",
		ChannelId:   "g_demo",
		ChannelType: int(common.ChannelTypeGroup.Uint8()),
		Participants: []*CallParticipantResp{
			{Uid: "caller", Name: "Caller"},
			{Uid: "u_alice", Name: "Alice"},
		},
	}

	if !isCallRoomParticipant(room, "u_alice") {
		t.Fatal("expected group call participant to be allowed")
	}
	if isCallRoomParticipant(room, "u_intruder") {
		t.Fatal("expected non-participant to be rejected")
	}
}

func TestHandleSendSignalEmitsEvent(t *testing.T) {
	api, store, realtime := newTestAPI()
	store.room = &CallRoomModel{
		RoomId:    "call_static",
		CallerUid: "caller",
		CalleeUid: "callee",
	}

	err := api.handleSendSignal("caller", CallSignalReq{
		RoomId:     "call_static",
		SignalType: 3,
		Payload:    "payload",
	})
	if err != nil {
		t.Fatalf("handleSendSignal error: %v", err)
	}
	if len(realtime.events) != 1 {
		t.Fatalf("expected 1 event, got %d", len(realtime.events))
	}
	event := realtime.events[0]
	if event.uid != "callee" || event.kind != callSignalKind {
		t.Fatalf("unexpected event: %#v", event)
	}
	payload := event.payload.(map[string]interface{})
	if payload["from_uid"] != "caller" {
		t.Fatalf("unexpected payload: %#v", payload)
	}
}

func TestHandleUpdateCallStatusEmitsEvent(t *testing.T) {
	api, store, realtime := newTestAPI()
	store.room = &CallRoomModel{
		RoomId:    "call_static",
		CallerUid: "caller",
		CalleeUid: "callee",
	}

	if err := api.handleUpdateCallStatus("callee", "call_static", 2); err != nil {
		t.Fatalf("handleUpdateCallStatus error: %v", err)
	}
	if len(realtime.events) != 1 {
		t.Fatalf("expected 1 event, got %d", len(realtime.events))
	}
	event := realtime.events[0]
	if event.uid != "caller" || event.kind != callStateKind {
		t.Fatalf("unexpected event: %#v", event)
	}
	payload := event.payload.(map[string]interface{})
	if payload["status"] != 2 {
		t.Fatalf("unexpected status: %v", payload["status"])
	}
}

func TestPendingCallsFallback(t *testing.T) {
	api, _, _ := newTestAPI()
	resp := api.pendingCallsResponse(nil, true)
	meta, _ := resp["meta"].(map[string]interface{})
	if resp["data"] == nil || meta == nil || meta[fallbackMetaKey] != true {
		t.Fatalf("fallback response missing meta: %#v", resp)
	}
}

func containsText(s string, want string) bool {
	return strings.Contains(s, want)
}

func participantUIDs(participants []*CallParticipantResp) []string {
	uids := make([]string, 0, len(participants))
	for _, participant := range participants {
		if participant == nil {
			continue
		}
		uids = append(uids, participant.Uid)
	}
	return uids
}

func TestSignalsFallback(t *testing.T) {
	api, _, _ := newTestAPI()
	resp := api.signalsResponse(nil, true)
	meta, _ := resp["meta"].(map[string]interface{})
	if resp["data"] == nil || meta == nil || meta[fallbackMetaKey] != true {
		t.Fatalf("signals fallback missing meta: %#v", resp)
	}
}
