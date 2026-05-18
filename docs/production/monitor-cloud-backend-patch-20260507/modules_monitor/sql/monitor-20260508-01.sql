-- +migrate Up

CREATE TABLE IF NOT EXISTS `monitor_credential` (
  `id` BIGINT NOT NULL PRIMARY KEY AUTO_INCREMENT,
  `credential_id` VARCHAR(80) NOT NULL DEFAULT '',
  `uid` VARCHAR(40) NOT NULL DEFAULT '',
  `platform` VARCHAR(32) NOT NULL DEFAULT 'feishu',
  `kind` VARCHAR(64) NOT NULL DEFAULT '',
  `display_name` VARCHAR(120) NOT NULL DEFAULT '',
  `app_id_ciphertext` TEXT NULL,
  `app_id_masked` VARCHAR(80) NOT NULL DEFAULT '',
  `app_secret_ciphertext` TEXT NULL,
  `webhook_url_ciphertext` TEXT NULL,
  `webhook_url_masked` VARCHAR(160) NOT NULL DEFAULT '',
  `secret_ciphertext` TEXT NULL,
  `status` VARCHAR(32) NOT NULL DEFAULT 'active',
  `last_checked_at` TIMESTAMP NULL DEFAULT NULL,
  `last_error` VARCHAR(255) NOT NULL DEFAULT '',
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `revoked_at` TIMESTAMP NULL DEFAULT NULL
);

CREATE UNIQUE INDEX `monitor_credential_credential_id_uidx` ON `monitor_credential` (`credential_id`);
CREATE INDEX `monitor_credential_uid_platform_status_idx` ON `monitor_credential` (`uid`, `platform`, `status`, `updated_at`);
CREATE INDEX `monitor_credential_uid_kind_idx` ON `monitor_credential` (`uid`, `kind`, `updated_at`);

CREATE TABLE IF NOT EXISTS `monitor_destination` (
  `id` BIGINT NOT NULL PRIMARY KEY AUTO_INCREMENT,
  `destination_id` VARCHAR(80) NOT NULL DEFAULT '',
  `uid` VARCHAR(40) NOT NULL DEFAULT '',
  `platform` VARCHAR(32) NOT NULL DEFAULT 'feishu',
  `destination_type` VARCHAR(64) NOT NULL DEFAULT '',
  `display_name` VARCHAR(120) NOT NULL DEFAULT '',
  `credential_id` VARCHAR(80) NOT NULL DEFAULT '',
  `chat_id` VARCHAR(120) NOT NULL DEFAULT '',
  `webhook_url_ciphertext` TEXT NULL,
  `webhook_url_masked` VARCHAR(160) NOT NULL DEFAULT '',
  `secret_ciphertext` TEXT NULL,
  `status` VARCHAR(32) NOT NULL DEFAULT 'active',
  `last_checked_at` TIMESTAMP NULL DEFAULT NULL,
  `last_error` VARCHAR(255) NOT NULL DEFAULT '',
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `revoked_at` TIMESTAMP NULL DEFAULT NULL
);

CREATE UNIQUE INDEX `monitor_destination_destination_id_uidx` ON `monitor_destination` (`destination_id`);
CREATE INDEX `monitor_destination_uid_platform_status_idx` ON `monitor_destination` (`uid`, `platform`, `status`, `updated_at`);
CREATE INDEX `monitor_destination_credential_idx` ON `monitor_destination` (`credential_id`, `updated_at`);
CREATE INDEX `monitor_destination_uid_chat_idx` ON `monitor_destination` (`uid`, `platform`, `destination_type`, `chat_id`);

ALTER TABLE `monitor_route`
  ADD COLUMN `destination_type` VARCHAR(64) NOT NULL DEFAULT 'wukong_im_group' AFTER `source_name`,
  ADD COLUMN `destination_id` VARCHAR(80) NOT NULL DEFAULT '' AFTER `destination_type`;

CREATE INDEX `monitor_route_destination_idx` ON `monitor_route` (`uid`, `destination_type`, `destination_id`);

-- +migrate Down

DROP INDEX `monitor_route_destination_idx` ON `monitor_route`;
ALTER TABLE `monitor_route`
  DROP COLUMN `destination_id`,
  DROP COLUMN `destination_type`;

DROP TABLE IF EXISTS `monitor_destination`;
DROP TABLE IF EXISTS `monitor_credential`;
