## Search Runtime Resolution Checkpoint

Date: 2026-04-03

## Summary

The deployed TangSeng search endpoint is no longer blocked by the missing WuKongIM search plugin.

The root cause of the remaining runtime failure was a missing WuKongIM config file, which left the search-plugin route forwarding path without a usable HTTP base URL.

After restoring the missing WuKongIM runtime config and restarting the container, real authenticated `POST /v1/search/global` requests began returning `200` with search data.

## Investigation Evidence

### 1. Plugin loaded, but search still failed

- TangSeng server log at `2026-04-03 15:37:41 +08:00`:
  - `【search】查询悟空IM消息错误`
  - `IM服务返回状态[502]失败！`
- Matching WuKongIM log at the same moment:
  - `【plugin.rpc】转发请求失败！`
  - `Post "/conversation/channels": unsupported protocol scheme ""`

Conclusion:

- TangSeng was successfully reaching WuKongIM and the loaded search plugin
- The failing hop was inside WuKongIM/plugin request forwarding, not Flutter request signing and not plugin installation anymore

### 2. The target route existed inside WuKongIM

- From inside the WuKongIM container:
  - `POST http://fullstack-wukongim-1:5001/conversation/channels` returned `500`
  - It did **not** return `404`

Conclusion:

- `/conversation/channels` is a valid WuKongIM-side route
- The error was caused by an empty/missing base URL, not by a nonexistent route

### 3. WuKongIM was starting without its expected config file

- Container startup args:
  - `/home/app --config=/root/wukongim/wk.yaml --ignoreMissingConfig=true`
- Host-mounted path check:
  - `/data/fullstack/wukongimdata/wk.yaml` was missing before the fix

Conclusion:

- WuKongIM was running with defaults plus partial environment overrides
- That deployment state was sufficient to start the API server and load the plugin, but not sufficient for the plugin forwarding path used by search

## Fix Applied On Server

Created `wk.yaml` at:

- `/data/fullstack/wukongimdata/wk.yaml`

with:

```yaml
rootDir: "/root/wukongim"
external:
  ip: "103.207.68.33"
  apiUrl: "http://103.207.68.33:5001"
cluster:
  apiUrl: "http://fullstack-wukongim-1:5001"
```

Then restarted:

- `fullstack-wukongim-1`

## Post-Fix Verification

### 1. WuKongIM now reads the config file

WuKongIM startup log now reports:

- `Config File: /root/wukongim/wk.yaml`

### 2. Search plugin still loads successfully

- `GET http://103.207.68.33:5001/plugins` returns `wk.plugin.search` with `status: 1`

### 3. Real authenticated global search now succeeds

Authenticated request at `2026-04-03 16:03:57 +08:00`:

```json
{
  "channel_id": "",
  "channel_type": 0,
  "only_message": 0,
  "keyword": "test",
  "from_uid": "",
  "topic": "",
  "limit": 20,
  "page": 1,
  "start_time": 0,
  "end_time": 0,
  "content_type": []
}
```

returned `200` with real search data, including friend and group hits.

## Phase 2 Impact

This removes the previously blocking runtime issue for search infrastructure.

Phase 2 is no longer blocked by:

- missing `wk.plugin.search`
- missing plugin process startup
- `plugin not found`
- WuKongIM plugin forward-path `502`

## Remaining Validation Gap

The current account used for smoke checks does not contain enough searchable message history to fully prove all three data-bearing search slices with real hits:

- in-chat keyword result list
- image result list
- member-scoped result list

Additional runtime seeding through `/v1/message/send` was attempted, but the deployed server currently rejects it with:

- `{"msg":"不支持代发消息","status":400}`

So the remaining gap is now **test data availability / deployment policy**, not search backend health.

## Recommended Next Step

Resume the Android-parity search Phase 2 work, using:

- the repaired live backend for integration validation
- existing Flutter widget/provider tests for scoped search and anchored navigation behavior

Then, when a searchable dataset is available, run a final live smoke pass for:

- keyword hit navigation
- image search result rendering
- member-scoped history search
