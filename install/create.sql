-- MySQL dump 10.13  Distrib 5.7.32, for Linux (x86_64)
--
-- Host: localhost    Database: calcms
-- ------------------------------------------------------
-- Server version	5.7.32-0ubuntu0.16.04.1

/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET @OLD_CHARACTER_SET_RESULTS=@@CHARACTER_SET_RESULTS */;
/*!40101 SET @OLD_COLLATION_CONNECTION=@@COLLATION_CONNECTION */;
/*!40101 SET NAMES utf8 */;
/*!40103 SET @OLD_TIME_ZONE=@@TIME_ZONE */;
/*!40103 SET TIME_ZONE='+00:00' */;
/*!40014 SET @OLD_UNIQUE_CHECKS=@@UNIQUE_CHECKS, UNIQUE_CHECKS=0 */;
/*!40014 SET @OLD_FOREIGN_KEY_CHECKS=@@FOREIGN_KEY_CHECKS, FOREIGN_KEY_CHECKS=0 */;
/*!40101 SET @OLD_SQL_MODE=@@SQL_MODE, SQL_MODE='NO_AUTO_VALUE_ON_ZERO' */;
/*!40111 SET @OLD_SQL_NOTES=@@SQL_NOTES, SQL_NOTES=0 */;

--
-- Table structure for table `calcms_audio_recordings`
--

DROP TABLE IF EXISTS `calcms_audio_recordings`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `calcms_audio_recordings` (
  `id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `project_id` int(11) NOT NULL,
  `studio_id` int(11) NOT NULL,
  `event_id` int(11) NOT NULL,
  `active` tinyint(1) NOT NULL DEFAULT '0',
  `path` varchar(300) NOT NULL,
  `size` bigint(20) unsigned NOT NULL DEFAULT '0',
  `audioDuration` float NOT NULL DEFAULT '0',
  `eventDuration` int(11) NOT NULL DEFAULT '0',
  `rmsLeft` float NOT NULL,
  `rmsRight` float NOT NULL,
  `mastered` tinyint(1) NOT NULL DEFAULT '0',
  `processed` tinyint(1) NOT NULL DEFAULT '0',
  `created_by` varchar(100) NOT NULL,
  `created_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `modified_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `project_index` (`project_id`),
  KEY `studio_index` (`studio_id`),
  KEY `event_index` (`event_id`),
  KEY `created_at_index` (`created_at`),
  KEY `active_index` (`active`)
) ENGINE=MyISAM AUTO_INCREMENT=2364 DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `calcms_audio_recordings`
--

LOCK TABLES `calcms_audio_recordings` WRITE;
/*!40000 ALTER TABLE `calcms_audio_recordings` DISABLE KEYS */;
/*!40000 ALTER TABLE `calcms_audio_recordings` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `calcms_categories`
--

DROP TABLE IF EXISTS `calcms_categories`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `calcms_categories` (
  `id` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
  `name` varchar(256) DEFAULT NULL,
  `event_id` varchar(256) CHARACTER SET latin1 NOT NULL,
  `project` varchar(64) DEFAULT NULL,
  KEY `id` (`id`),
  KEY `event_id` (`event_id`),
  KEY `name` (`name`),
  KEY `project` (`project`)
) ENGINE=MyISAM AUTO_INCREMENT=12646 DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `calcms_categories`
--

LOCK TABLES `calcms_categories` WRITE;
/*!40000 ALTER TABLE `calcms_categories` DISABLE KEYS */;
/*!40000 ALTER TABLE `calcms_categories` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `calcms_comments`
--

DROP TABLE IF EXISTS `calcms_comments`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `calcms_comments` (
  `id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `event_start` datetime DEFAULT NULL,
  `event_id` int(10) unsigned DEFAULT NULL,
  `content` text,
  `ip` varchar(22) DEFAULT NULL,
  `author` varchar(40) DEFAULT NULL,
  `email` varchar(40) DEFAULT NULL,
  `lock_status` varchar(16) NOT NULL DEFAULT 'show',
  `created_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `title` varchar(80) DEFAULT NULL,
  `parent_id` int(10) unsigned DEFAULT NULL,
  `level` int(10) unsigned DEFAULT NULL,
  `news_status` varchar(16) NOT NULL DEFAULT 'unread',
  `project` varchar(64) DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `event_start` (`event_start`),
  KEY `event_id` (`event_id`),
  KEY `status` (`lock_status`),
  KEY `parent_id` (`parent_id`),
  KEY `level` (`level`),
  KEY `created_at` (`created_at`),
  KEY `project` (`project`)
) ENGINE=MyISAM AUTO_INCREMENT=5485 DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `calcms_comments`
--

LOCK TABLES `calcms_comments` WRITE;
/*!40000 ALTER TABLE `calcms_comments` DISABLE KEYS */;
/*!40000 ALTER TABLE `calcms_comments` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `calcms_event_history`
--

DROP TABLE IF EXISTS `calcms_event_history`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `calcms_event_history` (
  `id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `event_id` int(10) unsigned NOT NULL,
  `start` datetime DEFAULT NULL,
  `end` datetime DEFAULT NULL,
  `reference` varchar(300) DEFAULT NULL,
  `title` varchar(200) DEFAULT NULL,
  `excerpt` longtext,
  `content` longtext,
  `modified_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `created_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `rating` int(11) DEFAULT NULL,
  `status` varchar(40) DEFAULT NULL,
  `visibility` varchar(40) DEFAULT NULL,
  `responsible` varchar(40) DEFAULT NULL,
  `start_date` date NOT NULL,
  `time_of_day` varchar(40) NOT NULL,
  `end_date` date NOT NULL,
  `program` varchar(40) DEFAULT NULL,
  `series_name` varchar(40) DEFAULT NULL,
  `comment_count` int(10) unsigned NOT NULL DEFAULT '0',
  `tag_count` int(10) unsigned NOT NULL DEFAULT '0',
  `image` varchar(200) DEFAULT NULL,
  `podcast_url` varchar(300) DEFAULT NULL,
  `media_url` varchar(300) DEFAULT NULL,
  `project` varchar(64) DEFAULT NULL,
  `recurrence` int(11) NOT NULL DEFAULT '0',
  `location` varchar(100) DEFAULT NULL,
  `user_title` varchar(200) DEFAULT NULL,
  `user_excerpt` longtext,
  `topic` longtext,
  `published` tinyint(1) unsigned DEFAULT NULL,
  `playout` tinyint(1) unsigned DEFAULT NULL,
  `archived` tinyint(1) unsigned DEFAULT NULL,
  `episode` int(10) unsigned DEFAULT NULL,
  `rerun` int(10) unsigned DEFAULT NULL,
  `disable_event_sync` tinyint(1) unsigned DEFAULT NULL,
  `live` tinyint(1) unsigned DEFAULT NULL,
  `modified_by` varchar(20) DEFAULT NULL,
  `archive_url` varchar(300) DEFAULT NULL,
  `studio_id` int(10) unsigned DEFAULT NULL,
  `series_id` int(10) unsigned DEFAULT NULL,
  `deleted` tinyint(1) unsigned DEFAULT '0',
  `project_id` int(10) unsigned NOT NULL,
  `draft` tinyint(3) unsigned NOT NULL DEFAULT '0',
  PRIMARY KEY (`id`),
  KEY `end` (`end`),
  KEY `start` (`start`),
  KEY `start_date` (`start_date`),
  KEY `status` (`status`),
  KEY `modified_at` (`modified_at`),
  KEY `time_of_day` (`time_of_day`),
  KEY `end_date` (`end_date`),
  KEY `reference` (`reference`),
  KEY `series_name` (`series_name`),
  KEY `program` (`program`),
  KEY `podcast_url` (`podcast_url`),
  KEY `media_url` (`media_url`),
  KEY `project` (`project`),
  KEY `recurrence` (`recurrence`),
  KEY `location` (`location`),
  KEY `published` (`published`),
  KEY `preproduced` (`playout`),
  KEY `archived` (`archived`),
  KEY `project_id` (`project_id`),
  KEY `draft` (`draft`)
) ENGINE=MyISAM AUTO_INCREMENT=101492 DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `calcms_event_history`
--

LOCK TABLES `calcms_event_history` WRITE;
/*!40000 ALTER TABLE `calcms_event_history` DISABLE KEYS */;
/*!40000 ALTER TABLE `calcms_event_history` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `calcms_events`
--

DROP TABLE IF EXISTS `calcms_events`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `calcms_events` (
  `id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `start` datetime NOT NULL,
  `end` datetime NOT NULL,
  `program` varchar(40) DEFAULT NULL,
  `series_name` varchar(40) DEFAULT NULL,
  `title` varchar(200) DEFAULT NULL,
  `episode` int(10) unsigned DEFAULT NULL,
  `excerpt` longtext,
  `content` longtext,
  `html_content` longtext,
  `rating` int(11) DEFAULT NULL,
  `status` varchar(40) DEFAULT NULL,
  `visibility` varchar(40) DEFAULT NULL,
  `responsible` varchar(40) DEFAULT NULL,
  `start_date` date NOT NULL,
  `end_date` date NOT NULL,
  `time_of_day` varchar(40) DEFAULT NULL,
  `comment_count` int(10) unsigned DEFAULT '0',
  `tag_count` int(10) unsigned DEFAULT '0',
  `podcast_url` varchar(300) DEFAULT NULL,
  `archive_url` varchar(300) DEFAULT NULL,
  `media_url` varchar(300) DEFAULT NULL,
  `project` varchar(64) DEFAULT NULL,
  `location` varchar(100) DEFAULT NULL,
  `user_title` varchar(200) DEFAULT NULL,
  `user_excerpt` longtext,
  `html_topic` longtext,
  `topic` longtext,
  `published` tinyint(1) unsigned DEFAULT NULL,
  `playout` tinyint(1) unsigned DEFAULT NULL,
  `archived` tinyint(1) unsigned DEFAULT NULL,
  `draft` tinyint(1) unsigned NOT NULL DEFAULT '0',
  `rerun` int(10) unsigned DEFAULT NULL,
  `live` tinyint(1) unsigned DEFAULT NULL,
  `recurrence_count` int(10) unsigned NOT NULL DEFAULT '0',
  `recurrence` int(11) DEFAULT '0',
  `image` varchar(200) DEFAULT NULL,
  `image_label` varchar(200) DEFAULT NULL,
  `series_image` varchar(200) DEFAULT NULL,
  `series_image_label` varchar(200) DEFAULT NULL,
  `created_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `modified_by` varchar(20) DEFAULT NULL,
  `modified_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `reference` varchar(300) DEFAULT NULL,
  `disable_event_sync` tinyint(1) unsigned DEFAULT NULL,
  `content_format` varchar(45) DEFAULT NULL,
  `listen_key` varchar(100) DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `end` (`end`),
  KEY `start` (`start`),
  KEY `start_date` (`start_date`),
  KEY `status` (`status`),
  KEY `modified_at` (`modified_at`),
  KEY `time_of_day` (`time_of_day`),
  KEY `end_date` (`end_date`),
  KEY `reference` (`reference`),
  KEY `series_name` (`series_name`),
  KEY `program` (`program`),
  KEY `podcast_url` (`podcast_url`),
  KEY `media_url` (`media_url`),
  KEY `project` (`project`),
  KEY `recurrence` (`recurrence`),
  KEY `location` (`location`),
  KEY `published` (`published`),
  KEY `preproduced` (`playout`),
  KEY `archived` (`archived`),
  KEY `draft` (`draft`)
) ENGINE=MyISAM AUTO_INCREMENT=23271 DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `calcms_events`
--

LOCK TABLES `calcms_events` WRITE;
/*!40000 ALTER TABLE `calcms_events` DISABLE KEYS */;
/*!40000 ALTER TABLE `calcms_events` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `calcms_images`
--

DROP TABLE IF EXISTS `calcms_images`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `calcms_images` (
  `id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `project_id` int(10) unsigned NOT NULL,
  `studio_id` int(10) unsigned DEFAULT NULL,
  `filename` varchar(64) NOT NULL,
  `name` varchar(300) DEFAULT NULL,
  `description` text,
  `licence` varchar(300) DEFAULT NULL,
  `public` tinyint(1) unsigned DEFAULT '0',
  `created_by` varchar(64) DEFAULT NULL,
  `modified_by` varchar(64) DEFAULT NULL,
  `created_at` datetime DEFAULT CURRENT_TIMESTAMP,
  `modified_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `created_at` (`created_at`),
  KEY `filename` (`filename`),
  KEY `created_by` (`created_by`),
  KEY `studio_id` (`studio_id`),
  KEY `project_id` (`project_id`)
) ENGINE=MyISAM AUTO_INCREMENT=2141 DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `calcms_images`
--

LOCK TABLES `calcms_images` WRITE;
/*!40000 ALTER TABLE `calcms_images` DISABLE KEYS */;
/*!40000 ALTER TABLE `calcms_images` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `calcms_metas`
--

DROP TABLE IF EXISTS `calcms_metas`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `calcms_metas` (
  `id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `name` varchar(256) NOT NULL,
  `value` varchar(256) NOT NULL,
  `project` varchar(64) DEFAULT NULL,
  `event_id` int(10) unsigned NOT NULL,
  KEY `id` (`id`),
  KEY `value` (`value`),
  KEY `project` (`project`),
  KEY `name` (`name`),
  KEY `event_id` (`event_id`)
) ENGINE=MyISAM AUTO_INCREMENT=8 DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `calcms_metas`
--

LOCK TABLES `calcms_metas` WRITE;
/*!40000 ALTER TABLE `calcms_metas` DISABLE KEYS */;
/*!40000 ALTER TABLE `calcms_metas` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `calcms_password_requests`
--

DROP TABLE IF EXISTS `calcms_password_requests`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `calcms_password_requests` (
  `id` int(12) unsigned NOT NULL AUTO_INCREMENT,
  `user` varchar(100) NOT NULL,
  `created_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `token` varchar(200) NOT NULL,
  `max_attempts` int(10) unsigned NOT NULL DEFAULT '0',
  PRIMARY KEY (`id`)
) ENGINE=MyISAM AUTO_INCREMENT=121 DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `calcms_password_requests`
--

LOCK TABLES `calcms_password_requests` WRITE;
/*!40000 ALTER TABLE `calcms_password_requests` DISABLE KEYS */;
/*!40000 ALTER TABLE `calcms_password_requests` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `calcms_playout`
--

DROP TABLE IF EXISTS `calcms_playout`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `calcms_playout` (
  `project_id` int(11) NOT NULL,
  `studio_id` int(11) NOT NULL,
  `start` datetime NOT NULL,
  `end` datetime NOT NULL,
  `duration` float unsigned NOT NULL,
  `start_date` date NOT NULL,
  `end_date` date NOT NULL,
  `file` varchar(300) NOT NULL,
  `errors` varchar(500) DEFAULT NULL,
  `channels` int(11) DEFAULT NULL,
  `bitrate` int(11) DEFAULT NULL,
  `stream_size` int(11) DEFAULT NULL,
  `sampling_rate` int(11) DEFAULT NULL,
  `bitrate_mode` varchar(10) DEFAULT NULL,
  `format` varchar(10) DEFAULT NULL,
  `format_version` varchar(30) DEFAULT NULL,
  `format_profile` varchar(10) DEFAULT NULL,
  `format_settings` varchar(30) DEFAULT NULL,
  `writing_library` varchar(30) DEFAULT NULL,
  `rms_left` float DEFAULT NULL,
  `rms_right` float DEFAULT NULL,
  `rms_image` varchar(300) DEFAULT NULL,
  `replay_gain` float DEFAULT NULL,
  `updated_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `modified_at` datetime DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`project_id`,`studio_id`,`start`),
  KEY `project_id` (`project_id`),
  KEY `studio_id` (`studio_id`),
  KEY `start` (`start`),
  KEY `end` (`end`),
  KEY `start_date` (`start_date`),
  KEY `end_date` (`end_date`),
  KEY `modified_at` (`modified_at`)
) ENGINE=MyISAM DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `calcms_playout`
--

LOCK TABLES `calcms_playout` WRITE;
/*!40000 ALTER TABLE `calcms_playout` DISABLE KEYS */;
/*!40000 ALTER TABLE `calcms_playout` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `calcms_project_series`
--

DROP TABLE IF EXISTS `calcms_project_series`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `calcms_project_series` (
  `project_id` int(10) unsigned NOT NULL,
  `studio_id` int(10) unsigned NOT NULL,
  `series_id` int(10) unsigned NOT NULL,
  PRIMARY KEY (`project_id`,`studio_id`,`series_id`),
  KEY `project_id` (`project_id`),
  KEY `studio_id` (`studio_id`),
  KEY `series_id` (`series_id`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `calcms_project_series`
--

LOCK TABLES `calcms_project_series` WRITE;
/*!40000 ALTER TABLE `calcms_project_series` DISABLE KEYS */;
INSERT INTO `calcms_project_series` VALUES (1,1,223);
/*!40000 ALTER TABLE `calcms_project_series` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `calcms_project_studios`
--

DROP TABLE IF EXISTS `calcms_project_studios`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `calcms_project_studios` (
  `project_id` int(10) unsigned NOT NULL,
  `studio_id` int(10) unsigned NOT NULL,
  PRIMARY KEY (`project_id`,`studio_id`),
  KEY `project_id` (`project_id`),
  KEY `studio_id` (`studio_id`)
) ENGINE=MyISAM DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `calcms_project_studios`
--

LOCK TABLES `calcms_project_studios` WRITE;
/*!40000 ALTER TABLE `calcms_project_studios` DISABLE KEYS */;
INSERT INTO `calcms_project_studios` VALUES (1,1);
/*!40000 ALTER TABLE `calcms_project_studios` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `calcms_projects`
--

DROP TABLE IF EXISTS `calcms_projects`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `calcms_projects` (
  `project_id` int(11) NOT NULL AUTO_INCREMENT,
  `name` varchar(32) NOT NULL,
  `title` varchar(100) DEFAULT NULL,
  `start_date` date NOT NULL,
  `end_date` date NOT NULL,
  `subtitle` varchar(100) DEFAULT NULL,
  `image` varchar(100) DEFAULT NULL,
  `email` varchar(100) DEFAULT NULL,
  PRIMARY KEY (`project_id`),
  KEY `name` (`name`)
) ENGINE=MyISAM AUTO_INCREMENT=89 DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `calcms_projects`
--

LOCK TABLES `calcms_projects` WRITE;
/*!40000 ALTER TABLE `calcms_projects` DISABLE KEYS */;
/*!40000 ALTER TABLE `calcms_projects` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `calcms_roles`
--

DROP TABLE IF EXISTS `calcms_roles`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `calcms_roles` (
  `id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `project_id` tinyint(1) unsigned NOT NULL,
  `studio_id` int(10) unsigned NOT NULL,
  `role` varchar(40) NOT NULL,
  `level` tinyint(3) unsigned NOT NULL DEFAULT '0',
  `read_role` tinyint(1) unsigned DEFAULT NULL,
  `update_role` tinyint(1) unsigned DEFAULT NULL,
  `read_user_role` tinyint(1) unsigned DEFAULT NULL,
  `create_user` tinyint(1) unsigned DEFAULT NULL,
  `read_user` tinyint(1) unsigned DEFAULT NULL,
  `update_user` tinyint(1) unsigned DEFAULT NULL,
  `delete_user` tinyint(1) unsigned DEFAULT NULL,
  `update_user_role` tinyint(1) unsigned DEFAULT NULL,
  `disable_user` tinyint(1) unsigned DEFAULT NULL,
  `create_project` tinyint(1) unsigned NOT NULL,
  `read_project` tinyint(1) unsigned NOT NULL,
  `update_project` tinyint(1) unsigned NOT NULL,
  `delete_project` tinyint(1) unsigned NOT NULL,
  `assign_project_studio` tinyint(1) unsigned NOT NULL,
  `create_studio` tinyint(1) unsigned NOT NULL,
  `read_studio` tinyint(1) unsigned NOT NULL,
  `update_studio` tinyint(1) unsigned DEFAULT NULL,
  `delete_studio` tinyint(1) unsigned NOT NULL,
  `read_studio_timeslot_schedule` tinyint(1) unsigned NOT NULL,
  `update_studio_timeslot_schedule` tinyint(1) unsigned NOT NULL,
  `create_series` tinyint(1) unsigned DEFAULT NULL,
  `read_series` tinyint(1) unsigned DEFAULT NULL,
  `update_series` tinyint(1) unsigned DEFAULT NULL,
  `delete_series` tinyint(1) unsigned DEFAULT NULL,
  `update_series_template` tinyint(1) unsigned NOT NULL,
  `assign_series_member` tinyint(1) unsigned NOT NULL,
  `remove_series_member` tinyint(1) unsigned NOT NULL,
  `scan_series_events` tinyint(1) unsigned NOT NULL,
  `assign_series_events` tinyint(1) unsigned NOT NULL,
  `read_schedule` tinyint(1) unsigned NOT NULL,
  `update_schedule` tinyint(1) unsigned NOT NULL,
  `delete_schedule` tinyint(1) unsigned NOT NULL,
  `create_event` tinyint(1) unsigned DEFAULT NULL,
  `create_event_from_schedule` tinyint(1) unsigned NOT NULL,
  `create_event_of_series` tinyint(1) unsigned NOT NULL,
  `read_event` tinyint(1) unsigned DEFAULT NULL,
  `delete_event` tinyint(1) unsigned DEFAULT NULL,
  `update_event_of_series` tinyint(1) unsigned DEFAULT NULL,
  `update_event_of_others` tinyint(1) unsigned DEFAULT NULL,
  `update_event_time` tinyint(1) unsigned DEFAULT NULL,
  `update_event_after_week` tinyint(1) unsigned NOT NULL,
  `update_event_field_title` tinyint(1) unsigned NOT NULL,
  `update_event_field_title_extension` tinyint(1) unsigned NOT NULL,
  `update_event_field_excerpt` tinyint(1) unsigned NOT NULL,
  `update_event_field_content` tinyint(1) unsigned NOT NULL,
  `update_event_field_description` tinyint(1) unsigned NOT NULL,
  `update_event_field_topic` tinyint(1) unsigned NOT NULL,
  `update_event_field_episode` tinyint(1) unsigned NOT NULL,
  `update_event_field_excerpt_extension` tinyint(1) unsigned NOT NULL,
  `update_event_field_image` tinyint(1) unsigned NOT NULL,
  `update_event_field_podcast_url` tinyint(1) unsigned NOT NULL,
  `update_event_field_archive_url` tinyint(1) unsigned NOT NULL,
  `update_event_status_disable_event_sync` tinyint(1) unsigned NOT NULL,
  `update_event_status_published` tinyint(1) unsigned NOT NULL,
  `update_event_status_rerun` tinyint(1) unsigned NOT NULL,
  `update_event_status_draft` tinyint(1) unsigned NOT NULL,
  `update_event_status_live` tinyint(1) unsigned NOT NULL,
  `update_event_status_playout` tinyint(1) unsigned NOT NULL,
  `update_event_status_archived` tinyint(1) unsigned NOT NULL,
  `create_image` tinyint(1) unsigned NOT NULL,
  `update_image_own` tinyint(1) unsigned NOT NULL,
  `read_image` tinyint(1) unsigned NOT NULL,
  `delete_image_own` tinyint(1) unsigned NOT NULL,
  `update_image_others` tinyint(1) unsigned NOT NULL,
  `delete_image_others` tinyint(1) unsigned NOT NULL,
  `read_changes` tinyint(1) unsigned NOT NULL,
  `undo_changes` tinyint(1) unsigned NOT NULL,
  `read_user_stats` tinyint(1) unsigned NOT NULL,
  `read_comment` tinyint(1) unsigned NOT NULL,
  `update_comment_status_lock` tinyint(1) unsigned NOT NULL,
  `update_comment_status_read` tinyint(1) unsigned NOT NULL,
  `upload_audio_recordings` tinyint(1) unsigned NOT NULL,
  `delete_audio_recordings` tinyint(1) unsigned NOT NULL,
  `read_playout` tinyint(1) unsigned NOT NULL,
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  `create_download` tinyint(1) unsigned NOT NULL,
  `modified_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `update_event_field_content_format` tinyint(1) unsigned NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `role_2` (`role`),
  KEY `studio_id` (`studio_id`),
  KEY `role` (`role`),
  KEY `project_id` (`project_id`)
) ENGINE=MyISAM AUTO_INCREMENT=40 DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `calcms_roles`
--

LOCK TABLES `calcms_roles` WRITE;
/*!40000 ALTER TABLE `calcms_roles` DISABLE KEYS */;
INSERT INTO `calcms_roles` VALUES (1,1,1,'Admin',1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,'0000-00-00 00:00:00',1,'0000-00-00 00:00:00',1);
UNLOCK TABLES;

--
-- Table structure for table `calcms_series`
--

DROP TABLE IF EXISTS `calcms_series`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `calcms_series` (
  `id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `series_name` varchar(100) DEFAULT NULL,
  `title` varchar(100) DEFAULT NULL,
  `excerpt` longtext,
  `content` longtext,
  `html_content` longtext,
  `topic` longtext,
  `program` varchar(40) DEFAULT NULL,
  `image` varchar(200) DEFAULT NULL,
  `project` varchar(64) DEFAULT NULL,
  `location` varchar(100) DEFAULT NULL,
  `modified_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `modified_by` varchar(100) NOT NULL,
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  `assign_event_series_name` varchar(100) DEFAULT NULL,
  `assign_event_title` varchar(100) DEFAULT NULL,
  `default_duration` int(10) unsigned DEFAULT NULL,
  `comment` longtext,
  `live` tinyint(1) unsigned DEFAULT NULL,
  `archive_url` varchar(300) DEFAULT NULL,
  `podcast_url` varchar(300) DEFAULT NULL,
  `count_episodes` tinyint(1) unsigned DEFAULT '1',
  `has_single_events` tinyint(1) unsigned DEFAULT '0',
  `predecessor_id` int(10) DEFAULT NULL,
  `content_format` varchar(45) DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `location` (`location`)
) ENGINE=MyISAM AUTO_INCREMENT=224 DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `calcms_series`
--

LOCK TABLES `calcms_series` WRITE;
/*!40000 ALTER TABLE `calcms_series` DISABLE KEYS */;
INSERT INTO `calcms_series` VALUES (223,'_single_',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,'0000-00-00 00:00:00','','0000-00-00 00:00:00',NULL,NULL,NULL,NULL,0,NULL,NULL,1,0,NULL,NULL);
/*!40000 ALTER TABLE `calcms_series` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `calcms_series_dates`
--

DROP TABLE IF EXISTS `calcms_series_dates`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `calcms_series_dates` (
  `id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `project_id` int(10) unsigned NOT NULL,
  `studio_id` int(10) unsigned NOT NULL,
  `series_id` int(10) unsigned NOT NULL,
  `start` timestamp NOT NULL DEFAULT '0000-00-00 00:00:00',
  `end` timestamp NOT NULL DEFAULT '0000-00-00 00:00:00',
  `start_date` date NOT NULL,
  `end_date` date NOT NULL,
  `exclude` tinyint(1) NOT NULL DEFAULT '0',
  `series_schedule_id` int(10) unsigned NOT NULL,
  PRIMARY KEY (`id`),
  KEY `series_id` (`series_id`),
  KEY `studio_id` (`studio_id`),
  KEY `start` (`start`) USING BTREE,
  KEY `end` (`end`) USING BTREE,
  KEY `start_date` (`start_date`),
  KEY `end_date` (`end_date`),
  KEY `project_id` (`project_id`)
) ENGINE=MyISAM AUTO_INCREMENT=17361 DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `calcms_series_dates`
--

LOCK TABLES `calcms_series_dates` WRITE;
/*!40000 ALTER TABLE `calcms_series_dates` DISABLE KEYS */;
/*!40000 ALTER TABLE `calcms_series_dates` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `calcms_series_events`
--

DROP TABLE IF EXISTS `calcms_series_events`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `calcms_series_events` (
  `project_id` int(10) unsigned NOT NULL,
  `studio_id` int(12) unsigned NOT NULL,
  `series_id` int(12) unsigned NOT NULL,
  `event_id` int(12) unsigned NOT NULL,
  `manual` int(1) unsigned NOT NULL,
  KEY `series_id` (`series_id`),
  KEY `event_id` (`event_id`),
  KEY `studio_id` (`studio_id`),
  KEY `project_id` (`project_id`),
  KEY `manual` (`manual`),
  KEY `pse` (`project_id`,`studio_id`,`event_id`)
) ENGINE=MyISAM DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `calcms_series_events`
--

LOCK TABLES `calcms_series_events` WRITE;
/*!40000 ALTER TABLE `calcms_series_events` DISABLE KEYS */;
/*!40000 ALTER TABLE `calcms_series_events` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `calcms_series_schedule`
--

DROP TABLE IF EXISTS `calcms_series_schedule`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `calcms_series_schedule` (
  `id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `project_id` int(10) unsigned NOT NULL DEFAULT '1',
  `studio_id` int(10) unsigned DEFAULT NULL,
  `series_id` int(10) unsigned NOT NULL,
  `start` datetime NOT NULL,
  `end` date DEFAULT NULL,
  `frequency` int(10) unsigned DEFAULT NULL,
  `duration` int(10) unsigned DEFAULT NULL,
  `exclude` tinyint(1) unsigned DEFAULT NULL,
  `weekday` int(10) unsigned DEFAULT NULL,
  `week_of_month` int(10) unsigned DEFAULT NULL,
  `period_type` varchar(16) DEFAULT NULL,
  `month` int(10) unsigned NOT NULL DEFAULT '0',
  `start_offset` int(11) DEFAULT '0',
  `nextDay` int(11) DEFAULT '0',
  PRIMARY KEY (`id`),
  KEY `series_id` (`series_id`),
  KEY `studio_id` (`studio_id`),
  KEY `start` (`start`) USING BTREE,
  KEY `end` (`end`) USING BTREE,
  KEY `project_id` (`project_id`)
) ENGINE=MyISAM AUTO_INCREMENT=402 DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `calcms_series_schedule`
--

LOCK TABLES `calcms_series_schedule` WRITE;
/*!40000 ALTER TABLE `calcms_series_schedule` DISABLE KEYS */;
/*!40000 ALTER TABLE `calcms_series_schedule` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `calcms_studio_timeslot_dates`
--

DROP TABLE IF EXISTS `calcms_studio_timeslot_dates`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `calcms_studio_timeslot_dates` (
  `project_id` int(10) unsigned NOT NULL,
  `studio_id` int(10) unsigned NOT NULL,
  `schedule_id` int(10) unsigned NOT NULL,
  `start` datetime NOT NULL,
  `end` datetime NOT NULL,
  `start_date` date NOT NULL,
  `end_date` date NOT NULL,
  PRIMARY KEY (`project_id`,`studio_id`,`start`,`end`) USING BTREE,
  KEY `studio_id` (`studio_id`),
  KEY `start_date` (`start_date`),
  KEY `end_date` (`end_date`),
  KEY `schedule_id` (`schedule_id`),
  KEY `start` (`start`),
  KEY `end` (`end`),
  KEY `project_id` (`project_id`)
) ENGINE=MyISAM DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `calcms_studio_timeslot_dates`
--

LOCK TABLES `calcms_studio_timeslot_dates` WRITE;
/*!40000 ALTER TABLE `calcms_studio_timeslot_dates` DISABLE KEYS */;
INSERT INTO `calcms_studio_timeslot_dates` VALUES (1,'2016-05-22 00:00:00','2016-05-23 00:00:00','2016-05-21','2016-05-22',60,1),(1,'2016-05-21 00:00:00','2016-05-22 00:00:00','2016-05-20','2016-05-21',60,1),(1,'2016-05-05 00:00:00','2016-05-06 00:00:00','2016-05-04','2016-05-05',60,1),(1,'2016-05-28 00:00:00','2016-05-29 00:00:00','2016-05-27','2016-05-28',60,1),(1,'2016-05-14 00:00:00','2016-05-15 00:00:00','2016-05-13','2016-05-14',60,1),(1,'2016-05-20 00:00:00','2016-05-21 00:00:00','2016-05-19','2016-05-20',60,1),(1,'2016-05-26 00:00:00','2016-05-27 00:00:00','2016-05-25','2016-05-26',60,1),(1,'2016-05-24 00:00:00','2016-05-25 00:00:00','2016-05-23','2016-05-24',60,1),(1,'2016-05-17 00:00:00','2016-05-18 00:00:00','2016-05-16','2016-05-17',60,1),(1,'2016-05-30 00:00:00','2016-05-31 00:00:00','2016-05-29','2016-05-30',60,1),(1,'2016-05-11 00:00:00','2016-05-12 00:00:00','2016-05-10','2016-05-11',60,1),(1,'2016-05-07 00:00:00','2016-05-08 00:00:00','2016-05-06','2016-05-07',60,1),(1,'2016-05-16 00:00:00','2016-05-17 00:00:00','2016-05-15','2016-05-16',60,1),(1,'2016-05-01 00:00:00','2016-05-02 00:00:00','2016-04-30','2016-05-01',60,1),(1,'2016-05-08 00:00:00','2016-05-09 00:00:00','2016-05-07','2016-05-08',60,1),(1,'2016-05-03 00:00:00','2016-05-04 00:00:00','2016-05-02','2016-05-03',60,1),(1,'2016-05-09 00:00:00','2016-05-10 00:00:00','2016-05-08','2016-05-09',60,1),(1,'2016-05-04 00:00:00','2016-05-05 00:00:00','2016-05-03','2016-05-04',60,1),(1,'2016-05-06 00:00:00','2016-05-07 00:00:00','2016-05-05','2016-05-06',60,1),(1,'2016-05-13 00:00:00','2016-05-14 00:00:00','2016-05-12','2016-05-13',60,1),(1,'2016-05-29 00:00:00','2016-05-30 00:00:00','2016-05-28','2016-05-29',60,1),(1,'2016-05-25 00:00:00','2016-05-26 00:00:00','2016-05-24','2016-05-25',60,1),(1,'2016-05-18 00:00:00','2016-05-19 00:00:00','2016-05-17','2016-05-18',60,1),(1,'2016-05-23 00:00:00','2016-05-24 00:00:00','2016-05-22','2016-05-23',60,1),(1,'2016-05-02 00:00:00','2016-05-03 00:00:00','2016-05-01','2016-05-02',60,1),(1,'2016-05-27 00:00:00','2016-05-28 00:00:00','2016-05-26','2016-05-27',60,1),(1,'2016-05-19 00:00:00','2016-05-20 00:00:00','2016-05-18','2016-05-19',60,1),(1,'2016-05-12 00:00:00','2016-05-13 00:00:00','2016-05-11','2016-05-12',60,1),(1,'2016-05-15 00:00:00','2016-05-16 00:00:00','2016-05-14','2016-05-15',60,1),(1,'2016-05-10 00:00:00','2016-05-11 00:00:00','2016-05-09','2016-05-10',60,1);
/*!40000 ALTER TABLE `calcms_studio_timeslot_dates` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `calcms_studio_timeslot_schedule`
--

DROP TABLE IF EXISTS `calcms_studio_timeslot_schedule`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `calcms_studio_timeslot_schedule` (
  `id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `project_id` int(10) unsigned NOT NULL,
  `studio_id` int(10) unsigned NOT NULL,
  `start` datetime NOT NULL,
  `end` datetime NOT NULL,
  `frequency` int(10) unsigned NOT NULL,
  `end_date` date NOT NULL,
  PRIMARY KEY (`id`),
  KEY `studio_id` (`studio_id`),
  KEY `start` (`start`),
  KEY `end` (`end`),
  KEY `project_id` (`project_id`)
) ENGINE=MyISAM AUTO_INCREMENT=61 DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `calcms_studio_timeslot_schedule`
--

LOCK TABLES `calcms_studio_timeslot_schedule` WRITE;
/*!40000 ALTER TABLE `calcms_studio_timeslot_schedule` DISABLE KEYS */;
INSERT INTO `calcms_studio_timeslot_schedule` VALUES (60,1,'2016-05-01 00:00:00','2016-05-02 00:00:00',1,'2016-05-30',1);
/*!40000 ALTER TABLE `calcms_studio_timeslot_schedule` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `calcms_studios`
--

DROP TABLE IF EXISTS `calcms_studios`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `calcms_studios` (
  `id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `name` varchar(32) NOT NULL,
  `description` text NOT NULL,
  `location` varchar(100) NOT NULL,
  `stream` varchar(100) NOT NULL,
  `image` varchar(200) NOT NULL,
  `google_calendar` varchar(100) NOT NULL,
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  `modified_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`) USING BTREE,
  UNIQUE KEY `name_2` (`name`),
  KEY `location` (`location`),
  KEY `name` (`name`)
) ENGINE=MyISAM AUTO_INCREMENT=23 DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `calcms_studios`
--

LOCK TABLES `calcms_studios` WRITE;
/*!40000 ALTER TABLE `calcms_studios` DISABLE KEYS */;
INSERT INTO `calcms_studios` VALUES (1,'MeinStudio','Studio','studio','','','','0000-00-00 00:00:00','');
/*!40000 ALTER TABLE `calcms_studios` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `calcms_tags`
--

DROP TABLE IF EXISTS `calcms_tags`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `calcms_tags` (
  `id` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
  `name` varchar(100) DEFAULT NULL,
  `event_id` bigint(20) unsigned NOT NULL,
  KEY `id` (`id`),
  KEY `event_id` (`event_id`)
) ENGINE=MyISAM AUTO_INCREMENT=8 DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `calcms_tags`
--

LOCK TABLES `calcms_tags` WRITE;
/*!40000 ALTER TABLE `calcms_tags` DISABLE KEYS */;
/*!40000 ALTER TABLE `calcms_tags` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `calcms_user_default_studios`
--

DROP TABLE IF EXISTS `calcms_user_default_studios`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `calcms_user_default_studios` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `user` varchar(50) NOT NULL,
  `project_id` int(11) NOT NULL,
  `studio_id` int(11) NOT NULL,
  PRIMARY KEY (`id`),
  KEY `user` (`user`)
) ENGINE=InnoDB AUTO_INCREMENT=11 DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `calcms_user_default_studios`
--

LOCK TABLES `calcms_user_default_studios` WRITE;
/*!40000 ALTER TABLE `calcms_user_default_studios` DISABLE KEYS */;
/*!40000 ALTER TABLE `calcms_user_default_studios` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `calcms_user_events`
--

DROP TABLE IF EXISTS `calcms_user_events`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `calcms_user_events` (
  `id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `start` datetime DEFAULT NULL,
  `end` datetime DEFAULT NULL,
  `title` varchar(200) DEFAULT NULL,
  `excerpt` longtext,
  `content` longtext,
  `status` varchar(40) DEFAULT NULL,
  `program` varchar(40) DEFAULT NULL,
  `series_name` varchar(40) DEFAULT NULL,
  `image` varchar(200) DEFAULT NULL,
  `location` varchar(100) DEFAULT NULL,
  `modified_by` timestamp NOT NULL DEFAULT '0000-00-00 00:00:00',
  `modified_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `title` (`title`),
  KEY `start` (`start`),
  KEY `end` (`end`),
  KEY `location` (`location`)
) ENGINE=MyISAM DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `calcms_user_events`
--

LOCK TABLES `calcms_user_events` WRITE;
/*!40000 ALTER TABLE `calcms_user_events` DISABLE KEYS */;
/*!40000 ALTER TABLE `calcms_user_events` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `calcms_user_roles`
--

DROP TABLE IF EXISTS `calcms_user_roles`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `calcms_user_roles` (
  `id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `project_id` int(10) unsigned NOT NULL,
  `studio_id` int(10) unsigned NOT NULL DEFAULT '0',
  `user_id` int(10) unsigned NOT NULL,
  `role_id` int(10) unsigned NOT NULL,
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  `modified_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`) USING BTREE,
  KEY `user_id` (`user_id`),
  KEY `role_id` (`role_id`),
  KEY `studio_id` (`studio_id`),
  KEY `project_id` (`project_id`)
) ENGINE=MyISAM AUTO_INCREMENT=261 DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `calcms_user_roles`
--

LOCK TABLES `calcms_user_roles` WRITE;
/*!40000 ALTER TABLE `calcms_user_roles` DISABLE KEYS */;
INSERT INTO `calcms_user_roles` VALUES (1,4,7,1,1,'0000-00-00 00:00:00',1);
/*!40000 ALTER TABLE `calcms_user_roles` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `calcms_user_series`
--

DROP TABLE IF EXISTS `calcms_user_series`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `calcms_user_series` (
  `id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `project_id` int(10) unsigned NOT NULL,
  `studio_id` int(10) unsigned NOT NULL,
  `user_id` int(10) unsigned NOT NULL,
  `series_id` int(10) unsigned NOT NULL,
  `active` char(1) NOT NULL,
  `modified_by` varchar(100) DEFAULT NULL,
  `modified_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `user_id` (`user_id`),
  KEY `series_id` (`series_id`),
  KEY `active` (`active`),
  KEY `studio_id` (`studio_id`),
  KEY `project_id` (`project_id`)
) ENGINE=MyISAM AUTO_INCREMENT=216 DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `calcms_user_series`
--

LOCK TABLES `calcms_user_series` WRITE;
/*!40000 ALTER TABLE `calcms_user_series` DISABLE KEYS */;
/*!40000 ALTER TABLE `calcms_user_series` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `calcms_user_sessions`
--

DROP TABLE IF EXISTS `calcms_user_sessions`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `calcms_user_sessions` (
  `id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `session_id` varchar(64) NOT NULL,
  `user` varchar(30) NOT NULL,
  `start` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  `end` timestamp NULL DEFAULT NULL,
  `expires_at` timestamp NOT NULL DEFAULT '0000-00-00 00:00:00',
  `timeout` int(10) unsigned NOT NULL,
  `pid` int(10) unsigned NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `id_UNIQUE` (`id`),
  UNIQUE KEY `session_id_UNIQUE` (`session_id`),
  KEY `user` (`user`),
  KEY `session_id` (`session_id`)
) ENGINE=InnoDB AUTO_INCREMENT=1797 DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `calcms_user_sessions`
--

LOCK TABLES `calcms_user_sessions` WRITE;
/*!40000 ALTER TABLE `calcms_user_sessions` DISABLE KEYS */;
/*!40000 ALTER TABLE `calcms_user_sessions` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `calcms_user_settings`
--

DROP TABLE IF EXISTS `calcms_user_settings`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `calcms_user_settings` (
  `id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `user` varchar(20) CHARACTER SET latin1 NOT NULL,
  `colors` longtext NOT NULL,
  `language` varchar(3) DEFAULT 'de',
  `period` varchar(16) DEFAULT 'month',
  `calendar_fontsize` smallint(5) unsigned DEFAULT '12',
  `project_id` int(10) unsigned DEFAULT NULL,
  `studio_id` int(10) unsigned DEFAULT NULL,
  PRIMARY KEY (`id`,`user`) USING BTREE,
  KEY `user` (`user`)
) ENGINE=MyISAM AUTO_INCREMENT=28 DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `calcms_user_settings`
--

LOCK TABLES `calcms_user_settings` WRITE;
/*!40000 ALTER TABLE `calcms_user_settings` DISABLE KEYS */;
INSERT INTO `calcms_user_settings` VALUES (27,'ccAdmin','#content .event=#eeeeee\n#content .schedule=#aaaaaa\n#content .event.published=#88ff88\n#content .event.no_series=#aa8822\n#content .event.marked=#0066aa\n#content.conflicts .event.error=#ff0000\n#content.conflicts .schedule.error=#ee4422\n#content .work=#cc00cc','en','month',12, NULL, NULL);
/*!40000 ALTER TABLE `calcms_user_settings` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `calcms_user_stats`
--

DROP TABLE IF EXISTS `calcms_user_stats`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `calcms_user_stats` (
  `project_id` int(10) unsigned NOT NULL,
  `studio_id` int(10) unsigned NOT NULL,
  `series_id` int(10) unsigned NOT NULL DEFAULT '0',
  `user` varchar(32) NOT NULL,
  `modified_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `create_events` int(10) unsigned DEFAULT '0',
  `update_events` int(10) unsigned DEFAULT '0',
  `delete_events` int(10) unsigned DEFAULT '0',
  `schedule_event` int(10) unsigned DEFAULT '0',
  `create_series` int(10) unsigned DEFAULT '0',
  `update_series` int(10) unsigned DEFAULT '0',
  `delete_series` int(10) unsigned DEFAULT '0',
  `upload_file` int(10) unsigned DEFAULT '0',
  `download_file` int(10) unsigned DEFAULT '0',
  PRIMARY KEY (`project_id`,`studio_id`,`series_id`,`user`) USING BTREE
) ENGINE=MyISAM DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `calcms_user_stats`
--

LOCK TABLES `calcms_user_stats` WRITE;
/*!40000 ALTER TABLE `calcms_user_stats` DISABLE KEYS */;
/*!40000 ALTER TABLE `calcms_user_stats` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `calcms_users`
--

DROP TABLE IF EXISTS `calcms_users`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `calcms_users` (
  `id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `name` varchar(30) NOT NULL,
  `full_name` varchar(30) DEFAULT NULL,
  `email` varchar(300) NOT NULL,
  `pass` varchar(100) NOT NULL,
  `salt` varchar(32) NOT NULL,
  `disabled` int(10) unsigned DEFAULT '0',
  `session_timeout` int(10) unsigned NOT NULL DEFAULT '120',
  `created_by` varchar(30) DEFAULT NULL,
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  `modified_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`) USING BTREE,
  UNIQUE KEY `name` (`name`),
  UNIQUE KEY `email` (`email`) USING BTREE,
  KEY `disabled` (`disabled`)
) ENGINE=MyISAM AUTO_INCREMENT=73 DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `calcms_users`
--

LOCK TABLES `calcms_users` WRITE;
/*!40000 ALTER TABLE `calcms_users` DISABLE KEYS */;
INSERT INTO `calcms_users` VALUES (4,'ccAdmin','Admin','info@localhost','Edt6Gt8VQk/pXQ1uWRZ8pu','$2a$08$Edt6Gt8VQk/pXQ1uWRZ8pu/KIe/qVFP/lYkbS64/D8URYEm6KshIG',0,120,NULL,'0000-00-00 00:00:00','0000-00-00 00:00:00');
/*!40000 ALTER TABLE `calcms_users` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `calcms_work_dates`
--

DROP TABLE IF EXISTS `calcms_work_dates`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `calcms_work_dates` (
  `schedule_id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `project_id` int(10) unsigned NOT NULL,
  `studio_id` int(10) unsigned NOT NULL,
  `start` timestamp NOT NULL DEFAULT '0000-00-00 00:00:00',
  `end` timestamp NOT NULL DEFAULT '0000-00-00 00:00:00',
  `start_date` date NOT NULL,
  `end_date` date NOT NULL,
  `exclude` tinyint(1) NOT NULL DEFAULT '0',
  `type` varchar(32) NOT NULL,
  `title` varchar(200) NOT NULL,
  KEY `project_id` (`project_id`),
  KEY `studio_id` (`studio_id`),
  KEY `start` (`start`),
  KEY `end` (`end`),
  KEY `type` (`type`),
  KEY `schedule_id` (`schedule_id`),
  KEY `start_date` (`start_date`),
  KEY `end_date` (`end_date`)
) ENGINE=MyISAM AUTO_INCREMENT=18 DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `calcms_work_dates`
--

LOCK TABLES `calcms_work_dates` WRITE;
/*!40000 ALTER TABLE `calcms_work_dates` DISABLE KEYS */;
/*!40000 ALTER TABLE `calcms_work_dates` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `calcms_work_schedule`
--

DROP TABLE IF EXISTS `calcms_work_schedule`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `calcms_work_schedule` (
  `schedule_id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `project_id` int(10) unsigned NOT NULL,
  `studio_id` int(10) unsigned NOT NULL,
  `start` datetime NOT NULL,
  `end` date DEFAULT NULL,
  `frequency` int(10) unsigned DEFAULT NULL,
  `duration` int(10) unsigned DEFAULT NULL,
  `exclude` tinyint(1) unsigned DEFAULT NULL,
  `weekday` int(10) unsigned DEFAULT NULL,
  `week_of_month` int(10) unsigned DEFAULT NULL,
  `period_type` varchar(16) DEFAULT NULL,
  `month` int(10) unsigned NOT NULL,
  `type` varchar(32) NOT NULL,
  `title` varchar(200) NOT NULL,
  PRIMARY KEY (`schedule_id`),
  KEY `project_id` (`project_id`),
  KEY `studio_id` (`studio_id`),
  KEY `type` (`type`)
) ENGINE=MyISAM AUTO_INCREMENT=18 DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `calcms_work_schedule`
--

LOCK TABLES `calcms_work_schedule` WRITE;
/*!40000 ALTER TABLE `calcms_work_schedule` DISABLE KEYS */;
/*!40000 ALTER TABLE `calcms_work_schedule` ENABLE KEYS */;
UNLOCK TABLES;
/*!40103 SET TIME_ZONE=@OLD_TIME_ZONE */;

/*!40101 SET SQL_MODE=@OLD_SQL_MODE */;
/*!40014 SET FOREIGN_KEY_CHECKS=@OLD_FOREIGN_KEY_CHECKS */;
/*!40014 SET UNIQUE_CHECKS=@OLD_UNIQUE_CHECKS */;
/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
/*!40111 SET SQL_NOTES=@OLD_SQL_NOTES */;


DROP TABLE IF EXISTS `calcms_user_selected_events`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `calcms_user_selected_events` (
  `id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `user` varchar(45) NOT NULL,
  `project_id` int(10) unsigned DEFAULT NULL,
  `studio_id` int(10) unsigned DEFAULT NULL,
  `series_id` int(10) unsigned DEFAULT NULL,
  `filter_project_studio` int(1) unsigned DEFAULT NULL,
  `filter_series` int(1) unsigned DEFAULT NULL,
  `selected_project` int(10) unsigned DEFAULT NULL,
  `selected_studio` int(10) unsigned DEFAULT NULL,
  `selected_series` int(10) unsigned DEFAULT NULL,
  `selected_event` int(10) unsigned DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `unique` (`user`,`project_id`,`studio_id`,`series_id`,`filter_project_studio`,`filter_series`),
  KEY `user` (`user`,`project_id`,`studio_id`,`series_id`)
) ENGINE=InnoDB AUTO_INCREMENT=4 DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;


ALTER TABLE `calcms`.`calcms_events` 
ADD COLUMN `upload_status` VARCHAR(45) NULL DEFAULT NULL AFTER `listen_key`;

--
-- Table structure for table `calcms_user_day_start`
--

DROP TABLE IF EXISTS `calcms_user_day_start`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `calcms_user_day_start` (
  `id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `user` varchar(45) NOT NULL,
  `project_id` int(10) unsigned NOT NULL,
  `studio_id` int(10) unsigned NOT NULL,
  `day_start` int(10) unsigned DEFAULT '0',
  PRIMARY KEY (`id`),
  UNIQUE KEY `select` (`project_id`,`studio_id`,`user`)
) ENGINE=InnoDB AUTO_INCREMENT=5 DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;
/*!40103 SET TIME_ZONE=@OLD_TIME_ZONE */;

/*!40101 SET SQL_MODE=@OLD_SQL_MODE */;
/*!40014 SET FOREIGN_KEY_CHECKS=@OLD_FOREIGN_KEY_CHECKS */;
/*!40014 SET UNIQUE_CHECKS=@OLD_UNIQUE_CHECKS */;
/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
/*!40111 SET SQL_NOTES=@OLD_SQL_NOTES */;

