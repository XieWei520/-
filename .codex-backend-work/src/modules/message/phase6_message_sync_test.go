package message

import (
	"strconv"
	"testing"

	"github.com/TangSengDaoDao/TangSengDaoDaoServerLib/config"
	"github.com/stretchr/testify/require"
)

func TestPhase6MessageIDsFromSyncResponsesSkipsNilAndDedupes(t *testing.T) {
	resps := []*config.MessageResp{
		{MessageID: 11},
		nil,
		{MessageID: 11},
		{MessageID: 12},
	}

	got := phase6MessageIDsFromSyncResponses(resps)

	require.Equal(t, []string{"11", "12"}, got)
}

func TestPhase6MessageExtraMapsByMessageID(t *testing.T) {
	extras := []*messageExtraDetailModel{
		{messageExtraModel: messageExtraModel{MessageID: "11", Version: 3}},
		{messageExtraModel: messageExtraModel{MessageID: "12", Version: 4}},
	}
	userExtras := []*messageUserExtraModel{
		{MessageID: "12", VoiceReaded: 1},
	}

	extraMap, userExtraMap := phase6BuildMessageExtraMaps(extras, userExtras)

	require.Equal(t, int64(3), extraMap["11"].Version)
	require.Equal(t, 1, userExtraMap["12"].VoiceReaded)
	require.Nil(t, userExtraMap["11"])
}

func TestPhase6MessageIDStringsMatchResponseIDs(t *testing.T) {
	resps := []*config.MessageResp{{MessageID: 123456789}}
	got := phase6MessageIDsFromSyncResponses(resps)

	require.Equal(t, strconv.FormatInt(resps[0].MessageID, 10), got[0])
}
