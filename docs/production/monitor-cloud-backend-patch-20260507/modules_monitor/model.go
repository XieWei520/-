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
	DestinationType     string       `db:"destination_type"`
	DestinationID       string       `db:"destination_id"`
	DestinationName     string       `db:"destination_name"`
	DestinationNo       string       `db:"destination_no"`
	SenderDisplayName   string       `db:"sender_display_name"`
	SenderDisplayAvatar string       `db:"sender_display_avatar"`
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

type updateRouteReq struct {
	Platform      string                 `json:"platform"`
	ConnectorType string                 `json:"connector_type"`
	RouteType     string                 `json:"route_type"`
	AgentID       string                 `json:"agent_id"`
	Source        map[string]interface{} `json:"source"`
	Destination   map[string]interface{} `json:"destination"`
	MessagePolicy map[string]interface{} `json:"message_policy"`
}

type credentialModel struct {
	Id                   int64        `db:"id"`
	CredentialID         string       `db:"credential_id"`
	UID                  string       `db:"uid"`
	Platform             string       `db:"platform"`
	Kind                 string       `db:"kind"`
	DisplayName          string       `db:"display_name"`
	AppIDCiphertext      string       `db:"app_id_ciphertext"`
	AppIDMasked          string       `db:"app_id_masked"`
	AppSecretCiphertext  string       `db:"app_secret_ciphertext"`
	WebhookURLCiphertext string       `db:"webhook_url_ciphertext"`
	WebhookURLMasked     string       `db:"webhook_url_masked"`
	SecretCiphertext     string       `db:"secret_ciphertext"`
	Status               string       `db:"status"`
	LastCheckedAt        dbr.NullTime `db:"last_checked_at"`
	LastError            string       `db:"last_error"`
	CreatedAt            dbr.NullTime `db:"created_at"`
	UpdatedAt            dbr.NullTime `db:"updated_at"`
	RevokedAt            dbr.NullTime `db:"revoked_at"`
}

type destinationModel struct {
	Id                   int64        `db:"id"`
	DestinationID        string       `db:"destination_id"`
	UID                  string       `db:"uid"`
	Platform             string       `db:"platform"`
	DestinationType      string       `db:"destination_type"`
	DisplayName          string       `db:"display_name"`
	CredentialID         string       `db:"credential_id"`
	ChatID               string       `db:"chat_id"`
	WebhookURLCiphertext string       `db:"webhook_url_ciphertext"`
	WebhookURLMasked     string       `db:"webhook_url_masked"`
	SecretCiphertext     string       `db:"secret_ciphertext"`
	Status               string       `db:"status"`
	LastCheckedAt        dbr.NullTime `db:"last_checked_at"`
	LastError            string       `db:"last_error"`
	CreatedAt            dbr.NullTime `db:"created_at"`
	UpdatedAt            dbr.NullTime `db:"updated_at"`
	RevokedAt            dbr.NullTime `db:"revoked_at"`
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
	Id                   int64  `db:"id"`
	MessageID            string `db:"message_id"`
	UID                  string `db:"uid"`
	RouteID              string `db:"route_id"`
	AgentID              string `db:"agent_id"`
	SourcePlatform       string `db:"source_platform"`
	SourceChatName       string `db:"source_chat_name"`
	SourceMessageID      string `db:"source_message_id"`
	MessageType          string `db:"message_type"`
	Content              string `db:"content"`
	Metadata             string `db:"metadata"`
	AttachmentsJSON      string `db:"attachments"`
	Attachments          []observedAttachment
	SourceCreatedAt      dbr.NullTime `db:"source_created_at"`
	ObservedAt           dbr.NullTime `db:"observed_at"`
	DuplicateOfMessageID string       `db:"duplicate_of_message_id"`
	ForwardStatus        string       `db:"forward_status"`
	ForwardedAt          dbr.NullTime `db:"forwarded_at"`
	ForwardErrorMessage  string       `db:"forward_error_message"`
	CreatedAt            dbr.NullTime `db:"created_at"`
	UpdatedAt            dbr.NullTime `db:"updated_at"`
}

type observedAttachment struct {
	Kind          string `json:"kind"`
	SourceURL     string `json:"source_url,omitempty"`
	DataURL       string `json:"data_url,omitempty"`
	LocalPath     string `json:"local_path,omitempty"`
	RemoteURL     string `json:"remote_url,omitempty"`
	FileName      string `json:"file_name,omitempty"`
	FileSizeText  string `json:"file_size_text,omitempty"`
	FileSizeBytes int64  `json:"file_size_bytes,omitempty"`
	MimeType      string `json:"mime_type,omitempty"`
	Width         int64  `json:"width,omitempty"`
	Height        int64  `json:"height,omitempty"`
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
	updateRouteReq
}

type createCredentialReq struct {
	Platform    string `json:"platform"`
	Kind        string `json:"kind"`
	DisplayName string `json:"display_name"`
	AppID       string `json:"app_id"`
	AppSecret   string `json:"app_secret"`
	WebhookURL  string `json:"webhook_url"`
	Secret      string `json:"secret"`
}

type createDestinationReq struct {
	Platform        string `json:"platform"`
	DestinationType string `json:"destination_type"`
	DisplayName     string `json:"display_name"`
	CredentialID    string `json:"credential_id"`
	ChatID          string `json:"chat_id"`
	WebhookURL      string `json:"webhook_url"`
	Secret          string `json:"secret"`
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
	AgentID         string                 `json:"agent_id"`
	RouteID         string                 `json:"route_id"`
	SourcePlatform  string                 `json:"source_platform"`
	SourceChatName  string                 `json:"source_chat_name"`
	SourceMessageID string                 `json:"source_message_id"`
	MessageType     string                 `json:"message_type"`
	Content         string                 `json:"content"`
	SourceCreatedAt string                 `json:"source_created_at"`
	ObservedAt      string                 `json:"observed_at"`
	Metadata        map[string]interface{} `json:"metadata"`
	Attachments     []observedAttachment   `json:"attachments"`
}
