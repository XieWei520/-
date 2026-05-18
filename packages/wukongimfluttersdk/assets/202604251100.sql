CREATE INDEX IF NOT EXISTS idx_message_channel_seq
ON message (channel_id, channel_type, message_seq DESC);

CREATE INDEX IF NOT EXISTS idx_message_channel_order_seq
ON message (channel_id, channel_type, order_seq DESC);

CREATE INDEX IF NOT EXISTS idx_message_client_msg_no
ON message (client_msg_no);

CREATE INDEX IF NOT EXISTS idx_message_message_id
ON message (message_id);

CREATE INDEX IF NOT EXISTS idx_conversation_sort
ON conversation (is_deleted, last_msg_timestamp DESC);
