package monitor

import "github.com/gocraft/dbr/v2"

type pairingCodeModel struct {
	Id         int64        `db:"id"`
	Code       string       `db:"code"`
	UID        string       `db:"uid"`
	DeviceName string       `db:"device_name"`
	Platform   string       `db:"platform"`
	ExpiresAt  dbr.NullTime `db:"expires_at"`
	UsedAt     dbr.NullTime `db:"used_at"`
	CreatedAt  dbr.NullTime `db:"created_at"`
	UpdatedAt  dbr.NullTime `db:"updated_at"`
}

type agentModel struct {
	Id              int64        `db:"id"`
	AgentID         string       `db:"agent_id"`
	UID             string       `db:"uid"`
	AgentToken      string       `db:"agent_token"`
	DeviceName      string       `db:"device_name"`
	Platform        string       `db:"platform"`
	Version         string       `db:"version"`
	Status          string       `db:"status"`
	LastHeartbeatAt dbr.NullTime `db:"last_heartbeat_at"`
	CreatedAt       dbr.NullTime `db:"created_at"`
	UpdatedAt       dbr.NullTime `db:"updated_at"`
	RevokedAt       dbr.NullTime `db:"revoked_at"`
}

type routeModel struct {
	Id                  int64        `db:"id"`
	RouteID             string       `db:"route_id"`
	UID                 string       `db:"uid"`
	Platform            string       `db:"platform"`
	ConnectorType       string       `db:"connector_type"`
	RouteType           string       `db:"route_type"`
	SourceName          string       `db:"source_name"`
	DestinationName     string       `db:"destination_name"`
	DestinationNo       string       `db:"destination_no"`
	AgentID             string       `db:"agent_id"`
	Status              string       `db:"status"`
	TodayForwardedCount int          `db:"today_forwarded_count"`
	LastForwardedAt     dbr.NullTime `db:"last_forwarded_at"`
	IncludeText         int          `db:"include_text"`
	IncludeLinks        int          `db:"include_links"`
	IncludeImages       int          `db:"include_images"`
	IncludeFiles        int          `db:"include_files"`
	CreatedAt           dbr.NullTime `db:"created_at"`
	UpdatedAt           dbr.NullTime `db:"updated_at"`
	PausedAt            dbr.NullTime `db:"paused_at"`
	ErrorMessage        string       `db:"error_message"`
}

type browserStatusModel struct {
	Id           int64        `db:"id"`
	StatusID     string       `db:"status_id"`
	UID          string       `db:"uid"`
	AgentID      string       `db:"agent_id"`
	Platform     string       `db:"platform"`
	Browser      string       `db:"browser"`
	ProfileMode  string       `db:"profile_mode"`
	LoginStatus  string       `db:"login_status"`
	ObservedAt   dbr.NullTime `db:"observed_at"`
	ErrorMessage string       `db:"error_message"`
	CreatedAt    dbr.NullTime `db:"created_at"`
	UpdatedAt    dbr.NullTime `db:"updated_at"`
}

type observedMessageModel struct {
	Id                   int64        `db:"id"`
	MessageID            string       `db:"message_id"`
	UID                  string       `db:"uid"`
	RouteID              string       `db:"route_id"`
	AgentID              string       `db:"agent_id"`
	SourcePlatform       string       `db:"source_platform"`
	SourceChatName       string       `db:"source_chat_name"`
	SourceMessageID      string       `db:"source_message_id"`
	MessageType          string       `db:"message_type"`
	Content              string       `db:"content"`
	SourceCreatedAt      dbr.NullTime `db:"source_created_at"`
	ObservedAt           dbr.NullTime `db:"observed_at"`
	DuplicateOfMessageID string       `db:"duplicate_of_message_id"`
	ForwardStatus        string       `db:"forward_status"`
	ForwardedAt          dbr.NullTime `db:"forwarded_at"`
	ForwardErrorMessage  string       `db:"forward_error_message"`
	CreatedAt            dbr.NullTime `db:"created_at"`
	UpdatedAt            dbr.NullTime `db:"updated_at"`
}

type eventModel struct {
	Id        int64        `db:"id"`
	EventID   string       `db:"event_id"`
	UID       string       `db:"uid"`
	Platform  string       `db:"platform"`
	AgentID   string       `db:"agent_id"`
	RouteID   string       `db:"route_id"`
	Type      string       `db:"type"`
	Message   string       `db:"message"`
	Metadata  string       `db:"metadata"`
	CreatedAt dbr.NullTime `db:"created_at"`
}

type createPairingCodeReq struct {
	DeviceName string `json:"device_name"`
	Platform   string `json:"platform"`
}

type pairAgentReq struct {
	PairingCode  string `json:"pairing_code"`
	DeviceName   string `json:"device_name"`
	Platform     string `json:"platform"`
	AgentVersion string `json:"agent_version"`
}

type heartbeatReq struct {
	AgentID      string   `json:"agent_id"`
	Status       string   `json:"status"`
	DeviceName   string   `json:"device_name"`
	Platform     string   `json:"platform"`
	AgentVersion string   `json:"agent_version"`
	Capabilities []string `json:"capabilities"`
	ObservedAt   string   `json:"observed_at"`
}

type createRouteReq struct {
	Platform      string                 `json:"platform"`
	ConnectorType string                 `json:"connector_type"`
	RouteType     string                 `json:"route_type"`
	AgentID       string                 `json:"agent_id"`
	Source        map[string]interface{} `json:"source"`
	Destination   map[string]interface{} `json:"destination"`
	MessagePolicy map[string]interface{} `json:"message_policy"`
}

type updateRouteStatusReq struct {
	Status string `json:"status"`
}

type browserStatusReq struct {
	AgentID      string `json:"agent_id"`
	Platform     string `json:"platform"`
	Browser      string `json:"browser"`
	ProfileMode  string `json:"profile_mode"`
	LoginStatus  string `json:"login_status"`
	ObservedAt   string `json:"observed_at"`
	ErrorMessage string `json:"error_message"`
}

type observedMessageReq struct {
	AgentID         string `json:"agent_id"`
	RouteID         string `json:"route_id"`
	SourcePlatform  string `json:"source_platform"`
	SourceChatName  string `json:"source_chat_name"`
	SourceMessageID string `json:"source_message_id"`
	MessageType     string `json:"message_type"`
	Content         string `json:"content"`
	SourceCreatedAt string `json:"source_created_at"`
	ObservedAt      string `json:"observed_at"`
}
