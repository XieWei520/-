package extra

import (
	"time"

	"github.com/gocraft/dbr/v2"
)

type FavoriteModel struct {
	Id          int64        `json:"id"`
	Uid         string       `json:"uid"`
	ClientMsgNo string       `json:"client_msg_no"`
	MessageId   string       `json:"message_id"`
	MessageSeq  int64        `json:"message_seq"`
	OrderSeq    int64        `json:"order_seq"`
	Content     string       `json:"content"`
	ContentType int          `json:"content_type"`
	ChannelId   string       `json:"channel_id"`
	ChannelType int          `json:"channel_type"`
	SenderUid   string       `json:"sender_uid"`
	SenderName  string       `json:"sender_name"`
	CreatedAt   dbr.NullTime `json:"created_at"`
	UpdatedAt   dbr.NullTime `json:"updated_at"`
}

type FavoriteResp struct {
	Id          int64  `json:"id"`
	Uid         string `json:"uid"`
	ClientMsgNo string `json:"client_msg_no"`
	MessageId   string `json:"message_id"`
	MessageSeq  int64  `json:"message_seq"`
	OrderSeq    int64  `json:"order_seq"`
	Content     string `json:"content"`
	ContentType int    `json:"content_type"`
	ChannelId   string `json:"channel_id"`
	ChannelType int    `json:"channel_type"`
	SenderUid   string `json:"sender_uid"`
	SenderName  string `json:"sender_name"`
	CreatedAt   string `json:"created_at"`
}

type TagModel struct {
	Id        int64        `json:"id"`
	Uid       string       `json:"uid"`
	Name      string       `json:"name"`
	Remark    string       `json:"remark"`
	CreatedAt dbr.NullTime `json:"created_at"`
	UpdatedAt dbr.NullTime `json:"updated_at"`
}

type TagMemberModel struct {
	Id        int64        `json:"id"`
	TagId     int64        `json:"tag_id"`
	Uid       string       `json:"uid"`
	UserName  string       `json:"user_name"`
	CreatedAt dbr.NullTime `json:"created_at"`
}

type TagResp struct {
	Id        int64            `json:"id"`
	Name      string           `json:"name"`
	Remark    string           `json:"remark"`
	Members   []*TagMemberResp `json:"members"`
	Count     int              `json:"count"`
	CreatedAt string           `json:"created_at"`
}

type TagMemberResp struct {
	Uid      string `json:"uid"`
	UserName string `json:"user_name"`
}

type MomentModel struct {
	Id           int64        `json:"id"`
	Uid          string       `json:"uid"`
	Content      string       `json:"content"`
	Location     string       `json:"location"`
	Images       string       `json:"images"`
	Mentions     string       `json:"mentions"`
	LikeCount    int          `json:"like_count"`
	CommentCount int          `json:"comment_count"`
	Status       int          `json:"status"`
	CreatedAt    dbr.NullTime `json:"created_at"`
	UpdatedAt    dbr.NullTime `json:"updated_at"`
}

type MomentLikeModel struct {
	Id        int64        `json:"id"`
	MomentId  int64        `json:"moment_id"`
	Uid       string       `json:"uid"`
	UserName  string       `json:"user_name"`
	CreatedAt dbr.NullTime `json:"created_at"`
}

type MomentCommentModel struct {
	Id          int64        `json:"id"`
	MomentId    int64        `json:"moment_id"`
	Uid         string       `json:"uid"`
	UserName    string       `json:"user_name"`
	Content     string       `json:"content"`
	ReplyToUid  string       `json:"reply_to_uid"`
	ReplyToName string       `json:"reply_to_name"`
	Status      int          `json:"status"`
	CreatedAt   dbr.NullTime `json:"created_at"`
	UpdatedAt   dbr.NullTime `json:"updated_at"`
}

type MomentResp struct {
	Id           int64                `json:"id"`
	Author       *MomentAuthorResp    `json:"author"`
	Content      string               `json:"content"`
	Location     string               `json:"location"`
	Images       []string             `json:"images"`
	Mentions     []string             `json:"mentions"`
	Likes        []*MomentLikeResp    `json:"likes"`
	Comments     []*MomentCommentResp `json:"comments"`
	LikeCount    int                  `json:"like_count"`
	CommentCount int                  `json:"comment_count"`
	IsLiked      bool                 `json:"is_liked"`
	Status       int                  `json:"status"`
	CreatedAt    string               `json:"created_at"`
}

type MomentAuthorResp struct {
	Uid    string `json:"uid"`
	Name   string `json:"name"`
	Avatar string `json:"avatar"`
}

type MomentLikeResp struct {
	Uid      string `json:"uid"`
	UserName string `json:"name"`
}

type MomentCommentResp struct {
	Id          int64  `json:"id"`
	Uid         string `json:"uid"`
	AuthorName  string `json:"author_name"`
	Content     string `json:"content"`
	ReplyToUid  string `json:"reply_to_uid"`
	ReplyToName string `json:"reply_to_name"`
	CreatedAt   string `json:"created_at"`
}

type ManagerMomentResp struct {
	Id           int64                       `json:"id"`
	Uid          string                      `json:"uid"`
	AuthorName   string                      `json:"author_name"`
	AuthorAvatar string                      `json:"author_avatar"`
	Content      string                      `json:"content"`
	Location     string                      `json:"location"`
	Images       []string                    `json:"images"`
	Mentions     []string                    `json:"mentions"`
	LikeCount    int                         `json:"like_count"`
	CommentCount int                         `json:"comment_count"`
	Status       int                         `json:"status"`
	CreatedAt    string                      `json:"created_at"`
	Comments     []*ManagerMomentCommentResp `json:"comments,omitempty"`
}

type ManagerMomentCommentResp struct {
	Id          int64  `json:"id"`
	Uid         string `json:"uid"`
	AuthorName  string `json:"author_name"`
	Content     string `json:"content"`
	ReplyToUid  string `json:"reply_to_uid"`
	ReplyToName string `json:"reply_to_name"`
	CreatedAt   string `json:"created_at"`
}

type UserGlobalSettingModel struct {
	Id                int64        `json:"id"`
	Uid               string       `json:"uid"`
	SearchByPhone     int          `json:"search_by_phone"`
	SearchByShort     int          `json:"search_by_short"`
	NewMsgNotice      int          `json:"new_msg_notice"`
	MsgShowDetail     int          `json:"msg_show_detail"`
	VoiceOn           int          `json:"voice_on"`
	ShockOn           int          `json:"shock_on"`
	OfflineProtection int          `json:"offline_protection"`
	DeviceLock        int          `json:"device_lock"`
	DeviceLockPwd     string       `json:"device_lock_pwd"`
	MuteOfApp         int          `json:"mute_of_app"`
	CreatedAt         dbr.NullTime `json:"created_at"`
	UpdatedAt         dbr.NullTime `json:"updated_at"`
}

type UserGlobalSettingResp struct {
	SearchByPhone     int `json:"search_by_phone"`
	SearchByShort     int `json:"search_by_short"`
	NewMsgNotice      int `json:"new_msg_notice"`
	MsgShowDetail     int `json:"msg_show_detail"`
	VoiceOn           int `json:"voice_on"`
	ShockOn           int `json:"shock_on"`
	OfflineProtection int `json:"offline_protection"`
	DeviceLock        int `json:"device_lock"`
	MuteOfApp         int `json:"mute_of_app"`
}

type DeviceLockRecordModel struct {
	Id        int64        `json:"id"`
	Uid       string       `json:"uid"`
	DeviceId  string       `json:"device_id"`
	Password  string       `json:"password"`
	Enabled   int          `json:"enabled"`
	CreatedAt dbr.NullTime `json:"created_at"`
	UpdatedAt dbr.NullTime `json:"updated_at"`
}

type CallRoomModel struct {
	Id           int64                  `json:"id"`
	RoomId       string                 `json:"room_id"`
	RoomName     string                 `json:"room_name"`
	ChannelId    string                 `json:"channel_id"`
	ChannelType  int                    `json:"channel_type"`
	CallerUid    string                 `json:"caller_uid"`
	CallerName   string                 `json:"caller_name"`
	CalleeUid    string                 `json:"callee_uid"`
	CalleeName   string                 `json:"callee_name"`
	CallType     int                    `json:"call_type"`
	Status       int                    `json:"status"`
	Participants []*CallParticipantResp `db:"-" json:"participants"`
	StartedAt    *time.Time             `json:"started_at"`
	EndedAt      *time.Time             `json:"ended_at"`
	CreatedAt    dbr.NullTime           `json:"created_at"`
	UpdatedAt    dbr.NullTime           `json:"updated_at"`
}

type CallSignalModel struct {
	Id         int64        `json:"id"`
	RoomId     string       `json:"room_id"`
	FromUid    string       `json:"from_uid"`
	SignalType int          `json:"signal_type"`
	Payload    string       `json:"payload"`
	CreatedAt  dbr.NullTime `json:"created_at"`
}

type CallRoomResp struct {
	RoomId       string                 `json:"room_id"`
	RoomName     string                 `json:"room_name"`
	ChannelId    string                 `json:"channel_id"`
	ChannelType  int                    `json:"channel_type"`
	CallerUid    string                 `json:"caller_uid"`
	CallerName   string                 `json:"caller_name"`
	CalleeUid    string                 `json:"callee_uid"`
	CalleeName   string                 `json:"callee_name"`
	CallType     int                    `json:"call_type"`
	Status       int                    `json:"status"`
	Participants []*CallParticipantResp `json:"participants"`
	CreatedAt    string                 `json:"created_at"`
}

type CallParticipantReq struct {
	Uid          string `json:"uid"`
	Name         string `json:"name"`
	Role         int    `json:"role"`
	InviteStatus int    `json:"invite_status"`
}

type CallParticipantResp struct {
	Uid          string `json:"uid" db:"uid"`
	Name         string `json:"name" db:"user_name"`
	Role         int    `json:"role" db:"role"`
	InviteStatus int    `json:"invite_status" db:"invite_status"`
}

type CallClientCapabilitiesReq struct {
	Platform      string `json:"platform"`
	SupportsVideo bool   `json:"supports_video"`
	SupportsAudio bool   `json:"supports_audio"`
	PrefersAudio  bool   `json:"prefers_audio"`
	IsSafari      bool   `json:"is_safari"`
	IsMobileWeb   bool   `json:"is_mobile_web"`
}

type CallSessionTicketResp struct {
	Token       string `json:"token"`
	ExpiresAt   int64  `json:"expires_at"`
	RoomID      string `json:"room_id"`
	Participant string `json:"participant"`
}

type CallJoinDescriptorResp struct {
	ControlURL string `json:"control_url"`
	LiveKitURL string `json:"livekit_url"`
	RoomName   string `json:"room_name"`
}

type CallRoomBootstrapResp struct {
	Room         *CallRoomResp             `json:"room"`
	Ticket       *CallSessionTicketResp    `json:"ticket"`
	Join         *CallJoinDescriptorResp   `json:"join"`
	Capabilities CallClientCapabilitiesReq `json:"capabilities"`
}

type PageReq struct {
	Page     int `json:"page"`
	PageSize int `json:"page_size"`
}

type PageResp struct {
	List       interface{} `json:"list"`
	Page       int         `json:"page"`
	PageSize   int         `json:"page_size"`
	TotalCount int64       `json:"total_count"`
}

type CreateFavoriteReq struct {
	ClientMsgNo string `json:"client_msg_no"`
	MessageId   string `json:"message_id"`
	MessageSeq  int64  `json:"message_seq"`
	OrderSeq    int64  `json:"order_seq"`
	Content     string `json:"content"`
	ContentType int    `json:"content_type"`
	ChannelId   string `json:"channel_id"`
	ChannelType int    `json:"channel_type"`
	SenderUid   string `json:"sender_uid"`
	SenderName  string `json:"sender_name"`
}

type CreateTagReq struct {
	Name   string `json:"name"`
	Remark string `json:"remark"`
}

type UpdateTagReq struct {
	Name   string `json:"name"`
	Remark string `json:"remark"`
}

type TagMembersReq struct {
	Uids []string `json:"uids"`
}

type PublishMomentReq struct {
	Content  string   `json:"content"`
	Images   []string `json:"images"`
	Mentions []string `json:"mentions"`
	Location string   `json:"location"`
}

type CommentMomentReq struct {
	Content string `json:"content"`
	ReplyTo string `json:"reply_to"`
}

type UpdateSettingReq struct {
	SearchByPhone     *int `json:"search_by_phone"`
	SearchByShort     *int `json:"search_by_short"`
	NewMsgNotice      *int `json:"new_msg_notice"`
	MsgShowDetail     *int `json:"msg_show_detail"`
	VoiceOn           *int `json:"voice_on"`
	ShockOn           *int `json:"shock_on"`
	OfflineProtection *int `json:"offline_protection"`
	DeviceLock        *int `json:"device_lock"`
	MuteOfApp         *int `json:"mute_of_app"`
}

type DeviceLockReq struct {
	Password string `json:"password"`
	Enabled  bool   `json:"enabled"`
}

type DeviceLockResp struct {
	Enabled bool `json:"enabled"`
}

type CallSignalReq struct {
	RoomId     string `json:"room_id"`
	FromUid    string `json:"from_uid"`
	SignalType int    `json:"signal_type"`
	Payload    string `json:"payload"`
}

type CreateCallRoomReq struct {
	CalleeUid    string                    `json:"callee_uid"`
	CalleeName   string                    `json:"callee_name"`
	CallType     int                       `json:"call_type"`
	RoomName     string                    `json:"room_name"`
	ChannelId    string                    `json:"channel_id"`
	ChannelType  int                       `json:"channel_type"`
	Participants []*CallParticipantReq     `json:"participants"`
	Capabilities CallClientCapabilitiesReq `json:"capabilities"`
}

type UpdateCallStatusReq struct {
	Status int `json:"status"`
}
