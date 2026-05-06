package monitor

import (
	"bytes"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"

	"github.com/TangSengDaoDao/TangSengDaoDaoServerLib/config"
	"github.com/TangSengDaoDao/TangSengDaoDaoServerLib/module"
	"github.com/TangSengDaoDao/TangSengDaoDaoServerLib/pkg/wkhttp"
	"github.com/TangSengDaoDao/TangSengDaoDaoServerLib/server"
	"github.com/TangSengDaoDao/TangSengDaoDaoServerLib/testutil"
	"github.com/stretchr/testify/require"
)

func newMigratedMonitorTestServer(t *testing.T) (*server.Server, *config.Context) {
	t.Helper()

	cfg := config.New()
	testutil.ConfigureTestMySQL(cfg)
	cfg.DB.Migration = true

	ctx := config.NewContext(cfg)
	s := server.New(ctx)
	ctx.SetHttpRoute(s.GetRoute())

	require.NoError(t, module.Setup(ctx))
	require.NoError(t, testutil.CleanAllTables(ctx))
	require.NoError(t, ctx.Cache().Set(cfg.Cache.TokenCachePrefix+testutil.Token, wkhttp.EncodeTokenCacheInfo(testutil.UID, "test", string(wkhttp.SuperAdmin))))

	return s, ctx
}

func TestMonitorAgentPairingHeartbeatFlow(t *testing.T) {
	s, _ := newMigratedMonitorTestServer(t)

	createRecorder := requestJSON(t, s, http.MethodPost, "/v1/monitor/agent-pairing-codes", map[string]interface{}{
		"device_name": "Windows Agent",
		"platform":    "windows",
	}, testutil.Token)
	require.Equal(t, http.StatusCreated, createRecorder.Code)
	createBody := decodeBody(t, createRecorder)
	createData := createBody["data"].(map[string]interface{})
	pairingCode := createData["pairing_code"].(string)
	require.NotEmpty(t, pairingCode)
	require.NotEmpty(t, createData["expires_at"])

	pairRecorder := requestJSON(t, s, http.MethodPost, "/v1/monitor/agents/pair", map[string]interface{}{
		"pairing_code":  pairingCode,
		"device_name":   "COLORFUL-PC",
		"platform":      "windows",
		"agent_version": "0.1.0",
	}, "")
	require.Equal(t, http.StatusCreated, pairRecorder.Code)
	pairBody := decodeBody(t, pairRecorder)
	pairData := pairBody["data"].(map[string]interface{})
	agentID := pairData["agent_id"].(string)
	agentToken := pairData["agent_token"].(string)
	require.NotEmpty(t, agentID)
	require.NotEmpty(t, agentToken)
	require.Equal(t, float64(20), pairData["heartbeat_interval_seconds"])

	reuseRecorder := requestJSON(t, s, http.MethodPost, "/v1/monitor/agents/pair", map[string]interface{}{
		"pairing_code":  pairingCode,
		"device_name":   "COLORFUL-PC",
		"platform":      "windows",
		"agent_version": "0.1.0",
	}, "")
	require.Equal(t, http.StatusConflict, reuseRecorder.Code)
	reuseBody := decodeBody(t, reuseRecorder)
	require.Equal(t, "pairing_code_used", reuseBody["error"].(map[string]interface{})["code"])

	heartbeatRecorder := requestJSONWithBearer(t, s, http.MethodPost, "/v1/monitor/agents/heartbeat", map[string]interface{}{
		"agent_id":      agentID,
		"status":        "online",
		"device_name":   "COLORFUL-PC",
		"platform":      "windows",
		"agent_version": "0.1.0",
		"capabilities":  []string{"feishu_web_group"},
		"observed_at":   "2026-05-06T10:15:20Z",
	}, agentToken)
	require.Equal(t, http.StatusOK, heartbeatRecorder.Code)
	heartbeatBody := decodeBody(t, heartbeatRecorder)
	require.Equal(t, "online", heartbeatBody["data"].(map[string]interface{})["status"])

	agentsRecorder := requestJSON(t, s, http.MethodGet, "/v1/monitor/agents?platform=feishu", nil, testutil.Token)
	require.Equal(t, http.StatusOK, agentsRecorder.Code)
	agentsBody := decodeBody(t, agentsRecorder)
	agents := agentsBody["data"].([]interface{})
	require.Len(t, agents, 1)
	agent := agents[0].(map[string]interface{})
	require.Equal(t, agentID, agent["id"])
	require.Equal(t, "COLORFUL-PC", agent["device_name"])
	require.Equal(t, "online", agent["status"])

	eventsRecorder := requestJSON(t, s, http.MethodGet, "/v1/monitor/events?platform=feishu", nil, testutil.Token)
	require.Equal(t, http.StatusOK, eventsRecorder.Code)
	eventsBody := decodeBody(t, eventsRecorder)
	events := eventsBody["data"].([]interface{})
	require.NotEmpty(t, events)
	messages := make([]string, 0, len(events))
	for _, rawEvent := range events {
		message := rawEvent.(map[string]interface{})["message"].(string)
		require.NotContains(t, message, "???")
		messages = append(messages, message)
	}
	require.Contains(t, messages, "Windows Agent COLORFUL-PC 已绑定")
	require.Contains(t, messages, "Windows Agent COLORFUL-PC 已在线")
}

func TestMonitorHeartbeatRejectsInvalidToken(t *testing.T) {
	s, _ := newMigratedMonitorTestServer(t)

	recorder := requestJSONWithBearer(t, s, http.MethodPost, "/v1/monitor/agents/heartbeat", map[string]interface{}{
		"agent_id":      "agent_missing",
		"status":        "online",
		"device_name":   "COLORFUL-PC",
		"platform":      "windows",
		"agent_version": "0.1.0",
		"capabilities":  []string{"feishu_web_group"},
		"observed_at":   "2026-05-06T10:15:20Z",
	}, "bad-token")

	require.Equal(t, http.StatusUnauthorized, recorder.Code)
	body := decodeBody(t, recorder)
	require.Equal(t, "invalid_agent_token", body["error"].(map[string]interface{})["code"])
}

func requestJSON(t *testing.T, s *server.Server, method string, path string, body map[string]interface{}, token string) *httptest.ResponseRecorder {
	t.Helper()
	return requestJSONWithBearerAndToken(t, s, method, path, body, "", token)
}

func requestJSONWithBearer(t *testing.T, s *server.Server, method string, path string, body map[string]interface{}, bearer string) *httptest.ResponseRecorder {
	t.Helper()
	return requestJSONWithBearerAndToken(t, s, method, path, body, bearer, "")
}

func requestJSONWithBearerAndToken(t *testing.T, s *server.Server, method string, path string, body map[string]interface{}, bearer string, token string) *httptest.ResponseRecorder {
	t.Helper()
	var reader *bytes.Reader
	if body == nil {
		reader = bytes.NewReader(nil)
	} else {
		payload, err := json.Marshal(body)
		require.NoError(t, err)
		reader = bytes.NewReader(payload)
	}
	req, err := http.NewRequest(method, path, reader)
	require.NoError(t, err)
	req.Header.Set("Content-Type", "application/json")
	if token != "" {
		req.Header.Set("token", token)
	}
	if bearer != "" {
		req.Header.Set("Authorization", "Bearer "+bearer)
	}
	recorder := httptest.NewRecorder()
	s.GetRoute().ServeHTTP(recorder, req)
	return recorder
}

func decodeBody(t *testing.T, recorder *httptest.ResponseRecorder) map[string]interface{} {
	t.Helper()
	var body map[string]interface{}
	require.NoError(t, json.Unmarshal(recorder.Body.Bytes(), &body), recorder.Body.String())
	return body
}
