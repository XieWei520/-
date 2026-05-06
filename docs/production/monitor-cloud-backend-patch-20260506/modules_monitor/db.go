package monitor

import (
	"time"

	"github.com/TangSengDaoDao/TangSengDaoDaoServerLib/config"
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

func formatDBTime(t time.Time) string {
	return t.Local().Format("2006-01-02 15:04:05")
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
