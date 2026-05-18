ALTER TABLE 'message' ADD COLUMN 'server_msg_id' TEXT;
UPDATE message
SET server_msg_id = message_id
WHERE (server_msg_id IS NULL OR TRIM(server_msg_id) = '')
  AND message_id IS NOT NULL
  AND TRIM(message_id) <> '';
UPDATE conversation
SET last_client_msg_no = (
  SELECT survivor.client_msg_no
  FROM message AS duplicate
  JOIN message AS survivor
    ON survivor.channel_id = duplicate.channel_id
   AND survivor.channel_type = duplicate.channel_type
   AND survivor.server_msg_id = duplicate.server_msg_id
   AND survivor.client_seq = (
     SELECT MIN(base.client_seq)
     FROM message AS base
     WHERE base.channel_id = duplicate.channel_id
       AND base.channel_type = duplicate.channel_type
       AND base.server_msg_id = duplicate.server_msg_id
       AND base.server_msg_id IS NOT NULL
       AND TRIM(base.server_msg_id) <> ''
   )
  WHERE duplicate.channel_id = conversation.channel_id
    AND duplicate.channel_type = conversation.channel_type
    AND duplicate.client_msg_no = conversation.last_client_msg_no
    AND duplicate.server_msg_id IS NOT NULL
    AND TRIM(duplicate.server_msg_id) <> ''
    AND duplicate.client_seq <> survivor.client_seq
  LIMIT 1
)
WHERE last_client_msg_no IS NOT NULL
  AND TRIM(last_client_msg_no) <> ''
  AND EXISTS (
    SELECT 1
    FROM message AS duplicate
    WHERE duplicate.channel_id = conversation.channel_id
      AND duplicate.channel_type = conversation.channel_type
      AND duplicate.client_msg_no = conversation.last_client_msg_no
      AND duplicate.server_msg_id IS NOT NULL
      AND TRIM(duplicate.server_msg_id) <> ''
      AND duplicate.client_seq <> (
        SELECT MIN(base.client_seq)
        FROM message AS base
        WHERE base.channel_id = duplicate.channel_id
          AND base.channel_type = duplicate.channel_type
          AND base.server_msg_id = duplicate.server_msg_id
          AND base.server_msg_id IS NOT NULL
          AND TRIM(base.server_msg_id) <> ''
      )
  );
DELETE FROM message
WHERE server_msg_id IS NOT NULL
  AND TRIM(server_msg_id) <> ''
  AND client_seq NOT IN (
    SELECT MIN(client_seq)
    FROM message
    WHERE server_msg_id IS NOT NULL AND TRIM(server_msg_id) <> ''
    GROUP BY channel_id, channel_type, server_msg_id
  );
CREATE UNIQUE INDEX IF NOT EXISTS idx_message_server_msg_id
ON message (channel_id, channel_type, server_msg_id)
WHERE server_msg_id IS NOT NULL AND server_msg_id <> '';
CREATE INDEX IF NOT EXISTS idx_message_conversation_sort
ON message (channel_id, channel_type, message_seq DESC, client_msg_no DESC);
