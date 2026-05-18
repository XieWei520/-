CREATE VIRTUAL TABLE IF NOT EXISTS message_fts USING fts5(
  client_seq UNINDEXED,
  message_id UNINDEXED,
  channel_id UNINDEXED,
  channel_type UNINDEXED,
  searchable_word,
  content_edit
);
DELETE FROM message_fts;
INSERT INTO message_fts(
  rowid,
  client_seq,
  message_id,
  channel_id,
  channel_type,
  searchable_word,
  content_edit
)
SELECT
  m.client_seq,
  m.client_seq,
  m.message_id,
  m.channel_id,
  m.channel_type,
  IFNULL(m.searchable_word, ''),
  IFNULL(me.content_edit, '')
FROM message AS m
LEFT JOIN message_extra AS me ON m.message_id = me.message_id
WHERE m.client_seq > 0
  AND (TRIM(IFNULL(m.searchable_word, '')) <> ''
       OR TRIM(IFNULL(me.content_edit, '')) <> '');
