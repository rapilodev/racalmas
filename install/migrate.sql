ALTER TABLE `calcms_audio_recordings` 
  DROP COLUMN md5, 
  ADD COLUMN processed tinyint(1) NULL DEFAULT '0', 
  ADD COLUMN modified_at timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP, 
  ADD COLUMN mastered tinyint(1) NULL DEFAULT '0', 
  ADD COLUMN rmsLeft float NULL, 
  ADD COLUMN audioDuration float NULL DEFAULT '0' AFTER size, 
  ADD COLUMN rmsRight float NULL, 
  ADD COLUMN eventDuration int(11) NULL DEFAULT '0', 
  CHANGE COLUMN created_at created_at timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP, 
  CHANGE COLUMN size size bigint(20) unsigned NOT NULL DEFAULT '0' AFTER created_at;


ALTER TABLE `calcms_playout` 
  DROP COLUMN relpay_gain, 
  ADD INDEX modified_at (modified_at), 
  ADD COLUMN replay_gain float NULL AFTER rms_image, 
  ADD COLUMN modified_at datetime NULL, 
  ADD COLUMN updated_at datetime NULL DEFAULT CURRENT_TIMESTAMP;


ALTER TABLE `calcms_roles` 
  ADD COLUMN read_playout tinyint(1) unsigned NOT NULL AFTER delete_audio_recordings;


ALTER TABLE `calcms_series_events` 
  ADD INDEX pse (studio_id,project_id,event_id);


ALTER TABLE `calcms_series_schedule` 
  CHANGE COLUMN start_offset start_offset int(11) NULL DEFAULT '0', 
  CHANGE COLUMN nextDay nextDay int(11) NULL DEFAULT '0';

ALTER TABLE `calcms_audio_recordings` 
  CHANGE COLUMN modified_at modified_at timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP on update CURRENT_TIMESTAMP;


ALTER TABLE `calcms_event_history` 
  CHANGE COLUMN created_at created_at timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP;


ALTER TABLE `calcms_events` 
  CHANGE COLUMN created_at created_at timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP;


ALTER TABLE `calcms_images` 
  CHANGE COLUMN created_at created_at datetime NULL DEFAULT CURRENT_TIMESTAMP, 
  CHANGE COLUMN modified_at modified_at timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP on update CURRENT_TIMESTAMP;


ALTER TABLE `calcms_roles` 
  CHANGE COLUMN modified_at modified_at timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP on update CURRENT_TIMESTAMP, 
  CHANGE COLUMN created_at created_at timestamp NULL DEFAULT CURRENT_TIMESTAMP;


ALTER TABLE `calcms_series` 
  CHANGE COLUMN created_at created_at timestamp NULL DEFAULT CURRENT_TIMESTAMP, 
  CHANGE COLUMN modified_at modified_at timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP on update CURRENT_TIMESTAMP;


ALTER TABLE `calcms_studios` 
  CHANGE COLUMN created_at created_at timestamp NULL DEFAULT CURRENT_TIMESTAMP, 
  CHANGE COLUMN modified_at modified_at timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP on update CURRENT_TIMESTAMP;


ALTER TABLE `calcms_user_events` 
  CHANGE COLUMN modified_at modified_at timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP on update CURRENT_TIMESTAMP;


ALTER TABLE `calcms_user_roles` 
  CHANGE COLUMN created_at created_at timestamp NULL DEFAULT CURRENT_TIMESTAMP, 
  CHANGE COLUMN modified_at modified_at timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP on update CURRENT_TIMESTAMP;


ALTER TABLE `calcms_user_series` 
  CHANGE COLUMN modified_at modified_at timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP on update CURRENT_TIMESTAMP;


ALTER TABLE `calcms_users` 
  CHANGE COLUMN created_at created_at timestamp NULL DEFAULT CURRENT_TIMESTAMP, 
  CHANGE COLUMN modified_at modified_at timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP on update CURRENT_TIMESTAMP;

ALTER TABLE `calcms_audio_recordings` 
  CHANGE COLUMN processed processed tinyint(1) NOT NULL DEFAULT '0', 
  CHANGE COLUMN modified_at modified_at timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP on update CURRENT_TIMESTAMP, 
  CHANGE COLUMN mastered mastered tinyint(1) NOT NULL DEFAULT '0', 
  CHANGE COLUMN eventDuration eventDuration int(11) NOT NULL DEFAULT '0', 
  CHANGE COLUMN rmsLeft rmsLeft float NOT NULL, 
  CHANGE COLUMN rmsRight rmsRight float NOT NULL, 
  CHANGE COLUMN audioDuration audioDuration float NOT NULL DEFAULT '0';

ALTER TABLE `calcms_events` 
  ADD COLUMN draft tinyint(1) unsigned NOT NULL DEFAULT '0' AFTER recurrence_count;

ALTER TABLE `calcms_users` 
  CHANGE COLUMN email email varchar(300) NOT NULL;
  
ALTER TABLE `calcms_events` ADD COLUMN `series_image` VARCHAR(200)  DEFAULT NULL AFTER `draft`;

ALTER TABLE `calcms_events` ADD COLUMN `image_label` VARCHAR(200)  DEFAULT NULL AFTER `series_image`,
 ADD COLUMN `series_image_label` VARCHAR(200)  DEFAULT NULL AFTER `image_label`;

ALTER TABLE `calcms_playout` 
  CHANGE COLUMN `modified_at` `modified_at` datetime  DEFAULT CURRENT_TIMESTAMP;

ALTER TABLE `calcms_images` 
  ADD COLUMN public tinyint(1) unsigned NULL DEFAULT '0', 
  ADD COLUMN licence varchar(300) NULL AFTER project_id;

ALTER TABLE `calcms_event_history` 
  CHANGE COLUMN draft draft tinyint(1) unsigned NOT NULL DEFAULT '0', 
  ADD COLUMN series_image_label varchar(200) NULL, 
  ADD COLUMN series_image varchar(200) NULL AFTER draft, 
  ADD COLUMN recurrence_count int(10) unsigned NOT NULL DEFAULT '0' AFTER project_id, 
  ADD COLUMN image_label varchar(200) NULL;

-- 2018-06-18 refactor columns

ALTER TABLE `calcms_audio_recordings` 
CHANGE COLUMN `created_by` `created_by` VARCHAR(100) NOT NULL AFTER `processed`,
CHANGE COLUMN `created_at` `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP AFTER `created_by`;

ALTER TABLE `calcms_events` 
CHANGE COLUMN `program` `program` VARCHAR(40) NULL DEFAULT NULL AFTER `end`,
CHANGE COLUMN `series_name` `series_name` VARCHAR(40) NULL DEFAULT NULL AFTER `program`,
CHANGE COLUMN `episode` `episode` INT(10) UNSIGNED NULL DEFAULT NULL AFTER `title`,
CHANGE COLUMN `html_content` `html_content` LONGTEXT NULL DEFAULT NULL AFTER `content`,
CHANGE COLUMN `end_date` `end_date` DATE NOT NULL AFTER `start_date`,
CHANGE COLUMN `archive_url` `archive_url` VARCHAR(300) NULL DEFAULT NULL AFTER `podcast_url`,
CHANGE COLUMN `html_topic` `html_topic` LONGTEXT NULL DEFAULT NULL AFTER `user_excerpt`,
CHANGE COLUMN `draft` `draft` TINYINT(1) UNSIGNED NOT NULL DEFAULT '0' AFTER `archived`,
CHANGE COLUMN `recurrence` `recurrence` INT(11) NULL DEFAULT '0' AFTER `recurrence_count`,
CHANGE COLUMN `image` `image` VARCHAR(200) NULL DEFAULT NULL AFTER `recurrence`,
CHANGE COLUMN `image_label` `image_label` VARCHAR(200) NULL DEFAULT NULL AFTER `image`,
CHANGE COLUMN `created_at` `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP AFTER `series_image_label`,
CHANGE COLUMN `modified_by` `modified_by` VARCHAR(20) NULL DEFAULT NULL AFTER `created_at`,
CHANGE COLUMN `modified_at` `modified_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP AFTER `modified_by`,
CHANGE COLUMN `reference` `reference` VARCHAR(300) NULL DEFAULT NULL AFTER `modified_at`,
CHANGE COLUMN `disable_event_sync` `disable_event_sync` TINYINT(1) UNSIGNED NULL DEFAULT NULL AFTER `reference`;

ALTER TABLE `calcms_images` 
CHANGE COLUMN `project_id` `project_id` INT(10) UNSIGNED NOT NULL AFTER `id`,
CHANGE COLUMN `studio_id` `studio_id` INT(10) UNSIGNED NULL DEFAULT NULL AFTER `project_id`,
CHANGE COLUMN `filename` `filename` VARCHAR(64) NOT NULL AFTER `studio_id`,
CHANGE COLUMN `name` `name` VARCHAR(300) NULL DEFAULT NULL AFTER `filename`,
CHANGE COLUMN `licence` `licence` VARCHAR(300) NULL DEFAULT NULL AFTER `description`,
CHANGE COLUMN `public` `public` TINYINT(1) UNSIGNED NULL DEFAULT '0' AFTER `licence`,
CHANGE COLUMN `created_at` `created_at` DATETIME NULL DEFAULT CURRENT_TIMESTAMP AFTER `modified_by`;

ALTER TABLE `calcms_roles` 
CHANGE COLUMN `project_id` `project_id` TINYINT(1) UNSIGNED NOT NULL AFTER `id`,
CHANGE COLUMN `studio_id` `studio_id` INT(10) UNSIGNED NOT NULL AFTER `project_id`,
CHANGE COLUMN `level` `level` TINYINT(3) UNSIGNED NOT NULL DEFAULT '0' AFTER `role`,
CHANGE COLUMN `read_role` `read_role` TINYINT(1) UNSIGNED NULL DEFAULT NULL AFTER `level`,
CHANGE COLUMN `update_role` `update_role` TINYINT(1) UNSIGNED NULL DEFAULT NULL AFTER `read_role`,
CHANGE COLUMN `read_user_role` `read_user_role` TINYINT(1) UNSIGNED NULL DEFAULT NULL AFTER `update_role`,
CHANGE COLUMN `delete_user` `delete_user` TINYINT(1) UNSIGNED NULL DEFAULT NULL AFTER `update_user`,
CHANGE COLUMN `update_user_role` `update_user_role` TINYINT(1) UNSIGNED NULL DEFAULT NULL AFTER `delete_user`,
CHANGE COLUMN `create_project` `create_project` TINYINT(1) UNSIGNED NOT NULL AFTER `disable_user`,
CHANGE COLUMN `read_project` `read_project` TINYINT(1) UNSIGNED NOT NULL AFTER `create_project`,
CHANGE COLUMN `update_project` `update_project` TINYINT(1) UNSIGNED NOT NULL AFTER `read_project`,
CHANGE COLUMN `delete_project` `delete_project` TINYINT(1) UNSIGNED NOT NULL AFTER `update_project`,
CHANGE COLUMN `assign_project_studio` `assign_project_studio` TINYINT(1) UNSIGNED NOT NULL AFTER `delete_project`,
CHANGE COLUMN `create_studio` `create_studio` TINYINT(1) UNSIGNED NOT NULL AFTER `assign_project_studio`,
CHANGE COLUMN `read_studio` `read_studio` TINYINT(1) UNSIGNED NOT NULL AFTER `create_studio`,
CHANGE COLUMN `delete_studio` `delete_studio` TINYINT(1) UNSIGNED NOT NULL AFTER `update_studio`,
CHANGE COLUMN `read_studio_timeslot_schedule` `read_studio_timeslot_schedule` TINYINT(1) UNSIGNED NOT NULL AFTER `delete_studio`,
CHANGE COLUMN `update_studio_timeslot_schedule` `update_studio_timeslot_schedule` TINYINT(1) UNSIGNED NOT NULL AFTER `read_studio_timeslot_schedule`,
CHANGE COLUMN `update_series_template` `update_series_template` TINYINT(1) UNSIGNED NOT NULL AFTER `delete_series`,
CHANGE COLUMN `assign_series_member` `assign_series_member` TINYINT(1) UNSIGNED NOT NULL AFTER `update_series_template`,
CHANGE COLUMN `remove_series_member` `remove_series_member` TINYINT(1) UNSIGNED NOT NULL AFTER `assign_series_member`,
CHANGE COLUMN `scan_series_events` `scan_series_events` TINYINT(1) UNSIGNED NOT NULL AFTER `remove_series_member`,
CHANGE COLUMN `assign_series_events` `assign_series_events` TINYINT(1) UNSIGNED NOT NULL AFTER `scan_series_events`,
CHANGE COLUMN `read_schedule` `read_schedule` TINYINT(1) UNSIGNED NOT NULL AFTER `assign_series_events`,
CHANGE COLUMN `update_schedule` `update_schedule` TINYINT(1) UNSIGNED NOT NULL AFTER `read_schedule`,
CHANGE COLUMN `delete_schedule` `delete_schedule` TINYINT(1) UNSIGNED NOT NULL AFTER `update_schedule`,
CHANGE COLUMN `create_event_from_schedule` `create_event_from_schedule` TINYINT(1) UNSIGNED NOT NULL AFTER `create_event`,
CHANGE COLUMN `create_event_of_series` `create_event_of_series` TINYINT(1) UNSIGNED NOT NULL AFTER `create_event_from_schedule`,
CHANGE COLUMN `update_event_after_week` `update_event_after_week` TINYINT(1) UNSIGNED NOT NULL AFTER `update_event_time`,
CHANGE COLUMN `update_event_field_title` `update_event_field_title` TINYINT(1) UNSIGNED NOT NULL AFTER `update_event_after_week`,
CHANGE COLUMN `update_event_field_title_extension` `update_event_field_title_extension` TINYINT(1) UNSIGNED NOT NULL AFTER `update_event_field_title`,
CHANGE COLUMN `update_event_field_excerpt` `update_event_field_excerpt` TINYINT(1) UNSIGNED NOT NULL AFTER `update_event_field_title_extension`,
CHANGE COLUMN `update_event_field_description` `update_event_field_description` TINYINT(1) UNSIGNED NOT NULL AFTER `update_event_field_content`,
CHANGE COLUMN `update_event_field_topic` `update_event_field_topic` TINYINT(1) UNSIGNED NOT NULL AFTER `update_event_field_description`,
CHANGE COLUMN `update_event_field_episode` `update_event_field_episode` TINYINT(1) UNSIGNED NOT NULL AFTER `update_event_field_topic`,
CHANGE COLUMN `update_event_field_excerpt_extension` `update_event_field_excerpt_extension` TINYINT(1) UNSIGNED NOT NULL AFTER `update_event_field_episode`,
CHANGE COLUMN `update_event_field_image` `update_event_field_image` TINYINT(1) UNSIGNED NOT NULL AFTER `update_event_field_excerpt_extension`,
CHANGE COLUMN `update_event_field_podcast_url` `update_event_field_podcast_url` TINYINT(1) UNSIGNED NOT NULL AFTER `update_event_field_image`,
CHANGE COLUMN `update_event_field_archive_url` `update_event_field_archive_url` TINYINT(1) UNSIGNED NOT NULL AFTER `update_event_field_podcast_url`,
CHANGE COLUMN `update_event_status_draft` `update_event_status_draft` TINYINT(1) UNSIGNED NOT NULL AFTER `update_event_status_rerun`,
CHANGE COLUMN `update_event_status_live` `update_event_status_live` TINYINT(1) UNSIGNED NOT NULL AFTER `update_event_status_draft`,
CHANGE COLUMN `update_event_status_playout` `update_event_status_playout` TINYINT(1) UNSIGNED NOT NULL AFTER `update_event_status_live`,
CHANGE COLUMN `update_event_status_archived` `update_event_status_archived` TINYINT(1) UNSIGNED NOT NULL AFTER `update_event_status_playout`,
CHANGE COLUMN `create_image` `create_image` TINYINT(1) UNSIGNED NOT NULL AFTER `update_event_status_archived`,
CHANGE COLUMN `update_image_own` `update_image_own` TINYINT(1) UNSIGNED NOT NULL AFTER `create_image`,
CHANGE COLUMN `created_at` `created_at` TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP AFTER `read_playout`,
CHANGE COLUMN `create_download` `create_download` TINYINT(1) UNSIGNED NOT NULL AFTER `created_at`,
CHANGE COLUMN `modified_at` `modified_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP AFTER `create_download`;

ALTER TABLE `calcms_series_dates` 
CHANGE COLUMN `project_id` `project_id` INT(10) UNSIGNED NOT NULL AFTER `id`,
CHANGE COLUMN `studio_id` `studio_id` INT(10) UNSIGNED NOT NULL AFTER `project_id`;

ALTER TABLE `calcms_series_events` 
CHANGE COLUMN `project_id` `project_id` INT(10) UNSIGNED NOT NULL FIRST,
CHANGE COLUMN `studio_id` `studio_id` INT(12) UNSIGNED NOT NULL AFTER `project_id`;

ALTER TABLE `calcms_series_schedule` 
CHANGE COLUMN `project_id` `project_id` INT(10) UNSIGNED NOT NULL DEFAULT '1' AFTER `id`,
CHANGE COLUMN `studio_id` `studio_id` INT(10) UNSIGNED NULL DEFAULT NULL AFTER `project_id`;

ALTER TABLE `calcms_studios` 
CHANGE COLUMN `image` `image` VARCHAR(200) NOT NULL AFTER `stream`;

ALTER TABLE `calcms_studio_timeslot_dates` 
CHANGE COLUMN `project_id` `project_id` INT(10) UNSIGNED NOT NULL FIRST,
CHANGE COLUMN `schedule_id` `schedule_id` INT(10) UNSIGNED NOT NULL AFTER `studio_id`,
DROP PRIMARY KEY,
ADD PRIMARY KEY USING BTREE (`project_id`, `studio_id`, `start`, `end`);

ALTER TABLE `calcms_studio_timeslot_schedule` 
CHANGE COLUMN `project_id` `project_id` INT(10) UNSIGNED NOT NULL AFTER `id`;

ALTER TABLE `calcms_user_events` 
CHANGE COLUMN `modified_by` `modified_by` TIMESTAMP NOT NULL DEFAULT '0000-00-00 00:00:00' AFTER `location`,
CHANGE COLUMN `modified_at` `modified_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP AFTER `modified_by`;

ALTER TABLE `calcms_user_roles` 
CHANGE COLUMN `project_id` `project_id` INT(10) UNSIGNED NOT NULL AFTER `id`,
CHANGE COLUMN `studio_id` `studio_id` INT(10) UNSIGNED NOT NULL DEFAULT '0' AFTER `project_id`;

ALTER TABLE `calcms_users` 
CHANGE COLUMN `email` `email` VARCHAR(300) NOT NULL AFTER `full_name`,
CHANGE COLUMN `pass` `pass` VARCHAR(100) NOT NULL AFTER `email`,
CHANGE COLUMN `created_at` `created_at` TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP AFTER `created_by`,
CHANGE COLUMN `modified_at` `modified_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP AFTER `created_at`;

ALTER TABLE `calcms_user_series` 
CHANGE COLUMN `project_id` `project_id` INT(10) UNSIGNED NOT NULL AFTER `id`,
CHANGE COLUMN `studio_id` `studio_id` INT(10) UNSIGNED NOT NULL AFTER `project_id`;

ALTER TABLE `calcms_user_stats` 
ADD COLUMN `upload_file` INT(10) UNSIGNED NULL DEFAULT 0 AFTER `delete_series`,
ADD COLUMN `download_file` INT(10) UNSIGNED NULL DEFAULT 0 AFTER `upload_file`;
 
ALTER TABLE `calcms_user_settings` 
ADD COLUMN `project_id` INT(10) UNSIGNED NULL AFTER `calendar_fontsize`,
ADD COLUMN `studio_id` INT(10) UNSIGNED NULL AFTER `project_id`;

ALTER TABLE `calcms_series` 
ADD COLUMN `predecessor_id` INT(10) NULL AFTER `has_single_events`;

CREATE TABLE `calcms_user_default_studios` (
  `id` INT(11) NOT NULL AUTO_INCREMENT,
  `user` VARCHAR(50) NOT NULL,
  `project_id` INT(11) NOT NULL,
  `studio_id` INT(11) NOT NULL,
  PRIMARY KEY (`id`),
  INDEX `user` (`user` ASC));


ALTER TABLE `calcms_series` 
ADD COLUMN `content_format` VARCHAR(45) NULL AFTER `predecessor_id`;

ALTER TABLE `calcms_events` 
ADD COLUMN `content_format` VARCHAR(45) NULL DEFAULT NULL AFTER `disable_event_sync`;

ALTER TABLE `calcms_roles` 
ADD COLUMN `update_event_field_content_format` TINYINT(1) UNSIGNED NOT NULL AFTER `modified_at`;

ALTER TABLE `calcms_events` 
ADD COLUMN `listen_key` VARCHAR(100) NULL;

ALTER TABLE `calcms_audio_recordings`
ADD COLUMN `active` TINYINT(1) NOT NULL DEFAULT 0 AFTER `event_id`;

ALTER TABLE `calcms_audio_recordings`
ADD INDEX `active_index` (`active`);

ALTER TABLE `calcms_events`
DROP COLUMN `category_count`,
DROP COLUMN `category`,
DROP INDEX `category` ;

ALTER TABLE `calcms_event_history`
DROP COLUMN `category_count`,
DROP COLUMN `category`,
DROP INDEX `category` ;

ALTER TABLE calcms_user_series DROP COLUMN active;

CREATE TABLE `calcms_help_texts` (
  `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `project_id` INT UNSIGNED NOT NULL,
  `studio_id` INT UNSIGNED NOT NULL,
  `lang` VARCHAR(5) NOT NULL,
  `table` VARCHAR(45) NOT NULL,
  `column` VARCHAR(45) NOT NULL,
  `text` TEXT(500) NOT NULL,
  PRIMARY KEY (`id`));

ALTER TABLE `calcms_roles` ADD COLUMN `edit_help_texts` INT(1) UNSIGNED NOT NULL;

-- admin roles
ALTER TABLE `calcms_roles` ADD COLUMN `admin` INT(1) UNSIGNED NOT NULL DEFAULT 0 AFTER `level`;
update calcms_roles set admin=1 where role = 'Admin';

ALTER TABLE calcms_studios DROP COLUMN google_calendar;

ALTER TABLE `calcms`.`calcms_users`
CHANGE COLUMN `name` `name` VARCHAR(100) NOT NULL ,
CHANGE COLUMN `full_name` `full_name` VARCHAR(100) NULL DEFAULT NULL ,
CHANGE COLUMN `created_by` `created_by` VARCHAR(100) NULL DEFAULT NULL ;

ALTER TABLE `calcms`.`calcms_user_sessions`
CHANGE COLUMN `user` `user` VARCHAR(100) NOT NULL ;

ALTER TABLE `calcms`.`calcms_user_settings`
CHANGE COLUMN `user` `user` VARCHAR(100) CHARACTER SET 'latin1' NOT NULL ;

ALTER TABLE `calcms`.`calcms_user_stats`
CHANGE COLUMN `user` `user` VARCHAR(100) NOT NULL ;

ALTER TABLE `calcms`.`calcms_user_default_studios`
CHANGE COLUMN `user` `user` VARCHAR(100) NOT NULL ;

ALTER TABLE `calcms`.`calcms_user_day_start`
CHANGE COLUMN `user` `user` VARCHAR(100) NOT NULL ;

ALTER TABLE `calcms`.`calcms_images`
CHANGE COLUMN `created_by` `created_by` VARCHAR(100) NULL DEFAULT NULL ,
CHANGE COLUMN `modified_by` `modified_by` VARCHAR(100) NULL DEFAULT NULL ;

ALTER TABLE `calcms`.`calcms_events`
CHANGE COLUMN `modified_by` `modified_by` VARCHAR(100) NULL DEFAULT NULL ;

ALTER TABLE `calcms`.`calcms_event_history`
CHANGE COLUMN `modified_by` `modified_by` VARCHAR(100) NULL DEFAULT NULL ;

ALTER TABLE `calcms`.`calcms_comments`
CHANGE COLUMN `author` `author` VARCHAR(100) NULL DEFAULT NULL ,
CHANGE COLUMN `email` `email` VARCHAR(100) NULL DEFAULT NULL ;

ALTER TABLE `calcms`.`calcms_user_selected_events`
CHANGE COLUMN `user` `user` VARCHAR(100) NOT NULL ;

-- remove dirs from images
update calcms_events set image = replace(image , '/agenda_files/media/images/', '') where image like '%/agenda_files/media/images/%';
update calcms_events set image = replace(image , '/agenda_files/media/icons/', '')  where image like '%/agenda_files/media/icons/%';
update calcms_events set image = replace(image , '/agenda_files/media/thumbs/', '') where image like '%/agenda_files/media/thumbs/%';

update calcms_series set image = replace(image , '/agenda_files/media/images/', '') where image like '%/agenda_files/media/images/%';
update calcms_series set image = replace(image , '/agenda_files/media/icons/', '')  where image like '%/agenda_files/media/icons/%';
update calcms_series set image = replace(image , '/agenda_files/media/thumbs/', '') where image like '%/agenda_files/media/thumbs/%';

-- add day of month to studio schedules
ALTER TABLE `calcms`.`calcms_studio_timeslot_schedule`
ADD COLUMN `period_type` VARCHAR(45) NOT NULL AFTER `end_date`,
ADD COLUMN `weekday` INT UNSIGNED NULL AFTER `period_type`,
ADD COLUMN `week_of_month` INT UNSIGNED NULL AFTER `weekday`,
ADD COLUMN `month` INT UNSIGNED NULL AFTER `week_of_month`,
CHANGE COLUMN `frequency` `frequency` INT UNSIGNED NULL ;

update `calcms_studio_timeslot_schedule` set period_type = 'days' where period_type = '';