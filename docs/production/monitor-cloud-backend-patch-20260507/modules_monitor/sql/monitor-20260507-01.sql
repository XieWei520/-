-- +migrate Up

CREATE TABLE IF NOT EXISTS `monitor_route` (
  `id` BIGINT NOT NULL PRIMARY KEY AUTO_INCREMENT,
  `route_id` VARCHAR(80) NOT NULL DEFAULT '',
  `uid` VARCHAR(40) NOT NULL DEFAULT '',
  `platform` VARCHAR(32) NOT NULL DEFAULT 'feishu',
  `connector_type` VARCHAR(64) NOT NULL DEFAULT '',
  `route_type` VARCHAR(64) NOT NULL DEFAULT '',
  `source_name` VARCHAR(120) NOT NULL DEFAULT '',
  `destination_name` VARCHAR(120) NOT NULL DEFAULT '',
  `destination_no` VARCHAR(80) NOT NULL DEFAULT '',
  `agent_id` VARCHAR(80) NOT NULL DEFAULT '',
  `status` VARCHAR(32) NOT NULL DEFAULT 'running',
  `today_forwarded_count` INT NOT NULL DEFAULT 0,
  `last_forwarded_at` TIMESTAMP NULL DEFAULT NULL,
  `include_text` TINYINT(1) NOT NULL DEFAULT 1,
  `include_links` TINYINT(1) NOT NULL DEFAULT 1,
  `include_images` TINYINT(1) NOT NULL DEFAULT 0,
  `include_files` TINYINT(1) NOT NULL DEFAULT 0,
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `paused_at` TIMESTAMP NULL DEFAULT NULL,
  `error_message` VARCHAR(255) NOT NULL DEFAULT ''
);

CREATE UNIQUE INDEX `monitor_route_route_id_uidx` ON `monitor_route` (`route_id`);
CREATE INDEX `monitor_route_uid_platform_status_idx` ON `monitor_route` (`uid`, `platform`, `status`, `updated_at`);
CREATE INDEX `monitor_route_agent_idx` ON `monitor_route` (`agent_id`, `status`);

CREATE TABLE IF NOT EXISTS `monitor_agent_browser_status` (
  `id` BIGINT NOT NULL PRIMARY KEY AUTO_INCREMENT,
  `status_id` VARCHAR(80) NOT NULL DEFAULT '',
  `uid` VARCHAR(40) NOT NULL DEFAULT '',
  `agent_id` VARCHAR(80) NOT NULL DEFAULT '',
  `platform` VARCHAR(32) NOT NULL DEFAULT 'feishu',
  `browser` VARCHAR(32) NOT NULL DEFAULT 'chromium',
  `profile_mode` VARCHAR(32) NOT NULL DEFAULT 'isolated_persistent',
  `login_status` VARCHAR(32) NOT NULL DEFAULT 'unknown',
  `observed_at` TIMESTAMP NOT NULL,
  `error_message` VARCHAR(255) NOT NULL DEFAULT '',
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
);

CREATE UNIQUE INDEX `monitor_agent_browser_status_status_id_uidx` ON `monitor_agent_browser_status` (`status_id`);
CREATE INDEX `monitor_agent_browser_status_uid_platform_observed_idx` ON `monitor_agent_browser_status` (`uid`, `platform`, `observed_at`);
CREATE INDEX `monitor_agent_browser_status_agent_platform_idx` ON `monitor_agent_browser_status` (`agent_id`, `platform`, `observed_at`);

CREATE TABLE IF NOT EXISTS `monitor_observed_message` (
  `id` BIGINT NOT NULL PRIMARY KEY AUTO_INCREMENT,
  `message_id` VARCHAR(80) NOT NULL DEFAULT '',
  `uid` VARCHAR(40) NOT NULL DEFAULT '',
  `route_id` VARCHAR(80) NOT NULL DEFAULT '',
  `agent_id` VARCHAR(80) NOT NULL DEFAULT '',
  `source_platform` VARCHAR(32) NOT NULL DEFAULT 'feishu',
  `source_chat_name` VARCHAR(120) NOT NULL DEFAULT '',
  `source_message_id` VARCHAR(128) NOT NULL DEFAULT '',
  `message_type` VARCHAR(32) NOT NULL DEFAULT 'text',
  `content` TEXT NOT NULL,
  `source_created_at` TIMESTAMP NULL DEFAULT NULL,
  `observed_at` TIMESTAMP NOT NULL,
  `duplicate_of_message_id` VARCHAR(80) NOT NULL DEFAULT '',
  `forward_status` VARCHAR(32) NOT NULL DEFAULT 'pending',
  `forwarded_at` TIMESTAMP NULL DEFAULT NULL,
  `forward_error_message` VARCHAR(255) NOT NULL DEFAULT '',
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
);

CREATE UNIQUE INDEX `monitor_observed_message_message_id_uidx` ON `monitor_observed_message` (`message_id`);
CREATE UNIQUE INDEX `monitor_observed_message_route_source_uidx` ON `monitor_observed_message` (`route_id`, `source_message_id`);
CREATE INDEX `monitor_observed_message_uid_route_observed_idx` ON `monitor_observed_message` (`uid`, `route_id`, `observed_at`);
CREATE INDEX `monitor_observed_message_uid_forward_idx` ON `monitor_observed_message` (`uid`, `forward_status`, `created_at`);

-- +migrate Down

DROP TABLE IF EXISTS `monitor_observed_message`;
DROP TABLE IF EXISTS `monitor_agent_browser_status`;
DROP TABLE IF EXISTS `monitor_route`;
