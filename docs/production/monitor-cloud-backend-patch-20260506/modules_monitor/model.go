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
