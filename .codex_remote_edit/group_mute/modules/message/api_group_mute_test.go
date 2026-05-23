package message

import (
	"bytes"
	"net/http"
	"net/http/httptest"
	"testing"

	"github.com/TangSengDaoDao/TangSengDaoDaoServer/modules/group"
	"github.com/TangSengDaoDao/TangSengDaoDaoServerLib/common"
	"github.com/TangSengDaoDao/TangSengDaoDaoServerLib/config"
	"github.com/TangSengDaoDao/TangSengDaoDaoServerLib/pkg/util"
	"github.com/TangSengDaoDao/TangSengDaoDaoServerLib/pkg/wkhttp"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

const (
	groupMuteSendOwnerToken  = "group-mute-owner-token"
	groupMuteSendAdminToken  = "group-mute-admin-token"
	groupMuteSendMemberToken = "group-mute-member-token"
)

func TestSendMsgRejectsNormalMemberWhenGroupMuted(t *testing.T) {
	s, ctx := newTestServerWithMockIM(t)
	ctx.GetConfig().Message.SendMessageOn = true
	require.NoError(t, seedMutedGroupSendMembers(ctx, "group_mute_send_blocked"))
	require.NoError(t, ctx.Cache().Set(ctx.GetConfig().Cache.TokenCachePrefix+groupMuteSendMemberToken, wkhttp.EncodeTokenCacheInfo("member_uid", "member", "")))

	w := httptest.NewRecorder()
	req, err := http.NewRequest("POST", "/v1/message/send", bytes.NewReader([]byte(util.ToJson(map[string]interface{}{
		"token":                groupMuteSendMemberToken,
		"receive_channel_id":   "group_mute_send_blocked",
		"receive_channel_type": common.ChannelTypeGroup.Uint8(),
		"payload": map[string]interface{}{
			"type":    common.Text.Int(),
			"content": "blocked",
		},
	}))))
	require.NoError(t, err)
	s.GetRoute().ServeHTTP(w, req)

	assert.NotEqual(t, http.StatusOK, w.Code)
	assert.Contains(t, w.Body.String(), "全员禁言")
}

func TestSendMsgAllowsManagerRolesWhenGroupMuted(t *testing.T) {
	s, ctx := newTestServerWithMockIM(t)
	ctx.GetConfig().Message.SendMessageOn = true
	require.NoError(t, seedMutedGroupSendMembers(ctx, "group_mute_send_allowed"))
	require.NoError(t, ctx.Cache().Set(ctx.GetConfig().Cache.TokenCachePrefix+groupMuteSendOwnerToken, wkhttp.EncodeTokenCacheInfo("owner_uid", "owner", "")))
	require.NoError(t, ctx.Cache().Set(ctx.GetConfig().Cache.TokenCachePrefix+groupMuteSendAdminToken, wkhttp.EncodeTokenCacheInfo("admin_uid", "admin", "")))

	for _, tc := range []struct {
		name  string
		token string
	}{
		{name: "owner", token: groupMuteSendOwnerToken},
		{name: "admin", token: groupMuteSendAdminToken},
	} {
		t.Run(tc.name, func(t *testing.T) {
			w := httptest.NewRecorder()
			req, err := http.NewRequest("POST", "/v1/message/send", bytes.NewReader([]byte(util.ToJson(map[string]interface{}{
				"token":                tc.token,
				"receive_channel_id":   "group_mute_send_allowed",
				"receive_channel_type": common.ChannelTypeGroup.Uint8(),
				"payload": map[string]interface{}{
					"type":    common.Text.Int(),
					"content": "allowed",
				},
			}))))
			require.NoError(t, err)
			s.GetRoute().ServeHTTP(w, req)

			assert.Equal(t, http.StatusOK, w.Code, w.Body.String())
		})
	}
}

func seedMutedGroupSendMembers(ctx *config.Context, groupNo string) error {
	db := group.NewDB(ctx)
	if err := db.Insert(&group.Model{
		GroupNo:   groupNo,
		Name:      "muted group",
		Creator:   "owner_uid",
		Status:    group.GroupStatusNormal,
		Forbidden: 1,
		Version:   ctx.GenSeq(common.GroupSeqKey),
	}); err != nil {
		return err
	}
	for _, member := range []*group.MemberModel{
		{
			GroupNo: groupNo,
			UID:     "owner_uid",
			Role:    group.MemberRoleCreator,
			Status:  int(common.GroupMemberStatusNormal),
			Version: ctx.GenSeq(common.GroupMemberSeqKey),
		},
		{
			GroupNo: groupNo,
			UID:     "admin_uid",
			Role:    group.MemberRoleManager,
			Status:  int(common.GroupMemberStatusNormal),
			Version: ctx.GenSeq(common.GroupMemberSeqKey),
		},
		{
			GroupNo: groupNo,
			UID:     "member_uid",
			Role:    group.MemberRoleCommon,
			Status:  int(common.GroupMemberStatusNormal),
			Version: ctx.GenSeq(common.GroupMemberSeqKey),
		},
	} {
		if err := db.InsertMember(member); err != nil {
			return err
		}
	}
	return nil
}
