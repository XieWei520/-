-- +migrate Up

ALTER TABLE `monitor_observed_message`
  ADD COLUMN `metadata` TEXT NULL AFTER `content`,
  ADD COLUMN `attachments` TEXT NULL AFTER `metadata`;

-- +migrate Down

ALTER TABLE `monitor_observed_message`
  DROP COLUMN `attachments`,
  DROP COLUMN `metadata`;
