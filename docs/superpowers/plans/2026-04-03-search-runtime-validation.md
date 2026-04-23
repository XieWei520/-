# Search Runtime Validation Checkpoint

Date: 2026-04-03

## Scope

Validate the current Flutter Android-parity search work against the deployed backend before entering Phase 2.

## Local Session Evidence

- Flutter desktop session found in `C:/Users/COLORFUL/AppData/Roaming/com.im/wukong_im_app/shared_preferences.json`
- Session values used for validation:
  - `uid = 0a13431ca09247439ba5aaafe8f93359`
  - `token = a5950b4cc49048e8b4018027acf07e11`
  - `device_id = aabff4e9ec1e4f07b44623c1a6667f88`

## Verified Runtime Results

### 1. Authenticated API access works

- `GET /v1/users/0a13431ca09247439ba5aaafe8f93359` returned `200`
- Conclusion: the Flutter session token is valid for read-side API validation

### 2. Global message search is blocked by backend deployment state

- `POST /v1/search/global` returned `400`
- TangSeng server log at `2026-04-03 14:40:30` recorded:
  - `【search】查询悟空IM消息错误`
  - `IM服务失败！ -> plugin not found`
- `GET http://103.207.68.33:5001/plugins` returned `[]`
- WukongIM container state:
  - mount: `/data/fullstack/wukongimdata -> /root/wukongim`
  - startup args: `/home/app --config=/root/wukongim/wk.yaml --ignoreMissingConfig=true`
  - actual mount contents contain logs/data but no `wk.yaml`
  - `/root/wukongim/plugins` contains only `plugindata/` and no installed plugin files
- TangSengDaoDao server binary evidence:
  - embedded strings include `plugins/wk.plugin.search`
  - embedded strings include `IMSearchMessages`

Conclusion:

- Flutter in-chat search UI can keep advancing, but real `/v1/search/global` validation cannot pass until the WukongIM search plugin is installed and loaded
- This is a deployment blocker, not a request-signing bug in the current Flutter client

### 3. Favorites list works, but favorites search route was wrong in Flutter

- `GET /v1/extra/favorites?page=1&page_size=20` returned `200`
- The account already has one stored favorite item
- Runtime endpoint checks showed:
  - `POST /v1/extra/favorites/search` -> `200`
  - `POST /v1/extra/favorite/search` -> `404`
- Flutter code previously called `POST /v1/extra/favorite/search`

Conclusion:

- Favorites backend is healthy for list/search
- Flutter had a real API route bug for favorites search

## Code Fix Landed In Flutter

- Fixed `CollectionApi.search()` to use `${ApiConfig.favorites}/search`
- Added regression test:
  - `test/service/api/collection_api_test.dart`

## Verification Run After Fix

- `flutter test test/service/api/collection_api_test.dart test/modules/search/chat_search_collection_page_test.dart`
- `dart analyze lib/service/api/collection_api.dart lib/modules/search test/service/api/collection_api_test.dart test/modules/search/chat_search_collection_page_test.dart`

Both commands passed on 2026-04-03.

## Phase 2 Gate

Do not enter the previously planned Phase 2 until these conditions are true:

1. WukongIM search plugin is installed and visible in `GET /plugins`
2. `POST /v1/search/global` returns real search data instead of `plugin not found`
3. Flutter smoke-checks pass for:
   - keyword search
   - image search
   - member search
   - show-in-chat anchored navigation

## Recommended Next Step

Prioritize backend search-plugin repair before broader Phase 2 execution. Without that, Phase 2 work would be forced to proceed against a broken runtime search substrate and would hide deployment issues behind UI progress.
