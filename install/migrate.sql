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
  
