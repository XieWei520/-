CREATE TABLE IF NOT EXISTS raw_events (
  event_id TEXT PRIMARY KEY,
  source_conversation_id TEXT NOT NULL,
  source_conversation_name TEXT NOT NULL,
  embedded_source_name TEXT NOT NULL,
  sender_name TEXT NOT NULL,
  observed_at TEXT NOT NULL,
  text TEXT NOT NULL,
  local_image_path TEXT NOT NULL,
  capture_source TEXT NOT NULL,
  content_hash TEXT NOT NULL,
  dedupe_key TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS forward_jobs (
  job_id TEXT PRIMARY KEY,
  event_id TEXT NOT NULL,
  status TEXT NOT NULL,
  attempts INTEGER NOT NULL,
  last_error TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS delivery_logs (
  log_id TEXT PRIMARY KEY,
  event_id TEXT NOT NULL,
  outcome TEXT NOT NULL,
  detail TEXT NOT NULL,
  created_at TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS conversation_trigger_snapshots (
  snapshot_id TEXT PRIMARY KEY,
  observed_at TEXT NOT NULL,
  readiness TEXT NOT NULL,
  conversation_count INTEGER NOT NULL,
  unread_count INTEGER NOT NULL,
  selected_conversation_name TEXT NOT NULL,
  first_unread_conversation_name TEXT NOT NULL,
  content_hash TEXT NOT NULL,
  summary TEXT NOT NULL
);
