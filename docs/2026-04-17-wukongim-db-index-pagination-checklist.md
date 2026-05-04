# WuKongIM 数据库索引与分页改造清单

## 1. 改造目标

本清单用于把当前 `message / conversation` 存储从“可写入”升级为“可分页、可去重、可稳定排序、可支撑海量消息查询”。

当前已完成基线：

- `server_msg_id` 已回填并建立唯一索引前置去重逻辑
- `conversation.last_client_msg_no` 已在重复消息折叠前完成 survivor 重映射
- `idx_message_conversation_sort` 已存在【F:/C:/Users/COLORFUL/Desktop/WuKongIM/TangSengDaoDao/WuKongIMFlutterSDK-master/assets/202604200930.sql†L1-L65】

下一阶段目标：

- 补齐“会话分页、未读查找、会话排序”三组索引
- 明确消息窗口分页协议
- 固化迁移顺序与回滚方式

## 2. 查询族划分

| 查询族 | 典型 SQL / 场景 | 需要的索引 |
|---|---|---|
| 会话最近消息翻页 | `WHERE channel_id=? AND channel_type=? AND message_seq < ? ORDER BY message_seq DESC LIMIT ?` | `idx_message_channel_seq` |
| 本地回显补位 | `WHERE channel_id=? AND channel_type=? ORDER BY client_seq DESC` | `idx_message_channel_client_seq` |
| 会话列表排序 | `WHERE is_deleted=0 ORDER BY top DESC, last_msg_timestamp DESC` | `idx_conversation_sort` |
| 未读消息定位 | `WHERE channel_id=? AND channel_type=? AND readed=0` | `idx_message_unread_lookup` |
| 去重命中 | `WHERE channel_id=? AND channel_type=? AND server_msg_id=?` | `uq_message_server_msg_id` |

## 3. 目标索引清单

按迁移顺序执行：

```sql
CREATE UNIQUE INDEX IF NOT EXISTS uq_message_server_msg_id
ON message (channel_id, channel_type, server_msg_id)
WHERE server_msg_id IS NOT NULL AND TRIM(server_msg_id) <> '';

CREATE INDEX IF NOT EXISTS idx_message_channel_seq
ON message (channel_id, channel_type, message_seq DESC);

CREATE INDEX IF NOT EXISTS idx_message_channel_client_seq
ON message (channel_id, channel_type, client_seq DESC);

CREATE INDEX IF NOT EXISTS idx_conversation_sort
ON conversation (is_deleted, top, last_msg_timestamp DESC);

CREATE INDEX IF NOT EXISTS idx_message_unread_lookup
ON message (channel_id, channel_type, is_deleted, readed, message_seq DESC);
```

## 4. 迁移执行顺序

1. 检查老库是否已完成 `server_msg_id` 回填。
2. 清理 `server_msg_id` 为空但 `message_id` 有值的遗留行。
3. 修复 `conversation.last_client_msg_no` 指针。
4. 执行重复消息折叠。
5. 创建唯一索引。
6. 创建分页与排序索引。
7. 跑迁移幂等回归测试。

禁止顺序：

- 先创建唯一索引，再去重
- 先删除重复消息，再修复 `last_client_msg_no`
- 未做幂等保护就直接上线第二版迁移 SQL

## 5. Flutter 端分页接口清单

### Repository / API Checklist

- [ ] 新增 `pageChannelMessages(channelId, channelType, beforeMessageSeq, limit)`
- [ ] 首屏默认 `limit = 50`
- [ ] 上滑预加载阈值 `remaining <= 15`
- [ ] 历史消息拉取批次 `limit = 100`
- [ ] 下发结果按 `message_seq DESC` 排序
- [ ] UI 渲染前反转为时间正序窗口
- [ ] 媒体消息只在进入可视区域时做详情解码

### 推荐接口签名

```dart
Future<List<Map<String, dynamic>>> pageChannelMessages({
  required String channelId,
  required int channelType,
  required int beforeMessageSeq,
  int limit = 50,
});
```

## 6. SQLite 运行时建议

初始化时执行：

```sql
PRAGMA journal_mode=WAL;
PRAGMA synchronous=NORMAL;
PRAGMA temp_store=MEMORY;
PRAGMA cache_size=-20000;
```

落地要求：

- [ ] 所有批量消息插入必须走事务
- [ ] 消息补偿写入与会话 patch 更新必须同事务提交
- [ ] `message_seq` 缺失时不得进入分页主查询
- [ ] 本地草稿、输入态、富文本 span 不进入消息主表

## 7. 验收 SQL

### 去重结果验收

```sql
SELECT channel_id, channel_type, server_msg_id, COUNT(*)
FROM message
WHERE server_msg_id IS NOT NULL AND TRIM(server_msg_id) <> ''
GROUP BY channel_id, channel_type, server_msg_id
HAVING COUNT(*) > 1;
```

Expected: `0 rows`

### 会话指针验收

```sql
SELECT c.channel_id, c.channel_type, c.last_client_msg_no
FROM conversation c
LEFT JOIN message m
  ON m.channel_id = c.channel_id
 AND m.channel_type = c.channel_type
 AND m.client_msg_no = c.last_client_msg_no
WHERE c.last_client_msg_no IS NOT NULL
  AND TRIM(c.last_client_msg_no) <> ''
  AND m.client_msg_no IS NULL;
```

Expected: `0 rows`

### 分页索引验收

```sql
EXPLAIN QUERY PLAN
SELECT *
FROM message
WHERE channel_id='u_1001'
  AND channel_type=1
  AND message_seq < 500000
ORDER BY message_seq DESC
LIMIT 50;
```

Expected:
- 走 `idx_message_channel_seq`
- 不出现全表扫描

## 8. 性能门槛

| 指标 | 目标 |
|---|---|
| 单会话 10 万条消息翻页 P95 | < 80ms |
| 会话列表首屏查询 P95 | < 50ms |
| 未读定位 P95 | < 30ms |
| 迁移幂等重跑 | 不报错 |
| 重复消息折叠后 survivor 指针丢失 | 0 |

## 9. 回滚策略

- [ ] 新增索引 migration 独立版本号，不与去重迁移混包
- [ ] 迁移前备份本地 DB 文件
- [ ] 升级失败时只回滚新索引，不回滚已生效的 `server_msg_id` 列
- [ ] 崩溃回放时优先检查 `wk_max_sql_version_*` 与 `sqlite_master`

## 10. 推荐测试命令

```powershell
flutter test test/service/im/wk_db_helper_migration_test.dart
dart analyze test/service/im/wk_db_helper_migration_test.dart
```

Expected:
- 迁移测试全部通过
- analyze 无 error
