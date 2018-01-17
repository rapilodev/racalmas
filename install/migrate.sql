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

