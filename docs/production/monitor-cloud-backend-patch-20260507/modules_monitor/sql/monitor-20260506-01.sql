-- +migrate Up

CREATE TABLE IF NOT EXISTS `monitor_agent_pairing_code` (
  `id` BIGINT NOT NULL PRIMARY KEY AUTO_INCREMENT,
  `code` VARCHAR(32) NOT NULL DEFAULT '',
  `uid` VARCHAR(40) NOT NULL DEFAULT '',
  `device_name` VARCHAR(100) NOT NULL DEFAULT '',
  `platform` VARCHAR(32) NOT NULL DEFAULT 'windows',
  `expires_at` TIMESTAMP NOT NULL,
  `used_at` TIMESTAMP NULL DEFAULT NULL,
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
);

CREATE UNIQUE INDEX `monitor_pairing_code_code_uidx` ON `monitor_agent_pairing_code` (`code`);
CREATE INDEX `monitor_pairing_code_uid_created_idx` ON `monitor_agent_pairing_code` (`uid`, `created_at`);

CREATE TABLE IF NOT EXISTS `monitor_agent` (
  `id` BIGINT NOT NULL PRIMARY KEY AUTO_INCREMENT,
  `agent_id` VARCHAR(80) NOT NULL DEFAULT '',
  `uid` VARCHAR(40) NOT NULL DEFAULT '',
  `agent_token` VARCHAR(128) NOT NULL DEFAULT '',
  `device_name` VARCHAR(100) NOT NULL DEFAULT '',
  `platform` VARCHAR(32) NOT NULL DEFAULT 'windows',
  `version` VARCHAR(40) NOT NULL DEFAULT '',
  `status` VARCHAR(32) NOT NULL DEFAULT 'offline',
  `last_heartbeat_at` TIMESTAMP NULL DEFAULT NULL,
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `revoked_at` TIMESTAMP NULL DEFAULT NULL
);

CREATE UNIQUE INDEX `monitor_agent_agent_id_uidx` ON `monitor_agent` (`agent_id`);
CREATE UNIQUE INDEX `monitor_agent_token_uidx` ON `monitor_agent` (`agent_token`);
CREATE INDEX `monitor_agent_uid_status_idx` ON `monitor_agent` (`uid`, `status`, `updated_at`);

CREATE TABLE IF NOT EXISTS `monitor_event` (
  `id` BIGINT NOT NULL PRIMARY KEY AUTO_INCREMENT,
  `event_id` VARCHAR(80) NOT NULL DEFAULT '',
  `uid` VARCHAR(40) NOT NULL DEFAULT '',
  `platform` VARCHAR(32) NOT NULL DEFAULT 'feishu',
  `agent_id` VARCHAR(80) NOT NULL DEFAULT '',
  `route_id` VARCHAR(80) NOT NULL DEFAULT '',
  `type` VARCHAR(64) NOT NULL DEFAULT '',
  `message` VARCHAR(255) NOT NULL DEFAULT '',
  `metadata` TEXT NOT NULL,
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE UNIQUE INDEX `monitor_event_event_id_uidx` ON `monitor_event` (`event_id`);
CREATE INDEX `monitor_event_uid_platform_created_idx` ON `monitor_event` (`uid`, `platform`, `created_at`);

-- +migrate Down

DROP TABLE IF EXISTS `monitor_event`;
DROP TABLE IF EXISTS `monitor_agent`;
DROP TABLE IF EXISTS `monitor_agent_pairing_code`;
