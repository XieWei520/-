package extra

import (
	"encoding/json"
	"time"

	"github.com/TangSengDaoDao/TangSengDaoDaoServerLib/config"
	"github.com/gocraft/dbr/v2"
)

// DB 鏁版嵁搴撴搷浣?type DB struct {
type DB struct {
	session *dbr.Session
}

// NewDB 鍒涘缓鏁版嵁搴撳疄渚?func NewDB(ctx *config.Context) *DB {
func NewDB(ctx *config.Context) *DB {
	return &DB{
		session: ctx.DB(),
	}
}

// ============================================================
// 鏀惰棌鎿嶄綔
// ============================================================

// InsertFavorite 娣诲姞鏀惰棌
func (d *DB) InsertFavorite(f *FavoriteModel) error {
	_, err := d.session.InsertInto("favorite").
		Columns("uid", "client_msg_no", "message_id", "message_seq", "order_seq", "content", "content_type",
			"channel_id", "channel_type", "sender_uid", "sender_name").
		Record(f).Exec()
	return err
}

// DeleteFavorite 鍒犻櫎鏀惰棌
func (d *DB) DeleteFavorite(uid string, clientMsgNo string) error {
	_, err := d.session.DeleteFrom("favorite").
		Where("uid=? and client_msg_no=?", uid, clientMsgNo).Exec()
	return err
}

// DeleteFavoriteByID 鍒犻櫎鏀惰棌锛堟寜ID锛?func (d *DB) DeleteFavoriteByID(id int64) error {
func (d *DB) DeleteFavoriteByID(id int64) error {
	_, err := d.session.DeleteFrom("favorite").Where("id=?", id).Exec()
	return err
}

// QueryFavoriteByClientMsgNo 鏌ヨ鏀惰棌锛堟寜瀹㈡埛绔秷鎭疘D锛?func (d *DB) QueryFavoriteByClientMsgNo(uid string, clientMsgNo string) (*FavoriteModel, error) {
func (d *DB) QueryFavoriteByClientMsgNo(uid string, clientMsgNo string) (*FavoriteModel, error) {
	var model *FavoriteModel
	_, err := d.session.Select("*").From("favorite").
		Where("uid=? and client_msg_no=?", uid, clientMsgNo).Load(&model)
	return model, err
}

// QueryFavoriteByID 鏌ヨ鏀惰棌锛堟寜ID锛?func (d *DB) QueryFavoriteByID(id int64) (*FavoriteModel, error) {
func (d *DB) QueryFavoriteByID(id int64) (*FavoriteModel, error) {
	var model *FavoriteModel
	_, err := d.session.Select("*").From("favorite").Where("id=?", id).Load(&model)
	return model, err
}

// QueryFavorites 鏌ヨ鏀惰棌鍒楄〃锛堝垎椤碉級
func (d *DB) QueryFavorites(uid string, page, pageSize int) ([]*FavoriteModel, int64, error) {
	var list []*FavoriteModel
	var total int64
	var cn int64

	offset := (page - 1) * pageSize

	// 缁熻鎬绘暟
	err := d.session.Select("count(*)").From("favorite").Where("uid=?", uid).LoadOne(&cn)
	if err != nil {
		return nil, 0, err
	}
	if cn == 0 {
		return list, 0, nil
	}
	total = cn

	_, err = d.session.Select("*").From("favorite").
		Where("uid=?", uid).
		OrderBy("created_at desc").
		Limit(uint64(pageSize)).
		Offset(uint64(offset)).
		Load(&list)
	return list, total, err
}

// SearchFavorites 鎼滅储鏀惰棌
func (d *DB) SearchFavorites(uid string, keyword string, page, pageSize int) ([]*FavoriteModel, int64, error) {
	var list []*FavoriteModel
	var total int64
	searchPattern := "%" + keyword + "%"
	offset := (page - 1) * pageSize

	// 缁熻
	err := d.session.Select("count(*)").From("favorite").
		Where("uid=? and content like ?", uid, searchPattern).LoadOne(&total)
	if err != nil {
		return nil, 0, err
	}

	_, err = d.session.Select("*").From("favorite").
		Where("uid=? and content like ?", uid, searchPattern).
		OrderBy("created_at desc").
		Limit(uint64(pageSize)).
		Offset(uint64(offset)).
		Load(&list)
	return list, total, err
}

// ============================================================
// 鏍囩鎿嶄綔
// ============================================================

// InsertTag 鍒涘缓鏍囩
func (d *DB) InsertTag(t *TagModel) error {
	_, err := d.session.InsertInto("tag").
		Columns("uid", "name", "remark").Record(t).Exec()
	return err
}

// UpdateTag 鏇存柊鏍囩
func (d *DB) UpdateTag(t *TagModel) error {
	_, err := d.session.Update("tag").
		SetMap(map[string]interface{}{
			"name":   t.Name,
			"remark": t.Remark,
		}).Where("id=?", t.Id).Exec()
	return err
}

// DeleteTag 鍒犻櫎鏍囩
func (d *DB) DeleteTag(tagId int64) error {
	tx, err := d.session.Begin()
	if err != nil {
		return err
	}
	defer tx.Rollback()

	// 鍒犻櫎鏍囩鎴愬憳
	_, err = tx.DeleteFrom("tag_member").Where("tag_id=?", tagId).Exec()
	if err != nil {
		return err
	}
	// 鍒犻櫎鏍囩
	_, err = tx.DeleteFrom("tag").Where("id=?", tagId).Exec()
	if err != nil {
		return err
	}
	return tx.Commit()
}

// QueryTagByID 鏌ヨ鏍囩
func (d *DB) QueryTagByID(tagId int64) (*TagModel, error) {
	var model *TagModel
	_, err := d.session.Select("*").From("tag").Where("id=?", tagId).Load(&model)
	return model, err
}

// QueryTagsByUID 鏌ヨ鐢ㄦ埛鐨勬墍鏈夋爣绛?func (d *DB) QueryTagsByUID(uid string) ([]*TagModel, error) {
func (d *DB) QueryTagsByUID(uid string) ([]*TagModel, error) {
	var list []*TagModel
	_, err := d.session.Select("*").From("tag").
		Where("uid=?", uid).
		OrderBy("created_at desc").
		Load(&list)
	return list, err
}

// InsertTagMember 娣诲姞鏍囩鎴愬憳
func (d *DB) InsertTagMember(m *TagMemberModel) error {
	_, err := d.session.InsertInto("tag_member").
		Columns("tag_id", "uid", "user_name").Record(m).Exec()
	return err
}

// DeleteTagMember 鍒犻櫎鏍囩鎴愬憳
func (d *DB) DeleteTagMember(tagId int64, uid string) error {
	_, err := d.session.DeleteFrom("tag_member").
		Where("tag_id=? and uid=?", tagId, uid).Exec()
	return err
}

// DeleteTagMembers 鎵归噺鍒犻櫎鏍囩鎴愬憳
func (d *DB) DeleteTagMembers(tagId int64, uids []string) error {
	_, err := d.session.DeleteFrom("tag_member").
		Where("tag_id=? and uid in ?", tagId, uids).Exec()
	return err
}

// QueryTagMembers 鏌ヨ鏍囩鐨勬墍鏈夋垚鍛?func (d *DB) QueryTagMembers(tagId int64) ([]*TagMemberModel, error) {
func (d *DB) QueryTagMembers(tagId int64) ([]*TagMemberModel, error) {
	var list []*TagMemberModel
	_, err := d.session.Select("*").From("tag_member").
		Where("tag_id=?", tagId).
		OrderBy("created_at desc").
		Load(&list)
	return list, err
}

// CountTagMembers 缁熻鏍囩鎴愬憳鏁伴噺
func (d *DB) CountTagMembers(tagId int64) (int, error) {
	var count int64
	err := d.session.Select("count(*)").From("tag_member").
		Where("tag_id=?", tagId).LoadOne(&count)
	return int(count), err
}

// ============================================================
// 鏈嬪弸鍦堟搷浣?// ============================================================

// InsertMoment 鍙戝竷鏈嬪弸鍦?func (d *DB) InsertMoment(m *MomentModel) error {
func (d *DB) InsertMoment(m *MomentModel) error {
	_, err := d.session.InsertInto("moment").
		Columns("uid", "content", "location", "images", "mentions", "like_count", "comment_count", "status").
		Record(m).Exec()
	return err
}

// DeleteMoment 鍒犻櫎鏈嬪弸鍦?func (d *DB) DeleteMoment(momentId int64, uid string) error {
func (d *DB) DeleteMoment(momentId int64, uid string) error {
	_, err := d.session.Update("moment").
		Set("status", 0).
		Where("id=? and uid=?", momentId, uid).Exec()
	return err
}

// UpdateMomentCounts 鏇存柊鏈嬪弸鍦堣鏁?func (d *DB) UpdateMomentCounts(momentId int64, likeDelta, commentDelta int) error {
func (d *DB) UpdateMomentCounts(momentId int64, likeDelta, commentDelta int) error {
	_, err := d.session.Update("moment").
		SetMap(map[string]interface{}{
			"like_count":    dbr.Expr("like_count + ?", likeDelta),
			"comment_count": dbr.Expr("comment_count + ?", commentDelta),
		}).Where("id=?", momentId).Exec()
	return err
}

// QueryMoments 鏌ヨ鏈嬪弸鍦堝垪琛紙鍒嗛〉锛?func (d *DB) QueryMoments(uid string, page, pageSize int) ([]*MomentModel, int64, error) {
func (d *DB) QueryMoments(uid string, page, pageSize int) ([]*MomentModel, int64, error) {
	var list []*MomentModel
	var total int64

	offset := (page - 1) * pageSize

	// 缁熻
	err := d.session.Select("count(*)").From("moment").
		Where("uid=? and status=1", uid).LoadOne(&total)
	if err != nil {
		return nil, 0, err
	}

	_, err = d.session.Select("*").From("moment").
		Where("uid=? and status=1", uid).
		OrderBy("created_at desc").
		Limit(uint64(pageSize)).
		Offset(uint64(offset)).
		Load(&list)
	return list, total, err
}

// QueryMomentsForFriends 鏌ヨ鏈嬪弸鍦堬紙渚涘ソ鍙嬫煡鐪嬶級
func (d *DB) QueryMomentsForFriends(uids []string, maxId int64, pageSize int) ([]*MomentModel, error) {
	var list []*MomentModel
	query := d.session.Select("*").From("moment").
		Where("uid in ? and status=1", uids).
		OrderBy("created_at desc")

	if maxId > 0 {
		query = query.Where("id < ?", maxId)
	}

	_, err := query.Limit(uint64(pageSize)).Load(&list)
	return list, err
}

// QueryMomentByID 鏌ヨ鏈嬪弸鍦?func (d *DB) QueryMomentByID(momentId int64) (*MomentModel, error) {
func (d *DB) QueryMomentByID(momentId int64) (*MomentModel, error) {
	var model *MomentModel
	_, err := d.session.Select("*").From("moment").Where("id=?", momentId).Load(&model)
	return model, err
}

// InsertMomentLike 娣诲姞鏈嬪弸鍦堢偣璧?func (d *DB) InsertMomentLike(m *MomentLikeModel) error {
func (d *DB) InsertMomentLike(m *MomentLikeModel) error {
	_, err := d.session.InsertInto("moment_like").
		Columns("moment_id", "uid", "user_name").
		Record(m).Exec()
	return err
}

// DeleteMomentLike 鍒犻櫎鏈嬪弸鍦堢偣璧?func (d *DB) DeleteMomentLike(momentId int64, uid string) error {
func (d *DB) DeleteMomentLike(momentId int64, uid string) error {
	_, err := d.session.DeleteFrom("moment_like").
		Where("moment_id=? and uid=?", momentId, uid).Exec()
	return err
}

// QueryMomentLike 鏌ヨ鐐硅禐璁板綍
func (d *DB) QueryMomentLike(momentId int64, uid string) (*MomentLikeModel, error) {
	var model *MomentLikeModel
	_, err := d.session.Select("*").From("moment_like").
		Where("moment_id=? and uid=?", momentId, uid).Load(&model)
	return model, err
}

// QueryMomentLikes 鏌ヨ鏈嬪弸鍦堢殑鎵€鏈夌偣璧?func (d *DB) QueryMomentLikes(momentId int64) ([]*MomentLikeModel, error) {
func (d *DB) QueryMomentLikes(momentId int64) ([]*MomentLikeModel, error) {
	var list []*MomentLikeModel
	_, err := d.session.Select("*").From("moment_like").
		Where("moment_id=?", momentId).
		OrderBy("created_at desc").
		Load(&list)
	return list, err
}

func (d *DB) QueryMomentLikesByMomentIDs(momentIDs []int64) ([]*MomentLikeModel, error) {
	if len(momentIDs) == 0 {
		return nil, nil
	}
	var list []*MomentLikeModel
	_, err := d.session.Select("*").From("moment_like").
		Where("moment_id in ?", momentIDs).
		OrderBy("moment_id asc, created_at desc, id desc").
		Load(&list)
	return list, err
}

// InsertMomentComment 娣诲姞鏈嬪弸鍦堣瘎璁?func (d *DB) InsertMomentComment(c *MomentCommentModel) error {
func (d *DB) InsertMomentComment(c *MomentCommentModel) error {
	_, err := d.session.InsertInto("moment_comment").
		Columns("moment_id", "uid", "user_name", "content", "reply_to_uid", "reply_to_name").
		Record(c).Exec()
	return err
}

// DeleteMomentComment 鍒犻櫎鏈嬪弸鍦堣瘎璁?func (d *DB) DeleteMomentComment(commentId int64, uid string) error {
func (d *DB) DeleteMomentComment(commentId int64, uid string) error {
	_, err := d.session.Update("moment_comment").
		Set("status", 0).
		Where("id=? and uid=?", commentId, uid).Exec()
	return err
}

// QueryMomentComments 鏌ヨ鏈嬪弸鍦堢殑璇勮
func (d *DB) QueryMomentComments(momentId int64, page, pageSize int) ([]*MomentCommentModel, int64, error) {
	var list []*MomentCommentModel
	var total int64

	offset := (page - 1) * pageSize

	err := d.session.Select("count(*)").From("moment_comment").
		Where("moment_id=? and status=1", momentId).LoadOne(&total)
	if err != nil {
		return nil, 0, err
	}

	_, err = d.session.Select("*").From("moment_comment").
		Where("moment_id=? and status=1", momentId).
		OrderBy("created_at asc").
		Limit(uint64(pageSize)).
		Offset(uint64(offset)).
		Load(&list)
	return list, total, err
}

func (d *DB) QueryMomentCommentsByMomentIDs(momentIDs []int64, limitPerMoment int) ([]*MomentCommentModel, error) {
	if len(momentIDs) == 0 || limitPerMoment <= 0 {
		return nil, nil
	}
	sql := `
SELECT id, moment_id, uid, user_name, content, reply_to_uid, reply_to_name, status, created_at, updated_at
FROM (
  SELECT *,
         ROW_NUMBER() OVER (PARTITION BY moment_id ORDER BY created_at DESC, id DESC) AS rn
  FROM moment_comment
  WHERE moment_id in ? AND status = 1
) ranked
WHERE rn <= ?
ORDER BY moment_id asc, created_at desc, id desc`
	var list []*MomentCommentModel
	_, err := d.session.SelectBySql(sql, momentIDs, limitPerMoment).Load(&list)
	return list, err
}

// QueryMomentCommentByID 鏌ヨ璇勮
func (d *DB) QueryMomentCommentByID(commentId int64) (*MomentCommentModel, error) {
	var model *MomentCommentModel
	_, err := d.session.Select("*").From("moment_comment").
		Where("id=?", commentId).Load(&model)
	return model, err
}

// QueryManagerMoments 查询朋友圈治理列表
func (d *DB) QueryManagerMoments(uid string, keyword string, status int, pageIndex, pageSize int) ([]*MomentModel, int64, error) {
	var list []*MomentModel
	var total int64

	if pageIndex <= 0 {
		pageIndex = 1
	}
	if pageSize <= 0 {
		pageSize = 15
	}
	offset := (pageIndex - 1) * pageSize
	if offset < 0 {
		offset = 0
	}

	countQuery := d.session.Select("count(*)").From("moment")
	listQuery := d.session.Select("*").From("moment")

	if uid != "" {
		countQuery = countQuery.Where("uid=?", uid)
		listQuery = listQuery.Where("uid=?", uid)
	}
	if keyword != "" {
		searchPattern := "%" + keyword + "%"
		countQuery = countQuery.Where("content like ?", searchPattern)
		listQuery = listQuery.Where("content like ?", searchPattern)
	}
	if status == 0 || status == 1 {
		countQuery = countQuery.Where("status=?", status)
		listQuery = listQuery.Where("status=?", status)
	}

	if err := countQuery.LoadOne(&total); err != nil {
		return nil, 0, err
	}
	if total == 0 {
		return list, 0, nil
	}

	_, err := listQuery.
		OrderBy("created_at desc").
		Limit(uint64(pageSize)).
		Offset(uint64(offset)).
		Load(&list)
	return list, total, err
}

// QueryManagerMomentComments 查询朋友圈治理评论
func (d *DB) QueryManagerMomentComments(momentId int64) ([]*MomentCommentModel, error) {
	var list []*MomentCommentModel
	_, err := d.session.Select("*").From("moment_comment").
		Where("moment_id=? and status=1", momentId).
		OrderBy("created_at asc, id asc").
		Load(&list)
	return list, err
}

// ManagerOfflineMoment 缁狅紕鎮婄粩顖欑瑓閺嬭埖婀呴崣瀣箑
func (d *DB) ManagerOfflineMoment(momentId int64) error {
	_, err := d.session.Update("moment").
		SetMap(map[string]interface{}{
			"status":     0,
			"updated_at": dbr.Expr("CURRENT_TIMESTAMP"),
		}).
		Where("id=?", momentId).
		Exec()
	return err
}

// ============================================================
// 鐢ㄦ埛鍏ㄥ眬璁剧疆鎿嶄綔
// ============================================================

// InsertOrUpdateSetting 鎻掑叆鎴栨洿鏂扮敤鎴疯缃?func (d *DB) InsertOrUpdateSetting(s *UserGlobalSettingModel) error {
func (d *DB) InsertOrUpdateSetting(s *UserGlobalSettingModel) error {
	_, err := d.session.InsertInto("user_global_setting").
		Columns("uid", "search_by_phone", "search_by_short", "new_msg_notice",
			"msg_show_detail", "voice_on", "shock_on", "offline_protection",
			"device_lock", "device_lock_pwd", "mute_of_app").
		Record(s).
		Exec()
	return err
}

// UpdateSetting 鏇存柊鐢ㄦ埛璁剧疆
func (d *DB) UpdateSetting(uid string, updates map[string]interface{}) error {
	_, err := d.session.Update("user_global_setting").
		SetMap(updates).
		Where("uid=?", uid).
		Exec()
	return err
}

// QuerySetting 鏌ヨ鐢ㄦ埛璁剧疆
func (d *DB) QuerySetting(uid string) (*UserGlobalSettingModel, error) {
	var model *UserGlobalSettingModel
	_, err := d.session.Select("*").From("user_global_setting").
		Where("uid=?", uid).Load(&model)
	return model, err
}

// EnsureSettingExists 纭繚鐢ㄦ埛璁剧疆瀛樺湪锛堜笉瀛樺湪鍒欏垱寤洪粯璁よ缃級
func (d *DB) EnsureSettingExists(uid string) error {
	model, err := d.QuerySetting(uid)
	if err != nil {
		return err
	}
	if model != nil {
		return nil
	}
	newModel := &UserGlobalSettingModel{
		Uid:               uid,
		SearchByPhone:     1,
		SearchByShort:     1,
		NewMsgNotice:      1,
		MsgShowDetail:     1,
		VoiceOn:           1,
		ShockOn:           1,
		OfflineProtection: 0,
		DeviceLock:        0,
		MuteOfApp:         0,
	}
	return d.InsertOrUpdateSetting(newModel)
}

// UpdateDeviceLockPwd 鏇存柊璁惧閿佸瘑鐮?func (d *DB) UpdateDeviceLockPwd(uid, deviceId, pwd string, enabled bool) error {
func (d *DB) UpdateDeviceLockPwd(uid, deviceId, pwd string, enabled bool) error {
	var existing *DeviceLockRecordModel
	d.session.Select("*").From("device_lock_record").
		Where("uid=? and device_id=?", uid, deviceId).Load(&existing)

	if existing != nil {
		enabledInt := 0
		if enabled {
			enabledInt = 1
		}
		_, err := d.session.Update("device_lock_record").
			SetMap(map[string]interface{}{
				"password": pwd,
				"enabled":  enabledInt,
			}).Where("uid=? and device_id=?", uid, deviceId).Exec()
		return err
	}

	enabledInt := 0
	if enabled {
		enabledInt = 1
	}
	record := &DeviceLockRecordModel{
		Uid:      uid,
		DeviceId: deviceId,
		Password: pwd,
		Enabled:  enabledInt,
	}
	_, err := d.session.InsertInto("device_lock_record").
		Columns("uid", "device_id", "password", "enabled").
		Record(record).Exec()
	return err
}

// QueryDeviceLock 鏌ヨ璁惧閿佺姸鎬?func (d *DB) QueryDeviceLock(uid, deviceId string) (*DeviceLockRecordModel, error) {
func (d *DB) QueryDeviceLock(uid, deviceId string) (*DeviceLockRecordModel, error) {
	var model *DeviceLockRecordModel
	_, err := d.session.Select("*").From("device_lock_record").
		Where("uid=? and device_id=?", uid, deviceId).Load(&model)
	return model, err
}

// GetDeviceLocks 鏌ヨ鐢ㄦ埛鐨勬墍鏈夎澶囬攣
func (d *DB) GetDeviceLocks(uid string) ([]*DeviceLockRecordModel, error) {
	var list []*DeviceLockRecordModel
	_, err := d.session.Select("*").From("device_lock_record").
		Where("uid=?", uid).
		OrderBy("created_at desc").
		Load(&list)
	return list, err
}

// DeleteDeviceLock 鍒犻櫎璁惧閿佽褰?func (d *DB) DeleteDeviceLock(uid, deviceId string) error {
func (d *DB) DeleteDeviceLock(uid, deviceId string) error {
	_, err := d.session.DeleteFrom("device_lock_record").
		Where("uid=? and device_id=?", uid, deviceId).Exec()
	return err
}

// ============================================================
// 閫氳瘽鎴块棿鎿嶄綔
// ============================================================

// InsertCallRoom 鍒涘缓閫氳瘽鎴块棿
func (d *DB) InsertCallRoom(r *CallRoomModel) error {
	tx, err := d.session.Begin()
	if err != nil {
		return err
	}
	defer func() {
		if err := recover(); err != nil {
			tx.RollbackUnlessCommitted()
			panic(err)
		}
	}()

	_, err = tx.InsertInto("call_room").
		Columns("room_id", "room_name", "channel_id", "channel_type", "caller_uid", "caller_name", "callee_uid", "callee_name", "call_type", "status").
		Record(r).Exec()
	if err != nil {
		tx.RollbackUnlessCommitted()
		return err
	}

	for _, participant := range r.Participants {
		if participant == nil || participant.Uid == "" {
			continue
		}
		_, err = tx.InsertInto("call_participant").
			Columns("room_id", "uid", "user_name", "role", "invite_status").
			Values(r.RoomId, participant.Uid, participant.Name, participant.Role, participant.InviteStatus).Exec()
		if err != nil {
			tx.RollbackUnlessCommitted()
			return err
		}
	}

	err = tx.Commit()
	return err
}

// UpdateCallRoomStatus 鏇存柊閫氳瘽鎴块棿鐘舵€?func (d *DB) UpdateCallRoomStatus(roomId string, status int) error {
func (d *DB) UpdateCallRoomStatus(roomId string, status int) error {
	updates := map[string]interface{}{"status": status}
	if status == 1 { // 鎺ラ€?		now := time.Now()
		now := time.Now()
		updates["started_at"] = now
	} else if status == 2 || status == 4 || status == 5 { // 缁撴潫
		now := time.Now()
		updates["ended_at"] = now
	}
	_, err := d.session.Update("call_room").
		SetMap(updates).
		Where("room_id=?", roomId).
		Exec()
	return err
}

// QueryCallRoomByID 鏌ヨ閫氳瘽鎴块棿
func (d *DB) QueryCallRoomByID(roomId string) (*CallRoomModel, error) {
	var model *CallRoomModel
	_, err := d.session.Select("*").From("call_room").
		Where("room_id=?", roomId).Load(&model)
	if err != nil || model == nil {
		return model, err
	}
	model.Participants, err = d.QueryCallParticipants(roomId)
	return model, err
}

// QueryPendingCalls 鏌ヨ寰呭鐞嗙殑鍛煎彨
func (d *DB) QueryPendingCalls(calleeUid string) ([]*CallRoomModel, error) {
	var list []*CallRoomModel
	_, err := d.session.Select("*").From("call_room").
		Where("callee_uid=? and status=0", calleeUid).
		OrderBy("created_at desc").
		Load(&list)
	if err != nil {
		return nil, err
	}
	for _, room := range list {
		if room == nil {
			continue
		}
		room.Participants, err = d.QueryCallParticipants(room.RoomId)
		if err != nil {
			return nil, err
		}
	}
	return list, err
}

func (d *DB) QueryCallParticipants(roomId string) ([]*CallParticipantResp, error) {
	var list []*CallParticipantResp
	_, err := d.session.Select("uid", "user_name", "role", "invite_status").From("call_participant").
		Where("room_id=?", roomId).
		OrderBy("created_at asc").
		Load(&list)
	return list, err
}

// InsertCallSignal 瀛樺偍閫氳瘽淇′护
func (d *DB) InsertCallSignal(s *CallSignalModel) error {
	_, err := d.session.InsertInto("call_signal").
		Columns("room_id", "from_uid", "signal_type", "payload").
		Record(s).Exec()
	return err
}

// QueryCallSignals 鏌ヨ閫氳瘽淇′护
func (d *DB) QueryCallSignals(roomId string) ([]*CallSignalModel, error) {
	var list []*CallSignalModel
	_, err := d.session.Select("*").From("call_signal").
		Where("room_id=?", roomId).
		OrderBy("created_at asc").
		Load(&list)
	return list, err
}

// ============================================================
// 宸ュ叿鏂规硶
// ============================================================

// FormatImages 鏍煎紡鍖栧浘鐗囧垪琛?func FormatImages(imagesJSON string) []string {
func FormatImages(imagesJSON string) []string {
	if imagesJSON == "" {
		return []string{}
	}
	var list []string
	if err := json.Unmarshal([]byte(imagesJSON), &list); err != nil {
		return []string{}
	}
	return list
}

// FormatMentions 鏍煎紡鍖栨彁鍙婂垪琛?func FormatMentions(mentionsJSON string) []string {
func FormatMentions(mentionsJSON string) []string {
	if mentionsJSON == "" {
		return []string{}
	}
	var list []string
	if err := json.Unmarshal([]byte(mentionsJSON), &list); err != nil {
		return []string{}
	}
	return list
}

// FormatTime 鏍煎紡鍖栨椂闂?func FormatTime(t dbr.NullTime) string {
func FormatTime(t dbr.NullTime) string {
	if !t.Valid {
		return ""
	}
	return t.Time.Format("2006-01-02 15:04:05")
}

// Helper to set JSON field safely
func setJSONField(data map[string]interface{}, key string, value interface{}) {
	if value == nil || value == "" {
		data[key] = "[]"
		return
	}
	data[key] = value
}

func (d *DB) applyManagerMomentFilters(query *dbr.SelectStmt, uid, keyword string, status int) *dbr.SelectStmt {
	if uid != "" {
		query = query.Where("uid=?", uid)
	}
	if keyword != "" {
		query = query.Where("content like ?", "%"+keyword+"%")
	}
	if status == 0 || status == 1 {
		query = query.Where("status=?", status)
	}
	return query
}
