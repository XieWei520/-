-- +migrate Up

ALTER TABLE `monitor_route`
  ADD COLUMN `sender_display_name` VARCHAR(120) NOT NULL DEFAULT 'Feishu Monitor' AFTER `destination_no`,
  ADD COLUMN `sender_display_avatar` VARCHAR(512) NOT NULL DEFAULT '' AFTER `sender_display_name`;

-- +migrate Down

ALTER TABLE `monitor_route`
  DROP COLUMN `sender_display_avatar`,
  DROP COLUMN `sender_display_name`;