package monitor

import (
	"errors"
	"time"

	"github.com/TangSengDaoDao/TangSengDaoDaoServerLib/config"
	"github.com/go-sql-driver/mysql"
	"github.com/gocraft/dbr/v2"
)

type DB struct {
	session *dbr.Session
}

func NewDB(ctx *config.Context) *DB {
	return &DB{session: ctx.DB()}
}

func (d *DB) insertPairingCode(m *pairingCodeModel) error {
	_, err := d.session.InsertInto("monitor_agent_pairing_code").
		Columns("code", "uid", "device_name", "platform", "expires_at").
		Values(m.Code, m.UID, m.DeviceName, m.Platform, formatDBTime(m.ExpiresAt.Time)).Exec()
	return err
}

func (d *DB) queryPairingCode(code string) (*pairingCodeModel, error) {
	var model *pairingCodeModel
	_, err := d.session.Select("*").From("monitor_agent_pairing_code").Where("code=?", code).Load(&model)
	return model, err
}

func (d *DB) markPairingCodeUsed(code string, usedAt time.Time) error {
	_, err := d.session.Update("monitor_agent_pairing_code").
		Set("used_at", formatDBTime(usedAt)).
		Where("code=? and used_at is null", code).Exec()
	return err
}

func (d *DB) insertAgent(m *agentModel) error {
	_, err := d.session.InsertInto("monitor_agent").
		Columns("agent_id", "uid", "agent_token", "device_name", "platform", "version", "status").
		Record(m).Exec()
	return err
}

func (d *DB) queryAgentByDevice(uid, platform, deviceName string) (*agentModel, error) {
	var model *agentModel
	_, err := d.session.Select("*").From("monitor_agent").
		Where("uid=? and platform=? and device_name=? and revoked_at is null", uid, platform, deviceName).
		OrderDir("updated_at", false).
		Limit(1).
		Load(&model)
	return model, err
}

func (d *DB) updateAgentPairing(agentID, token, deviceName, version string) error {
	_, err := d.session.Update("monitor_agent").SetMap(map[string]interface{}{
		"agent_token":       token,
		"device_name":       deviceName,
		"version":           version,
		"status":            "offline",
		"last_heartbeat_at": nil,
	}).Where("agent_id=? and revoked_at is null", agentID).Exec()
	return err
}

func (d *DB) queryAgentByToken(token string) (*agentModel, error) {
	var model *agentModel
	_, err := d.session.Select("*").From("monitor_agent").
		Where("agent_token=? and revoked_at is null", token).Load(&model)
	return model, err
}

func (d *DB) queryAgents(uid string, limit uint64) ([]*agentModel, error) {
	var list []*agentModel
	_, err := d.session.Select("*").From("monitor_agent").
		Where("uid=? and revoked_at is null", uid).
		OrderDir("updated_at", false).
		Limit(limit).
		Load(&list)
	return list, err
}

func (d *DB) updateAgentHeartbeat(agentID, token, deviceName, version string, now time.Time) error {
	_, err := d.session.Update("monitor_agent").SetMap(map[string]interface{}{
		"device_name":       deviceName,
		"version":           version,
		"status":            "online",
		"last_heartbeat_at": formatDBTime(now),
	}).Where("agent_id=? and agent_token=? and revoked_at is null", agentID, token).Exec()
	return err
}

func (d *DB) insertRoute(m *routeModel) error {
	_, err := d.session.InsertInto("monitor_route").
		Columns(
			"route_id", "uid", "platform", "connector_type", "route_type",
			"source_name", "destination_type", "destination_id", "destination_name", "destination_no",
			"sender_display_name", "sender_display_avatar", "agent_id", "status",
			"include_text", "include_links", "include_images", "include_files",
		).
		Record(m).Exec()
	return err
}

func (d *DB) queryRoutes(uid, platform string, limit uint64) ([]*routeModel, error) {
	var list []*routeModel
	builder := d.session.Select("*").From("monitor_route").Where("uid=?", uid)
	if platform != "" {
		builder = builder.Where("platform=?", platform)
	}
	_, err := builder.OrderDir("updated_at", false).Limit(limit).Load(&list)
	return list, err
}

func (d *DB) queryRunningRoutesForAgent(agentID string) ([]*routeModel, error) {
	var list []*routeModel
	_, err := d.session.Select("*").From("monitor_route").
		Where("agent_id=? and status=?", agentID, "running").
		OrderDir("updated_at", false).
		Load(&list)
	return list, err
}

func (d *DB) queryRouteByID(routeID string) (*routeModel, error) {
	var model *routeModel
	_, err := d.session.Select("*").From("monitor_route").Where("route_id=?", routeID).Load(&model)
	return model, err
}

func (d *DB) updateRouteStatus(uid, routeID, status string, pausedAt dbr.NullTime) error {
	setMap := map[string]interface{}{
		"status": status,
	}
	if pausedAt.Valid {
		setMap["paused_at"] = formatDBTime(pausedAt.Time)
	} else if status == "running" {
		setMap["paused_at"] = nil
	}
	_, err := d.session.Update("monitor_route").SetMap(setMap).
		Where("uid=? and route_id=?", uid, routeID).Exec()
	return err
}

func (d *DB) updateRoute(m *routeModel) error {
	setMap := map[string]interface{}{
		"platform":             m.Platform,
		"connector_type":       m.ConnectorType,
		"route_type":           m.RouteType,
		"source_name":          m.SourceName,
		"destination_type":     m.DestinationType,
		"destination_id":       m.DestinationID,
		"destination_name":     m.DestinationName,
		"destination_no":       m.DestinationNo,
		"sender_display_name":  m.SenderDisplayName,
		"sender_display_avatar": m.SenderDisplayAvatar,
		"include_text":         m.IncludeText,
		"include_links":        m.IncludeLinks,
		"include_images":       m.IncludeImages,
		"include_files":        m.IncludeFiles,
	}
	_, err := d.session.Update("monitor_route").SetMap(setMap).
		Where("uid=? and route_id=?", m.UID, m.RouteID).Exec()
	return err
}

func (d *DB) deleteRoute(uid, routeID string) error {
	_, err := d.session.DeleteFrom("monitor_route").
		Where("uid=? and route_id=?", uid, routeID).Exec()
	return err
}

func (d *DB) incrementRouteForwarded(routeID string, forwardedAt time.Time) error {
	_, err := d.session.Update("monitor_route").SetMap(map[string]interface{}{
		"today_forwarded_count": dbr.Expr("today_forwarded_count + 1"),
		"last_forwarded_at":     formatDBTime(forwardedAt),
	}).Where("route_id=?", routeID).Exec()
	return err
}

func (d *DB) insertCredential(m *credentialModel) error {
	_, err := d.session.InsertInto("monitor_credential").
		Columns(
			"credential_id", "uid", "platform", "kind", "display_name",
			"app_id_ciphertext", "app_id_masked", "app_secret_ciphertext",
			"webhook_url_ciphertext", "webhook_url_masked", "secret_ciphertext",
			"status", "last_error",
		).
		Values(
			m.CredentialID, m.UID, m.Platform, m.Kind, m.DisplayName,
			m.AppIDCiphertext, m.AppIDMasked, m.AppSecretCiphertext,
			m.WebhookURLCiphertext, m.WebhookURLMasked, m.SecretCiphertext,
			m.Status, m.LastError,
		).Exec()
	return err
}

func (d *DB) queryCredentials(uid, platform string, limit uint64) ([]*credentialModel, error) {
	var list []*credentialModel
	builder := d.session.Select("*").From("monitor_credential").
		Where("uid=? and revoked_at is null", uid)
	if platform != "" {
		builder = builder.Where("platform=?", platform)
	}
	_, err := builder.OrderDir("updated_at", false).Limit(limit).Load(&list)
	return list, err
}

func (d *DB) queryCredentialByID(uid, credentialID string) (*credentialModel, error) {
	var model *credentialModel
	_, err := d.session.Select("*").From("monitor_credential").
		Where("uid=? and credential_id=? and revoked_at is null", uid, credentialID).
		Limit(1).
		Load(&model)
	return model, err
}

func (d *DB) updateCredentialCheck(uid, credentialID, status, lastError string, checkedAt time.Time) error {
	_, err := d.session.Update("monitor_credential").SetMap(map[string]interface{}{
		"status":          status,
		"last_checked_at": formatDBTime(checkedAt),
		"last_error":      lastError,
	}).Where("uid=? and credential_id=? and revoked_at is null", uid, credentialID).Exec()
	return err
}

func (d *DB) insertDestination(m *destinationModel) error {
	_, err := d.session.InsertInto("monitor_destination").
		Columns(
			"destination_id", "uid", "platform", "destination_type", "display_name",
			"credential_id", "chat_id", "webhook_url_ciphertext", "webhook_url_masked",
			"secret_ciphertext", "status", "last_error",
		).
		Values(
			m.DestinationID, m.UID, m.Platform, m.DestinationType, m.DisplayName,
			m.CredentialID, m.ChatID, m.WebhookURLCiphertext, m.WebhookURLMasked,
			m.SecretCiphertext, m.Status, m.LastError,
		).Exec()
	return err
}

func (d *DB) queryDestinations(uid, platform string, limit uint64) ([]*destinationModel, error) {
	var list []*destinationModel
	builder := d.session.Select("*").From("monitor_destination").
		Where("uid=? and revoked_at is null", uid)
	if platform != "" {
		builder = builder.Where("platform=?", platform)
	}
	_, err := builder.OrderDir("updated_at", false).Limit(limit).Load(&list)
	return list, err
}

func (d *DB) queryDestinationByID(uid, destinationID string) (*destinationModel, error) {
	var model *destinationModel
	_, err := d.session.Select("*").From("monitor_destination").
		Where("uid=? and destination_id=? and revoked_at is null", uid, destinationID).
		Limit(1).
		Load(&model)
	return model, err
}

func (d *DB) upsertBrowserStatus(m *browserStatusModel) error {
	existing, err := d.queryLatestBrowserStatusForAgent(m.AgentID, m.Platform)
	if err != nil {
		return err
	}
	if existing == nil {
		_, err = d.session.InsertInto("monitor_agent_browser_status").
			Columns("status_id", "uid", "agent_id", "platform", "browser", "profile_mode", "login_status", "observed_at", "error_message").
			Values(m.StatusID, m.UID, m.AgentID, m.Platform, m.Browser, m.ProfileMode, m.LoginStatus, formatDBTime(m.ObservedAt.Time), m.ErrorMessage).Exec()
		return err
	}
	_, err = d.session.Update("monitor_agent_browser_status").SetMap(map[string]interface{}{
		"browser":       m.Browser,
		"profile_mode":  m.ProfileMode,
		"login_status":  m.LoginStatus,
		"observed_at":   formatDBTime(m.ObservedAt.Time),
		"error_message": m.ErrorMessage,
	}).Where("agent_id=? and platform=?", m.AgentID, m.Platform).Exec()
	return err
}

func (d *DB) queryLatestBrowserStatus(uid, platform string) (*browserStatusModel, error) {
	var model *browserStatusModel
	_, err := d.session.Select("*").From("monitor_agent_browser_status").
		Where("uid=? and platform=?", uid, platform).
		OrderDir("observed_at", false).
		Limit(1).
		Load(&model)
	return model, err
}

func (d *DB) queryLatestBrowserStatusForAgent(agentID, platform string) (*browserStatusModel, error) {
	var model *browserStatusModel
	_, err := d.session.Select("*").From("monitor_agent_browser_status").
		Where("agent_id=? and platform=?", agentID, platform).
		OrderDir("observed_at", false).
		Limit(1).
		Load(&model)
	return model, err
}

func (d *DB) insertObservedMessage(m *observedMessageModel) error {
	_, err := d.session.InsertInto("monitor_observed_message").
		Columns(
			"message_id", "uid", "route_id", "agent_id", "source_platform",
			"source_chat_name", "source_message_id", "message_type", "content",
			"metadata", "attachments",
			"source_created_at", "observed_at", "duplicate_of_message_id", "forward_status",
		).
		Values(
			m.MessageID, m.UID, m.RouteID, m.AgentID, m.SourcePlatform,
			m.SourceChatName, m.SourceMessageID, m.MessageType, m.Content,
			m.Metadata, m.AttachmentsJSON,
			nullTimeValue(m.SourceCreatedAt), formatDBTime(m.ObservedAt.Time), m.DuplicateOfMessageID, m.ForwardStatus,
		).Exec()
	return err
}

func isDuplicateKeyError(err error) bool {
	if err == nil {
		return false
	}
	var mysqlErr *mysql.MySQLError
	if errors.As(err, &mysqlErr) {
		return mysqlErr.Number == 1062
	}
	return false
}

func (d *DB) queryObservedMessageByRouteSource(routeID, sourceMessageID string) (*observedMessageModel, error) {
	var model *observedMessageModel
	_, err := d.session.Select("*").From("monitor_observed_message").
		Where("route_id=? and source_message_id=?", routeID, sourceMessageID).
		Limit(1).
		Load(&model)
	return model, err
}

func (d *DB) updateObservedMessageAttachments(messageID, attachmentsJSON string) error {
	_, err := d.session.Update("monitor_observed_message").SetMap(map[string]interface{}{
		"attachments": attachmentsJSON,
	}).Where("message_id=?", messageID).Exec()
	return err
}

func (d *DB) markObservedMessageForwarded(messageID string, forwardedAt time.Time) error {
	_, err := d.session.Update("monitor_observed_message").SetMap(map[string]interface{}{
		"forward_status":        "forwarded",
		"forwarded_at":          formatDBTime(forwardedAt),
		"forward_error_message": "",
	}).Where("message_id=?", messageID).Exec()
	return err
}

func (d *DB) markObservedMessageForwardFailed(messageID string, reason string) error {
	_, err := d.session.Update("monitor_observed_message").SetMap(map[string]interface{}{
		"forward_status":        "failed",
		"forward_error_message": reason,
	}).Where("message_id=?", messageID).Exec()
	return err
}

func (d *DB) insertEvent(m *eventModel) error {
	_, err := d.session.InsertInto("monitor_event").
		Columns("event_id", "uid", "platform", "agent_id", "route_id", "type", "message", "metadata").
		Record(m).Exec()
	return err
}

func (d *DB) queryEvents(uid, platform string, limit uint64) ([]*eventModel, error) {
	var list []*eventModel
	_, err := d.session.Select("*").From("monitor_event").
		Where("uid=? and platform=?", uid, platform).
		OrderDir("created_at", false).
		Limit(limit).
		Load(&list)
	return list, err
}

func formatDBTime(t time.Time) string {
	return t.Local().Format("2006-01-02 15:04:05")
}

func nullTimeValue(t dbr.NullTime) interface{} {
	if !t.Valid {
		return nil
	}
	return formatDBTime(t.Time)
}
