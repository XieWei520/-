package extra

import (
	"encoding/json"
	"fmt"
	"strconv"
	"strings"
	"time"

	"github.com/TangSengDaoDao/TangSengDaoDaoServer/modules/group"
	"github.com/TangSengDaoDao/TangSengDaoDaoServer/modules/user"
	"github.com/TangSengDaoDao/TangSengDaoDaoServerLib/common"
	"github.com/TangSengDaoDao/TangSengDaoDaoServerLib/config"
	"github.com/TangSengDaoDao/TangSengDaoDaoServerLib/pkg/log"
	"github.com/TangSengDaoDao/TangSengDaoDaoServerLib/pkg/register"
	"github.com/TangSengDaoDao/TangSengDaoDaoServerLib/pkg/util"
	"github.com/TangSengDaoDao/TangSengDaoDaoServerLib/pkg/wkhttp"
	"github.com/pkg/errors"
	"go.uber.org/zap"
)

const (
	callInviteKind      = "call.invite"
	callSignalKind      = "call.signal"
	callStateKind       = "call.state"
	fallbackMetaKey     = "fallback_only"
	realtimeServiceName = "realtime"
)

type callRepository interface {
	InsertCallRoom(*CallRoomModel) error
	InsertCallSignal(*CallSignalModel) error
	UpdateCallRoomStatus(string, int) error
	QueryCallRoomByID(string) (*CallRoomModel, error)
	QueryPendingCalls(string) ([]*CallRoomModel, error)
	QueryCallSignals(string) ([]*CallSignalModel, error)
}

type realtimeService interface {
	Append(uid, kind, aggregateID string, payload interface{}) error
}

type groupCallPolicyService interface {
	GetGroupWithGroupNo(groupNo string) (*group.InfoResp, error)
	GetMember(groupNo, uid string) (*group.MemberResp, error)
}

// API 浠樿垂妯″潡API
type API struct {
	ctx *config.Context
	log.Log
	db              *DB
	userService     user.IService
	groupService    groupCallPolicyService
	callStore       callRepository
	roomIDGenerator func() string
	realtimeSvc     realtimeService
}

// NewAPI 鍒涘缓API瀹炰緥
func NewAPI(ctx *config.Context) *API {
	dbService := NewDB(ctx)
	return &API{
		ctx:          ctx,
		Log:          log.NewTLog("Extra"),
		db:           dbService,
		userService:  user.NewService(ctx),
		groupService: group.NewService(ctx),
		callStore:    dbService,
		roomIDGenerator: func() string {
			return "call_" + util.GenerUUID()
		},
	}
}

// RegisterRoutes 娉ㄥ唽璺敱
func (a *API) Route(r *wkhttp.WKHttp) {
	auth := r.Group("/v1/extra", a.ctx.AuthMiddleware(r))

	auth.GET("/favorites", a.getFavorites)
	auth.POST("/favorites/search", a.searchFavorites)
	auth.POST("/favorite", a.createFavorite)
	auth.DELETE("/favorite/:id", a.deleteFavorite)

	auth.GET("/tags", a.getTags)
	auth.POST("/tag", a.createTag)
	auth.PUT("/tag/:id", a.updateTag)
	auth.DELETE("/tag/:id", a.deleteTag)
	auth.GET("/tag/:id/members", a.getTagMembers)
	auth.POST("/tag/:id/members", a.addTagMembers)
	auth.DELETE("/tag/:id/members", a.removeTagMembers)

	auth.GET("/moments", a.getMoments)
	auth.POST("/moment", a.publishMoment)
	auth.DELETE("/moment/:id", a.deleteMoment)
	auth.POST("/moment/:id/like", a.likeMoment)
	auth.DELETE("/moment/:id/like", a.unlikeMoment)
	auth.POST("/moment/:id/comment", a.commentMoment)
	auth.DELETE("/moment/:id/comment/:comment_id", a.deleteComment)
	auth.GET("/moment/:id/comments", a.getComments)

	auth.GET("/user/setting", a.getUserSetting)
	auth.PUT("/user/setting", a.updateUserSetting)
	auth.GET("/user/device/lock", a.getDeviceLock)
	auth.POST("/user/device/lock", a.setDeviceLock)
	auth.GET("/user/devices", a.getDevices)
	auth.DELETE("/user/devices/:device_id", a.deleteDevice)

	auth.POST("/call/room", a.createCallRoom)
	auth.POST("/call/signal", a.sendSignal)
	auth.POST("/call/status", a.updateCallStatus)
	auth.GET("/call/pending", a.getPendingCalls)
	auth.GET("/call/session/:room_id", a.getCallSession)
	auth.GET("/call/signals/:room_id", a.getSignals)
	auth.POST("/call/telemetry", a.recordCallTelemetry)
}

func (a *API) routeLegacy(r *wkhttp.WKHttp) {
	// ==================== 鏀惰棌妯″潡 ====================
	favorites := r.Group("/favorites")
	{
		favorites.GET("", a.getFavorites)            // 鑾峰彇鏀惰棌鍒楄〃
		favorites.POST("/search", a.searchFavorites) // 鎼滅储鏀惰棌
	}

	favorite := r.Group("/favorite")
	{
		favorite.POST("", a.createFavorite)       // 娣诲姞鏀惰棌
		favorite.DELETE("/:id", a.deleteFavorite) // 鍒犻櫎鏀惰棌
	}

	// ==================== 鏍囩妯″潡 ====================
	tags := r.Group("/tags")
	{
		tags.GET("", a.getTags) // 鑾峰彇鏍囩鍒楄〃
	}

	tag := r.Group("/tag")
	{
		tag.POST("", a.createTag)                      // 鍒涘缓鏍囩
		tag.PUT("/:id", a.updateTag)                   // 鏇存柊鏍囩
		tag.DELETE("/:id", a.deleteTag)                // 鍒犻櫎鏍囩
		tag.GET("/:id/members", a.getTagMembers)       // 鑾峰彇鏍囩鎴愬憳
		tag.POST("/:id/members", a.addTagMembers)      // 娣诲姞鏍囩鎴愬憳
		tag.DELETE("/:id/members", a.removeTagMembers) // 绉婚櫎鏍囩鎴愬憳
	}

	// ==================== 鏈嬪弸鍦堟ā鍧?====================
	moments := r.Group("/moments")
	{
		moments.GET("", a.getMoments) // 鑾峰彇鏈嬪弸鍦堝垪琛?
	}

	moment := r.Group("/moment")
	{
		moment.POST("", a.publishMoment)                           // 鍙戝竷鏈嬪弸鍦?
		moment.DELETE("/:id", a.deleteMoment)                      // 鍒犻櫎鏈嬪弸鍦?
		moment.POST("/:id/like", a.likeMoment)                     // 鐐硅禐鏈嬪弸鍦?
		moment.DELETE("/:id/like", a.unlikeMoment)                 // 鍙栨秷鐐硅禐
		moment.POST("/:id/comment", a.commentMoment)               // 璇勮鏈嬪弸鍦?
		moment.DELETE("/:id/comment/:comment_id", a.deleteComment) // 鍒犻櫎璇勮
		moment.GET("/:id/comments", a.getComments)                 // 鑾峰彇璇勮鍒楄〃
	}

	// ==================== 鐢ㄦ埛璁剧疆妯″潡 ====================
	userSetting := r.Group("/user/setting")
	{
		userSetting.GET("", a.getUserSetting)    // 鑾峰彇鐢ㄦ埛璁剧疆
		userSetting.PUT("", a.updateUserSetting) // 鏇存柊鐢ㄦ埛璁剧疆
	}

	deviceLock := r.Group("/user/device/lock")
	{
		deviceLock.GET("", a.getDeviceLock)  // 鑾峰彇璁惧閿佺姸鎬?
		deviceLock.POST("", a.setDeviceLock) // 璁剧疆璁惧閿?
	}

	devices := r.Group("/user/devices")
	{
		devices.GET("", a.getDevices)                 // 鑾峰彇璁惧鍒楄〃
		devices.DELETE("/:device_id", a.deleteDevice) // 鍒犻櫎璁惧
	}

	// ==================== 闊宠棰戦€氳瘽妯″潡 ====================
	call := r.Group("/call")
	{
		call.POST("/room", a.createCallRoom)        // 鍒涘缓閫氳瘽鎴块棿
		call.POST("/signal", a.sendSignal)          // 鍙戦€佷俊浠?
		call.POST("/status", a.updateCallStatus)    // 鏇存柊閫氳瘽鐘舵€?
		call.GET("/pending", a.getPendingCalls)     // 鑾峰彇寰呮帴鍚懠鍙?
		call.GET("/signals/:room_id", a.getSignals) // 鑾峰彇淇′护
	}
}

// ============================================================
// 鏀惰棌 API
// ============================================================

// getFavorites 鑾峰彇鏀惰棌鍒楄〃
func (a *API) getFavorites(c *wkhttp.Context) {
	uid := c.GetLoginUID()
	if uid == "" {
		c.ResponseError(errors.New("not logged in"))
		return
	}

	page := a.parseInt(c.Query("page"), 1)
	pageSize := a.parseInt(c.Query("page_size"), 20)

	list, total, err := a.db.QueryFavorites(uid, page, pageSize)
	if err != nil {
		a.Error("鏌ヨ鏀惰棌澶辫触", zap.Error(err))
		c.ResponseError(errors.New("鏌ヨ鏀惰棌澶辫触"))
		return
	}

	respList := make([]*FavoriteResp, 0, len(list))
	for _, item := range list {
		respList = append(respList, &FavoriteResp{
			Id:          item.Id,
			Uid:         item.Uid,
			ClientMsgNo: item.ClientMsgNo,
			MessageId:   item.MessageId,
			MessageSeq:  item.MessageSeq,
			OrderSeq:    item.OrderSeq,
			Content:     item.Content,
			ContentType: item.ContentType,
			ChannelId:   item.ChannelId,
			ChannelType: item.ChannelType,
			SenderUid:   item.SenderUid,
			SenderName:  item.SenderName,
			CreatedAt:   FormatTime(item.CreatedAt),
		})
	}

	c.Response(map[string]interface{}{
		"data":  respList,
		"page":  page,
		"count": total,
	})
}

// searchFavorites 鎼滅储鏀惰棌
func (a *API) searchFavorites(c *wkhttp.Context) {
	uid := c.GetLoginUID()
	if uid == "" {
		c.ResponseError(errors.New("not logged in"))
		return
	}

	var req struct {
		Keyword  string `json:"keyword"`
		Page     int    `json:"page"`
		PageSize int    `json:"page_size"`
	}
	if err := c.BindJSON(&req); err != nil {
		c.ResponseError(errors.New("璇锋眰鍙傛暟閿欒"))
		return
	}
	if req.Keyword == "" {
		c.ResponseError(errors.New("keyword cannot be empty"))
		return
	}
	if req.Page <= 0 {
		req.Page = 1
	}
	if req.PageSize <= 0 {
		req.PageSize = 20
	}

	list, total, err := a.db.SearchFavorites(uid, req.Keyword, req.Page, req.PageSize)
	if err != nil {
		a.Error("鎼滅储鏀惰棌澶辫触", zap.Error(err))
		c.ResponseError(errors.New("鎼滅储鏀惰棌澶辫触"))
		return
	}

	respList := make([]*FavoriteResp, 0, len(list))
	for _, item := range list {
		respList = append(respList, &FavoriteResp{
			Id:          item.Id,
			Uid:         item.Uid,
			ClientMsgNo: item.ClientMsgNo,
			MessageId:   item.MessageId,
			MessageSeq:  item.MessageSeq,
			OrderSeq:    item.OrderSeq,
			Content:     item.Content,
			ContentType: item.ContentType,
			ChannelId:   item.ChannelId,
			ChannelType: item.ChannelType,
			SenderUid:   item.SenderUid,
			SenderName:  item.SenderName,
			CreatedAt:   FormatTime(item.CreatedAt),
		})
	}

	c.Response(map[string]interface{}{
		"data":  respList,
		"page":  req.Page,
		"count": total,
	})
}

// createFavorite 娣诲姞鏀惰棌
func (a *API) createFavorite(c *wkhttp.Context) {
	uid := c.GetLoginUID()
	if uid == "" {
		c.ResponseError(errors.New("not logged in"))
		return
	}

	var req CreateFavoriteReq
	if err := c.BindJSON(&req); err != nil {
		c.ResponseError(errors.New("璇锋眰鍙傛暟閿欒"))
		return
	}

	// 妫€鏌ユ槸鍚﹀凡鏀惰棌
	if req.MessageSeq < 0 || req.OrderSeq < 0 {
		c.ResponseError(errors.New("message_seq and order_seq must be non-negative"))
		return
	}

	existing, err := a.db.QueryFavoriteByClientMsgNo(uid, req.ClientMsgNo)
	if err != nil {
		a.Error("鏌ヨ鏀惰棌澶辫触", zap.Error(err))
		c.ResponseError(errors.New("鏌ヨ鏀惰棌澶辫触"))
		return
	}
	if existing != nil {
		c.ResponseError(errors.New("favorite already exists"))
		return
	}

	model := &FavoriteModel{
		Uid:         uid,
		ClientMsgNo: req.ClientMsgNo,
		MessageId:   req.MessageId,
		MessageSeq:  req.MessageSeq,
		OrderSeq:    req.OrderSeq,
		Content:     req.Content,
		ContentType: req.ContentType,
		ChannelId:   req.ChannelId,
		ChannelType: req.ChannelType,
		SenderUid:   req.SenderUid,
		SenderName:  req.SenderName,
	}

	if err := a.db.InsertFavorite(model); err != nil {
		a.Error("娣诲姞鏀惰棌澶辫触", zap.Error(err))
		c.ResponseError(errors.New("娣诲姞鏀惰棌澶辫触"))
		return
	}

	c.ResponseOK()
}

// deleteFavorite 鍒犻櫎鏀惰棌
func (a *API) deleteFavorite(c *wkhttp.Context) {
	uid := c.GetLoginUID()
	if uid == "" {
		c.ResponseError(errors.New("not logged in"))
		return
	}

	idStr := c.Param("id")
	var id int64
	if strings.Contains(idStr, "_") {
		// client_msg_no format
		existing, err := a.db.QueryFavoriteByClientMsgNo(uid, idStr)
		if err != nil || existing == nil {
			c.ResponseError(errors.New("favorite not found"))
			return
		}
		id = existing.Id
	} else {
		id = a.parseInt64(idStr, 0)
	}

	if id <= 0 {
		c.ResponseError(errors.New("鍙傛暟閿欒"))
		return
	}

	// 妫€鏌ユ潈闄?
	existing, err := a.db.QueryFavoriteByID(id)
	if err != nil || existing == nil {
		c.ResponseError(errors.New("favorite not found"))
		return
	}
	if existing.Uid != uid {
		c.ResponseError(errors.New("鏃犳潈鍒犻櫎"))
		return
	}

	if err := a.db.DeleteFavoriteByID(id); err != nil {
		a.Error("鍒犻櫎鏀惰棌澶辫触", zap.Error(err))
		c.ResponseError(errors.New("鍒犻櫎鏀惰棌澶辫触"))
		return
	}

	c.ResponseOK()
}

// ============================================================
// 鏍囩 API
// ============================================================

// getTags 鑾峰彇鏍囩鍒楄〃
func (a *API) getTags(c *wkhttp.Context) {
	uid := c.GetLoginUID()
	if uid == "" {
		c.ResponseError(errors.New("not logged in"))
		return
	}

	tags, err := a.db.QueryTagsByUID(uid)
	if err != nil {
		a.Error("鏌ヨ鏍囩澶辫触", zap.Error(err))
		c.ResponseError(errors.New("鏌ヨ鏍囩澶辫触"))
		return
	}

	respList := make([]*TagResp, 0, len(tags))
	for _, tag := range tags {
		members, _ := a.db.QueryTagMembers(tag.Id)
		memberList := make([]*TagMemberResp, 0, len(members))
		for _, m := range members {
			memberList = append(memberList, &TagMemberResp{
				Uid:      m.Uid,
				UserName: m.UserName,
			})
		}
		respList = append(respList, &TagResp{
			Id:        tag.Id,
			Name:      tag.Name,
			Remark:    tag.Remark,
			Members:   memberList,
			Count:     len(members),
			CreatedAt: FormatTime(tag.CreatedAt),
		})
	}

	c.Response(map[string]interface{}{
		"data": respList,
	})
}

// createTag 鍒涘缓鏍囩
func (a *API) createTag(c *wkhttp.Context) {
	uid := c.GetLoginUID()
	if uid == "" {
		c.ResponseError(errors.New("not logged in"))
		return
	}

	var req CreateTagReq
	if err := c.BindJSON(&req); err != nil {
		c.ResponseError(errors.New("璇锋眰鍙傛暟閿欒"))
		return
	}
	if strings.TrimSpace(req.Name) == "" {
		c.ResponseError(errors.New("鏍囩鍚嶇О涓嶈兘涓虹┖"))
		return
	}

	model := &TagModel{
		Uid:    uid,
		Name:   strings.TrimSpace(req.Name),
		Remark: req.Remark,
	}

	if err := a.db.InsertTag(model); err != nil {
		a.Error("鍒涘缓鏍囩澶辫触", zap.Error(err))
		c.ResponseError(errors.New("鍒涘缓鏍囩澶辫触"))
		return
	}

	c.Response(map[string]interface{}{
		"data": map[string]interface{}{
			"id": model.Id,
		},
	})
}

// updateTag 鏇存柊鏍囩
func (a *API) updateTag(c *wkhttp.Context) {
	uid := c.GetLoginUID()
	if uid == "" {
		c.ResponseError(errors.New("not logged in"))
		return
	}

	idStr := c.Param("id")
	id := a.parseInt64(idStr, 0)
	if id <= 0 {
		c.ResponseError(errors.New("鍙傛暟閿欒"))
		return
	}

	// 妫€鏌ユ潈闄?
	tag, err := a.db.QueryTagByID(id)
	if err != nil || tag == nil {
		c.ResponseError(errors.New("tag not found"))
		return
	}
	if tag.Uid != uid {
		c.ResponseError(errors.New("鏃犳潈淇敼"))
		return
	}

	var req UpdateTagReq
	if err := c.BindJSON(&req); err != nil {
		c.ResponseError(errors.New("璇锋眰鍙傛暟閿欒"))
		return
	}
	if strings.TrimSpace(req.Name) == "" {
		c.ResponseError(errors.New("鏍囩鍚嶇О涓嶈兘涓虹┖"))
		return
	}

	tag.Name = strings.TrimSpace(req.Name)
	tag.Remark = req.Remark

	if err := a.db.UpdateTag(tag); err != nil {
		a.Error("鏇存柊鏍囩澶辫触", zap.Error(err))
		c.ResponseError(errors.New("鏇存柊鏍囩澶辫触"))
		return
	}

	c.ResponseOK()
}

// deleteTag 鍒犻櫎鏍囩
func (a *API) deleteTag(c *wkhttp.Context) {
	uid := c.GetLoginUID()
	if uid == "" {
		c.ResponseError(errors.New("not logged in"))
		return
	}

	idStr := c.Param("id")
	id := a.parseInt64(idStr, 0)
	if id <= 0 {
		c.ResponseError(errors.New("鍙傛暟閿欒"))
		return
	}

	// 妫€鏌ユ潈闄?
	tag, err := a.db.QueryTagByID(id)
	if err != nil || tag == nil {
		c.ResponseError(errors.New("tag not found"))
		return
	}
	if tag.Uid != uid {
		c.ResponseError(errors.New("鏃犳潈鍒犻櫎"))
		return
	}

	if err := a.db.DeleteTag(id); err != nil {
		a.Error("鍒犻櫎鏍囩澶辫触", zap.Error(err))
		c.ResponseError(errors.New("鍒犻櫎鏍囩澶辫触"))
		return
	}

	c.ResponseOK()
}

// getTagMembers 鑾峰彇鏍囩鎴愬憳
func (a *API) getTagMembers(c *wkhttp.Context) {
	uid := c.GetLoginUID()
	if uid == "" {
		c.ResponseError(errors.New("not logged in"))
		return
	}

	idStr := c.Param("id")
	id := a.parseInt64(idStr, 0)
	if id <= 0 {
		c.ResponseError(errors.New("鍙傛暟閿欒"))
		return
	}

	members, err := a.db.QueryTagMembers(id)
	if err != nil {
		a.Error("鏌ヨ鏍囩鎴愬憳澶辫触", zap.Error(err))
		c.ResponseError(errors.New("鏌ヨ鏍囩鎴愬憳澶辫触"))
		return
	}

	respList := make([]*TagMemberResp, 0, len(members))
	for _, m := range members {
		respList = append(respList, &TagMemberResp{
			Uid:      m.Uid,
			UserName: m.UserName,
		})
	}

	c.Response(map[string]interface{}{
		"data": respList,
	})
}

// addTagMembers 娣诲姞鏍囩鎴愬憳
func (a *API) addTagMembers(c *wkhttp.Context) {
	uid := c.GetLoginUID()
	if uid == "" {
		c.ResponseError(errors.New("not logged in"))
		return
	}

	idStr := c.Param("id")
	id := a.parseInt64(idStr, 0)
	if id <= 0 {
		c.ResponseError(errors.New("鍙傛暟閿欒"))
		return
	}

	// 妫€鏌ユ潈闄?
	tag, err := a.db.QueryTagByID(id)
	if err != nil || tag == nil {
		c.ResponseError(errors.New("tag not found"))
		return
	}
	if tag.Uid != uid {
		c.ResponseError(errors.New("鏃犳潈鎿嶄綔"))
		return
	}

	var req TagMembersReq
	if err := c.BindJSON(&req); err != nil {
		c.ResponseError(errors.New("璇锋眰鍙傛暟閿欒"))
		return
	}
	if len(req.Uids) == 0 {
		c.ResponseError(errors.New("鎴愬憳鍒楄〃涓嶈兘涓虹┖"))
		return
	}

	// 鑾峰彇鐢ㄦ埛淇℃伅
	userMap, _ := a.getUserInfoMap(req.Uids)

	for _, memberUID := range req.Uids {
		member := &TagMemberModel{
			TagId:    id,
			Uid:      memberUID,
			UserName: userMap[memberUID],
		}
		a.db.InsertTagMember(member)
	}

	c.ResponseOK()
}

// removeTagMembers 绉婚櫎鏍囩鎴愬憳
func (a *API) removeTagMembers(c *wkhttp.Context) {
	uid := c.GetLoginUID()
	if uid == "" {
		c.ResponseError(errors.New("not logged in"))
		return
	}

	idStr := c.Param("id")
	id := a.parseInt64(idStr, 0)
	if id <= 0 {
		c.ResponseError(errors.New("鍙傛暟閿欒"))
		return
	}

	// 妫€鏌ユ潈闄?
	tag, err := a.db.QueryTagByID(id)
	if err != nil || tag == nil {
		c.ResponseError(errors.New("tag not found"))
		return
	}
	if tag.Uid != uid {
		c.ResponseError(errors.New("鏃犳潈鎿嶄綔"))
		return
	}

	var req TagMembersReq
	if err := c.BindJSON(&req); err != nil {
		c.ResponseError(errors.New("璇锋眰鍙傛暟閿欒"))
		return
	}
	if len(req.Uids) == 0 {
		c.ResponseError(errors.New("鎴愬憳鍒楄〃涓嶈兘涓虹┖"))
		return
	}

	if err := a.db.DeleteTagMembers(id, req.Uids); err != nil {
		a.Error("绉婚櫎鏍囩鎴愬憳澶辫触", zap.Error(err))
		c.ResponseError(errors.New("绉婚櫎鏍囩鎴愬憳澶辫触"))
		return
	}

	c.ResponseOK()
}

// ============================================================
// 鏈嬪弸鍦?API
// ============================================================

// getMoments 鑾峰彇鏈嬪弸鍦堝垪琛?
func (a *API) getMoments(c *wkhttp.Context) {
	uid := c.GetLoginUID()
	if uid == "" {
		c.ResponseError(errors.New("not logged in"))
		return
	}

	page := a.parseInt(c.Query("page"), 1)
	pageSize := a.parseInt(c.Query("page_size"), 20)
	maxId := a.parseInt64(c.Query("max_id"), 0)

	var moments []*MomentModel
	var err error

	if maxId > 0 {
		moments, err = a.db.QueryMomentsForFriends([]string{uid}, maxId, pageSize)
	} else {
		moments, _, err = a.db.QueryMoments(uid, page, pageSize)
	}

	if err != nil {
		a.Error("query moments failed", zap.Error(err))
		c.ResponseError(errors.New("query moments failed"))
		return
	}

	// 濉厖浣滆€呬俊鎭?
	friendUids := make([]string, 0, len(moments))
	momentIDs := make([]int64, 0, len(moments))
	for _, m := range moments {
		friendUids = append(friendUids, m.Uid)
		momentIDs = append(momentIDs, m.Id)
	}
	userInfoMap, _ := a.getUserInfoMap(friendUids)
	likes, err := a.db.QueryMomentLikesByMomentIDs(momentIDs)
	if err != nil {
		a.Error("query moment likes failed", zap.Error(err))
		c.ResponseError(errors.New("query moments failed"))
		return
	}
	likesByMomentID := groupMomentLikesByMomentID(likes)

	comments, err := a.db.QueryMomentCommentsByMomentIDs(momentIDs, 3)
	if err != nil {
		a.Error("query moment comments failed", zap.Error(err))
		c.ResponseError(errors.New("query moments failed"))
		return
	}
	commentsByMomentID := groupMomentCommentsByMomentID(comments)

	respList := make([]*MomentResp, 0, len(moments))
	for _, m := range moments {
		authorName := m.Uid
		if name, ok := userInfoMap[m.Uid]; ok && name != "" {
			authorName = name
		}

		// 鑾峰彇鐐硅禐
		likes := likesByMomentID[m.Id]
		likeList := make([]*MomentLikeResp, 0, len(likes))
		isLiked := false
		for _, l := range likes {
			likeList = append(likeList, &MomentLikeResp{
				Uid:      l.Uid,
				UserName: l.UserName,
			})
			if l.Uid == uid {
				isLiked = true
			}
		}

		// 鑾峰彇璇勮
		comments := commentsByMomentID[m.Id]
		commentList := make([]*MomentCommentResp, 0, len(comments))
		for _, cm := range comments {
			commentList = append(commentList, &MomentCommentResp{
				Id:          cm.Id,
				Uid:         cm.Uid,
				AuthorName:  cm.UserName,
				Content:     cm.Content,
				ReplyToUid:  cm.ReplyToUid,
				ReplyToName: cm.ReplyToName,
				CreatedAt:   FormatTime(cm.CreatedAt),
			})
		}

		respList = append(respList, &MomentResp{
			Id: m.Id,
			Author: &MomentAuthorResp{
				Uid:    m.Uid,
				Name:   authorName,
				Avatar: fmt.Sprintf("users/%s/avatar", m.Uid),
			},
			Content:      m.Content,
			Location:     m.Location,
			Images:       FormatImages(m.Images),
			Mentions:     FormatMentions(m.Mentions),
			Likes:        likeList,
			Comments:     commentList,
			LikeCount:    m.LikeCount,
			CommentCount: m.CommentCount,
			IsLiked:      isLiked,
			Status:       m.Status,
			CreatedAt:    FormatTime(m.CreatedAt),
		})
	}

	c.Response(map[string]interface{}{
		"data": respList,
	})
}

// publishMoment 鍙戝竷鏈嬪弸鍦?
func (a *API) publishMoment(c *wkhttp.Context) {
	uid := c.GetLoginUID()
	if uid == "" {
		c.ResponseError(errors.New("not logged in"))
		return
	}

	var req PublishMomentReq
	if err := c.BindJSON(&req); err != nil {
		c.ResponseError(errors.New("璇锋眰鍙傛暟閿欒"))
		return
	}

	if req.Content == "" && len(req.Images) == 0 {
		c.ResponseError(errors.New("content and images cannot both be empty"))
		return
	}

	// 搴忓垪鍖?images 鍜?mentions
	imagesJSON, _ := json.Marshal(req.Images)
	mentionsJSON, _ := json.Marshal(req.Mentions)

	model := &MomentModel{
		Uid:      uid,
		Content:  req.Content,
		Location: req.Location,
		Images:   string(imagesJSON),
		Mentions: string(mentionsJSON),
		Status:   1,
	}

	if err := a.db.InsertMoment(model); err != nil {
		a.Error("publish moment failed", zap.Error(err))
		c.ResponseError(errors.New("publish moment failed"))
		return
	}

	c.Response(map[string]interface{}{
		"data": map[string]interface{}{
			"id": model.Id,
		},
	})
}

// deleteMoment 鍒犻櫎鏈嬪弸鍦?
func (a *API) deleteMoment(c *wkhttp.Context) {
	uid := c.GetLoginUID()
	if uid == "" {
		c.ResponseError(errors.New("not logged in"))
		return
	}

	idStr := c.Param("id")
	id := a.parseInt64(idStr, 0)
	if id <= 0 {
		c.ResponseError(errors.New("鍙傛暟閿欒"))
		return
	}

	if err := a.db.DeleteMoment(id, uid); err != nil {
		a.Error("delete moment failed", zap.Error(err))
		c.ResponseError(errors.New("delete moment failed"))
		return
	}

	c.ResponseOK()
}

// likeMoment 鐐硅禐鏈嬪弸鍦?
func (a *API) likeMoment(c *wkhttp.Context) {
	uid := c.GetLoginUID()
	if uid == "" {
		c.ResponseError(errors.New("not logged in"))
		return
	}

	idStr := c.Param("id")
	id := a.parseInt64(idStr, 0)
	if id <= 0 {
		c.ResponseError(errors.New("鍙傛暟閿欒"))
		return
	}

	// 妫€鏌ユ槸鍚﹀凡鐐硅禐
	existing, _ := a.db.QueryMomentLike(id, uid)
	if existing != nil {
		c.ResponseError(errors.New("already liked"))
		return
	}

	userName := uid
	userInfo, _ := a.getUserInfo(uid)
	if userInfo != nil {
		userName = userInfo["name"]
	}

	model := &MomentLikeModel{
		MomentId: id,
		Uid:      uid,
		UserName: userName,
	}

	if err := a.db.InsertMomentLike(model); err != nil {
		a.Error("鐐硅禐澶辫触", zap.Error(err))
		c.ResponseError(errors.New("鐐硅禐澶辫触"))
		return
	}

	// 鏇存柊鐐硅禐鏁?
	a.db.UpdateMomentCounts(id, 1, 0)

	c.ResponseOK()
}

// unlikeMoment 鍙栨秷鐐硅禐
func (a *API) unlikeMoment(c *wkhttp.Context) {
	uid := c.GetLoginUID()
	if uid == "" {
		c.ResponseError(errors.New("not logged in"))
		return
	}

	idStr := c.Param("id")
	id := a.parseInt64(idStr, 0)
	if id <= 0 {
		c.ResponseError(errors.New("鍙傛暟閿欒"))
		return
	}

	if err := a.db.DeleteMomentLike(id, uid); err != nil {
		a.Error("鍙栨秷鐐硅禐澶辫触", zap.Error(err))
		c.ResponseError(errors.New("鍙栨秷鐐硅禐澶辫触"))
		return
	}

	// 鏇存柊鐐硅禐鏁?
	a.db.UpdateMomentCounts(id, -1, 0)

	c.ResponseOK()
}

// commentMoment 璇勮鏈嬪弸鍦?
func (a *API) commentMoment(c *wkhttp.Context) {
	uid := c.GetLoginUID()
	if uid == "" {
		c.ResponseError(errors.New("not logged in"))
		return
	}

	idStr := c.Param("id")
	momentId := a.parseInt64(idStr, 0)
	if momentId <= 0 {
		c.ResponseError(errors.New("鍙傛暟閿欒"))
		return
	}

	var req CommentMomentReq
	if err := c.BindJSON(&req); err != nil {
		c.ResponseError(errors.New("璇锋眰鍙傛暟閿欒"))
		return
	}
	if strings.TrimSpace(req.Content) == "" {
		c.ResponseError(errors.New("璇勮鍐呭涓嶈兘涓虹┖"))
		return
	}

	userName := uid
	replyToName := ""
	userInfo, _ := a.getUserInfo(uid)
	if userInfo != nil {
		userName = userInfo["name"]
	}

	if req.ReplyTo != "" {
		replyInfo, _ := a.getUserInfo(req.ReplyTo)
		if replyInfo != nil {
			replyToName = replyInfo["name"]
		}
	}

	model := &MomentCommentModel{
		MomentId:    momentId,
		Uid:         uid,
		UserName:    userName,
		Content:     req.Content,
		ReplyToUid:  req.ReplyTo,
		ReplyToName: replyToName,
		Status:      1,
	}

	if err := a.db.InsertMomentComment(model); err != nil {
		a.Error("璇勮澶辫触", zap.Error(err))
		c.ResponseError(errors.New("璇勮澶辫触"))
		return
	}

	// 鏇存柊璇勮鏁?
	a.db.UpdateMomentCounts(momentId, 0, 1)

	c.Response(map[string]interface{}{
		"data": map[string]interface{}{
			"id": model.Id,
		},
	})
}

// deleteComment 鍒犻櫎璇勮
func (a *API) deleteComment(c *wkhttp.Context) {
	uid := c.GetLoginUID()
	if uid == "" {
		c.ResponseError(errors.New("not logged in"))
		return
	}

	momentIdStr := c.Param("id")
	momentId := a.parseInt64(momentIdStr, 0)
	commentIdStr := c.Param("comment_id")
	commentId := a.parseInt64(commentIdStr, 0)

	if momentId <= 0 || commentId <= 0 {
		c.ResponseError(errors.New("鍙傛暟閿欒"))
		return
	}

	if err := a.db.DeleteMomentComment(commentId, uid); err != nil {
		a.Error("鍒犻櫎璇勮澶辫触", zap.Error(err))
		c.ResponseError(errors.New("鍒犻櫎璇勮澶辫触"))
		return
	}

	// 鏇存柊璇勮鏁?
	a.db.UpdateMomentCounts(momentId, 0, -1)

	c.ResponseOK()
}

// getComments 鑾峰彇璇勮鍒楄〃
func (a *API) getComments(c *wkhttp.Context) {
	momentIdStr := c.Param("id")
	momentId := a.parseInt64(momentIdStr, 0)
	if momentId <= 0 {
		c.ResponseError(errors.New("鍙傛暟閿欒"))
		return
	}

	page := a.parseInt(c.Query("page"), 1)
	pageSize := a.parseInt(c.Query("page_size"), 20)

	comments, total, err := a.db.QueryMomentComments(momentId, page, pageSize)
	if err != nil {
		a.Error("鏌ヨ璇勮澶辫触", zap.Error(err))
		c.ResponseError(errors.New("鏌ヨ璇勮澶辫触"))
		return
	}

	respList := make([]*MomentCommentResp, 0, len(comments))
	for _, cm := range comments {
		respList = append(respList, &MomentCommentResp{
			Id:          cm.Id,
			Uid:         cm.Uid,
			AuthorName:  cm.UserName,
			Content:     cm.Content,
			ReplyToUid:  cm.ReplyToUid,
			ReplyToName: cm.ReplyToName,
			CreatedAt:   FormatTime(cm.CreatedAt),
		})
	}

	c.Response(map[string]interface{}{
		"data":  respList,
		"page":  page,
		"count": total,
	})
}

// ============================================================
// 鐢ㄦ埛璁剧疆 API
// ============================================================

// getUserSetting 鑾峰彇鐢ㄦ埛璁剧疆
func (a *API) getUserSetting(c *wkhttp.Context) {
	uid := c.GetLoginUID()
	if uid == "" {
		c.ResponseError(errors.New("not logged in"))
		return
	}

	// 纭繚璁剧疆瀛樺湪
	a.db.EnsureSettingExists(uid)

	setting, err := a.db.QuerySetting(uid)
	if err != nil || setting == nil {
		// 杩斿洖榛樿璁剧疆
		c.Response(map[string]interface{}{
			"data": &UserGlobalSettingResp{
				SearchByPhone:     1,
				SearchByShort:     1,
				NewMsgNotice:      1,
				MsgShowDetail:     1,
				VoiceOn:           1,
				ShockOn:           1,
				OfflineProtection: 0,
				DeviceLock:        0,
				MuteOfApp:         0,
			},
		})
		return
	}

	c.Response(map[string]interface{}{
		"data": &UserGlobalSettingResp{
			SearchByPhone:     setting.SearchByPhone,
			SearchByShort:     setting.SearchByShort,
			NewMsgNotice:      setting.NewMsgNotice,
			MsgShowDetail:     setting.MsgShowDetail,
			VoiceOn:           setting.VoiceOn,
			ShockOn:           setting.ShockOn,
			OfflineProtection: setting.OfflineProtection,
			DeviceLock:        setting.DeviceLock,
			MuteOfApp:         setting.MuteOfApp,
		},
	})
}

// updateUserSetting 鏇存柊鐢ㄦ埛璁剧疆
func (a *API) updateUserSetting(c *wkhttp.Context) {
	uid := c.GetLoginUID()
	if uid == "" {
		c.ResponseError(errors.New("not logged in"))
		return
	}

	var req UpdateSettingReq
	if err := c.BindJSON(&req); err != nil {
		c.ResponseError(errors.New("璇锋眰鍙傛暟閿欒"))
		return
	}

	// 纭繚璁剧疆瀛樺湪
	a.db.EnsureSettingExists(uid)

	updates := make(map[string]interface{})
	if req.SearchByPhone != nil {
		updates["search_by_phone"] = *req.SearchByPhone
	}
	if req.SearchByShort != nil {
		updates["search_by_short"] = *req.SearchByShort
	}
	if req.NewMsgNotice != nil {
		updates["new_msg_notice"] = *req.NewMsgNotice
	}
	if req.MsgShowDetail != nil {
		updates["msg_show_detail"] = *req.MsgShowDetail
	}
	if req.VoiceOn != nil {
		updates["voice_on"] = *req.VoiceOn
	}
	if req.ShockOn != nil {
		updates["shock_on"] = *req.ShockOn
	}
	if req.OfflineProtection != nil {
		updates["offline_protection"] = *req.OfflineProtection
	}
	if req.DeviceLock != nil {
		updates["device_lock"] = *req.DeviceLock
	}
	if req.MuteOfApp != nil {
		updates["mute_of_app"] = *req.MuteOfApp
	}

	if len(updates) > 0 {
		if err := a.db.UpdateSetting(uid, updates); err != nil {
			a.Error("鏇存柊璁剧疆澶辫触", zap.Error(err))
			c.ResponseError(errors.New("鏇存柊璁剧疆澶辫触"))
			return
		}
	}

	c.ResponseOK()
}

// getDeviceLock 鑾峰彇璁惧閿佺姸鎬?
func (a *API) getDeviceLock(c *wkhttp.Context) {
	uid := c.GetLoginUID()
	if uid == "" {
		c.ResponseError(errors.New("not logged in"))
		return
	}

	deviceId := c.Query("device_id")
	if deviceId == "" {
		// 杩斿洖鐢ㄦ埛鏄惁鏈変换浣曡澶囬攣
		locks, _ := a.db.GetDeviceLocks(uid)
		hasLock := false
		for _, l := range locks {
			if l.Enabled == 1 {
				hasLock = true
				break
			}
		}
		c.Response(map[string]interface{}{
			"data": map[string]interface{}{
				"enabled": hasLock,
			},
		})
		return
	}

	lock, _ := a.db.QueryDeviceLock(uid, deviceId)
	if lock == nil {
		c.Response(map[string]interface{}{
			"data": map[string]interface{}{
				"enabled": false,
			},
		})
		return
	}

	c.Response(map[string]interface{}{
		"data": map[string]interface{}{
			"enabled": lock.Enabled == 1,
		},
	})
}

// setDeviceLock 璁剧疆璁惧閿?
func (a *API) setDeviceLock(c *wkhttp.Context) {
	uid := c.GetLoginUID()
	if uid == "" {
		c.ResponseError(errors.New("not logged in"))
		return
	}

	var req DeviceLockReq
	if err := c.BindJSON(&req); err != nil {
		c.ResponseError(errors.New("璇锋眰鍙傛暟閿欒"))
		return
	}

	deviceId := c.GetHeader("X-Device-ID")
	if deviceId == "" {
		deviceId = fmt.Sprintf("device_%d", time.Now().UnixNano())
	}

	if err := a.db.UpdateDeviceLockPwd(uid, deviceId, req.Password, req.Enabled); err != nil {
		a.Error("set device lock failed", zap.Error(err))
		c.ResponseError(errors.New("set device lock failed"))
		return
	}

	c.ResponseOK()
}

// getDevices 鑾峰彇璁惧鍒楄〃
func (a *API) getDevices(c *wkhttp.Context) {
	uid := c.GetLoginUID()
	if uid == "" {
		c.ResponseError(errors.New("not logged in"))
		return
	}

	devices, _ := a.db.GetDeviceLocks(uid)
	deviceList := make([]map[string]interface{}, 0, len(devices))
	for _, d := range devices {
		deviceList = append(deviceList, map[string]interface{}{
			"device_id":  d.DeviceId,
			"enabled":    d.Enabled == 1,
			"created_at": FormatTime(d.CreatedAt),
		})
	}

	c.Response(map[string]interface{}{
		"data": deviceList,
	})
}

// deleteDevice 鍒犻櫎璁惧
func (a *API) deleteDevice(c *wkhttp.Context) {
	uid := c.GetLoginUID()
	if uid == "" {
		c.ResponseError(errors.New("not logged in"))
		return
	}

	deviceId := c.Param("device_id")
	if deviceId == "" {
		c.ResponseError(errors.New("鍙傛暟閿欒"))
		return
	}

	if err := a.db.DeleteDeviceLock(uid, deviceId); err != nil {
		a.Error("鍒犻櫎璁惧澶辫触", zap.Error(err))
		c.ResponseError(errors.New("鍒犻櫎璁惧澶辫触"))
		return
	}

	c.ResponseOK()
}

// ============================================================
// 闊宠棰戦€氳瘽 API
// ============================================================

// createCallRoom 鍒涘缓閫氳瘽鎴块棿
func (a *API) createCallRoom(c *wkhttp.Context) {
	uid := c.GetLoginUID()
	if uid == "" {
		c.ResponseError(errors.New("not logged in"))
		return
	}

	var req CreateCallRoomReq
	if err := c.BindJSON(&req); err != nil {
		c.ResponseError(errors.New("璇锋眰鍙傛暟閿欒"))
		return
	}

	if strings.TrimSpace(req.CalleeUid) == "" && strings.TrimSpace(req.ChannelId) == "" {
		c.ResponseError(errors.New("璇锋眰鍙傛暟閿欒"))
		return
	}
	if err := a.ensureCanCreateCallRoom(uid, req); err != nil {
		c.ResponseError(err)
		return
	}

	resp, err := a.handleCreateCallRoom(uid, req)
	if err != nil {
		a.Error("鍒涘缓閫氳瘽鎴块棿澶辫触", zap.Error(err))
		c.ResponseError(errors.New("鍒涘缓閫氳瘽鎴块棿澶辫触"))
		return
	}

	bootstrap, err := a.buildCallBootstrap(uid, resp, req.Capabilities)
	if err != nil {
		a.Error("build call bootstrap failed", zap.Error(err))
		c.ResponseError(errors.New("build call bootstrap failed"))
		return
	}

	c.Response(map[string]interface{}{
		"data": bootstrap,
	})
}

// sendSignal 鍙戦€侀€氳瘽淇′护
func (a *API) sendSignal(c *wkhttp.Context) {
	uid := c.GetLoginUID()
	if uid == "" {
		c.ResponseError(errors.New("not logged in"))
		return
	}

	var req CallSignalReq
	if err := c.BindJSON(&req); err != nil {
		c.ResponseError(errors.New("璇锋眰鍙傛暟閿欒"))
		return
	}

	if err := a.handleSendSignal(uid, req); err != nil {
		a.Error("鍙戦€侀€氳瘽淇′护澶辫触", zap.Error(err))
		c.ResponseError(errors.New("鍙戦€侀€氳瘽淇′护澶辫触"))
		return
	}

	c.ResponseOK()
}

// updateCallStatus 鏇存柊閫氳瘽鐘舵€?
func (a *API) updateCallStatus(c *wkhttp.Context) {
	uid := c.GetLoginUID()
	if uid == "" {
		c.ResponseError(errors.New("not logged in"))
		return
	}

	var req UpdateCallStatusReq
	if err := c.BindJSON(&req); err != nil {
		c.ResponseError(errors.New("璇锋眰鍙傛暟閿欒"))
		return
	}

	roomId := c.Query("room_id")
	if roomId == "" {
		c.ResponseError(errors.New("閫氳瘽ID涓嶈兘涓虹┖"))
		return
	}

	if err := a.handleUpdateCallStatus(uid, roomId, req.Status); err != nil {
		a.Error("update call status failed", zap.Error(err))
		c.ResponseError(errors.New("update call status failed"))
		return
	}

	c.ResponseOK()
}

// getPendingCalls 鑾峰彇寰呮帴鍚殑鍛煎彨
func (a *API) getPendingCalls(c *wkhttp.Context) {
	uid := c.GetLoginUID()
	if uid == "" {
		c.ResponseError(errors.New("not logged in"))
		return
	}

	fallbackOnly := c.Query("fallback") != "1"
	if fallbackOnly {
		c.Response(a.pendingCallsResponse(nil, true))
		return
	}

	calls, err := a.callStore.QueryPendingCalls(uid)
	if err != nil {
		a.Error("鏌ヨ寰呮帴鍚€氳瘽澶辫触", zap.Error(err))
	}

	c.Response(a.pendingCallsResponse(calls, false))
}

func (a *API) getSignals(c *wkhttp.Context) {
	uid := c.GetLoginUID()
	if uid == "" {
		c.ResponseError(errors.New("not logged in"))
		return
	}

	roomId := c.Param("room_id")
	if roomId == "" {
		c.ResponseError(errors.New("閫氳瘽ID涓嶈兘涓虹┖"))
		return
	}

	fallbackOnly := c.Query("fallback") != "1"
	if fallbackOnly {
		c.Response(a.signalsResponse(nil, true))
		return
	}

	signals, err := a.callStore.QueryCallSignals(roomId)
	if err != nil {
		a.Error("鏌ヨ淇′护澶辫触", zap.Error(err))
	}

	c.Response(a.signalsResponse(signals, false))
}

func (a *API) getCallSession(c *wkhttp.Context) {
	uid := c.GetLoginUID()
	if uid == "" {
		c.ResponseError(errors.New("not logged in"))
		return
	}

	roomId := c.Param("room_id")
	if roomId == "" {
		c.ResponseError(errors.New("闁俺鐦絀D娑撳秷鍏樻稉铏光敄"))
		return
	}

	room, err := a.callStore.QueryCallRoomByID(roomId)
	if err != nil || room == nil || !isCallRoomParticipant(room, uid) {
		c.ResponseError(errors.New("forbidden"))
		return
	}

	bootstrap, err := a.buildCallBootstrap(uid, &CallRoomResp{
		RoomId:       room.RoomId,
		RoomName:     room.RoomName,
		ChannelId:    room.ChannelId,
		ChannelType:  room.ChannelType,
		CallerUid:    room.CallerUid,
		CallerName:   room.CallerName,
		CalleeUid:    room.CalleeUid,
		CalleeName:   room.CalleeName,
		CallType:     room.CallType,
		Status:       room.Status,
		Participants: room.Participants,
		CreatedAt:    FormatTime(room.CreatedAt),
	}, callCapabilitiesFromQuery(c))
	if err != nil {
		c.ResponseError(err)
		return
	}

	c.Response(map[string]any{
		"data": bootstrap,
	})
}

// ============================================================
// ============================================================
// 杈呭姪鏂规硶
// ============================================================

func (a *API) handleCreateCallRoom(uid string, req CreateCallRoomReq) (*CallRoomResp, error) {
	callerName := a.resolveCallerName(uid)
	roomId := a.generateRoomID()
	participants := normalizeCallParticipants(req.Participants)

	model := &CallRoomModel{
		RoomId:       roomId,
		RoomName:     strings.TrimSpace(req.RoomName),
		ChannelId:    strings.TrimSpace(req.ChannelId),
		ChannelType:  req.ChannelType,
		CallerUid:    uid,
		CallerName:   callerName,
		CalleeUid:    strings.TrimSpace(req.CalleeUid),
		CalleeName:   strings.TrimSpace(req.CalleeName),
		CallType:     req.CallType,
		Status:       0,
		Participants: participants,
	}

	if err := a.callStore.InsertCallRoom(model); err != nil {
		return nil, err
	}

	resp := &CallRoomResp{
		RoomId:       roomId,
		RoomName:     model.RoomName,
		ChannelId:    model.ChannelId,
		ChannelType:  model.ChannelType,
		CallerUid:    uid,
		CallerName:   callerName,
		CalleeUid:    model.CalleeUid,
		CalleeName:   model.CalleeName,
		CallType:     req.CallType,
		Status:       0,
		Participants: participants,
		CreatedAt:    FormatTime(model.CreatedAt),
	}

	if model.ChannelType == int(common.ChannelTypeGroup.Uint8()) {
		for _, participant := range participants {
			if participant == nil || strings.TrimSpace(participant.Uid) == "" || strings.TrimSpace(participant.Uid) == uid {
				continue
			}
			a.emitCallEvent(participant.Uid, callInviteKind, roomId, a.buildCallInviteFrame(model))
		}
	} else if model.CalleeUid != "" {
		a.emitCallEvent(model.CalleeUid, callInviteKind, roomId, a.buildCallInviteFrame(model))
	}

	return resp, nil
}

func (a *API) ensureCanCreateCallRoom(uid string, req CreateCallRoomReq) error {
	groupNo := strings.TrimSpace(req.ChannelId)
	if groupNo == "" {
		return nil
	}
	if req.ChannelType != int(common.ChannelTypeGroup.Uint8()) {
		return errors.New("群通话参数错误")
	}
	if a.groupService == nil && a.ctx != nil {
		a.groupService = group.NewService(a.ctx)
	}
	if a.groupService == nil {
		return errors.New("群服务不可用")
	}
	groupInfo, err := a.groupService.GetGroupWithGroupNo(groupNo)
	if err != nil {
		return err
	}
	member, err := a.groupService.GetMember(groupNo, uid)
	if err != nil {
		return err
	}
	if member == nil {
		return errors.New("未在群内")
	}
	if member.ForbiddenExpirTime > time.Now().Unix() {
		return errors.New("当前账号已被禁言，无法发起群通话")
	}
	if groupInfo.Forbidden == 1 && member.Role != group.MemberRoleCreator && member.Role != group.MemberRoleManager {
		return errors.New("当前群已全员禁言，仅群主、管理员和机器人可以发言")
	}
	return nil
}

func normalizeCallParticipants(participants []*CallParticipantReq) []*CallParticipantResp {
	if len(participants) == 0 {
		return nil
	}
	resp := make([]*CallParticipantResp, 0, len(participants))
	seen := make(map[string]struct{}, len(participants))
	for _, participant := range participants {
		if participant == nil {
			continue
		}
		uid := strings.TrimSpace(participant.Uid)
		if uid == "" {
			continue
		}
		if _, ok := seen[uid]; ok {
			continue
		}
		seen[uid] = struct{}{}
		resp = append(resp, &CallParticipantResp{
			Uid:          uid,
			Name:         strings.TrimSpace(participant.Name),
			Role:         participant.Role,
			InviteStatus: participant.InviteStatus,
		})
	}
	return resp
}

func isCallRoomParticipant(room *CallRoomModel, uid string) bool {
	if room == nil || strings.TrimSpace(uid) == "" {
		return false
	}
	if room.CallerUid == uid || room.CalleeUid == uid {
		return true
	}
	for _, participant := range room.Participants {
		if participant != nil && participant.Uid == uid {
			return true
		}
	}
	return false
}

func (a *API) handleSendSignal(uid string, req CallSignalReq) error {
	model := &CallSignalModel{
		RoomId:     req.RoomId,
		FromUid:    uid,
		SignalType: req.SignalType,
		Payload:    req.Payload,
	}

	if err := a.callStore.InsertCallSignal(model); err != nil {
		return err
	}

	room, err := a.callStore.QueryCallRoomByID(req.RoomId)
	if err == nil && room != nil {
		if target := a.callRoomOpponent(room, uid); target != "" {
			req.FromUid = uid
			a.emitCallEvent(target, callSignalKind, req.RoomId, a.buildCallSignalFrame(room, &req))
		}
	}
	return nil
}

func (a *API) handleUpdateCallStatus(uid, roomId string, status int) error {
	if err := a.callStore.UpdateCallRoomStatus(roomId, status); err != nil {
		return err
	}

	room, err := a.callStore.QueryCallRoomByID(roomId)
	if err == nil && room != nil {
		if target := a.callRoomOpponent(room, uid); target != "" {
			a.emitCallEvent(target, callStateKind, roomId, a.buildCallStateFrame(room, status))
		}
	}
	return nil
}

func (a *API) resolveCallerName(uid string) string {
	callerName := uid
	if info, err := a.getUserInfo(uid); err == nil && info != nil {
		if name, ok := info["name"]; ok && name != "" {
			callerName = name
		}
	}
	return callerName
}

func (a *API) buildCallInviteFrame(room *CallRoomModel) map[string]interface{} {
	if room == nil {
		return nil
	}
	return map[string]interface{}{
		"room_id":      room.RoomId,
		"room_name":    room.RoomName,
		"channel_id":   room.ChannelId,
		"channel_type": room.ChannelType,
		"caller_uid":   room.CallerUid,
		"caller_name":  room.CallerName,
		"callee_uid":   room.CalleeUid,
		"callee_name":  room.CalleeName,
		"call_type":    room.CallType,
		"status":       room.Status,
		"participants": room.Participants,
		"created_at":   FormatTime(room.CreatedAt),
	}
}

func (a *API) buildCallSignalFrame(room *CallRoomModel, req *CallSignalReq) map[string]interface{} {
	return map[string]interface{}{
		"room_id":     req.RoomId,
		"from_uid":    req.FromUid,
		"signal_type": req.SignalType,
		"payload":     req.Payload,
	}
}

func (a *API) buildCallStateFrame(room *CallRoomModel, status int) map[string]interface{} {
	if room == nil {
		return nil
	}
	return map[string]interface{}{
		"room_id":    room.RoomId,
		"status":     status,
		"caller_uid": room.CallerUid,
		"callee_uid": room.CalleeUid,
		"updated_at": FormatTime(room.UpdatedAt),
	}
}

func (a *API) emitCallEvent(targetUID, kind, aggregateID string, payload interface{}) {
	if targetUID == "" || payload == nil {
		return
	}
	svc := a.getRealtimeService()
	if svc == nil {
		return
	}
	if err := svc.Append(targetUID, kind, aggregateID, payload); err != nil {
		a.Error("杩藉姞瀹炴椂浜嬩欢澶辫触", zap.String("kind", kind), zap.String("uid", targetUID), zap.Error(err))
	}
}

func (a *API) getRealtimeService() realtimeService {
	if a.realtimeSvc != nil {
		return a.realtimeSvc
	}
	svc := register.GetService(realtimeServiceName)
	if svc == nil {
		return nil
	}
	if realtime, ok := svc.(realtimeService); ok {
		a.realtimeSvc = realtime
		return realtime
	}
	a.Error("realtime service unavailable", zap.String("service", realtimeServiceName))
	return nil
}

func (a *API) callRoomOpponent(room *CallRoomModel, uid string) string {
	if room == nil {
		return ""
	}
	if room.CallerUid == uid {
		return room.CalleeUid
	}
	return room.CallerUid
}

func (a *API) generateRoomID() string {
	if a.roomIDGenerator != nil {
		return a.roomIDGenerator()
	}
	return "call_" + util.GenerUUID()
}

func (a *API) pendingCallsResponse(calls []*CallRoomModel, fallbackOnly bool) map[string]interface{} {
	if fallbackOnly {
		return map[string]interface{}{
			"data": []interface{}{},
			"meta": map[string]interface{}{
				fallbackMetaKey: true,
			},
		}
	}
	respList := make([]*CallRoomResp, 0, len(calls))
	for _, call := range calls {
		respList = append(respList, &CallRoomResp{
			RoomId:       call.RoomId,
			RoomName:     call.RoomName,
			ChannelId:    call.ChannelId,
			ChannelType:  call.ChannelType,
			CallerUid:    call.CallerUid,
			CallerName:   call.CallerName,
			CalleeUid:    call.CalleeUid,
			CalleeName:   call.CalleeName,
			CallType:     call.CallType,
			Status:       call.Status,
			Participants: call.Participants,
			CreatedAt:    FormatTime(call.CreatedAt),
		})
	}
	return map[string]interface{}{
		"data": respList,
	}
}

func (a *API) signalsResponse(signals []*CallSignalModel, fallbackOnly bool) map[string]interface{} {
	if fallbackOnly {
		return map[string]interface{}{
			"data": []interface{}{},
			"meta": map[string]interface{}{
				fallbackMetaKey: true,
			},
		}
	}
	signalList := make([]map[string]interface{}, 0, len(signals))
	for _, s := range signals {
		signalList = append(signalList, map[string]interface{}{
			"from_uid":    s.FromUid,
			"signal_type": s.SignalType,
			"payload":     s.Payload,
			"created_at":  FormatTime(s.CreatedAt),
		})
	}
	return map[string]interface{}{
		"data": signalList,
	}
}

func callCapabilitiesFromQuery(c *wkhttp.Context) CallClientCapabilitiesReq {
	supportsAudioRaw := strings.TrimSpace(c.Query("supports_audio"))
	supportsVideoRaw := strings.TrimSpace(c.Query("supports_video"))
	prefersAudioRaw := strings.TrimSpace(c.Query("prefers_audio"))
	isSafariRaw := strings.TrimSpace(c.Query("is_safari"))
	isMobileWebRaw := strings.TrimSpace(c.Query("is_mobile_web"))

	return CallClientCapabilitiesReq{
		Platform:      strings.TrimSpace(c.Query("platform")),
		SupportsAudio: supportsAudioRaw == "" || supportsAudioRaw == "1" || strings.EqualFold(supportsAudioRaw, "true"),
		SupportsVideo: supportsVideoRaw == "1" || strings.EqualFold(supportsVideoRaw, "true"),
		PrefersAudio:  prefersAudioRaw == "1" || strings.EqualFold(prefersAudioRaw, "true"),
		IsSafari:      isSafariRaw == "1" || strings.EqualFold(isSafariRaw, "true"),
		IsMobileWeb:   isMobileWebRaw == "1" || strings.EqualFold(isMobileWebRaw, "true"),
	}
}

func groupMomentLikesByMomentID(likes []*MomentLikeModel) map[int64][]*MomentLikeModel {
	grouped := make(map[int64][]*MomentLikeModel, len(likes))
	for _, like := range likes {
		grouped[like.MomentId] = append(grouped[like.MomentId], like)
	}
	return grouped
}

func groupMomentCommentsByMomentID(comments []*MomentCommentModel) map[int64][]*MomentCommentModel {
	grouped := make(map[int64][]*MomentCommentModel, len(comments))
	for _, comment := range comments {
		grouped[comment.MomentId] = append(grouped[comment.MomentId], comment)
	}
	return grouped
}

func (a *API) parseInt(s string, defaultVal int) int {
	if s == "" {
		return defaultVal
	}
	v, err := strconv.Atoi(strings.TrimSpace(s))
	if err != nil || v <= 0 {
		return defaultVal
	}
	return v
}

// getUserInfo 鑾峰彇鐢ㄦ埛淇℃伅
func (a *API) parseInt64(s string, defaultVal int64) int64 {
	if s == "" {
		return defaultVal
	}
	v, err := strconv.ParseInt(strings.TrimSpace(s), 10, 64)
	if err != nil || v <= 0 {
		return defaultVal
	}
	return v
}

func (a *API) getUserInfo(uid string) (map[string]string, error) {
	if a.userService == nil {
		return nil, nil
	}
	userResp, err := a.userService.GetUser(uid)
	if err != nil || userResp == nil {
		return nil, err
	}
	return map[string]string{
		"name":   userResp.Name,
		"avatar": fmt.Sprintf("users/%s/avatar", uid),
	}, nil
}

// getUserInfoMap 鎵归噺鑾峰彇鐢ㄦ埛淇℃伅
func (a *API) getUserInfoMap(uids []string) (map[string]string, error) {
	if len(uids) == 0 {
		return make(map[string]string), nil
	}

	if a.userService == nil {
		return make(map[string]string), nil
	}
	users, err := a.userService.GetUsers(uids)
	if err != nil {
		return make(map[string]string), err
	}

	result := make(map[string]string)
	for _, u := range users {
		result[u.UID] = u.Name
	}
	return result, nil
}

// Error 璁板綍閿欒鏃ュ織
func (a *API) Error(msg string, fields ...zap.Field) {
	a.ctx.Error(msg, fields...)
}
