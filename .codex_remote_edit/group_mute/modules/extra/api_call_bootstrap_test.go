package extra

import (
	"bytes"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"
	"time"

	"github.com/TangSengDaoDao/TangSengDaoDaoServerLib/config"
	"github.com/TangSengDaoDao/TangSengDaoDaoServerLib/pkg/util"
	"github.com/TangSengDaoDao/TangSengDaoDaoServerLib/pkg/wkhttp"
	"github.com/TangSengDaoDao/TangSengDaoDaoServerLib/testutil"
	"github.com/golang-jwt/jwt/v4"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

func TestCreateCallRoomReturnsCallBootstrap(t *testing.T) {
	t.Setenv("WK_CALL_TICKET_SECRET", "test-call-ticket-secret")
	s, _ := newMigratedExtraTestServer(t)

	body := map[string]any{
		"callee_uid":  "u_peer",
		"callee_name": "Peer",
		"call_type":   1,
		"capabilities": map[string]any{
			"platform":       "web",
			"supports_video": true,
			"supports_audio": true,
			"prefers_audio":  false,
			"is_safari":      false,
			"is_mobile_web":  false,
		},
	}

	req := httptest.NewRequest(http.MethodPost, "/v1/extra/call/room", bytes.NewReader([]byte(util.ToJson(body))))
	req.Header.Set("token", testutil.Token)
	rec := httptest.NewRecorder()
	s.GetRoute().ServeHTTP(rec, req)

	require.Equal(t, http.StatusOK, rec.Code)

	var envelope struct {
		Status int                   `json:"status"`
		Msg    string                `json:"msg"`
		Data   CallRoomBootstrapResp `json:"data"`
	}
	require.NoError(t, json.Unmarshal(rec.Body.Bytes(), &envelope))

	bootstrap := envelope.Data
	require.NotNil(t, bootstrap.Room)
	require.NotNil(t, bootstrap.Ticket)
	require.NotNil(t, bootstrap.Join)

	assert.Equal(t, testutil.UID, bootstrap.Room.CallerUid)
	assert.Equal(t, testutil.UID, bootstrap.Room.CallerName)
	assert.Equal(t, "u_peer", bootstrap.Room.CalleeUid)
	assert.Equal(t, "Peer", bootstrap.Room.CalleeName)
	assert.Equal(t, 1, bootstrap.Room.CallType)
	assert.NotEmpty(t, bootstrap.Room.RoomId)
	assert.Equal(t, bootstrap.Room.RoomId, bootstrap.Join.RoomName)

	assert.Equal(t, "wss://wemx.cc/v1/callgateway/ws", bootstrap.Join.ControlURL)
	assert.Equal(t, "wss://wemx.cc/livekit", bootstrap.Join.LiveKitURL)

	assert.Equal(t, "web", bootstrap.Capabilities.Platform)
	assert.True(t, bootstrap.Capabilities.SupportsVideo)
	assert.True(t, bootstrap.Capabilities.SupportsAudio)
	assert.False(t, bootstrap.Capabilities.PrefersAudio)
	assert.False(t, bootstrap.Capabilities.IsSafari)
	assert.False(t, bootstrap.Capabilities.IsMobileWeb)

	assert.NotEmpty(t, bootstrap.Ticket.Token)
	assert.Equal(t, bootstrap.Room.RoomId, bootstrap.Ticket.RoomID)
	assert.Equal(t, testutil.UID, bootstrap.Ticket.Participant)

	ttlLeft := bootstrap.Ticket.ExpiresAt - time.Now().Unix()
	assert.GreaterOrEqual(t, ttlLeft, int64(100))
	assert.LessOrEqual(t, ttlLeft, int64(125))

	claims := jwt.MapClaims{}
	parsedToken, err := jwt.ParseWithClaims(bootstrap.Ticket.Token, claims, func(token *jwt.Token) (interface{}, error) {
		return []byte("test-call-ticket-secret"), nil
	})
	require.NoError(t, err)
	require.True(t, parsedToken.Valid)

	assert.Equal(t, bootstrap.Room.RoomId, claims["room_id"])
	assert.Equal(t, testutil.UID, claims["participant"])
	assert.Equal(t, "web", claims["platform"])
	assert.Equal(t, testutil.UID, claims["sub"])
	_, hasDeviceID := claims["device_id"]
	assert.False(t, hasDeviceID)

	exp, ok := claims["exp"].(float64)
	require.True(t, ok)
	iat, ok := claims["iat"].(float64)
	require.True(t, ok)
	assert.InDelta(t, float64(120), exp-iat, float64(2))
}

func TestGetCallSessionRejectsNonParticipants(t *testing.T) {
	t.Setenv("WK_CALL_TICKET_SECRET", "test-call-ticket-secret")
	s, ctx := newMigratedExtraTestServer(t)

	createBody := map[string]any{
		"callee_uid":  "u_peer",
		"callee_name": "Peer",
		"call_type":   1,
		"capabilities": map[string]any{
			"platform":       "web",
			"supports_video": true,
			"supports_audio": true,
			"prefers_audio":  false,
			"is_safari":      false,
			"is_mobile_web":  false,
		},
	}
	createReq := httptest.NewRequest(http.MethodPost, "/v1/extra/call/room", bytes.NewReader([]byte(util.ToJson(createBody))))
	createReq.Header.Set("token", testutil.Token)
	createRec := httptest.NewRecorder()
	s.GetRoute().ServeHTTP(createRec, createReq)

	require.Equal(t, http.StatusOK, createRec.Code)

	var createEnvelope struct {
		Status int `json:"status"`
		Data   struct {
			Room struct {
				RoomID string `json:"room_id"`
			} `json:"room"`
		} `json:"data"`
	}
	require.NoError(t, json.Unmarshal(createRec.Body.Bytes(), &createEnvelope))
	require.NotEmpty(t, createEnvelope.Data.Room.RoomID)

	participantReq := httptest.NewRequest(http.MethodGet, "/v1/extra/call/session/"+createEnvelope.Data.Room.RoomID, nil)
	participantReq.Header.Set("token", testutil.Token)
	participantRec := httptest.NewRecorder()
	s.GetRoute().ServeHTTP(participantRec, participantReq)
	require.Equal(t, http.StatusOK, participantRec.Code)

	const intruderToken = "test-call-intruder-token"
	cacheTestToken(t, ctx, intruderToken, "u_intruder")

	req := httptest.NewRequest(http.MethodGet, "/v1/extra/call/session/"+createEnvelope.Data.Room.RoomID, nil)
	req.Header.Set("token", intruderToken)

	rec := httptest.NewRecorder()
	s.GetRoute().ServeHTTP(rec, req)

	var envelope struct {
		Status int    `json:"status"`
		Msg    string `json:"msg"`
	}
	require.NoError(t, json.Unmarshal(rec.Body.Bytes(), &envelope))
	assert.NotEqual(t, http.StatusOK, envelope.Status)
	assert.Contains(t, envelope.Msg, "forbidden")
}

func cacheTestToken(t *testing.T, ctx *config.Context, token, uid string) {
	t.Helper()
	err := ctx.Cache().Set(
		ctx.GetConfig().Cache.TokenCachePrefix+token,
		wkhttp.EncodeTokenCacheInfo(uid, "test", string(wkhttp.SuperAdmin)),
	)
	require.NoError(t, err)
}
