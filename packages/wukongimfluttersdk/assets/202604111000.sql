CREATE INDEX IF NOT EXISTS idx_message_channel_order_seq ON message (channel_id, channel_type, order_seq);
CREATE INDEX IF NOT EXISTS idx_message_channel_message_seq ON message (channel_id, channel_type, message_seq);
CREATE INDEX IF NOT EXISTS idx_message_channel_timestamp ON message (channel_id, channel_type, timestamp);