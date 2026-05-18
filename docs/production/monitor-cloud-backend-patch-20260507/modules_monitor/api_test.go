package monitor

import (
	"bytes"
	"context"
	"encoding/base64"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"net/http"
	"net/http/httptest"
	"testing"
	"time"

	"github.com/TangSengDaoDao/TangSengDaoDaoServerLib/common"
	"github.com/TangSengDaoDao/TangSengDaoDaoServerLib/config"
	"github.com/TangSengDaoDao/TangSengDaoDaoServerLib/module"
	"github.com/TangSengDaoDao/TangSengDaoDaoServerLib/pkg/wkhttp"
	"github.com/TangSengDaoDao/TangSengDaoDaoServerLib/server"
	"github.com/TangSengDaoDao/TangSengDaoDaoServerLib/testutil"
	"github.com/go-sql-driver/mysql"
	"github.com/stretchr/testify/require"
)

func newMigratedMonitorTestServer(t *testing.T) (*server.Server, *config.Context) {
	t.Helper()

	cfg := config.New()
	testutil.ConfigureTestMySQL(cfg)
	testutil.ConfigureMockWuKongIM(t, cfg)
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

	agentID, agentToken, pairingCode := pairTestAgent(t, s)

	reuseRecorder := requestJSON(t, s, http.MethodPost, "/v1/monitor/agents/pair", map[string]interface{}{
		"pairing_code":  pairingCode,
		"device_name":   "COLORFUL-PC",
		"platform":      "windows",
		"agent_version": "0.1.0",
	}, "")
	require.NotEqual(t, http.StatusOK, reuseRecorder.Code)

	heartbeatRecorder := requestJSONWithBearer(t, s, http.MethodPost, "/v1/monitor/agents/heartbeat", map[string]interface{}{
		"agent_id":      agentID,
		"status":        "online",
		"device_name":   "COLORFUL-PC",
		"platform":      "windows",
		"agent_version": "0.1.0",
		"capabilities":  []string{"feishu_web_group"},
		"observed_at":   "2026-05-07T10:15:20Z",
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

func TestMonitorPairingSameDeviceReusesAgent(t *testing.T) {
	s, _ := newMigratedMonitorTestServer(t)

	firstAgentID, firstToken, _ := pairTestAgent(t, s)

	createRecorder := requestJSON(t, s, http.MethodPost, "/v1/monitor/agent-pairing-codes", map[string]interface{}{
		"device_name": "Windows Agent",
		"platform":    "windows",
	}, testutil.Token)
	require.Equal(t, http.StatusCreated, createRecorder.Code, createRecorder.Body.String())
	code := decodeBody(t, createRecorder)["data"].(map[string]interface{})["pairing_code"].(string)

	pairRecorder := requestJSON(t, s, http.MethodPost, "/v1/monitor/agents/pair", map[string]interface{}{
		"pairing_code":  code,
		"device_name":   "COLORFUL-PC",
		"platform":      "windows",
		"agent_version": "0.1.0",
	}, "")
	require.Equal(t, http.StatusCreated, pairRecorder.Code, pairRecorder.Body.String())
	pairData := decodeBody(t, pairRecorder)["data"].(map[string]interface{})
	require.Equal(t, firstAgentID, pairData["agent_id"])
	require.NotEqual(t, firstToken, pairData["agent_token"])

	agentsRecorder := requestJSON(t, s, http.MethodGet, "/v1/monitor/agents?platform=feishu", nil, testutil.Token)
	require.Equal(t, http.StatusOK, agentsRecorder.Code, agentsRecorder.Body.String())
	agents := decodeBody(t, agentsRecorder)["data"].([]interface{})
	require.Len(t, agents, 1)
	require.Equal(t, firstAgentID, agents[0].(map[string]interface{})["id"])
}

func TestMonitorForwardingBackendFlow(t *testing.T) {
	s, _ := newMigratedMonitorTestServer(t)

	agentID, agentToken, _ := pairTestAgent(t, s)

	routeRecorder := requestJSON(t, s, http.MethodPost, "/v1/monitor/routes", map[string]interface{}{
		"platform":       "feishu",
		"connector_type": "feishu_web_group",
		"route_type":     "feishu_web_group_to_wukong_im_group",
		"source": map[string]interface{}{
			"chat_name": "飞书新闻群",
		},
		"destination": map[string]interface{}{
			"type":       "wukong_im_group",
			"group_no":   "group_1",
			"group_name": "悟空 IM 新闻群",
		},
		"message_policy": map[string]interface{}{
			"include_text":   true,
			"include_links":  true,
			"include_images": false,
			"include_files":  false,
		},
	}, testutil.Token)
	require.Equal(t, http.StatusCreated, routeRecorder.Code, routeRecorder.Body.String())
	routeBody := decodeBody(t, routeRecorder)
	routeData := routeBody["data"].(map[string]interface{})
	routeID := routeData["route_id"].(string)
	require.NotEmpty(t, routeID)
	require.Equal(t, agentID, routeData["agent_id"])
	require.Equal(t, "????", routeData["sender_display_name"])
	require.Equal(t, "https://cdn.example.com/news-bot.png", routeData["sender_display_avatar"])

	myRoutesRecorder := requestJSONWithBearer(t, s, http.MethodGet, "/v1/monitor/agents/me/routes", nil, agentToken)
	require.Equal(t, http.StatusOK, myRoutesRecorder.Code, myRoutesRecorder.Body.String())
	myRoutesBody := decodeBody(t, myRoutesRecorder)
	myRoutes := myRoutesBody["data"].([]interface{})
	require.Len(t, myRoutes, 1)
	myRoute := myRoutes[0].(map[string]interface{})
	require.Equal(t, routeID, myRoute["route_id"])
	require.Equal(t, "飞书新闻群", myRoute["source"].(map[string]interface{})["chat_name"])
	require.Equal(t, "group_1", myRoute["destination"].(map[string]interface{})["group_no"])
	myRouteSender := myRoute["destination"].(map[string]interface{})["sender_identity"].(map[string]interface{})
	require.Equal(t, "????", myRouteSender["display_name"])
	require.Equal(t, "https://cdn.example.com/news-bot.png", myRouteSender["display_avatar"])

	statusRecorder := requestJSONWithBearer(t, s, http.MethodPost, "/v1/monitor/agents/browser-status", map[string]interface{}{
		"agent_id":      agentID,
		"platform":      "feishu",
		"browser":       "chromium",
		"profile_mode":  "isolated_persistent",
		"login_status":  "logged_in",
		"observed_at":   "2026-05-07T10:00:00Z",
		"error_message": "",
	}, agentToken)
	require.Equal(t, http.StatusOK, statusRecorder.Code, statusRecorder.Body.String())

	fetchStatusRecorder := requestJSON(t, s, http.MethodGet, "/v1/monitor/platforms/feishu/browser-status", nil, testutil.Token)
	require.Equal(t, http.StatusOK, fetchStatusRecorder.Code, fetchStatusRecorder.Body.String())
	fetchStatusBody := decodeBody(t, fetchStatusRecorder)
	require.Equal(t, "logged_in", fetchStatusBody["data"].(map[string]interface{})["login_status"])

	observedBody := map[string]interface{}{
		"agent_id":          agentID,
		"route_id":          routeID,
		"source_platform":   "feishu",
		"source_chat_name":  "飞书新闻群",
		"source_message_id": "feishu_web_hash_1",
		"message_type":      "text",
		"content":           "新闻正文",
		"source_created_at": "2026-05-07T10:00:00Z",
		"observed_at":       "2026-05-07T10:00:05Z",
	}
	observedRecorder := requestJSONWithBearer(t, s, http.MethodPost, "/v1/monitor/messages/observed", observedBody, agentToken)
	require.Equal(t, http.StatusOK, observedRecorder.Code, observedRecorder.Body.String())
	observedData := decodeBody(t, observedRecorder)["data"].(map[string]interface{})
	require.Equal(t, false, observedData["duplicate"])
	require.Equal(t, "forwarded", observedData["forward_status"])

	duplicateRecorder := requestJSONWithBearer(t, s, http.MethodPost, "/v1/monitor/messages/observed", observedBody, agentToken)
	require.Equal(t, http.StatusOK, duplicateRecorder.Code, duplicateRecorder.Body.String())
	duplicateData := decodeBody(t, duplicateRecorder)["data"].(map[string]interface{})
	require.Equal(t, true, duplicateData["duplicate"])
	require.Equal(t, "duplicate", duplicateData["forward_status"])

	eventsRecorder := requestJSON(t, s, http.MethodGet, "/v1/monitor/events?platform=feishu", nil, testutil.Token)
	require.Equal(t, http.StatusOK, eventsRecorder.Code)
	events := decodeBody(t, eventsRecorder)["data"].([]interface{})
	foundForwarded := false
	for _, rawEvent := range events {
		event := rawEvent.(map[string]interface{})
		if event["type"] == "forwarded" {
			foundForwarded = true
			require.Equal(t, routeID, event["route_id"])
		}
	}
	require.True(t, foundForwarded)

	routesRecorder := requestJSON(t, s, http.MethodGet, "/v1/monitor/routes?platform=feishu", nil, testutil.Token)
	require.Equal(t, http.StatusOK, routesRecorder.Code)
	routes := decodeBody(t, routesRecorder)["data"].([]interface{})
	require.Len(t, routes, 1)
	require.Equal(t, float64(1), routes[0].(map[string]interface{})["today_forwarded_count"])
}

func TestForwardObservedMessageContentUsesRawMessageOnly(t *testing.T) {
	content := forwardObservedMessageContent(
		&routeModel{SourceName: "满满正能量"},
		&observedMessageModel{Content: "新闻正文"},
	)

	require.Equal(t, "新闻正文", content)
	require.NotContains(t, content, "[Feishu:")
	require.NotContains(t, content, "满满正能量")
}

func TestForwardObservedMessagePayloadShapesRichMessages(t *testing.T) {
	imagePayload, err := forwardObservedMessagePayload(&routeModel{DestinationNo: "group_1"}, &observedMessageModel{
		MessageType: "image",
		Content:     "news.png",
		Attachments: []observedAttachment{{Kind: "image", RemoteURL: "file/preview/chat/2/group_1/news.png", Width: 640, Height: 360, FileName: "news.png"}},
	})
	require.NoError(t, err)
	require.Equal(t, common.Image, imagePayload["type"])
	require.Equal(t, "file/preview/chat/2/group_1/news.png", imagePayload["url"])
	require.Equal(t, int64(640), imagePayload["width"])
	require.Equal(t, "news.png", imagePayload["name"])

	filePayload, err := forwardObservedMessagePayload(&routeModel{DestinationNo: "group_1"}, &observedMessageModel{
		MessageType: "file",
		Content:     "report.pdf",
		Attachments: []observedAttachment{{Kind: "file", RemoteURL: "file/preview/chat/2/group_1/report.pdf", FileName: "report.pdf", FileSizeBytes: 2048}},
	})
	require.NoError(t, err)
	require.Equal(t, common.File, filePayload["type"])
	require.Equal(t, "file/preview/chat/2/group_1/report.pdf", filePayload["url"])
	require.Equal(t, "report.pdf", filePayload["name"])
	require.Equal(t, int64(2048), filePayload["size"])
	require.Equal(t, "pdf", filePayload["suffix"])

	cardPayload, err := forwardObservedMessagePayload(&routeModel{DestinationNo: "group_1"}, &observedMessageModel{
		MessageType: "card",
		Content:     "????\n?????????\nhttps://example.com/report",
	})
	require.NoError(t, err)
	require.Equal(t, common.Text, cardPayload["type"])
	require.Equal(t, "????\n?????????\nhttps://example.com/report", cardPayload["content"])

	require.True(t, routeAllowsType(&routeModel{IncludeText: 0, IncludeLinks: 1}, "card"))
	require.True(t, routeAllowsType(&routeModel{IncludeText: 1, IncludeLinks: 0}, "card"))
	require.False(t, routeAllowsType(&routeModel{IncludeText: 0, IncludeLinks: 0}, "card"))
}

func TestForwardObservedMessagePayloadUsesRouteSenderIdentity(t *testing.T) {
	payload, err := forwardObservedMessagePayload(&routeModel{
		DestinationNo:       "group_1",
		SenderDisplayName:   "????",
		SenderDisplayAvatar: "https://cdn.example.com/news-bot.png",
	}, &observedMessageModel{
		MessageType: "text",
		Content:     "????",
	})
	require.NoError(t, err)

	robot := payload["robot"].(map[string]interface{})
	require.Equal(t, "feishu_monitor", robot["provider"])
	require.Equal(t, "????", robot["display_name"])
	require.Equal(t, "https://cdn.example.com/news-bot.png", robot["display_avatar"])
}

func TestForwardObservedMessagePayloadFallsBackToDefaultSenderIdentity(t *testing.T) {
	payload, err := forwardObservedMessagePayload(&routeModel{DestinationNo: "group_1"}, &observedMessageModel{
		MessageType: "text",
		Content:     "????",
	})
	require.NoError(t, err)

	robot := payload["robot"].(map[string]interface{})
	require.Equal(t, "Feishu Monitor", robot["display_name"])
	require.Equal(t, "", robot["display_avatar"])
}

func TestMonitorDuplicateKeyErrorIsTreatedAsIdempotentDuplicate(t *testing.T) {
	require.True(t, isDuplicateKeyError(&mysql.MySQLError{Number: 1062}))
	require.True(t, isDuplicateKeyError(fmt.Errorf("wrapped: %w", &mysql.MySQLError{Number: 1062})))
	require.False(t, isDuplicateKeyError(&mysql.MySQLError{Number: 1048}))
	require.False(t, isDuplicateKeyError(errors.New("plain error")))
}

func TestEnsureObservedAttachmentUploadedPersistsRemoteURL(t *testing.T) {
	_, ctx := newMigratedMonitorTestServer(t)
	api := NewAPI(ctx)
	fakeFiles := &fakeMonitorFileService{}
	api.fileService = fakeFiles
	api.now = func() time.Time { return time.Date(2026, 5, 8, 2, 0, 0, 0, time.UTC) }

	message := &observedMessageModel{
		MessageID:       "monitor_msg_attachment_persist",
		UID:             "uid_attachment",
		RouteID:         "route_attachment",
		AgentID:         "agent_attachment",
		SourcePlatform:  monitorPlatformFeishu,
		SourceChatName:  "飞书测试群",
		SourceMessageID: "source_attachment_1",
		MessageType:     "image",
		Content:         "图片",
		Metadata:        "{}",
		AttachmentsJSON: `[{"kind":"image","data_url":"data:image/png;base64,aGVsbG8=","mime_type":"image/png"}]`,
		Attachments: []observedAttachment{{
			Kind:     "image",
			DataURL:  "data:image/png;base64,aGVsbG8=",
			MimeType: "image/png",
		}},
		ObservedAt:    dbrNullTime(api.now()),
		ForwardStatus: "pending",
	}
	require.NoError(t, api.db.insertObservedMessage(message))

	err := api.ensureObservedAttachmentUploaded(
		&routeModel{DestinationNo: "group_1"},
		message,
		"image",
	)
	require.NoError(t, err)
	require.Len(t, fakeFiles.uploads, 1)
	require.Equal(t, "image/png", fakeFiles.uploads[0].contentType)
	require.Equal(t, []byte("hello"), fakeFiles.uploads[0].body)

	persisted, err := api.db.queryObservedMessageByRouteSource(
		message.RouteID,
		message.SourceMessageID,
	)
	require.NoError(t, err)
	require.NotNil(t, persisted)
	var attachments []observedAttachment
	require.NoError(t, json.Unmarshal([]byte(persisted.AttachmentsJSON), &attachments))
	require.Len(t, attachments, 1)
	require.NotEmpty(t, attachments[0].RemoteURL)
	require.Contains(t, attachments[0].RemoteURL, "v1/file/preview/")
	require.Equal(t, "image/png", attachments[0].MimeType)
	require.Equal(t, int64(5), attachments[0].FileSizeBytes)
}

func TestPrepareObservedMessageAssetsForInsertUploadsAndStripsInlineData(t *testing.T) {
	api := &API{}
	fakeFiles := &fakeMonitorFileService{}
	api.fileService = fakeFiles
	api.now = func() time.Time { return time.Date(2026, 5, 8, 2, 30, 0, 0, time.UTC) }

	message := &observedMessageModel{
		MessageID:   "monitor_msg_pre_insert",
		MessageType: "image",
		Content:     "图片",
		Attachments: []observedAttachment{{
			Kind:      "image",
			SourceURL: "blob:https://feishu.example/image",
			DataURL:   "data:image/png;base64,aGVsbG8=",
			LocalPath: "C:\\Users\\COLORFUL\\AppData\\Local\\Temp\\feishu-image.png",
			FileName:  "feishu-image.png",
			MimeType:  "image/png",
		}},
	}

	err := api.prepareObservedMessageAssetsForInsert(&routeModel{DestinationNo: "group_1", IncludeImages: 1}, message)
	require.NoError(t, err)
	require.Len(t, fakeFiles.uploads, 1)
	require.Equal(t, "image/png", fakeFiles.uploads[0].contentType)
	require.Equal(t, []byte("hello"), fakeFiles.uploads[0].body)
	require.NotEmpty(t, message.Attachments[0].RemoteURL)
	require.Empty(t, message.Attachments[0].DataURL)
	require.Empty(t, message.Attachments[0].LocalPath)
	require.Empty(t, message.Attachments[0].SourceURL)
	require.NotContains(t, message.AttachmentsJSON, "data:image")
	require.NotContains(t, message.AttachmentsJSON, "aGVsbG8")
	require.NotContains(t, message.AttachmentsJSON, "local_path")
	require.NotContains(t, message.AttachmentsJSON, "source_url")
	require.Contains(t, message.AttachmentsJSON, "remote_url")
}

func TestPrepareObservedMessageAssetsDetectsWebPAndFixesStalePNGName(t *testing.T) {
	api := &API{}
	fakeFiles := &fakeMonitorFileService{}
	api.fileService = fakeFiles
	api.now = func() time.Time { return time.Date(2026, 5, 8, 4, 30, 0, 0, time.UTC) }
	webpBytes := []byte{
		0x52, 0x49, 0x46, 0x46,
		0x10, 0x00, 0x00, 0x00,
		0x57, 0x45, 0x42, 0x50,
		0x56, 0x50, 0x38, 0x58,
		0x00, 0x00, 0x00, 0x00,
	}

	message := &observedMessageModel{
		MessageID:   "monitor_msg_webp_mismatch",
		MessageType: "image",
		Content:     "图片",
		Attachments: []observedAttachment{{
			Kind:     "image",
			DataURL:  "data:image/png;base64," + base64.StdEncoding.EncodeToString(webpBytes),
			FileName: "feishu-image.png",
			MimeType: "image/png",
		}},
	}

	err := api.prepareObservedMessageAssetsForInsert(&routeModel{DestinationNo: "group_1", IncludeImages: 1}, message)
	require.NoError(t, err)
	require.Len(t, fakeFiles.uploads, 1)
	require.Equal(t, "image/webp", fakeFiles.uploads[0].contentType)
	require.Contains(t, fakeFiles.uploads[0].path, ".webp")
	require.Equal(t, webpBytes, fakeFiles.uploads[0].body)
	require.Equal(t, "feishu-image.webp", message.Attachments[0].FileName)
	require.Equal(t, "image/webp", message.Attachments[0].MimeType)
	require.Contains(t, message.Attachments[0].RemoteURL, ".webp")
	require.NotContains(t, message.AttachmentsJSON, "data:image")
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
		"observed_at":   "2026-05-07T10:15:20Z",
	}, "bad-token")

	require.Equal(t, http.StatusUnauthorized, recorder.Code)
	body := decodeBody(t, recorder)
	require.Equal(t, "invalid_agent_token", body["error"].(map[string]interface{})["code"])
}

func pairTestAgent(t *testing.T, s *server.Server) (string, string, string) {
	t.Helper()
	createRecorder := requestJSON(t, s, http.MethodPost, "/v1/monitor/agent-pairing-codes", map[string]interface{}{
		"device_name": "Windows Agent",
		"platform":    "windows",
	}, testutil.Token)
	require.Equal(t, http.StatusCreated, createRecorder.Code, createRecorder.Body.String())
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
	require.Equal(t, http.StatusCreated, pairRecorder.Code, pairRecorder.Body.String())
	pairBody := decodeBody(t, pairRecorder)
	pairData := pairBody["data"].(map[string]interface{})
	agentID := pairData["agent_id"].(string)
	agentToken := pairData["agent_token"].(string)
	require.NotEmpty(t, agentID)
	require.NotEmpty(t, agentToken)
	require.Equal(t, float64(20), pairData["heartbeat_interval_seconds"])
	return agentID, agentToken, pairingCode
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

type fakeMonitorFileUpload struct {
	path        string
	contentType string
	body        []byte
}

type fakeMonitorFileService struct {
	uploads []fakeMonitorFileUpload
}

func (s *fakeMonitorFileService) UploadFile(filePath string, contentType string, copyFileWriter func(io.Writer) error) (map[string]interface{}, error) {
	var body bytes.Buffer
	if err := copyFileWriter(&body); err != nil {
		return nil, err
	}
	s.uploads = append(s.uploads, fakeMonitorFileUpload{
		path:        filePath,
		contentType: contentType,
		body:        body.Bytes(),
	})
	return map[string]interface{}{"path": filePath}, nil
}

func (s *fakeMonitorFileService) DownloadURL(path string, filename string) (string, error) {
	return "", errors.New("not implemented")
}

func (s *fakeMonitorFileService) InitiateMultipartUpload(filePath string, contentType string, fileSize int64, chunkSize int64) (map[string]interface{}, error) {
	return nil, errors.New("not implemented")
}

func (s *fakeMonitorFileService) UploadMultipartPart(filePath string, uploadID string, partNumber int, reader io.Reader) error {
	return errors.New("not implemented")
}

func (s *fakeMonitorFileService) CompleteMultipartUpload(filePath string, contentType string, uploadID string, parts []int) (map[string]interface{}, error) {
	return nil, errors.New("not implemented")
}

func (s *fakeMonitorFileService) AbortMultipartUpload(uploadID string) error {
	return errors.New("not implemented")
}

func (s *fakeMonitorFileService) DownloadAndMakeCompose(uploadPath string, downloadURLs []string) (map[string]interface{}, error) {
	return nil, errors.New("not implemented")
}

func (s *fakeMonitorFileService) DownloadImage(url string, ctx context.Context) (io.ReadCloser, error) {
	return nil, errors.New("not implemented")
}

func (s *fakeMonitorFileService) ReadFile(path string, ctx context.Context) (io.ReadCloser, string, error) {
	return nil, "", errors.New("not implemented")
}
