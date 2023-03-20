-- MySQL dump 10.13  Distrib 8.0.32, for Linux (x86_64)
--
-- Host: localhost    Database: calcms
-- ------------------------------------------------------
-- Server version   8.0.32-0ubuntu0.20.04.2

/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET @OLD_CHARACTER_SET_RESULTS=@@CHARACTER_SET_RESULTS */;
/*!40101 SET @OLD_COLLATION_CONNECTION=@@COLLATION_CONNECTION */;
/*!50503 SET NAMES utf8mb4 */;
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
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `calcms_audio_recordings` (
  `id` int unsigned NOT NULL AUTO_INCREMENT,
  `project_id` int NOT NULL,
  `studio_id` int NOT NULL,
  `event_id` int NOT NULL,
  `active` tinyint(1) NOT NULL DEFAULT '0',
  `path` varchar(300) NOT NULL,
  `size` bigint unsigned NOT NULL DEFAULT '0',
  `audioDuration` float NOT NULL DEFAULT '0',
  `eventDuration` int NOT NULL DEFAULT '0',
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
) ENGINE=MyISAM AUTO_INCREMENT=4570 DEFAULT CHARSET=utf8mb3;
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
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `calcms_categories` (
  `id` bigint unsigned NOT NULL AUTO_INCREMENT,
  `name` varchar(256) DEFAULT NULL,
  `event_id` varchar(256) CHARACTER SET latin1 COLLATE latin1_swedish_ci NOT NULL,
  `project` varchar(64) DEFAULT NULL,
  KEY `id` (`id`),
  KEY `event_id` (`event_id`),
  KEY `name` (`name`),
  KEY `project` (`project`)
) ENGINE=MyISAM AUTO_INCREMENT=12646 DEFAULT CHARSET=utf8mb3;
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
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `calcms_comments` (
  `id` int unsigned NOT NULL AUTO_INCREMENT,
  `event_start` datetime DEFAULT NULL,
  `event_id` int unsigned DEFAULT NULL,
  `content` text,
  `ip` varchar(22) DEFAULT NULL,
  `author` varchar(40) DEFAULT NULL,
  `email` varchar(40) DEFAULT NULL,
  `lock_status` varchar(16) NOT NULL DEFAULT 'show',
  `created_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `title` varchar(80) DEFAULT NULL,
  `parent_id` int unsigned DEFAULT NULL,
  `level` int unsigned DEFAULT NULL,
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
) ENGINE=MyISAM AUTO_INCREMENT=7314 DEFAULT CHARSET=utf8mb3;
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
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `calcms_event_history` (
  `id` int unsigned NOT NULL AUTO_INCREMENT,
  `project_id` int unsigned NOT NULL,
  `studio_id` int unsigned DEFAULT NULL,
  `series_id` int unsigned DEFAULT NULL,
  `event_id` int unsigned NOT NULL,
  `start` datetime DEFAULT NULL,
  `end` datetime DEFAULT NULL,
  `reference` varchar(300) DEFAULT NULL,
  `title` varchar(200) DEFAULT NULL,
  `excerpt` longtext,
  `content` longtext,
  `rating` int DEFAULT NULL,
  `status` varchar(40) DEFAULT NULL,
  `visibility` varchar(40) DEFAULT NULL,
  `responsible` varchar(40) DEFAULT NULL,
  `start_date` date NOT NULL,
  `end_date` date NOT NULL,
  `program` varchar(40) DEFAULT NULL,
  `series_name` varchar(40) DEFAULT NULL,
  `comment_count` int unsigned NOT NULL DEFAULT '0',
  `tag_count` int unsigned NOT NULL DEFAULT '0',
  `image` varchar(200) DEFAULT NULL,
  `podcast_url` varchar(300) DEFAULT NULL,
  `media_url` varchar(300) DEFAULT NULL,
  `project` varchar(64) DEFAULT NULL,
  `recurrence` int NOT NULL DEFAULT '0',
  `location` varchar(100) DEFAULT NULL,
  `user_title` varchar(200) DEFAULT NULL,
  `user_excerpt` longtext,
  `topic` longtext,
  `published` tinyint unsigned DEFAULT NULL,
  `playout` tinyint unsigned DEFAULT NULL,
  `archived` tinyint unsigned DEFAULT NULL,
  `episode` int unsigned DEFAULT NULL,
  `rerun` int unsigned DEFAULT NULL,
  `disable_event_sync` tinyint unsigned DEFAULT NULL,
  `live` tinyint unsigned DEFAULT NULL,
  `archive_url` varchar(300) DEFAULT NULL,
  `deleted` tinyint unsigned DEFAULT '0',
  `draft` tinyint unsigned NOT NULL DEFAULT '0',
  `created_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `modified_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `modified_by` varchar(20) DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `project_id` (`project_id`),
  KEY `start` (`start`),
  KEY `end` (`end`),
  KEY `start_date` (`start_date`),
  KEY `status` (`status`),
  KEY `modified_at` (`modified_at`),
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
) ENGINE=MyISAM AUTO_INCREMENT=121927 DEFAULT CHARSET=utf8mb3;
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
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `calcms_events` (
  `id` int unsigned NOT NULL AUTO_INCREMENT,
  `start` datetime NOT NULL,
  `end` datetime NOT NULL,
  `program` varchar(40) DEFAULT NULL,
  `series_name` varchar(40) DEFAULT NULL,
  `title` varchar(200) DEFAULT NULL,
  `episode` int unsigned DEFAULT NULL,
  `excerpt` longtext,
  `content` longtext,
  `html_content` longtext,
  `rating` int DEFAULT NULL,
  `status` varchar(40) DEFAULT NULL,
  `visibility` varchar(40) DEFAULT NULL,
  `responsible` varchar(40) DEFAULT NULL,
  `start_date` date NOT NULL,
  `end_date` date NOT NULL,
  `comment_count` int unsigned DEFAULT '0',
  `tag_count` int unsigned DEFAULT '0',
  `podcast_url` varchar(300) DEFAULT NULL,
  `archive_url` varchar(300) DEFAULT NULL,
  `media_url` varchar(300) DEFAULT NULL,
  `project` varchar(64) DEFAULT NULL,
  `location` varchar(100) DEFAULT NULL,
  `user_title` varchar(200) DEFAULT NULL,
  `user_excerpt` longtext,
  `html_topic` longtext,
  `topic` longtext,
  `published` tinyint unsigned DEFAULT NULL,
  `playout` tinyint unsigned DEFAULT NULL,
  `archived` tinyint unsigned DEFAULT NULL,
  `draft` tinyint unsigned NOT NULL DEFAULT '0',
  `rerun` int unsigned DEFAULT NULL,
  `live` tinyint unsigned DEFAULT NULL,
  `recurrence_count` int unsigned NOT NULL DEFAULT '0',
  `recurrence` int DEFAULT '0',
  `image` varchar(200) DEFAULT NULL,
  `image_label` varchar(200) DEFAULT NULL,
  `series_image` varchar(200) DEFAULT NULL,
  `series_image_label` varchar(200) DEFAULT NULL,
  `reference` varchar(300) DEFAULT NULL,
  `disable_event_sync` tinyint unsigned DEFAULT NULL,
  `content_format` varchar(45) DEFAULT NULL,
  `listen_key` varchar(100) DEFAULT NULL,
  `upload_status` varchar(45) DEFAULT NULL,
  `created_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `modified_by` varchar(20) DEFAULT NULL,
  `modified_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `end` (`end`),
  KEY `start` (`start`),
  KEY `start_date` (`start_date`),
  KEY `status` (`status`),
  KEY `modified_at` (`modified_at`),
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
) ENGINE=MyISAM AUTO_INCREMENT=56905 DEFAULT CHARSET=utf8mb3;
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
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `calcms_images` (
  `id` int unsigned NOT NULL AUTO_INCREMENT,
  `project_id` int unsigned NOT NULL,
  `studio_id` int unsigned DEFAULT NULL,
  `filename` varchar(64) NOT NULL,
  `name` varchar(300) DEFAULT NULL,
  `description` text,
  `licence` varchar(300) DEFAULT NULL,
  `public` tinyint unsigned DEFAULT '0',
  `created_by` varchar(64) DEFAULT NULL,
  `modified_by` varchar(64) DEFAULT NULL,
  `created_at` datetime DEFAULT CURRENT_TIMESTAMP,
  `modified_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `project_id` (`project_id`),
  KEY `studio_id` (`studio_id`),
  KEY `created_at` (`created_at`),
  KEY `filename` (`filename`),
  KEY `created_by` (`created_by`)
) ENGINE=MyISAM AUTO_INCREMENT=3150 DEFAULT CHARSET=utf8mb3;
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
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `calcms_metas` (
  `id` int unsigned NOT NULL AUTO_INCREMENT,
  `name` varchar(256) NOT NULL,
  `value` varchar(256) NOT NULL,
  `project` varchar(64) DEFAULT NULL,
  `event_id` int unsigned NOT NULL,
  KEY `id` (`id`),
  KEY `value` (`value`),
  KEY `project` (`project`),
  KEY `name` (`name`),
  KEY `event_id` (`event_id`)
) ENGINE=MyISAM AUTO_INCREMENT=8 DEFAULT CHARSET=utf8mb3;
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
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `calcms_password_requests` (
  `id` int unsigned NOT NULL AUTO_INCREMENT,
  `user` varchar(100) NOT NULL,
  `created_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `token` varchar(200) NOT NULL,
  `max_attempts` int unsigned NOT NULL DEFAULT '0',
  PRIMARY KEY (`id`)
) ENGINE=MyISAM AUTO_INCREMENT=168 DEFAULT CHARSET=utf8mb3;
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
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `calcms_playout` (
  `project_id` int NOT NULL,
  `studio_id` int NOT NULL,
  `start` datetime NOT NULL,
  `end` datetime NOT NULL,
  `duration` float unsigned NOT NULL,
  `start_date` date NOT NULL,
  `end_date` date NOT NULL,
  `file` varchar(300) NOT NULL,
  `errors` varchar(500) DEFAULT NULL,
  `channels` int DEFAULT NULL,
  `bitrate` int DEFAULT NULL,
  `stream_size` int DEFAULT NULL,
  `sampling_rate` int DEFAULT NULL,
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
) ENGINE=MyISAM DEFAULT CHARSET=utf8mb3;
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
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `calcms_project_series` (
  `project_id` int unsigned NOT NULL,
  `studio_id` int unsigned NOT NULL,
  `series_id` int unsigned NOT NULL,
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
INSERT INTO `calcms_project_series` (`project_id`, `studio_id`, `series_id`) VALUES (1,1,1);
INSERT INTO `calcms_project_series` (`project_id`, `studio_id`, `series_id`) VALUES (1,1,1223);
/*!40000 ALTER TABLE `calcms_project_series` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `calcms_project_studios`
--

DROP TABLE IF EXISTS `calcms_project_studios`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `calcms_project_studios` (
  `project_id` int unsigned NOT NULL,
  `studio_id` int unsigned NOT NULL,
  PRIMARY KEY (`project_id`,`studio_id`),
  KEY `project_id` (`project_id`),
  KEY `studio_id` (`studio_id`)
) ENGINE=MyISAM DEFAULT CHARSET=utf8mb3;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `calcms_project_studios`
--

LOCK TABLES `calcms_project_studios` WRITE;
/*!40000 ALTER TABLE `calcms_project_studios` DISABLE KEYS */;
INSERT INTO `calcms_project_studios` (`project_id`, `studio_id`) VALUES (1,1);
/*!40000 ALTER TABLE `calcms_project_studios` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `calcms_projects`
--

DROP TABLE IF EXISTS `calcms_projects`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `calcms_projects` (
  `project_id` int NOT NULL AUTO_INCREMENT,
  `name` varchar(32) NOT NULL,
  `title` varchar(100) DEFAULT NULL,
  `start_date` date NOT NULL,
  `end_date` date NOT NULL,
  `subtitle` varchar(100) DEFAULT NULL,
  `image` varchar(100) DEFAULT NULL,
  `email` varchar(100) DEFAULT NULL,
  PRIMARY KEY (`project_id`),
  KEY `name` (`name`)
) ENGINE=MyISAM AUTO_INCREMENT=101 DEFAULT CHARSET=utf8mb3;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `calcms_projects`
--

LOCK TABLES `calcms_projects` WRITE;
/*!40000 ALTER TABLE `calcms_projects` DISABLE KEYS */;
INSERT INTO `calcms_projects` (`project_id`, `name`, `title`, `start_date`, `end_date`, `subtitle`, `image`, `email`) VALUES (1,'my-project','My Project','2010-05-01','2023-12-31','This is my project','','info@my-radio.org');
/*!40000 ALTER TABLE `calcms_projects` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `calcms_roles`
--

DROP TABLE IF EXISTS `calcms_roles`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `calcms_roles` (
  `id` int unsigned NOT NULL AUTO_INCREMENT,
  `project_id` tinyint unsigned NOT NULL,
  `studio_id` int unsigned NOT NULL,
  `role` varchar(40) NOT NULL,
  `level` tinyint unsigned NOT NULL DEFAULT '0',
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  `modified_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `read_role` tinyint unsigned DEFAULT NULL,
  `update_role` tinyint unsigned DEFAULT NULL,
  `read_user_role` tinyint unsigned DEFAULT NULL,
  `create_user` tinyint unsigned DEFAULT NULL,
  `read_user` tinyint unsigned DEFAULT NULL,
  `update_user` tinyint unsigned DEFAULT NULL,
  `delete_user` tinyint unsigned DEFAULT NULL,
  `update_user_role` tinyint unsigned DEFAULT NULL,
  `disable_user` tinyint unsigned DEFAULT NULL,
  `create_project` tinyint unsigned NOT NULL,
  `read_project` tinyint unsigned NOT NULL,
  `update_project` tinyint unsigned NOT NULL,
  `delete_project` tinyint unsigned NOT NULL,
  `assign_project_studio` tinyint unsigned NOT NULL,
  `create_studio` tinyint unsigned NOT NULL,
  `read_studio` tinyint unsigned NOT NULL,
  `update_studio` tinyint unsigned DEFAULT NULL,
  `delete_studio` tinyint unsigned NOT NULL,
  `read_studio_timeslot_schedule` tinyint unsigned NOT NULL,
  `update_studio_timeslot_schedule` tinyint unsigned NOT NULL,
  `create_series` tinyint unsigned DEFAULT NULL,
  `read_series` tinyint unsigned DEFAULT NULL,
  `update_series` tinyint unsigned DEFAULT NULL,
  `delete_series` tinyint unsigned DEFAULT NULL,
  `update_series_template` tinyint unsigned NOT NULL,
  `assign_series_member` tinyint unsigned NOT NULL,
  `remove_series_member` tinyint unsigned NOT NULL,
  `scan_series_events` tinyint unsigned NOT NULL,
  `assign_series_events` tinyint unsigned NOT NULL,
  `read_schedule` tinyint unsigned NOT NULL,
  `update_schedule` tinyint unsigned NOT NULL,
  `delete_schedule` tinyint unsigned NOT NULL,
  `create_event` tinyint unsigned DEFAULT NULL,
  `create_event_from_schedule` tinyint unsigned NOT NULL,
  `create_event_of_series` tinyint unsigned NOT NULL,
  `read_event` tinyint unsigned DEFAULT NULL,
  `delete_event` tinyint unsigned DEFAULT NULL,
  `update_event_of_series` tinyint unsigned DEFAULT NULL,
  `update_event_of_others` tinyint unsigned DEFAULT NULL,
  `update_event_time` tinyint unsigned DEFAULT NULL,
  `update_event_after_week` tinyint unsigned NOT NULL,
  `update_event_field_title` tinyint unsigned NOT NULL,
  `update_event_field_title_extension` tinyint unsigned NOT NULL,
  `update_event_field_excerpt` tinyint unsigned NOT NULL,
  `update_event_field_content` tinyint unsigned NOT NULL,
  `update_event_field_content_format` tinyint unsigned NOT NULL,
  `update_event_field_description` tinyint unsigned NOT NULL,
  `update_event_field_topic` tinyint unsigned NOT NULL,
  `update_event_field_episode` tinyint unsigned NOT NULL,
  `update_event_field_excerpt_extension` tinyint unsigned NOT NULL,
  `update_event_field_image` tinyint unsigned NOT NULL,
  `update_event_field_podcast_url` tinyint unsigned NOT NULL,
  `update_event_field_archive_url` tinyint unsigned NOT NULL,
  `update_event_status_disable_event_sync` tinyint unsigned NOT NULL,
  `update_event_status_published` tinyint unsigned NOT NULL,
  `update_event_status_rerun` tinyint unsigned NOT NULL,
  `update_event_status_draft` tinyint unsigned NOT NULL,
  `update_event_status_live` tinyint unsigned NOT NULL,
  `update_event_status_playout` tinyint unsigned NOT NULL,
  `update_event_status_archived` tinyint unsigned NOT NULL,
  `create_image` tinyint unsigned NOT NULL,
  `update_image_own` tinyint unsigned NOT NULL,
  `read_image` tinyint unsigned NOT NULL,
  `delete_image_own` tinyint unsigned NOT NULL,
  `update_image_others` tinyint unsigned NOT NULL,
  `delete_image_others` tinyint unsigned NOT NULL,
  `read_changes` tinyint unsigned NOT NULL,
  `undo_changes` tinyint unsigned NOT NULL,
  `read_user_stats` tinyint unsigned NOT NULL,
  `read_comment` tinyint unsigned NOT NULL,
  `update_comment_status_lock` tinyint unsigned NOT NULL,
  `update_comment_status_read` tinyint unsigned NOT NULL,
  `upload_audio_recordings` tinyint unsigned NOT NULL,
  `delete_audio_recordings` tinyint unsigned NOT NULL,
  `read_playout` tinyint unsigned NOT NULL,
  `create_download` tinyint unsigned NOT NULL,
  `edit_help_texts` INT(1) UNSIGNED NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `role_2` (`role`),
  KEY `project_id` (`project_id`),
  KEY `studio_id` (`studio_id`),
  KEY `role` (`role`)
) ENGINE=MyISAM AUTO_INCREMENT=97 DEFAULT CHARSET=utf8mb3;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `calcms_roles`
--

LOCK TABLES `calcms_roles` WRITE;
/*!40000 ALTER TABLE `calcms_roles` DISABLE KEYS */;
INSERT INTO `calcms_roles` (`id`, `project_id`, `studio_id`, `role`, `level`, `created_at`, `modified_at`, `read_role`, `update_role`, `read_user_role`, `create_user`, `read_user`, `update_user`, `delete_user`, `update_user_role`, `disable_user`, `create_project`, `read_project`, `update_project`, `delete_project`, `assign_project_studio`, `create_studio`, `read_studio`, `update_studio`, `delete_studio`, `read_studio_timeslot_schedule`, `update_studio_timeslot_schedule`, `create_series`, `read_series`, `update_series`, `delete_series`, `update_series_template`, `assign_series_member`, `remove_series_member`, `scan_series_events`, `assign_series_events`, `read_schedule`, `update_schedule`, `delete_schedule`, `create_event`, `create_event_from_schedule`, `create_event_of_series`, `read_event`, `delete_event`, `update_event_of_series`, `update_event_of_others`, `update_event_time`, `update_event_after_week`, `update_event_field_title`, `update_event_field_title_extension`, `update_event_field_excerpt`, `update_event_field_content`, `update_event_field_content_format`, `update_event_field_description`, `update_event_field_topic`, `update_event_field_episode`, `update_event_field_excerpt_extension`, `update_event_field_image`, `update_event_field_podcast_url`, `update_event_field_archive_url`, `update_event_status_disable_event_sync`, `update_event_status_published`, `update_event_status_rerun`, `update_event_status_draft`, `update_event_status_live`, `update_event_status_playout`, `update_event_status_archived`, `create_image`, `update_image_own`, `read_image`, `delete_image_own`, `update_image_others`, `delete_image_others`, `read_changes`, `undo_changes`, `read_user_stats`, `read_comment`, `update_comment_status_lock`, `update_comment_status_read`, `upload_audio_recordings`, `delete_audio_recordings`, `read_playout`, `create_download`) VALUES (7,1,1,'Admin',7,NULL,'2023-02-19 21:32:32',1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,0,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1);
INSERT INTO `calcms_roles` (`id`, `project_id`, `studio_id`, `role`, `level`, `created_at`, `modified_at`, `read_role`, `update_role`, `read_user_role`, `create_user`, `read_user`, `update_user`, `delete_user`, `update_user_role`, `disable_user`, `create_project`, `read_project`, `update_project`, `delete_project`, `assign_project_studio`, `create_studio`, `read_studio`, `update_studio`, `delete_studio`, `read_studio_timeslot_schedule`, `update_studio_timeslot_schedule`, `create_series`, `read_series`, `update_series`, `delete_series`, `update_series_template`, `assign_series_member`, `remove_series_member`, `scan_series_events`, `assign_series_events`, `read_schedule`, `update_schedule`, `delete_schedule`, `create_event`, `create_event_from_schedule`, `create_event_of_series`, `read_event`, `delete_event`, `update_event_of_series`, `update_event_of_others`, `update_event_time`, `update_event_after_week`, `update_event_field_title`, `update_event_field_title_extension`, `update_event_field_excerpt`, `update_event_field_content`, `update_event_field_content_format`, `update_event_field_description`, `update_event_field_topic`, `update_event_field_episode`, `update_event_field_excerpt_extension`, `update_event_field_image`, `update_event_field_podcast_url`, `update_event_field_archive_url`, `update_event_status_disable_event_sync`, `update_event_status_published`, `update_event_status_rerun`, `update_event_status_draft`, `update_event_status_live`, `update_event_status_playout`, `update_event_status_archived`, `create_image`, `update_image_own`, `read_image`, `delete_image_own`, `update_image_others`, `delete_image_others`, `read_changes`, `undo_changes`, `read_user_stats`, `read_comment`, `update_comment_status_lock`, `update_comment_status_read`, `upload_audio_recordings`, `delete_audio_recordings`, `read_playout`, `create_download`) VALUES (3,1,1,'Studio Manager',6,NULL,'2023-02-19 21:32:32',1,1,1,1,1,1,1,1,1,0,1,0,0,0,0,1,1,0,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,0,1,1,1,1,1,0,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,0,0,0,0,0,0,1,0,1,1,0,0,1,1,1,1);
INSERT INTO `calcms_roles` (`id`, `project_id`, `studio_id`, `role`, `level`, `created_at`, `modified_at`, `read_role`, `update_role`, `read_user_role`, `create_user`, `read_user`, `update_user`, `delete_user`, `update_user_role`, `disable_user`, `create_project`, `read_project`, `update_project`, `delete_project`, `assign_project_studio`, `create_studio`, `read_studio`, `update_studio`, `delete_studio`, `read_studio_timeslot_schedule`, `update_studio_timeslot_schedule`, `create_series`, `read_series`, `update_series`, `delete_series`, `update_series_template`, `assign_series_member`, `remove_series_member`, `scan_series_events`, `assign_series_events`, `read_schedule`, `update_schedule`, `delete_schedule`, `create_event`, `create_event_from_schedule`, `create_event_of_series`, `read_event`, `delete_event`, `update_event_of_series`, `update_event_of_others`, `update_event_time`, `update_event_after_week`, `update_event_field_title`, `update_event_field_title_extension`, `update_event_field_excerpt`, `update_event_field_content`, `update_event_field_content_format`, `update_event_field_description`, `update_event_field_topic`, `update_event_field_episode`, `update_event_field_excerpt_extension`, `update_event_field_image`, `update_event_field_podcast_url`, `update_event_field_archive_url`, `update_event_status_disable_event_sync`, `update_event_status_published`, `update_event_status_rerun`, `update_event_status_draft`, `update_event_status_live`, `update_event_status_playout`, `update_event_status_archived`, `create_image`, `update_image_own`, `read_image`, `delete_image_own`, `update_image_others`, `delete_image_others`, `read_changes`, `undo_changes`, `read_user_stats`, `read_comment`, `update_comment_status_lock`, `update_comment_status_read`, `upload_audio_recordings`, `delete_audio_recordings`, `read_playout`, `create_download`) VALUES (1,1,1,'Program Planing',4,NULL,'2023-02-19 21:32:32',1,0,1,1,1,1,0,1,0,0,0,0,0,0,0,1,0,0,1,0,1,1,1,1,1,1,1,0,1,1,1,1,1,1,0,1,1,1,1,1,0,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,0,1,1,1,1,1,0,1,1);
INSERT INTO `calcms_roles` (`id`, `project_id`, `studio_id`, `role`, `level`, `created_at`, `modified_at`, `read_role`, `update_role`, `read_user_role`, `create_user`, `read_user`, `update_user`, `delete_user`, `update_user_role`, `disable_user`, `create_project`, `read_project`, `update_project`, `delete_project`, `assign_project_studio`, `create_studio`, `read_studio`, `update_studio`, `delete_studio`, `read_studio_timeslot_schedule`, `update_studio_timeslot_schedule`, `create_series`, `read_series`, `update_series`, `delete_series`, `update_series_template`, `assign_series_member`, `remove_series_member`, `scan_series_events`, `assign_series_events`, `read_schedule`, `update_schedule`, `delete_schedule`, `create_event`, `create_event_from_schedule`, `create_event_of_series`, `read_event`, `delete_event`, `update_event_of_series`, `update_event_of_others`, `update_event_time`, `update_event_after_week`, `update_event_field_title`, `update_event_field_title_extension`, `update_event_field_excerpt`, `update_event_field_content`, `update_event_field_content_format`, `update_event_field_description`, `update_event_field_topic`, `update_event_field_episode`, `update_event_field_excerpt_extension`, `update_event_field_image`, `update_event_field_podcast_url`, `update_event_field_archive_url`, `update_event_status_disable_event_sync`, `update_event_status_published`, `update_event_status_rerun`, `update_event_status_draft`, `update_event_status_live`, `update_event_status_playout`, `update_event_status_archived`, `create_image`, `update_image_own`, `read_image`, `delete_image_own`, `update_image_others`, `delete_image_others`, `read_changes`, `undo_changes`, `read_user_stats`, `read_comment`, `update_comment_status_lock`, `update_comment_status_read`, `upload_audio_recordings`, `delete_audio_recordings`, `read_playout`, `create_download`) VALUES (2,1,1,'Editorial',2,NULL,'2023-02-19 21:32:32',0,0,0,0,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,0,0,0,0,0,0,0,1,0,0,0,0,0,1,0,1,0,0,0,0,1,0,1,0,0,1,0,1,1,0,0,0,0,0,0,1,0,0,0,0,0,0,0,0,0,0,0,1,0,0,1,0,1,1);
INSERT INTO `calcms_roles` (`id`, `project_id`, `studio_id`, `role`, `level`, `created_at`, `modified_at`, `read_role`, `update_role`, `read_user_role`, `create_user`, `read_user`, `update_user`, `delete_user`, `update_user_role`, `disable_user`, `create_project`, `read_project`, `update_project`, `delete_project`, `assign_project_studio`, `create_studio`, `read_studio`, `update_studio`, `delete_studio`, `read_studio_timeslot_schedule`, `update_studio_timeslot_schedule`, `create_series`, `read_series`, `update_series`, `delete_series`, `update_series_template`, `assign_series_member`, `remove_series_member`, `scan_series_events`, `assign_series_events`, `read_schedule`, `update_schedule`, `delete_schedule`, `create_event`, `create_event_from_schedule`, `create_event_of_series`, `read_event`, `delete_event`, `update_event_of_series`, `update_event_of_others`, `update_event_time`, `update_event_after_week`, `update_event_field_title`, `update_event_field_title_extension`, `update_event_field_excerpt`, `update_event_field_content`, `update_event_field_content_format`, `update_event_field_description`, `update_event_field_topic`, `update_event_field_episode`, `update_event_field_excerpt_extension`, `update_event_field_image`, `update_event_field_podcast_url`, `update_event_field_archive_url`, `update_event_status_disable_event_sync`, `update_event_status_published`, `update_event_status_rerun`, `update_event_status_draft`, `update_event_status_live`, `update_event_status_playout`, `update_event_status_archived`, `create_image`, `update_image_own`, `read_image`, `delete_image_own`, `update_image_others`, `delete_image_others`, `read_changes`, `undo_changes`, `read_user_stats`, `read_comment`, `update_comment_status_lock`, `update_comment_status_read`, `upload_audio_recordings`, `delete_audio_recordings`, `read_playout`, `create_download`) VALUES (25,1,1,'Guest',1,NULL,'2023-02-19 21:32:32',0,0,0,0,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,0,0,0,0,0,0,0,1,0,0,0,0,0,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0);
/*!40000 ALTER TABLE `calcms_roles` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `calcms_series`
--

DROP TABLE IF EXISTS `calcms_series`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `calcms_series` (
  `id` int unsigned NOT NULL AUTO_INCREMENT,
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
  `category` varchar(60) DEFAULT NULL,
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  `assign_event_series_name` varchar(100) DEFAULT NULL,
  `assign_event_title` varchar(100) DEFAULT NULL,
  `default_duration` int unsigned DEFAULT NULL,
  `comment` longtext,
  `live` tinyint unsigned DEFAULT NULL,
  `archive_url` varchar(300) DEFAULT NULL,
  `podcast_url` varchar(300) DEFAULT NULL,
  `count_episodes` tinyint unsigned DEFAULT '1',
  `has_single_events` tinyint unsigned DEFAULT '0',
  `predecessor_id` int DEFAULT NULL,
  `content_format` varchar(45) DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `location` (`location`)
) ENGINE=MyISAM AUTO_INCREMENT=1224 DEFAULT CHARSET=utf8mb3;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `calcms_series`
--

LOCK TABLES `calcms_series` WRITE;
/*!40000 ALTER TABLE `calcms_series` DISABLE KEYS */;
INSERT INTO `calcms_series` (`id`, `series_name`, `title`, `excerpt`, `content`, `html_content`, `topic`, `program`, `image`, `project`, `location`, `modified_at`, `modified_by`, `category`, `created_at`, `assign_event_series_name`, `assign_event_title`, `default_duration`, `comment`, `live`, `archive_url`, `podcast_url`, `count_episodes`, `has_single_events`, `predecessor_id`, `content_format`) VALUES (1,'Night Train','Is Coming','','','\n','','','p5skauKk_DoI_lsrsBfxiw.jpg',NULL,NULL,'2023-02-19 21:33:05','ccAdmin',NULL,NULL,'Berliner Runde','Hauptstadtteam',60,'',0,'','',0,0,0,'markdown');
INSERT INTO `calcms_series` (`id`, `series_name`, `title`, `excerpt`, `content`, `html_content`, `topic`, `program`, `image`, `project`, `location`, `modified_at`, `modified_by`, `category`, `created_at`, `assign_event_series_name`, `assign_event_title`, `default_duration`, `comment`, `live`, `archive_url`, `podcast_url`, `count_episodes`, `has_single_events`, `predecessor_id`, `content_format`) VALUES (1223,'_single_',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,'2023-02-19 21:17:18','ccAdmin',NULL,'2023-02-19 21:17:18',NULL,NULL,NULL,NULL,NULL,NULL,NULL,0,1,NULL,NULL);
/*!40000 ALTER TABLE `calcms_series` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `calcms_series_dates`
--

DROP TABLE IF EXISTS `calcms_series_dates`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `calcms_series_dates` (
  `id` int unsigned NOT NULL AUTO_INCREMENT,
  `project_id` int unsigned NOT NULL,
  `studio_id` int unsigned NOT NULL,
  `series_id` int unsigned NOT NULL,
  `start` timestamp NOT NULL DEFAULT '0000-00-00 00:00:00',
  `end` timestamp NOT NULL DEFAULT '0000-00-00 00:00:00',
  `start_date` date NOT NULL,
  `end_date` date NOT NULL,
  `exclude` tinyint(1) NOT NULL DEFAULT '0',
  `series_schedule_id` int unsigned NOT NULL,
  PRIMARY KEY (`id`),
  KEY `project_id` (`project_id`),
  KEY `studio_id` (`studio_id`),
  KEY `series_id` (`series_id`),
  KEY `start` (`start`) USING BTREE,
  KEY `end` (`end`) USING BTREE,
  KEY `start_date` (`start_date`),
  KEY `end_date` (`end_date`)
) ENGINE=MyISAM AUTO_INCREMENT=614255 DEFAULT CHARSET=utf8mb3;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `calcms_series_dates`
--

LOCK TABLES `calcms_series_dates` WRITE;
/*!40000 ALTER TABLE `calcms_series_dates` DISABLE KEYS */;
INSERT INTO `calcms_series_dates` (`id`, `project_id`, `studio_id`, `series_id`, `start`, `end`, `start_date`, `end_date`, `exclude`, `series_schedule_id`) VALUES (614202,1,1,1,'2023-11-15 11:00:00','2023-11-15 12:00:00','2023-11-15','2023-11-15',0,9729);
INSERT INTO `calcms_series_dates` (`id`, `project_id`, `studio_id`, `series_id`, `start`, `end`, `start_date`, `end_date`, `exclude`, `series_schedule_id`) VALUES (614203,1,1,1,'2023-04-12 10:00:00','2023-04-12 11:00:00','2023-04-12','2023-04-12',0,9729);
INSERT INTO `calcms_series_dates` (`id`, `project_id`, `studio_id`, `series_id`, `start`, `end`, `start_date`, `end_date`, `exclude`, `series_schedule_id`) VALUES (614204,1,1,1,'2023-07-12 10:00:00','2023-07-12 11:00:00','2023-07-12','2023-07-12',0,9729);
INSERT INTO `calcms_series_dates` (`id`, `project_id`, `studio_id`, `series_id`, `start`, `end`, `start_date`, `end_date`, `exclude`, `series_schedule_id`) VALUES (614205,1,1,1,'2023-02-08 11:00:00','2023-02-08 12:00:00','2023-02-08','2023-02-08',0,9729);
INSERT INTO `calcms_series_dates` (`id`, `project_id`, `studio_id`, `series_id`, `start`, `end`, `start_date`, `end_date`, `exclude`, `series_schedule_id`) VALUES (614206,1,1,1,'2023-06-07 10:00:00','2023-06-07 11:00:00','2023-06-07','2023-06-07',0,9729);
INSERT INTO `calcms_series_dates` (`id`, `project_id`, `studio_id`, `series_id`, `start`, `end`, `start_date`, `end_date`, `exclude`, `series_schedule_id`) VALUES (614207,1,1,1,'2023-03-29 10:00:00','2023-03-29 11:00:00','2023-03-29','2023-03-29',0,9729);
INSERT INTO `calcms_series_dates` (`id`, `project_id`, `studio_id`, `series_id`, `start`, `end`, `start_date`, `end_date`, `exclude`, `series_schedule_id`) VALUES (614208,1,1,1,'2023-12-06 11:00:00','2023-12-06 12:00:00','2023-12-06','2023-12-06',0,9729);
INSERT INTO `calcms_series_dates` (`id`, `project_id`, `studio_id`, `series_id`, `start`, `end`, `start_date`, `end_date`, `exclude`, `series_schedule_id`) VALUES (614209,1,1,1,'2023-09-20 10:00:00','2023-09-20 11:00:00','2023-09-20','2023-09-20',0,9729);
INSERT INTO `calcms_series_dates` (`id`, `project_id`, `studio_id`, `series_id`, `start`, `end`, `start_date`, `end_date`, `exclude`, `series_schedule_id`) VALUES (614210,1,1,1,'2024-01-31 11:00:00','2024-01-31 12:00:00','2024-01-31','2024-01-31',0,9729);
INSERT INTO `calcms_series_dates` (`id`, `project_id`, `studio_id`, `series_id`, `start`, `end`, `start_date`, `end_date`, `exclude`, `series_schedule_id`) VALUES (614211,1,1,1,'2023-05-03 10:00:00','2023-05-03 11:00:00','2023-05-03','2023-05-03',0,9729);
INSERT INTO `calcms_series_dates` (`id`, `project_id`, `studio_id`, `series_id`, `start`, `end`, `start_date`, `end_date`, `exclude`, `series_schedule_id`) VALUES (614212,1,1,1,'2023-02-22 11:00:00','2023-02-22 12:00:00','2023-02-22','2023-02-22',0,9729);
INSERT INTO `calcms_series_dates` (`id`, `project_id`, `studio_id`, `series_id`, `start`, `end`, `start_date`, `end_date`, `exclude`, `series_schedule_id`) VALUES (614213,1,1,1,'2023-09-27 10:00:00','2023-09-27 11:00:00','2023-09-27','2023-09-27',0,9729);
INSERT INTO `calcms_series_dates` (`id`, `project_id`, `studio_id`, `series_id`, `start`, `end`, `start_date`, `end_date`, `exclude`, `series_schedule_id`) VALUES (614214,1,1,1,'2023-11-22 11:00:00','2023-11-22 12:00:00','2023-11-22','2023-11-22',0,9729);
INSERT INTO `calcms_series_dates` (`id`, `project_id`, `studio_id`, `series_id`, `start`, `end`, `start_date`, `end_date`, `exclude`, `series_schedule_id`) VALUES (614215,1,1,1,'2023-09-13 10:00:00','2023-09-13 11:00:00','2023-09-13','2023-09-13',0,9729);
INSERT INTO `calcms_series_dates` (`id`, `project_id`, `studio_id`, `series_id`, `start`, `end`, `start_date`, `end_date`, `exclude`, `series_schedule_id`) VALUES (614216,1,1,1,'2023-10-11 10:00:00','2023-10-11 11:00:00','2023-10-11','2023-10-11',0,9729);
INSERT INTO `calcms_series_dates` (`id`, `project_id`, `studio_id`, `series_id`, `start`, `end`, `start_date`, `end_date`, `exclude`, `series_schedule_id`) VALUES (614217,1,1,1,'2023-08-02 10:00:00','2023-08-02 11:00:00','2023-08-02','2023-08-02',0,9729);
INSERT INTO `calcms_series_dates` (`id`, `project_id`, `studio_id`, `series_id`, `start`, `end`, `start_date`, `end_date`, `exclude`, `series_schedule_id`) VALUES (614218,1,1,1,'2023-08-23 10:00:00','2023-08-23 11:00:00','2023-08-23','2023-08-23',0,9729);
INSERT INTO `calcms_series_dates` (`id`, `project_id`, `studio_id`, `series_id`, `start`, `end`, `start_date`, `end_date`, `exclude`, `series_schedule_id`) VALUES (614219,1,1,1,'2023-06-21 10:00:00','2023-06-21 11:00:00','2023-06-21','2023-06-21',0,9729);
INSERT INTO `calcms_series_dates` (`id`, `project_id`, `studio_id`, `series_id`, `start`, `end`, `start_date`, `end_date`, `exclude`, `series_schedule_id`) VALUES (614220,1,1,1,'2024-01-24 11:00:00','2024-01-24 12:00:00','2024-01-24','2024-01-24',0,9729);
INSERT INTO `calcms_series_dates` (`id`, `project_id`, `studio_id`, `series_id`, `start`, `end`, `start_date`, `end_date`, `exclude`, `series_schedule_id`) VALUES (614221,1,1,1,'2023-05-10 10:00:00','2023-05-10 11:00:00','2023-05-10','2023-05-10',0,9729);
INSERT INTO `calcms_series_dates` (`id`, `project_id`, `studio_id`, `series_id`, `start`, `end`, `start_date`, `end_date`, `exclude`, `series_schedule_id`) VALUES (614222,1,1,1,'2023-02-15 11:00:00','2023-02-15 12:00:00','2023-02-15','2023-02-15',0,9729);
INSERT INTO `calcms_series_dates` (`id`, `project_id`, `studio_id`, `series_id`, `start`, `end`, `start_date`, `end_date`, `exclude`, `series_schedule_id`) VALUES (614223,1,1,1,'2023-03-01 11:00:00','2023-03-01 12:00:00','2023-03-01','2023-03-01',0,9729);
INSERT INTO `calcms_series_dates` (`id`, `project_id`, `studio_id`, `series_id`, `start`, `end`, `start_date`, `end_date`, `exclude`, `series_schedule_id`) VALUES (614224,1,1,1,'2023-11-08 11:00:00','2023-11-08 12:00:00','2023-11-08','2023-11-08',0,9729);
INSERT INTO `calcms_series_dates` (`id`, `project_id`, `studio_id`, `series_id`, `start`, `end`, `start_date`, `end_date`, `exclude`, `series_schedule_id`) VALUES (614225,1,1,1,'2023-05-17 10:00:00','2023-05-17 11:00:00','2023-05-17','2023-05-17',0,9729);
INSERT INTO `calcms_series_dates` (`id`, `project_id`, `studio_id`, `series_id`, `start`, `end`, `start_date`, `end_date`, `exclude`, `series_schedule_id`) VALUES (614226,1,1,1,'2023-07-05 10:00:00','2023-07-05 11:00:00','2023-07-05','2023-07-05',0,9729);
INSERT INTO `calcms_series_dates` (`id`, `project_id`, `studio_id`, `series_id`, `start`, `end`, `start_date`, `end_date`, `exclude`, `series_schedule_id`) VALUES (614227,1,1,1,'2023-04-05 10:00:00','2023-04-05 11:00:00','2023-04-05','2023-04-05',0,9729);
INSERT INTO `calcms_series_dates` (`id`, `project_id`, `studio_id`, `series_id`, `start`, `end`, `start_date`, `end_date`, `exclude`, `series_schedule_id`) VALUES (614228,1,1,1,'2023-07-19 10:00:00','2023-07-19 11:00:00','2023-07-19','2023-07-19',0,9729);
INSERT INTO `calcms_series_dates` (`id`, `project_id`, `studio_id`, `series_id`, `start`, `end`, `start_date`, `end_date`, `exclude`, `series_schedule_id`) VALUES (614229,1,1,1,'2023-04-19 10:00:00','2023-04-19 11:00:00','2023-04-19','2023-04-19',0,9729);
INSERT INTO `calcms_series_dates` (`id`, `project_id`, `studio_id`, `series_id`, `start`, `end`, `start_date`, `end_date`, `exclude`, `series_schedule_id`) VALUES (614230,1,1,1,'2023-08-30 10:00:00','2023-08-30 11:00:00','2023-08-30','2023-08-30',0,9729);
INSERT INTO `calcms_series_dates` (`id`, `project_id`, `studio_id`, `series_id`, `start`, `end`, `start_date`, `end_date`, `exclude`, `series_schedule_id`) VALUES (614231,1,1,1,'2023-10-18 10:00:00','2023-10-18 11:00:00','2023-10-18','2023-10-18',0,9729);
INSERT INTO `calcms_series_dates` (`id`, `project_id`, `studio_id`, `series_id`, `start`, `end`, `start_date`, `end_date`, `exclude`, `series_schedule_id`) VALUES (614232,1,1,1,'2023-03-22 11:00:00','2023-03-22 12:00:00','2023-03-22','2023-03-22',0,9729);
INSERT INTO `calcms_series_dates` (`id`, `project_id`, `studio_id`, `series_id`, `start`, `end`, `start_date`, `end_date`, `exclude`, `series_schedule_id`) VALUES (614233,1,1,1,'2023-12-27 11:00:00','2023-12-27 12:00:00','2023-12-27','2023-12-27',0,9729);
INSERT INTO `calcms_series_dates` (`id`, `project_id`, `studio_id`, `series_id`, `start`, `end`, `start_date`, `end_date`, `exclude`, `series_schedule_id`) VALUES (614234,1,1,1,'2023-06-14 10:00:00','2023-06-14 11:00:00','2023-06-14','2023-06-14',0,9729);
INSERT INTO `calcms_series_dates` (`id`, `project_id`, `studio_id`, `series_id`, `start`, `end`, `start_date`, `end_date`, `exclude`, `series_schedule_id`) VALUES (614235,1,1,1,'2023-08-16 10:00:00','2023-08-16 11:00:00','2023-08-16','2023-08-16',0,9729);
INSERT INTO `calcms_series_dates` (`id`, `project_id`, `studio_id`, `series_id`, `start`, `end`, `start_date`, `end_date`, `exclude`, `series_schedule_id`) VALUES (614236,1,1,1,'2023-03-08 11:00:00','2023-03-08 12:00:00','2023-03-08','2023-03-08',0,9729);
INSERT INTO `calcms_series_dates` (`id`, `project_id`, `studio_id`, `series_id`, `start`, `end`, `start_date`, `end_date`, `exclude`, `series_schedule_id`) VALUES (614237,1,1,1,'2024-01-03 11:00:00','2024-01-03 12:00:00','2024-01-03','2024-01-03',0,9729);
INSERT INTO `calcms_series_dates` (`id`, `project_id`, `studio_id`, `series_id`, `start`, `end`, `start_date`, `end_date`, `exclude`, `series_schedule_id`) VALUES (614238,1,1,1,'2023-05-31 10:00:00','2023-05-31 11:00:00','2023-05-31','2023-05-31',0,9729);
INSERT INTO `calcms_series_dates` (`id`, `project_id`, `studio_id`, `series_id`, `start`, `end`, `start_date`, `end_date`, `exclude`, `series_schedule_id`) VALUES (614239,1,1,1,'2023-11-01 11:00:00','2023-11-01 12:00:00','2023-11-01','2023-11-01',0,9729);
INSERT INTO `calcms_series_dates` (`id`, `project_id`, `studio_id`, `series_id`, `start`, `end`, `start_date`, `end_date`, `exclude`, `series_schedule_id`) VALUES (614240,1,1,1,'2023-09-06 10:00:00','2023-09-06 11:00:00','2023-09-06','2023-09-06',0,9729);
INSERT INTO `calcms_series_dates` (`id`, `project_id`, `studio_id`, `series_id`, `start`, `end`, `start_date`, `end_date`, `exclude`, `series_schedule_id`) VALUES (614241,1,1,1,'2023-12-20 11:00:00','2023-12-20 12:00:00','2023-12-20','2023-12-20',0,9729);
INSERT INTO `calcms_series_dates` (`id`, `project_id`, `studio_id`, `series_id`, `start`, `end`, `start_date`, `end_date`, `exclude`, `series_schedule_id`) VALUES (614242,1,1,1,'2023-06-28 10:00:00','2023-06-28 11:00:00','2023-06-28','2023-06-28',0,9729);
INSERT INTO `calcms_series_dates` (`id`, `project_id`, `studio_id`, `series_id`, `start`, `end`, `start_date`, `end_date`, `exclude`, `series_schedule_id`) VALUES (614243,1,1,1,'2023-10-04 10:00:00','2023-10-04 11:00:00','2023-10-04','2023-10-04',0,9729);
INSERT INTO `calcms_series_dates` (`id`, `project_id`, `studio_id`, `series_id`, `start`, `end`, `start_date`, `end_date`, `exclude`, `series_schedule_id`) VALUES (614244,1,1,1,'2023-11-29 11:00:00','2023-11-29 12:00:00','2023-11-29','2023-11-29',0,9729);
INSERT INTO `calcms_series_dates` (`id`, `project_id`, `studio_id`, `series_id`, `start`, `end`, `start_date`, `end_date`, `exclude`, `series_schedule_id`) VALUES (614245,1,1,1,'2023-08-09 10:00:00','2023-08-09 11:00:00','2023-08-09','2023-08-09',0,9729);
INSERT INTO `calcms_series_dates` (`id`, `project_id`, `studio_id`, `series_id`, `start`, `end`, `start_date`, `end_date`, `exclude`, `series_schedule_id`) VALUES (614246,1,1,1,'2023-10-25 10:00:00','2023-10-25 11:00:00','2023-10-25','2023-10-25',0,9729);
INSERT INTO `calcms_series_dates` (`id`, `project_id`, `studio_id`, `series_id`, `start`, `end`, `start_date`, `end_date`, `exclude`, `series_schedule_id`) VALUES (614247,1,1,1,'2023-02-01 11:00:00','2023-02-01 12:00:00','2023-02-01','2023-02-01',0,9729);
INSERT INTO `calcms_series_dates` (`id`, `project_id`, `studio_id`, `series_id`, `start`, `end`, `start_date`, `end_date`, `exclude`, `series_schedule_id`) VALUES (614248,1,1,1,'2023-12-13 11:00:00','2023-12-13 12:00:00','2023-12-13','2023-12-13',0,9729);
INSERT INTO `calcms_series_dates` (`id`, `project_id`, `studio_id`, `series_id`, `start`, `end`, `start_date`, `end_date`, `exclude`, `series_schedule_id`) VALUES (614249,1,1,1,'2023-03-15 11:00:00','2023-03-15 12:00:00','2023-03-15','2023-03-15',0,9729);
INSERT INTO `calcms_series_dates` (`id`, `project_id`, `studio_id`, `series_id`, `start`, `end`, `start_date`, `end_date`, `exclude`, `series_schedule_id`) VALUES (614250,1,1,1,'2023-04-26 10:00:00','2023-04-26 11:00:00','2023-04-26','2023-04-26',0,9729);
INSERT INTO `calcms_series_dates` (`id`, `project_id`, `studio_id`, `series_id`, `start`, `end`, `start_date`, `end_date`, `exclude`, `series_schedule_id`) VALUES (614251,1,1,1,'2023-07-26 10:00:00','2023-07-26 11:00:00','2023-07-26','2023-07-26',0,9729);
INSERT INTO `calcms_series_dates` (`id`, `project_id`, `studio_id`, `series_id`, `start`, `end`, `start_date`, `end_date`, `exclude`, `series_schedule_id`) VALUES (614252,1,1,1,'2024-01-17 11:00:00','2024-01-17 12:00:00','2024-01-17','2024-01-17',0,9729);
INSERT INTO `calcms_series_dates` (`id`, `project_id`, `studio_id`, `series_id`, `start`, `end`, `start_date`, `end_date`, `exclude`, `series_schedule_id`) VALUES (614253,1,1,1,'2023-05-24 10:00:00','2023-05-24 11:00:00','2023-05-24','2023-05-24',0,9729);
INSERT INTO `calcms_series_dates` (`id`, `project_id`, `studio_id`, `series_id`, `start`, `end`, `start_date`, `end_date`, `exclude`, `series_schedule_id`) VALUES (614254,1,1,1,'2024-01-10 11:00:00','2024-01-10 12:00:00','2024-01-10','2024-01-10',0,9729);
/*!40000 ALTER TABLE `calcms_series_dates` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `calcms_series_events`
--

DROP TABLE IF EXISTS `calcms_series_events`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `calcms_series_events` (
  `project_id` int unsigned NOT NULL,
  `studio_id` int unsigned NOT NULL,
  `series_id` int unsigned NOT NULL,
  `event_id` int unsigned NOT NULL,
  `manual` int unsigned NOT NULL,
  KEY `project_id` (`project_id`),
  KEY `studio_id` (`studio_id`),
  KEY `series_id` (`series_id`),
  KEY `event_id` (`event_id`),
  KEY `manual` (`manual`),
  KEY `pse` (`project_id`,`studio_id`,`event_id`)
) ENGINE=MyISAM DEFAULT CHARSET=utf8mb3;
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
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `calcms_series_schedule` (
  `id` int unsigned NOT NULL AUTO_INCREMENT,
  `project_id` int unsigned NOT NULL DEFAULT '1',
  `studio_id` int unsigned DEFAULT NULL,
  `series_id` int unsigned NOT NULL,
  `start` datetime NOT NULL,
  `end` date DEFAULT NULL,
  `frequency` int unsigned DEFAULT NULL,
  `duration` int unsigned DEFAULT NULL,
  `exclude` tinyint unsigned DEFAULT NULL,
  `weekday` int unsigned DEFAULT NULL,
  `week_of_month` int unsigned DEFAULT NULL,
  `period_type` varchar(16) DEFAULT NULL,
  `month` int unsigned NOT NULL DEFAULT '0',
  `start_offset` int DEFAULT '0',
  `nextDay` int DEFAULT '0',
  PRIMARY KEY (`id`),
  KEY `project_id` (`project_id`),
  KEY `studio_id` (`studio_id`),
  KEY `series_id` (`series_id`),
  KEY `start` (`start`) USING BTREE,
  KEY `end` (`end`) USING BTREE
) ENGINE=MyISAM AUTO_INCREMENT=9730 DEFAULT CHARSET=utf8mb3;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `calcms_series_schedule`
--

LOCK TABLES `calcms_series_schedule` WRITE;
/*!40000 ALTER TABLE `calcms_series_schedule` DISABLE KEYS */;
INSERT INTO `calcms_series_schedule` (`id`, `project_id`, `studio_id`, `series_id`, `start`, `end`, `frequency`, `duration`, `exclude`, `weekday`, `week_of_month`, `period_type`, `month`, `start_offset`, `nextDay`) VALUES (9729,1,1,1,'2023-02-01 12:00:00','2024-02-29',7,60,0,1,1,'days',1,0,0);
/*!40000 ALTER TABLE `calcms_series_schedule` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `calcms_studio_timeslot_dates`
--

DROP TABLE IF EXISTS `calcms_studio_timeslot_dates`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `calcms_studio_timeslot_dates` (
  `project_id` int unsigned NOT NULL,
  `studio_id` int unsigned NOT NULL,
  `schedule_id` int unsigned NOT NULL,
  `start` datetime NOT NULL,
  `end` datetime NOT NULL,
  `start_date` date NOT NULL,
  `end_date` date NOT NULL,
  PRIMARY KEY (`project_id`,`studio_id`,`start`,`end`) USING BTREE,
  KEY `project_id` (`project_id`),
  KEY `studio_id` (`studio_id`),
  KEY `schedule_id` (`schedule_id`),
  KEY `start_date` (`start_date`),
  KEY `end_date` (`end_date`),
  KEY `start` (`start`),
  KEY `end` (`end`)
) ENGINE=MyISAM DEFAULT CHARSET=utf8mb3;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `calcms_studio_timeslot_dates`
--

LOCK TABLES `calcms_studio_timeslot_dates` WRITE;
/*!40000 ALTER TABLE `calcms_studio_timeslot_dates` DISABLE KEYS */;
INSERT INTO `calcms_studio_timeslot_dates` (`project_id`, `studio_id`, `schedule_id`, `start`, `end`, `start_date`, `end_date`) VALUES (1,1,152,'2023-07-12 12:00:00','2023-07-13 12:00:00','2023-07-12','2023-07-13');
INSERT INTO `calcms_studio_timeslot_dates` (`project_id`, `studio_id`, `schedule_id`, `start`, `end`, `start_date`, `end_date`) VALUES (1,1,152,'2023-05-14 12:00:00','2023-05-15 12:00:00','2023-05-14','2023-05-15');
INSERT INTO `calcms_studio_timeslot_dates` (`project_id`, `studio_id`, `schedule_id`, `start`, `end`, `start_date`, `end_date`) VALUES (1,1,152,'2023-02-11 12:00:00','2023-02-12 12:00:00','2023-02-11','2023-02-12');
INSERT INTO `calcms_studio_timeslot_dates` (`project_id`, `studio_id`, `schedule_id`, `start`, `end`, `start_date`, `end_date`) VALUES (1,1,152,'2023-07-30 12:00:00','2023-07-31 12:00:00','2023-07-30','2023-07-31');
INSERT INTO `calcms_studio_timeslot_dates` (`project_id`, `studio_id`, `schedule_id`, `start`, `end`, `start_date`, `end_date`) VALUES (1,1,152,'2023-07-04 12:00:00','2023-07-05 12:00:00','2023-07-04','2023-07-05');
INSERT INTO `calcms_studio_timeslot_dates` (`project_id`, `studio_id`, `schedule_id`, `start`, `end`, `start_date`, `end_date`) VALUES (1,1,152,'2023-05-02 12:00:00','2023-05-03 12:00:00','2023-05-02','2023-05-03');
INSERT INTO `calcms_studio_timeslot_dates` (`project_id`, `studio_id`, `schedule_id`, `start`, `end`, `start_date`, `end_date`) VALUES (1,1,152,'2023-12-22 12:00:00','2023-12-23 12:00:00','2023-12-22','2023-12-23');
INSERT INTO `calcms_studio_timeslot_dates` (`project_id`, `studio_id`, `schedule_id`, `start`, `end`, `start_date`, `end_date`) VALUES (1,1,152,'2023-02-28 12:00:00','2023-03-01 12:00:00','2023-02-28','2023-03-01');
INSERT INTO `calcms_studio_timeslot_dates` (`project_id`, `studio_id`, `schedule_id`, `start`, `end`, `start_date`, `end_date`) VALUES (1,1,152,'2023-03-21 12:00:00','2023-03-22 12:00:00','2023-03-21','2023-03-22');
INSERT INTO `calcms_studio_timeslot_dates` (`project_id`, `studio_id`, `schedule_id`, `start`, `end`, `start_date`, `end_date`) VALUES (1,1,152,'2023-11-28 12:00:00','2023-11-29 12:00:00','2023-11-28','2023-11-29');
INSERT INTO `calcms_studio_timeslot_dates` (`project_id`, `studio_id`, `schedule_id`, `start`, `end`, `start_date`, `end_date`) VALUES (1,1,152,'2023-10-26 12:00:00','2023-10-27 12:00:00','2023-10-26','2023-10-27');
INSERT INTO `calcms_studio_timeslot_dates` (`project_id`, `studio_id`, `schedule_id`, `start`, `end`, `start_date`, `end_date`) VALUES (1,1,152,'2023-08-08 12:00:00','2023-08-09 12:00:00','2023-08-08','2023-08-09');
INSERT INTO `calcms_studio_timeslot_dates` (`project_id`, `studio_id`, `schedule_id`, `start`, `end`, `start_date`, `end_date`) VALUES (1,1,152,'2023-12-17 12:00:00','2023-12-18 12:00:00','2023-12-17','2023-12-18');
INSERT INTO `calcms_studio_timeslot_dates` (`project_id`, `studio_id`, `schedule_id`, `start`, `end`, `start_date`, `end_date`) VALUES (1,1,152,'2024-01-21 12:00:00','2024-01-22 12:00:00','2024-01-21','2024-01-22');
INSERT INTO `calcms_studio_timeslot_dates` (`project_id`, `studio_id`, `schedule_id`, `start`, `end`, `start_date`, `end_date`) VALUES (1,1,152,'2023-07-27 12:00:00','2023-07-28 12:00:00','2023-07-27','2023-07-28');
INSERT INTO `calcms_studio_timeslot_dates` (`project_id`, `studio_id`, `schedule_id`, `start`, `end`, `start_date`, `end_date`) VALUES (1,1,152,'2023-06-16 12:00:00','2023-06-17 12:00:00','2023-06-16','2023-06-17');
INSERT INTO `calcms_studio_timeslot_dates` (`project_id`, `studio_id`, `schedule_id`, `start`, `end`, `start_date`, `end_date`) VALUES (1,1,152,'2023-11-11 12:00:00','2023-11-12 12:00:00','2023-11-11','2023-11-12');
INSERT INTO `calcms_studio_timeslot_dates` (`project_id`, `studio_id`, `schedule_id`, `start`, `end`, `start_date`, `end_date`) VALUES (1,1,152,'2023-03-18 12:00:00','2023-03-19 12:00:00','2023-03-18','2023-03-19');
INSERT INTO `calcms_studio_timeslot_dates` (`project_id`, `studio_id`, `schedule_id`, `start`, `end`, `start_date`, `end_date`) VALUES (1,1,152,'2024-01-18 12:00:00','2024-01-19 12:00:00','2024-01-18','2024-01-19');
INSERT INTO `calcms_studio_timeslot_dates` (`project_id`, `studio_id`, `schedule_id`, `start`, `end`, `start_date`, `end_date`) VALUES (1,1,152,'2023-09-26 12:00:00','2023-09-27 12:00:00','2023-09-26','2023-09-27');
INSERT INTO `calcms_studio_timeslot_dates` (`project_id`, `studio_id`, `schedule_id`, `start`, `end`, `start_date`, `end_date`) VALUES (1,1,152,'2023-05-27 12:00:00','2023-05-28 12:00:00','2023-05-27','2023-05-28');
INSERT INTO `calcms_studio_timeslot_dates` (`project_id`, `studio_id`, `schedule_id`, `start`, `end`, `start_date`, `end_date`) VALUES (1,1,152,'2023-08-18 12:00:00','2023-08-19 12:00:00','2023-08-18','2023-08-19');
INSERT INTO `calcms_studio_timeslot_dates` (`project_id`, `studio_id`, `schedule_id`, `start`, `end`, `start_date`, `end_date`) VALUES (1,1,152,'2023-12-07 12:00:00','2023-12-08 12:00:00','2023-12-07','2023-12-08');
INSERT INTO `calcms_studio_timeslot_dates` (`project_id`, `studio_id`, `schedule_id`, `start`, `end`, `start_date`, `end_date`) VALUES (1,1,152,'2023-03-08 12:00:00','2023-03-09 12:00:00','2023-03-08','2023-03-09');
INSERT INTO `calcms_studio_timeslot_dates` (`project_id`, `studio_id`, `schedule_id`, `start`, `end`, `start_date`, `end_date`) VALUES (1,1,152,'2023-11-01 12:00:00','2023-11-02 12:00:00','2023-11-01','2023-11-02');
INSERT INTO `calcms_studio_timeslot_dates` (`project_id`, `studio_id`, `schedule_id`, `start`, `end`, `start_date`, `end_date`) VALUES (1,1,152,'2023-08-21 12:00:00','2023-08-22 12:00:00','2023-08-21','2023-08-22');
INSERT INTO `calcms_studio_timeslot_dates` (`project_id`, `studio_id`, `schedule_id`, `start`, `end`, `start_date`, `end_date`) VALUES (1,1,152,'2023-06-06 12:00:00','2023-06-07 12:00:00','2023-06-06','2023-06-07');
INSERT INTO `calcms_studio_timeslot_dates` (`project_id`, `studio_id`, `schedule_id`, `start`, `end`, `start_date`, `end_date`) VALUES (1,1,152,'2024-01-08 12:00:00','2024-01-09 12:00:00','2024-01-08','2024-01-09');
INSERT INTO `calcms_studio_timeslot_dates` (`project_id`, `studio_id`, `schedule_id`, `start`, `end`, `start_date`, `end_date`) VALUES (1,1,152,'2023-05-04 12:00:00','2023-05-05 12:00:00','2023-05-04','2023-05-05');
INSERT INTO `calcms_studio_timeslot_dates` (`project_id`, `studio_id`, `schedule_id`, `start`, `end`, `start_date`, `end_date`) VALUES (1,1,152,'2024-02-02 12:00:00','2024-02-03 12:00:00','2024-02-02','2024-02-03');
INSERT INTO `calcms_studio_timeslot_dates` (`project_id`, `studio_id`, `schedule_id`, `start`, `end`, `start_date`, `end_date`) VALUES (1,1,152,'2023-07-02 12:00:00','2023-07-03 12:00:00','2023-07-02','2023-07-03');
INSERT INTO `calcms_studio_timeslot_dates` (`project_id`, `studio_id`, `schedule_id`, `start`, `end`, `start_date`, `end_date`) VALUES (1,1,152,'2023-04-26 12:00:00','2023-04-27 12:00:00','2023-04-26','2023-04-27');
INSERT INTO `calcms_studio_timeslot_dates` (`project_id`, `studio_id`, `schedule_id`, `start`, `end`, `start_date`, `end_date`) VALUES (1,1,152,'2023-10-31 12:00:00','2023-11-01 12:00:00','2023-10-31','2023-11-01');
INSERT INTO `calcms_studio_timeslot_dates` (`project_id`, `studio_id`, `schedule_id`, `start`, `end`, `start_date`, `end_date`) VALUES (1,1,152,'2023-12-24 12:00:00','2023-12-25 12:00:00','2023-12-24','2023-12-25');
INSERT INTO `calcms_studio_timeslot_dates` (`project_id`, `studio_id`, `schedule_id`, `start`, `end`, `start_date`, `end_date`) VALUES (1,1,152,'2023-02-01 12:00:00','2023-02-02 12:00:00','2023-02-01','2023-02-02');
INSERT INTO `calcms_studio_timeslot_dates` (`project_id`, `studio_id`, `schedule_id`, `start`, `end`, `start_date`, `end_date`) VALUES (1,1,152,'2023-05-12 12:00:00','2023-05-13 12:00:00','2023-05-12','2023-05-13');
INSERT INTO `calcms_studio_timeslot_dates` (`project_id`, `studio_id`, `schedule_id`, `start`, `end`, `start_date`, `end_date`) VALUES (1,1,152,'2023-07-14 12:00:00','2023-07-15 12:00:00','2023-07-14','2023-07-15');
INSERT INTO `calcms_studio_timeslot_dates` (`project_id`, `studio_id`, `schedule_id`, `start`, `end`, `start_date`, `end_date`) VALUES (1,1,152,'2023-05-30 12:00:00','2023-05-31 12:00:00','2023-05-30','2023-05-31');
INSERT INTO `calcms_studio_timeslot_dates` (`project_id`, `studio_id`, `schedule_id`, `start`, `end`, `start_date`, `end_date`) VALUES (1,1,152,'2023-02-26 12:00:00','2023-02-27 12:00:00','2023-02-26','2023-02-27');
INSERT INTO `calcms_studio_timeslot_dates` (`project_id`, `studio_id`, `schedule_id`, `start`, `end`, `start_date`, `end_date`) VALUES (1,1,152,'2023-07-13 12:00:00','2023-07-14 12:00:00','2023-07-13','2023-07-14');
INSERT INTO `calcms_studio_timeslot_dates` (`project_id`, `studio_id`, `schedule_id`, `start`, `end`, `start_date`, `end_date`) VALUES (1,1,152,'2023-04-01 12:00:00','2023-04-02 12:00:00','2023-04-01','2023-04-02');
INSERT INTO `calcms_studio_timeslot_dates` (`project_id`, `studio_id`, `schedule_id`, `start`, `end`, `start_date`, `end_date`) VALUES (1,1,152,'2023-12-23 12:00:00','2023-12-24 12:00:00','2023-12-23','2023-12-24');
INSERT INTO `calcms_studio_timeslot_dates` (`project_id`, `studio_id`, `schedule_id`, `start`, `end`, `start_date`, `end_date`) VALUES (1,1,152,'2023-05-03 12:00:00','2023-05-04 12:00:00','2023-05-03','2023-05-04');
INSERT INTO `calcms_studio_timeslot_dates` (`project_id`, `studio_id`, `schedule_id`, `start`, `end`, `start_date`, `end_date`) VALUES (1,1,152,'2023-03-16 12:00:00','2023-03-17 12:00:00','2023-03-16','2023-03-17');
INSERT INTO `calcms_studio_timeslot_dates` (`project_id`, `studio_id`, `schedule_id`, `start`, `end`, `start_date`, `end_date`) VALUES (1,1,152,'2023-10-11 12:00:00','2023-10-12 12:00:00','2023-10-11','2023-10-12');
INSERT INTO `calcms_studio_timeslot_dates` (`project_id`, `studio_id`, `schedule_id`, `start`, `end`, `start_date`, `end_date`) VALUES (1,1,152,'2023-06-18 12:00:00','2023-06-19 12:00:00','2023-06-18','2023-06-19');
INSERT INTO `calcms_studio_timeslot_dates` (`project_id`, `studio_id`, `schedule_id`, `start`, `end`, `start_date`, `end_date`) VALUES (1,1,152,'2023-12-19 12:00:00','2023-12-20 12:00:00','2023-12-19','2023-12-20');
INSERT INTO `calcms_studio_timeslot_dates` (`project_id`, `studio_id`, `schedule_id`, `start`, `end`, `start_date`, `end_date`) VALUES (1,1,152,'2023-09-01 12:00:00','2023-09-02 12:00:00','2023-09-01','2023-09-02');
INSERT INTO `calcms_studio_timeslot_dates` (`project_id`, `studio_id`, `schedule_id`, `start`, `end`, `start_date`, `end_date`) VALUES (1,1,152,'2024-01-16 12:00:00','2024-01-17 12:00:00','2024-01-16','2024-01-17');
INSERT INTO `calcms_studio_timeslot_dates` (`project_id`, `studio_id`, `schedule_id`, `start`, `end`, `start_date`, `end_date`) VALUES (1,1,152,'2023-05-15 12:00:00','2023-05-16 12:00:00','2023-05-15','2023-05-16');
INSERT INTO `calcms_studio_timeslot_dates` (`project_id`, `studio_id`, `schedule_id`, `start`, `end`, `start_date`, `end_date`) VALUES (1,1,152,'2023-05-10 12:00:00','2023-05-11 12:00:00','2023-05-10','2023-05-11');
INSERT INTO `calcms_studio_timeslot_dates` (`project_id`, `studio_id`, `schedule_id`, `start`, `end`, `start_date`, `end_date`) VALUES (1,1,152,'2023-08-06 12:00:00','2023-08-07 12:00:00','2023-08-06','2023-08-07');
INSERT INTO `calcms_studio_timeslot_dates` (`project_id`, `studio_id`, `schedule_id`, `start`, `end`, `start_date`, `end_date`) VALUES (1,1,152,'2023-06-21 12:00:00','2023-06-22 12:00:00','2023-06-21','2023-06-22');
INSERT INTO `calcms_studio_timeslot_dates` (`project_id`, `studio_id`, `schedule_id`, `start`, `end`, `start_date`, `end_date`) VALUES (1,1,152,'2023-11-26 12:00:00','2023-11-27 12:00:00','2023-11-26','2023-11-27');
INSERT INTO `calcms_studio_timeslot_dates` (`project_id`, `studio_id`, `schedule_id`, `start`, `end`, `start_date`, `end_date`) VALUES (1,1,152,'2023-10-28 12:00:00','2023-10-29 12:00:00','2023-10-28','2023-10-29');
INSERT INTO `calcms_studio_timeslot_dates` (`project_id`, `studio_id`, `schedule_id`, `start`, `end`, `start_date`, `end_date`) VALUES (1,1,152,'2023-07-05 12:00:00','2023-07-06 12:00:00','2023-07-05','2023-07-06');
INSERT INTO `calcms_studio_timeslot_dates` (`project_id`, `studio_id`, `schedule_id`, `start`, `end`, `start_date`, `end_date`) VALUES (1,1,152,'2023-07-29 12:00:00','2023-07-30 12:00:00','2023-07-29','2023-07-30');
INSERT INTO `calcms_studio_timeslot_dates` (`project_id`, `studio_id`, `schedule_id`, `start`, `end`, `start_date`, `end_date`) VALUES (1,1,152,'2023-07-10 12:00:00','2023-07-11 12:00:00','2023-07-10','2023-07-11');
INSERT INTO `calcms_studio_timeslot_dates` (`project_id`, `studio_id`, `schedule_id`, `start`, `end`, `start_date`, `end_date`) VALUES (1,1,152,'2023-09-11 12:00:00','2023-09-12 12:00:00','2023-09-11','2023-09-12');
INSERT INTO `calcms_studio_timeslot_dates` (`project_id`, `studio_id`, `schedule_id`, `start`, `end`, `start_date`, `end_date`) VALUES (1,1,152,'2023-12-25 12:00:00','2023-12-26 12:00:00','2023-12-25','2023-12-26');
INSERT INTO `calcms_studio_timeslot_dates` (`project_id`, `studio_id`, `schedule_id`, `start`, `end`, `start_date`, `end_date`) VALUES (1,1,152,'2023-12-09 12:00:00','2023-12-10 12:00:00','2023-12-09','2023-12-10');
INSERT INTO `calcms_studio_timeslot_dates` (`project_id`, `studio_id`, `schedule_id`, `start`, `end`, `start_date`, `end_date`) VALUES (1,1,152,'2023-06-08 12:00:00','2023-06-09 12:00:00','2023-06-08','2023-06-09');
INSERT INTO `calcms_studio_timeslot_dates` (`project_id`, `studio_id`, `schedule_id`, `start`, `end`, `start_date`, `end_date`) VALUES (1,1,152,'2023-10-01 12:00:00','2023-10-02 12:00:00','2023-10-01','2023-10-02');
INSERT INTO `calcms_studio_timeslot_dates` (`project_id`, `studio_id`, `schedule_id`, `start`, `end`, `start_date`, `end_date`) VALUES (1,1,152,'2023-03-06 12:00:00','2023-03-07 12:00:00','2023-03-06','2023-03-07');
INSERT INTO `calcms_studio_timeslot_dates` (`project_id`, `studio_id`, `schedule_id`, `start`, `end`, `start_date`, `end_date`) VALUES (1,1,152,'2024-01-06 12:00:00','2024-01-07 12:00:00','2024-01-06','2024-01-07');
INSERT INTO `calcms_studio_timeslot_dates` (`project_id`, `studio_id`, `schedule_id`, `start`, `end`, `start_date`, `end_date`) VALUES (1,1,152,'2023-05-29 12:00:00','2023-05-30 12:00:00','2023-05-29','2023-05-30');
INSERT INTO `calcms_studio_timeslot_dates` (`project_id`, `studio_id`, `schedule_id`, `start`, `end`, `start_date`, `end_date`) VALUES (1,1,152,'2023-05-05 12:00:00','2023-05-06 12:00:00','2023-05-05','2023-05-06');
INSERT INTO `calcms_studio_timeslot_dates` (`project_id`, `studio_id`, `schedule_id`, `start`, `end`, `start_date`, `end_date`) VALUES (1,1,152,'2023-08-16 12:00:00','2023-08-17 12:00:00','2023-08-16','2023-08-17');
INSERT INTO `calcms_studio_timeslot_dates` (`project_id`, `studio_id`, `schedule_id`, `start`, `end`, `start_date`, `end_date`) VALUES (1,1,152,'2023-09-28 12:00:00','2023-09-29 12:00:00','2023-09-28','2023-09-29');
INSERT INTO `calcms_studio_timeslot_dates` (`project_id`, `studio_id`, `schedule_id`, `start`, `end`, `start_date`, `end_date`) VALUES (1,1,152,'2023-07-15 12:00:00','2023-07-16 12:00:00','2023-07-15','2023-07-16');
INSERT INTO `calcms_studio_timeslot_dates` (`project_id`, `studio_id`, `schedule_id`, `start`, `end`, `start_date`, `end_date`) VALUES (1,1,152,'2023-12-20 12:00:00','2023-12-21 12:00:00','2023-12-20','2023-12-21');
INSERT INTO `calcms_studio_timeslot_dates` (`project_id`, `studio_id`, `schedule_id`, `start`, `end`, `start_date`, `end_date`) VALUES (1,1,152,'2023-04-11 12:00:00','2023-04-12 12:00:00','2023-04-11','2023-04-12');
INSERT INTO `calcms_studio_timeslot_dates` (`project_id`, `studio_id`, `schedule_id`, `start`, `end`, `start_date`, `end_date`) VALUES (1,1,152,'2023-07-03 12:00:00','2023-07-04 12:00:00','2023-07-03','2023-07-04');
INSERT INTO `calcms_studio_timeslot_dates` (`project_id`, `studio_id`, `schedule_id`, `start`, `end`, `start_date`, `end_date`) VALUES (1,1,152,'2023-05-13 12:00:00','2023-05-14 12:00:00','2023-05-13','2023-05-14');
INSERT INTO `calcms_studio_timeslot_dates` (`project_id`, `studio_id`, `schedule_id`, `start`, `end`, `start_date`, `end_date`) VALUES (1,1,152,'2023-04-28 12:00:00','2023-04-29 12:00:00','2023-04-28','2023-04-29');
INSERT INTO `calcms_studio_timeslot_dates` (`project_id`, `studio_id`, `schedule_id`, `start`, `end`, `start_date`, `end_date`) VALUES (1,1,152,'2023-11-15 12:00:00','2023-11-16 12:00:00','2023-11-15','2023-11-16');
INSERT INTO `calcms_studio_timeslot_dates` (`project_id`, `studio_id`, `schedule_id`, `start`, `end`, `start_date`, `end_date`) VALUES (1,1,152,'2023-04-12 12:00:00','2023-04-13 12:00:00','2023-04-12','2023-04-13');
INSERT INTO `calcms_studio_timeslot_dates` (`project_id`, `studio_id`, `schedule_id`, `start`, `end`, `start_date`, `end_date`) VALUES (1,1,152,'2023-08-19 12:00:00','2023-08-20 12:00:00','2023-08-19','2023-08-20');
INSERT INTO `calcms_studio_timeslot_dates` (`project_id`, `studio_id`, `schedule_id`, `start`, `end`, `start_date`, `end_date`) VALUES (1,1,152,'2024-01-20 12:00:00','2024-01-21 12:00:00','2024-01-20','2024-01-21');
INSERT INTO `calcms_studio_timeslot_dates` (`project_id`, `studio_id`, `schedule_id`, `start`, `end`, `start_date`, `end_date`) VALUES (1,1,152,'2023-03-20 12:00:00','2023-03-21 12:00:00','2023-03-20','2023-03-21');
INSERT INTO `calcms_studio_timeslot_dates` (`project_id`, `studio_id`, `schedule_id`, `start`, `end`, `start_date`, `end_date`) VALUES (1,1,152,'2023-04-30 12:00:00','2023-05-01 12:00:00','2023-04-30','2023-05-01');
INSERT INTO `calcms_studio_timeslot_dates` (`project_id`, `studio_id`, `schedule_id`, `start`, `end`, `start_date`, `end_date`) VALUES (1,1,152,'2023-06-07 12:00:00','2023-06-08 12:00:00','2023-06-07','2023-06-08');
INSERT INTO `calcms_studio_timeslot_dates` (`project_id`, `studio_id`, `schedule_id`, `start`, `end`, `start_date`, `end_date`) VALUES (1,1,152,'2023-02-03 12:00:00','2023-02-04 12:00:00','2023-02-03','2023-02-04');
INSERT INTO `calcms_studio_timeslot_dates` (`project_id`, `studio_id`, `schedule_id`, `start`, `end`, `start_date`, `end_date`) VALUES (1,1,152,'2023-12-06 12:00:00','2023-12-07 12:00:00','2023-12-06','2023-12-07');
INSERT INTO `calcms_studio_timeslot_dates` (`project_id`, `studio_id`, `schedule_id`, `start`, `end`, `start_date`, `end_date`) VALUES (1,1,152,'2023-04-04 12:00:00','2023-04-05 12:00:00','2023-04-04','2023-04-05');
INSERT INTO `calcms_studio_timeslot_dates` (`project_id`, `studio_id`, `schedule_id`, `start`, `end`, `start_date`, `end_date`) VALUES (1,1,152,'2023-03-25 12:00:00','2023-03-26 12:00:00','2023-03-25','2023-03-26');
INSERT INTO `calcms_studio_timeslot_dates` (`project_id`, `studio_id`, `schedule_id`, `start`, `end`, `start_date`, `end_date`) VALUES (1,1,152,'2023-03-09 12:00:00','2023-03-10 12:00:00','2023-03-09','2023-03-10');
INSERT INTO `calcms_studio_timeslot_dates` (`project_id`, `studio_id`, `schedule_id`, `start`, `end`, `start_date`, `end_date`) VALUES (1,1,152,'2023-09-27 12:00:00','2023-09-28 12:00:00','2023-09-27','2023-09-28');
INSERT INTO `calcms_studio_timeslot_dates` (`project_id`, `studio_id`, `schedule_id`, `start`, `end`, `start_date`, `end_date`) VALUES (1,1,152,'2024-01-25 12:00:00','2024-01-26 12:00:00','2024-01-25','2024-01-26');
INSERT INTO `calcms_studio_timeslot_dates` (`project_id`, `studio_id`, `schedule_id`, `start`, `end`, `start_date`, `end_date`) VALUES (1,1,152,'2024-01-09 12:00:00','2024-01-10 12:00:00','2024-01-09','2024-01-10');
INSERT INTO `calcms_studio_timeslot_dates` (`project_id`, `studio_id`, `schedule_id`, `start`, `end`, `start_date`, `end_date`) VALUES (1,1,152,'2023-05-26 12:00:00','2023-05-27 12:00:00','2023-05-26','2023-05-27');
INSERT INTO `calcms_studio_timeslot_dates` (`project_id`, `studio_id`, `schedule_id`, `start`, `end`, `start_date`, `end_date`) VALUES (1,1,152,'2023-11-10 12:00:00','2023-11-11 12:00:00','2023-11-10','2023-11-11');
INSERT INTO `calcms_studio_timeslot_dates` (`project_id`, `studio_id`, `schedule_id`, `start`, `end`, `start_date`, `end_date`) VALUES (1,1,152,'2023-09-30 12:00:00','2023-10-01 12:00:00','2023-09-30','2023-10-01');
INSERT INTO `calcms_studio_timeslot_dates` (`project_id`, `studio_id`, `schedule_id`, `start`, `end`, `start_date`, `end_date`) VALUES (1,1,152,'2023-02-10 12:00:00','2023-02-11 12:00:00','2023-02-10','2023-02-11');
INSERT INTO `calcms_studio_timeslot_dates` (`project_id`, `studio_id`, `schedule_id`, `start`, `end`, `start_date`, `end_date`) VALUES (1,1,152,'2023-07-31 12:00:00','2023-08-01 12:00:00','2023-07-31','2023-08-01');
INSERT INTO `calcms_studio_timeslot_dates` (`project_id`, `studio_id`, `schedule_id`, `start`, `end`, `start_date`, `end_date`) VALUES (1,1,152,'2023-09-12 12:00:00','2023-09-13 12:00:00','2023-09-12','2023-09-13');
INSERT INTO `calcms_studio_timeslot_dates` (`project_id`, `studio_id`, `schedule_id`, `start`, `end`, `start_date`, `end_date`) VALUES (1,1,152,'2023-10-02 12:00:00','2023-10-03 12:00:00','2023-10-02','2023-10-03');
INSERT INTO `calcms_studio_timeslot_dates` (`project_id`, `studio_id`, `schedule_id`, `start`, `end`, `start_date`, `end_date`) VALUES (1,1,152,'2023-06-24 12:00:00','2023-06-25 12:00:00','2023-06-24','2023-06-25');
INSERT INTO `calcms_studio_timeslot_dates` (`project_id`, `studio_id`, `schedule_id`, `start`, `end`, `start_date`, `end_date`) VALUES (1,1,152,'2023-04-27 12:00:00','2023-04-28 12:00:00','2023-04-27','2023-04-28');
INSERT INTO `calcms_studio_timeslot_dates` (`project_id`, `studio_id`, `schedule_id`, `start`, `end`, `start_date`, `end_date`) VALUES (1,1,152,'2023-11-03 12:00:00','2023-11-04 12:00:00','2023-11-03','2023-11-04');
INSERT INTO `calcms_studio_timeslot_dates` (`project_id`, `studio_id`, `schedule_id`, `start`, `end`, `start_date`, `end_date`) VALUES (1,1,152,'2023-08-23 12:00:00','2023-08-24 12:00:00','2023-08-23','2023-08-24');
INSERT INTO `calcms_studio_timeslot_dates` (`project_id`, `studio_id`, `schedule_id`, `start`, `end`, `start_date`, `end_date`) VALUES (1,1,152,'2023-09-04 12:00:00','2023-09-05 12:00:00','2023-09-04','2023-09-05');
INSERT INTO `calcms_studio_timeslot_dates` (`project_id`, `studio_id`, `schedule_id`, `start`, `end`, `start_date`, `end_date`) VALUES (1,1,152,'2023-02-15 12:00:00','2023-02-16 12:00:00','2023-02-15','2023-02-16');
INSERT INTO `calcms_studio_timeslot_dates` (`project_id`, `studio_id`, `schedule_id`, `start`, `end`, `start_date`, `end_date`) VALUES (1,1,152,'2023-10-14 12:00:00','2023-10-15 12:00:00','2023-10-14','2023-10-15');
INSERT INTO `calcms_studio_timeslot_dates` (`project_id`, `studio_id`, `schedule_id`, `start`, `end`, `start_date`, `end_date`) VALUES (1,1,152,'2023-10-30 12:00:00','2023-10-31 12:00:00','2023-10-30','2023-10-31');
INSERT INTO `calcms_studio_timeslot_dates` (`project_id`, `studio_id`, `schedule_id`, `start`, `end`, `start_date`, `end_date`) VALUES (1,1,152,'2023-03-23 12:00:00','2023-03-24 12:00:00','2023-03-23','2023-03-24');
INSERT INTO `calcms_studio_timeslot_dates` (`project_id`, `studio_id`, `schedule_id`, `start`, `end`, `start_date`, `end_date`) VALUES (1,1,152,'2023-10-12 12:00:00','2023-10-13 12:00:00','2023-10-12','2023-10-13');
INSERT INTO `calcms_studio_timeslot_dates` (`project_id`, `studio_id`, `schedule_id`, `start`, `end`, `start_date`, `end_date`) VALUES (1,1,152,'2023-09-02 12:00:00','2023-09-03 12:00:00','2023-09-02','2023-09-03');
INSERT INTO `calcms_studio_timeslot_dates` (`project_id`, `studio_id`, `schedule_id`, `start`, `end`, `start_date`, `end_date`) VALUES (1,1,152,'2024-01-23 12:00:00','2024-01-24 12:00:00','2024-01-23','2024-01-24');
INSERT INTO `calcms_studio_timeslot_dates` (`project_id`, `studio_id`, `schedule_id`, `start`, `end`, `start_date`, `end_date`) VALUES (1,1,152,'2023-05-31 12:00:00','2023-06-01 12:00:00','2023-05-31','2023-06-01');
INSERT INTO `calcms_studio_timeslot_dates` (`project_id`, `studio_id`, `schedule_id`, `start`, `end`, `start_date`, `end_date`) VALUES (1,1,152,'2023-11-13 12:00:00','2023-11-14 12:00:00','2023-11-13','2023-11-14');
INSERT INTO `calcms_studio_timeslot_dates` (`project_id`, `studio_id`, `schedule_id`, `start`, `end`, `start_date`, `end_date`) VALUES (1,1,152,'2023-06-22 12:00:00','2023-06-23 12:00:00','2023-06-22','2023-06-23');
INSERT INTO `calcms_studio_timeslot_dates` (`project_id`, `studio_id`, `schedule_id`, `start`, `end`, `start_date`, `end_date`) VALUES (1,1,152,'2023-10-04 12:00:00','2023-10-05 12:00:00','2023-10-04','2023-10-05');
INSERT INTO `calcms_studio_timeslot_dates` (`project_id`, `studio_id`, `schedule_id`, `start`, `end`, `start_date`, `end_date`) VALUES (1,1,152,'2023-02-05 12:00:00','2023-02-06 12:00:00','2023-02-05','2023-02-06');
INSERT INTO `calcms_studio_timeslot_dates` (`project_id`, `studio_id`, `schedule_id`, `start`, `end`, `start_date`, `end_date`) VALUES (1,1,152,'2023-09-14 12:00:00','2023-09-15 12:00:00','2023-09-14','2023-09-15');
INSERT INTO `calcms_studio_timeslot_dates` (`project_id`, `studio_id`, `schedule_id`, `start`, `end`, `start_date`, `end_date`) VALUES (1,1,152,'2023-08-09 12:00:00','2023-08-10 12:00:00','2023-08-09','2023-08-10');
INSERT INTO `calcms_studio_timeslot_dates` (`project_id`, `studio_id`, `schedule_id`, `start`, `end`, `start_date`, `end_date`) VALUES (1,1,152,'2023-08-25 12:00:00','2023-08-26 12:00:00','2023-08-25','2023-08-26');
INSERT INTO `calcms_studio_timeslot_dates` (`project_id`, `studio_id`, `schedule_id`, `start`, `end`, `start_date`, `end_date`) VALUES (1,1,152,'2023-04-02 12:00:00','2023-04-03 12:00:00','2023-04-02','2023-04-03');
INSERT INTO `calcms_studio_timeslot_dates` (`project_id`, `studio_id`, `schedule_id`, `start`, `end`, `start_date`, `end_date`) VALUES (1,1,152,'2023-11-29 12:00:00','2023-11-30 12:00:00','2023-11-29','2023-11-30');
INSERT INTO `calcms_studio_timeslot_dates` (`project_id`, `studio_id`, `schedule_id`, `start`, `end`, `start_date`, `end_date`) VALUES (1,1,152,'2023-11-05 12:00:00','2023-11-06 12:00:00','2023-11-05','2023-11-06');
INSERT INTO `calcms_studio_timeslot_dates` (`project_id`, `studio_id`, `schedule_id`, `start`, `end`, `start_date`, `end_date`) VALUES (1,1,152,'2023-07-26 12:00:00','2023-07-27 12:00:00','2023-07-26','2023-07-27');
INSERT INTO `calcms_studio_timeslot_dates` (`project_id`, `studio_id`, `schedule_id`, `start`, `end`, `start_date`, `end_date`) VALUES (1,1,152,'2023-02-13 12:00:00','2023-02-14 12:00:00','2023-02-13','2023-02-14');
INSERT INTO `calcms_studio_timeslot_dates` (`project_id`, `studio_id`, `schedule_id`, `start`, `end`, `start_date`, `end_date`) VALUES (1,1,152,'2023-06-17 12:00:00','2023-06-18 12:00:00','2023-06-17','2023-06-18');
INSERT INTO `calcms_studio_timeslot_dates` (`project_id`, `studio_id`, `schedule_id`, `start`, `end`, `start_date`, `end_date`) VALUES (1,1,152,'2023-03-19 12:00:00','2023-03-20 12:00:00','2023-03-19','2023-03-20');
INSERT INTO `calcms_studio_timeslot_dates` (`project_id`, `studio_id`, `schedule_id`, `start`, `end`, `start_date`, `end_date`) VALUES (1,1,152,'2023-04-14 12:00:00','2023-04-15 12:00:00','2023-04-14','2023-04-15');
INSERT INTO `calcms_studio_timeslot_dates` (`project_id`, `studio_id`, `schedule_id`, `start`, `end`, `start_date`, `end_date`) VALUES (1,1,152,'2023-12-16 12:00:00','2023-12-17 12:00:00','2023-12-16','2023-12-17');
INSERT INTO `calcms_studio_timeslot_dates` (`project_id`, `studio_id`, `schedule_id`, `start`, `end`, `start_date`, `end_date`) VALUES (1,1,152,'2023-10-27 12:00:00','2023-10-28 12:00:00','2023-10-27','2023-10-28');
INSERT INTO `calcms_studio_timeslot_dates` (`project_id`, `studio_id`, `schedule_id`, `start`, `end`, `start_date`, `end_date`) VALUES (1,1,152,'2023-08-20 12:00:00','2023-08-21 12:00:00','2023-08-20','2023-08-21');
INSERT INTO `calcms_studio_timeslot_dates` (`project_id`, `studio_id`, `schedule_id`, `start`, `end`, `start_date`, `end_date`) VALUES (1,1,152,'2024-01-19 12:00:00','2024-01-20 12:00:00','2024-01-19','2024-01-20');
INSERT INTO `calcms_studio_timeslot_dates` (`project_id`, `studio_id`, `schedule_id`, `start`, `end`, `start_date`, `end_date`) VALUES (1,1,152,'2023-02-02 12:00:00','2023-02-03 12:00:00','2023-02-02','2023-02-03');
INSERT INTO `calcms_studio_timeslot_dates` (`project_id`, `studio_id`, `schedule_id`, `start`, `end`, `start_date`, `end_date`) VALUES (1,1,152,'2023-06-09 12:00:00','2023-06-10 12:00:00','2023-06-09','2023-06-10');
INSERT INTO `calcms_studio_timeslot_dates` (`project_id`, `studio_id`, `schedule_id`, `start`, `end`, `start_date`, `end_date`) VALUES (1,1,152,'2023-06-25 12:00:00','2023-06-26 12:00:00','2023-06-25','2023-06-26');
INSERT INTO `calcms_studio_timeslot_dates` (`project_id`, `studio_id`, `schedule_id`, `start`, `end`, `start_date`, `end_date`) VALUES (1,1,152,'2023-12-08 12:00:00','2023-12-09 12:00:00','2023-12-08','2023-12-09');
INSERT INTO `calcms_studio_timeslot_dates` (`project_id`, `studio_id`, `schedule_id`, `start`, `end`, `start_date`, `end_date`) VALUES (1,1,152,'2024-02-01 12:00:00','2024-02-02 12:00:00','2024-02-01','2024-02-02');
INSERT INTO `calcms_studio_timeslot_dates` (`project_id`, `studio_id`, `schedule_id`, `start`, `end`, `start_date`, `end_date`) VALUES (1,1,152,'2023-04-13 12:00:00','2023-04-14 12:00:00','2023-04-13','2023-04-14');
INSERT INTO `calcms_studio_timeslot_dates` (`project_id`, `studio_id`, `schedule_id`, `start`, `end`, `start_date`, `end_date`) VALUES (1,1,152,'2023-10-10 12:00:00','2023-10-11 12:00:00','2023-10-10','2023-10-11');
INSERT INTO `calcms_studio_timeslot_dates` (`project_id`, `studio_id`, `schedule_id`, `start`, `end`, `start_date`, `end_date`) VALUES (1,1,152,'2023-05-28 12:00:00','2023-05-29 12:00:00','2023-05-28','2023-05-29');
INSERT INTO `calcms_studio_timeslot_dates` (`project_id`, `studio_id`, `schedule_id`, `start`, `end`, `start_date`, `end_date`) VALUES (1,1,152,'2023-08-17 12:00:00','2023-08-18 12:00:00','2023-08-17','2023-08-18');
INSERT INTO `calcms_studio_timeslot_dates` (`project_id`, `studio_id`, `schedule_id`, `start`, `end`, `start_date`, `end_date`) VALUES (1,1,152,'2023-07-01 12:00:00','2023-07-02 12:00:00','2023-07-01','2023-07-02');
INSERT INTO `calcms_studio_timeslot_dates` (`project_id`, `studio_id`, `schedule_id`, `start`, `end`, `start_date`, `end_date`) VALUES (1,1,152,'2024-01-07 12:00:00','2024-01-08 12:00:00','2024-01-07','2024-01-08');
INSERT INTO `calcms_studio_timeslot_dates` (`project_id`, `studio_id`, `schedule_id`, `start`, `end`, `start_date`, `end_date`) VALUES (1,1,152,'2023-09-05 12:00:00','2023-09-06 12:00:00','2023-09-05','2023-09-06');
INSERT INTO `calcms_studio_timeslot_dates` (`project_id`, `studio_id`, `schedule_id`, `start`, `end`, `start_date`, `end_date`) VALUES (1,1,152,'2023-09-29 12:00:00','2023-09-30 12:00:00','2023-09-29','2023-09-30');
INSERT INTO `calcms_studio_timeslot_dates` (`project_id`, `studio_id`, `schedule_id`, `start`, `end`, `start_date`, `end_date`) VALUES (1,1,152,'2023-02-14 12:00:00','2023-02-15 12:00:00','2023-02-14','2023-02-15');
INSERT INTO `calcms_studio_timeslot_dates` (`project_id`, `studio_id`, `schedule_id`, `start`, `end`, `start_date`, `end_date`) VALUES (1,1,152,'2023-10-15 12:00:00','2023-10-16 12:00:00','2023-10-15','2023-10-16');
INSERT INTO `calcms_studio_timeslot_dates` (`project_id`, `studio_id`, `schedule_id`, `start`, `end`, `start_date`, `end_date`) VALUES (1,1,152,'2023-06-20 12:00:00','2023-06-21 12:00:00','2023-06-20','2023-06-21');
INSERT INTO `calcms_studio_timeslot_dates` (`project_id`, `studio_id`, `schedule_id`, `start`, `end`, `start_date`, `end_date`) VALUES (1,1,152,'2023-05-11 12:00:00','2023-05-12 12:00:00','2023-05-11','2023-05-12');
INSERT INTO `calcms_studio_timeslot_dates` (`project_id`, `studio_id`, `schedule_id`, `start`, `end`, `start_date`, `end_date`) VALUES (1,1,152,'2023-03-07 12:00:00','2023-03-08 12:00:00','2023-03-07','2023-03-08');
INSERT INTO `calcms_studio_timeslot_dates` (`project_id`, `studio_id`, `schedule_id`, `start`, `end`, `start_date`, `end_date`) VALUES (1,1,152,'2023-09-13 12:00:00','2023-09-14 12:00:00','2023-09-13','2023-09-14');
INSERT INTO `calcms_studio_timeslot_dates` (`project_id`, `studio_id`, `schedule_id`, `start`, `end`, `start_date`, `end_date`) VALUES (1,1,152,'2023-10-03 12:00:00','2023-10-04 12:00:00','2023-10-03','2023-10-04');
INSERT INTO `calcms_studio_timeslot_dates` (`project_id`, `studio_id`, `schedule_id`, `start`, `end`, `start_date`, `end_date`) VALUES (1,1,152,'2023-11-14 12:00:00','2023-11-15 12:00:00','2023-11-14','2023-11-15');
INSERT INTO `calcms_studio_timeslot_dates` (`project_id`, `studio_id`, `schedule_id`, `start`, `end`, `start_date`, `end_date`) VALUES (1,1,152,'2024-01-24 12:00:00','2024-01-25 12:00:00','2024-01-24','2024-01-25');
INSERT INTO `calcms_studio_timeslot_dates` (`project_id`, `studio_id`, `schedule_id`, `start`, `end`, `start_date`, `end_date`) VALUES (1,1,152,'2023-11-02 12:00:00','2023-11-03 12:00:00','2023-11-02','2023-11-03');
INSERT INTO `calcms_studio_timeslot_dates` (`project_id`, `studio_id`, `schedule_id`, `start`, `end`, `start_date`, `end_date`) VALUES (1,1,152,'2023-04-05 12:00:00','2023-04-06 12:00:00','2023-04-05','2023-04-06');
INSERT INTO `calcms_studio_timeslot_dates` (`project_id`, `studio_id`, `schedule_id`, `start`, `end`, `start_date`, `end_date`) VALUES (1,1,152,'2023-04-29 12:00:00','2023-04-30 12:00:00','2023-04-29','2023-04-30');
INSERT INTO `calcms_studio_timeslot_dates` (`project_id`, `studio_id`, `schedule_id`, `start`, `end`, `start_date`, `end_date`) VALUES (1,1,152,'2023-03-24 12:00:00','2023-03-25 12:00:00','2023-03-24','2023-03-25');
INSERT INTO `calcms_studio_timeslot_dates` (`project_id`, `studio_id`, `schedule_id`, `start`, `end`, `start_date`, `end_date`) VALUES (1,1,152,'2023-08-22 12:00:00','2023-08-23 12:00:00','2023-08-22','2023-08-23');
INSERT INTO `calcms_studio_timeslot_dates` (`project_id`, `studio_id`, `schedule_id`, `start`, `end`, `start_date`, `end_date`) VALUES (1,1,152,'2023-10-13 12:00:00','2023-10-14 12:00:00','2023-10-13','2023-10-14');
INSERT INTO `calcms_studio_timeslot_dates` (`project_id`, `studio_id`, `schedule_id`, `start`, `end`, `start_date`, `end_date`) VALUES (1,1,152,'2023-04-10 12:00:00','2023-04-11 12:00:00','2023-04-10','2023-04-11');
INSERT INTO `calcms_studio_timeslot_dates` (`project_id`, `studio_id`, `schedule_id`, `start`, `end`, `start_date`, `end_date`) VALUES (1,1,152,'2023-09-03 12:00:00','2023-09-04 12:00:00','2023-09-03','2023-09-04');
INSERT INTO `calcms_studio_timeslot_dates` (`project_id`, `studio_id`, `schedule_id`, `start`, `end`, `start_date`, `end_date`) VALUES (1,1,152,'2024-01-22 12:00:00','2024-01-23 12:00:00','2024-01-22','2024-01-23');
INSERT INTO `calcms_studio_timeslot_dates` (`project_id`, `studio_id`, `schedule_id`, `start`, `end`, `start_date`, `end_date`) VALUES (1,1,152,'2023-08-24 12:00:00','2023-08-25 12:00:00','2023-08-24','2023-08-25');
INSERT INTO `calcms_studio_timeslot_dates` (`project_id`, `studio_id`, `schedule_id`, `start`, `end`, `start_date`, `end_date`) VALUES (1,1,152,'2023-03-22 12:00:00','2023-03-23 12:00:00','2023-03-22','2023-03-23');
INSERT INTO `calcms_studio_timeslot_dates` (`project_id`, `studio_id`, `schedule_id`, `start`, `end`, `start_date`, `end_date`) VALUES (1,1,152,'2023-11-04 12:00:00','2023-11-05 12:00:00','2023-11-04','2023-11-05');
INSERT INTO `calcms_studio_timeslot_dates` (`project_id`, `studio_id`, `schedule_id`, `start`, `end`, `start_date`, `end_date`) VALUES (1,1,152,'2023-02-27 12:00:00','2023-02-28 12:00:00','2023-02-27','2023-02-28');
INSERT INTO `calcms_studio_timeslot_dates` (`project_id`, `studio_id`, `schedule_id`, `start`, `end`, `start_date`, `end_date`) VALUES (1,1,152,'2023-06-23 12:00:00','2023-06-24 12:00:00','2023-06-23','2023-06-24');
INSERT INTO `calcms_studio_timeslot_dates` (`project_id`, `studio_id`, `schedule_id`, `start`, `end`, `start_date`, `end_date`) VALUES (1,1,152,'2023-11-30 12:00:00','2023-12-01 12:00:00','2023-11-30','2023-12-01');
INSERT INTO `calcms_studio_timeslot_dates` (`project_id`, `studio_id`, `schedule_id`, `start`, `end`, `start_date`, `end_date`) VALUES (1,1,152,'2023-04-15 12:00:00','2023-04-16 12:00:00','2023-04-15','2023-04-16');
INSERT INTO `calcms_studio_timeslot_dates` (`project_id`, `studio_id`, `schedule_id`, `start`, `end`, `start_date`, `end_date`) VALUES (1,1,152,'2023-11-12 12:00:00','2023-11-13 12:00:00','2023-11-12','2023-11-13');
INSERT INTO `calcms_studio_timeslot_dates` (`project_id`, `studio_id`, `schedule_id`, `start`, `end`, `start_date`, `end_date`) VALUES (1,1,152,'2023-12-18 12:00:00','2023-12-19 12:00:00','2023-12-18','2023-12-19');
INSERT INTO `calcms_studio_timeslot_dates` (`project_id`, `studio_id`, `schedule_id`, `start`, `end`, `start_date`, `end_date`) VALUES (1,1,152,'2023-06-19 12:00:00','2023-06-20 12:00:00','2023-06-19','2023-06-20');
INSERT INTO `calcms_studio_timeslot_dates` (`project_id`, `studio_id`, `schedule_id`, `start`, `end`, `start_date`, `end_date`) VALUES (1,1,152,'2023-02-12 12:00:00','2023-02-13 12:00:00','2023-02-12','2023-02-13');
INSERT INTO `calcms_studio_timeslot_dates` (`project_id`, `studio_id`, `schedule_id`, `start`, `end`, `start_date`, `end_date`) VALUES (1,1,152,'2023-09-10 12:00:00','2023-09-11 12:00:00','2023-09-10','2023-09-11');
INSERT INTO `calcms_studio_timeslot_dates` (`project_id`, `studio_id`, `schedule_id`, `start`, `end`, `start_date`, `end_date`) VALUES (1,1,152,'2023-07-11 12:00:00','2023-07-12 12:00:00','2023-07-11','2023-07-12');
INSERT INTO `calcms_studio_timeslot_dates` (`project_id`, `studio_id`, `schedule_id`, `start`, `end`, `start_date`, `end_date`) VALUES (1,1,152,'2023-08-07 12:00:00','2023-08-08 12:00:00','2023-08-07','2023-08-08');
INSERT INTO `calcms_studio_timeslot_dates` (`project_id`, `studio_id`, `schedule_id`, `start`, `end`, `start_date`, `end_date`) VALUES (1,1,152,'2023-11-27 12:00:00','2023-11-28 12:00:00','2023-11-27','2023-11-28');
INSERT INTO `calcms_studio_timeslot_dates` (`project_id`, `studio_id`, `schedule_id`, `start`, `end`, `start_date`, `end_date`) VALUES (1,1,152,'2023-04-03 12:00:00','2023-04-04 12:00:00','2023-04-03','2023-04-04');
INSERT INTO `calcms_studio_timeslot_dates` (`project_id`, `studio_id`, `schedule_id`, `start`, `end`, `start_date`, `end_date`) VALUES (1,1,152,'2023-10-05 12:00:00','2023-10-06 12:00:00','2023-10-05','2023-10-06');
INSERT INTO `calcms_studio_timeslot_dates` (`project_id`, `studio_id`, `schedule_id`, `start`, `end`, `start_date`, `end_date`) VALUES (1,1,152,'2023-10-29 12:00:00','2023-10-30 12:00:00','2023-10-29','2023-10-30');
INSERT INTO `calcms_studio_timeslot_dates` (`project_id`, `studio_id`, `schedule_id`, `start`, `end`, `start_date`, `end_date`) VALUES (1,1,152,'2023-02-04 12:00:00','2023-02-05 12:00:00','2023-02-04','2023-02-05');
INSERT INTO `calcms_studio_timeslot_dates` (`project_id`, `studio_id`, `schedule_id`, `start`, `end`, `start_date`, `end_date`) VALUES (1,1,152,'2023-09-15 12:00:00','2023-09-16 12:00:00','2023-09-15','2023-09-16');
INSERT INTO `calcms_studio_timeslot_dates` (`project_id`, `studio_id`, `schedule_id`, `start`, `end`, `start_date`, `end_date`) VALUES (1,1,152,'2024-01-17 12:00:00','2024-01-18 12:00:00','2024-01-17','2024-01-18');
INSERT INTO `calcms_studio_timeslot_dates` (`project_id`, `studio_id`, `schedule_id`, `start`, `end`, `start_date`, `end_date`) VALUES (1,1,152,'2023-12-21 12:00:00','2023-12-22 12:00:00','2023-12-21','2023-12-22');
INSERT INTO `calcms_studio_timeslot_dates` (`project_id`, `studio_id`, `schedule_id`, `start`, `end`, `start_date`, `end_date`) VALUES (1,1,152,'2023-03-17 12:00:00','2023-03-18 12:00:00','2023-03-17','2023-03-18');
INSERT INTO `calcms_studio_timeslot_dates` (`project_id`, `studio_id`, `schedule_id`, `start`, `end`, `start_date`, `end_date`) VALUES (1,1,152,'2023-05-01 12:00:00','2023-05-02 12:00:00','2023-05-01','2023-05-02');
INSERT INTO `calcms_studio_timeslot_dates` (`project_id`, `studio_id`, `schedule_id`, `start`, `end`, `start_date`, `end_date`) VALUES (1,1,152,'2023-07-28 12:00:00','2023-07-29 12:00:00','2023-07-28','2023-07-29');
INSERT INTO `calcms_studio_timeslot_dates` (`project_id`, `studio_id`, `schedule_id`, `start`, `end`, `start_date`, `end_date`) VALUES (1,1,152,'2023-12-02 12:00:00','2023-12-03 12:00:00','2023-12-02','2023-12-03');
INSERT INTO `calcms_studio_timeslot_dates` (`project_id`, `studio_id`, `schedule_id`, `start`, `end`, `start_date`, `end_date`) VALUES (1,1,152,'2023-02-08 12:00:00','2023-02-09 12:00:00','2023-02-08','2023-02-09');
INSERT INTO `calcms_studio_timeslot_dates` (`project_id`, `studio_id`, `schedule_id`, `start`, `end`, `start_date`, `end_date`) VALUES (1,1,152,'2023-05-22 12:00:00','2023-05-23 12:00:00','2023-05-22','2023-05-23');
INSERT INTO `calcms_studio_timeslot_dates` (`project_id`, `studio_id`, `schedule_id`, `start`, `end`, `start_date`, `end_date`) VALUES (1,1,152,'2023-07-24 12:00:00','2023-07-25 12:00:00','2023-07-24','2023-07-25');
INSERT INTO `calcms_studio_timeslot_dates` (`project_id`, `studio_id`, `schedule_id`, `start`, `end`, `start_date`, `end_date`) VALUES (1,1,152,'2023-12-14 12:00:00','2023-12-15 12:00:00','2023-12-14','2023-12-15');
INSERT INTO `calcms_studio_timeslot_dates` (`project_id`, `studio_id`, `schedule_id`, `start`, `end`, `start_date`, `end_date`) VALUES (1,1,152,'2023-04-16 12:00:00','2023-04-17 12:00:00','2023-04-16','2023-04-17');
INSERT INTO `calcms_studio_timeslot_dates` (`project_id`, `studio_id`, `schedule_id`, `start`, `end`, `start_date`, `end_date`) VALUES (1,1,152,'2023-07-07 12:00:00','2023-07-08 12:00:00','2023-07-07','2023-07-08');
INSERT INTO `calcms_studio_timeslot_dates` (`project_id`, `studio_id`, `schedule_id`, `start`, `end`, `start_date`, `end_date`) VALUES (1,1,152,'2023-08-11 12:00:00','2023-08-12 12:00:00','2023-08-11','2023-08-12');
INSERT INTO `calcms_studio_timeslot_dates` (`project_id`, `studio_id`, `schedule_id`, `start`, `end`, `start_date`, `end_date`) VALUES (1,1,152,'2024-01-01 12:00:00','2024-01-02 12:00:00','2024-01-01','2024-01-02');
INSERT INTO `calcms_studio_timeslot_dates` (`project_id`, `studio_id`, `schedule_id`, `start`, `end`, `start_date`, `end_date`) VALUES (1,1,152,'2023-05-17 12:00:00','2023-05-18 12:00:00','2023-05-17','2023-05-18');
INSERT INTO `calcms_studio_timeslot_dates` (`project_id`, `studio_id`, `schedule_id`, `start`, `end`, `start_date`, `end_date`) VALUES (1,1,152,'2023-08-28 12:00:00','2023-08-29 12:00:00','2023-08-28','2023-08-29');
INSERT INTO `calcms_studio_timeslot_dates` (`project_id`, `studio_id`, `schedule_id`, `start`, `end`, `start_date`, `end_date`) VALUES (1,1,152,'2023-09-16 12:00:00','2023-09-17 12:00:00','2023-09-16','2023-09-17');
INSERT INTO `calcms_studio_timeslot_dates` (`project_id`, `studio_id`, `schedule_id`, `start`, `end`, `start_date`, `end_date`) VALUES (1,1,152,'2023-03-01 12:00:00','2023-03-02 12:00:00','2023-03-01','2023-03-02');
INSERT INTO `calcms_studio_timeslot_dates` (`project_id`, `studio_id`, `schedule_id`, `start`, `end`, `start_date`, `end_date`) VALUES (1,1,152,'2023-10-06 12:00:00','2023-10-07 12:00:00','2023-10-06','2023-10-07');
INSERT INTO `calcms_studio_timeslot_dates` (`project_id`, `studio_id`, `schedule_id`, `start`, `end`, `start_date`, `end_date`) VALUES (1,1,152,'2023-11-08 12:00:00','2023-11-09 12:00:00','2023-11-08','2023-11-09');
INSERT INTO `calcms_studio_timeslot_dates` (`project_id`, `studio_id`, `schedule_id`, `start`, `end`, `start_date`, `end_date`) VALUES (1,1,152,'2024-01-28 12:00:00','2024-01-29 12:00:00','2024-01-28','2024-01-29');
INSERT INTO `calcms_studio_timeslot_dates` (`project_id`, `studio_id`, `schedule_id`, `start`, `end`, `start_date`, `end_date`) VALUES (1,1,152,'2023-06-26 12:00:00','2023-06-27 12:00:00','2023-06-26','2023-06-27');
INSERT INTO `calcms_studio_timeslot_dates` (`project_id`, `studio_id`, `schedule_id`, `start`, `end`, `start_date`, `end_date`) VALUES (1,1,152,'2023-08-01 12:00:00','2023-08-02 12:00:00','2023-08-01','2023-08-02');
INSERT INTO `calcms_studio_timeslot_dates` (`project_id`, `studio_id`, `schedule_id`, `start`, `end`, `start_date`, `end_date`) VALUES (1,1,152,'2023-07-17 12:00:00','2023-07-18 12:00:00','2023-07-17','2023-07-18');
INSERT INTO `calcms_studio_timeslot_dates` (`project_id`, `studio_id`, `schedule_id`, `start`, `end`, `start_date`, `end_date`) VALUES (1,1,152,'2023-03-28 12:00:00','2023-03-29 12:00:00','2023-03-28','2023-03-29');
INSERT INTO `calcms_studio_timeslot_dates` (`project_id`, `studio_id`, `schedule_id`, `start`, `end`, `start_date`, `end_date`) VALUES (1,1,152,'2023-11-21 12:00:00','2023-11-22 12:00:00','2023-11-21','2023-11-22');
INSERT INTO `calcms_studio_timeslot_dates` (`project_id`, `studio_id`, `schedule_id`, `start`, `end`, `start_date`, `end_date`) VALUES (1,1,152,'2024-01-11 12:00:00','2024-01-12 12:00:00','2024-01-11','2024-01-12');
INSERT INTO `calcms_studio_timeslot_dates` (`project_id`, `studio_id`, `schedule_id`, `start`, `end`, `start_date`, `end_date`) VALUES (1,1,152,'2023-12-27 12:00:00','2023-12-28 12:00:00','2023-12-27','2023-12-28');
INSERT INTO `calcms_studio_timeslot_dates` (`project_id`, `studio_id`, `schedule_id`, `start`, `end`, `start_date`, `end_date`) VALUES (1,1,152,'2023-11-18 12:00:00','2023-11-19 12:00:00','2023-11-18','2023-11-19');
INSERT INTO `calcms_studio_timeslot_dates` (`project_id`, `studio_id`, `schedule_id`, `start`, `end`, `start_date`, `end_date`) VALUES (1,1,152,'2023-10-16 12:00:00','2023-10-17 12:00:00','2023-10-16','2023-10-17');
INSERT INTO `calcms_studio_timeslot_dates` (`project_id`, `studio_id`, `schedule_id`, `start`, `end`, `start_date`, `end_date`) VALUES (1,1,152,'2023-03-11 12:00:00','2023-03-12 12:00:00','2023-03-11','2023-03-12');
INSERT INTO `calcms_studio_timeslot_dates` (`project_id`, `studio_id`, `schedule_id`, `start`, `end`, `start_date`, `end_date`) VALUES (1,1,152,'2023-09-06 12:00:00','2023-09-07 12:00:00','2023-09-06','2023-09-07');
INSERT INTO `calcms_studio_timeslot_dates` (`project_id`, `studio_id`, `schedule_id`, `start`, `end`, `start_date`, `end_date`) VALUES (1,1,152,'2023-05-07 12:00:00','2023-05-08 12:00:00','2023-05-07','2023-05-08');
INSERT INTO `calcms_studio_timeslot_dates` (`project_id`, `studio_id`, `schedule_id`, `start`, `end`, `start_date`, `end_date`) VALUES (1,1,152,'2023-02-18 12:00:00','2023-02-19 12:00:00','2023-02-18','2023-02-19');
INSERT INTO `calcms_studio_timeslot_dates` (`project_id`, `studio_id`, `schedule_id`, `start`, `end`, `start_date`, `end_date`) VALUES (1,1,152,'2023-12-12 12:00:00','2023-12-13 12:00:00','2023-12-12','2023-12-13');
INSERT INTO `calcms_studio_timeslot_dates` (`project_id`, `studio_id`, `schedule_id`, `start`, `end`, `start_date`, `end_date`) VALUES (1,1,152,'2023-12-30 12:00:00','2023-12-31 12:00:00','2023-12-30','2023-12-31');
INSERT INTO `calcms_studio_timeslot_dates` (`project_id`, `studio_id`, `schedule_id`, `start`, `end`, `start_date`, `end_date`) VALUES (1,1,152,'2023-02-21 12:00:00','2023-02-22 12:00:00','2023-02-21','2023-02-22');
INSERT INTO `calcms_studio_timeslot_dates` (`project_id`, `studio_id`, `schedule_id`, `start`, `end`, `start_date`, `end_date`) VALUES (1,1,152,'2023-04-06 12:00:00','2023-04-07 12:00:00','2023-04-06','2023-04-07');
INSERT INTO `calcms_studio_timeslot_dates` (`project_id`, `studio_id`, `schedule_id`, `start`, `end`, `start_date`, `end_date`) VALUES (1,1,152,'2023-12-04 12:00:00','2023-12-05 12:00:00','2023-12-04','2023-12-05');
INSERT INTO `calcms_studio_timeslot_dates` (`project_id`, `studio_id`, `schedule_id`, `start`, `end`, `start_date`, `end_date`) VALUES (1,1,152,'2023-07-22 12:00:00','2023-07-23 12:00:00','2023-07-22','2023-07-23');
INSERT INTO `calcms_studio_timeslot_dates` (`project_id`, `studio_id`, `schedule_id`, `start`, `end`, `start_date`, `end_date`) VALUES (1,1,152,'2023-05-24 12:00:00','2023-05-25 12:00:00','2023-05-24','2023-05-25');
INSERT INTO `calcms_studio_timeslot_dates` (`project_id`, `studio_id`, `schedule_id`, `start`, `end`, `start_date`, `end_date`) VALUES (1,1,152,'2023-05-23 12:00:00','2023-05-24 12:00:00','2023-05-23','2023-05-24');
INSERT INTO `calcms_studio_timeslot_dates` (`project_id`, `studio_id`, `schedule_id`, `start`, `end`, `start_date`, `end_date`) VALUES (1,1,152,'2023-04-18 12:00:00','2023-04-19 12:00:00','2023-04-18','2023-04-19');
INSERT INTO `calcms_studio_timeslot_dates` (`project_id`, `studio_id`, `schedule_id`, `start`, `end`, `start_date`, `end_date`) VALUES (1,1,152,'2023-12-03 12:00:00','2023-12-04 12:00:00','2023-12-03','2023-12-04');
INSERT INTO `calcms_studio_timeslot_dates` (`project_id`, `studio_id`, `schedule_id`, `start`, `end`, `start_date`, `end_date`) VALUES (1,1,152,'2023-04-21 12:00:00','2023-04-22 12:00:00','2023-04-21','2023-04-22');
INSERT INTO `calcms_studio_timeslot_dates` (`project_id`, `studio_id`, `schedule_id`, `start`, `end`, `start_date`, `end_date`) VALUES (1,1,152,'2023-03-31 12:00:00','2023-04-01 12:00:00','2023-03-31','2023-04-01');
INSERT INTO `calcms_studio_timeslot_dates` (`project_id`, `studio_id`, `schedule_id`, `start`, `end`, `start_date`, `end_date`) VALUES (1,1,152,'2023-02-06 12:00:00','2023-02-07 12:00:00','2023-02-06','2023-02-07');
INSERT INTO `calcms_studio_timeslot_dates` (`project_id`, `studio_id`, `schedule_id`, `start`, `end`, `start_date`, `end_date`) VALUES (1,1,152,'2024-01-31 12:00:00','2024-02-01 12:00:00','2024-01-31','2024-02-01');
INSERT INTO `calcms_studio_timeslot_dates` (`project_id`, `studio_id`, `schedule_id`, `start`, `end`, `start_date`, `end_date`) VALUES (1,1,152,'2023-12-10 12:00:00','2023-12-11 12:00:00','2023-12-10','2023-12-11');
INSERT INTO `calcms_studio_timeslot_dates` (`project_id`, `studio_id`, `schedule_id`, `start`, `end`, `start_date`, `end_date`) VALUES (1,1,152,'2023-07-09 12:00:00','2023-07-10 12:00:00','2023-07-09','2023-07-10');
INSERT INTO `calcms_studio_timeslot_dates` (`project_id`, `studio_id`, `schedule_id`, `start`, `end`, `start_date`, `end_date`) VALUES (1,1,152,'2023-07-25 12:00:00','2023-07-26 12:00:00','2023-07-25','2023-07-26');
INSERT INTO `calcms_studio_timeslot_dates` (`project_id`, `studio_id`, `schedule_id`, `start`, `end`, `start_date`, `end_date`) VALUES (1,1,152,'2023-10-08 12:00:00','2023-10-09 12:00:00','2023-10-08','2023-10-09');
INSERT INTO `calcms_studio_timeslot_dates` (`project_id`, `studio_id`, `schedule_id`, `start`, `end`, `start_date`, `end_date`) VALUES (1,1,152,'2023-11-06 12:00:00','2023-11-07 12:00:00','2023-11-06','2023-11-07');
INSERT INTO `calcms_studio_timeslot_dates` (`project_id`, `studio_id`, `schedule_id`, `start`, `end`, `start_date`, `end_date`) VALUES (1,1,152,'2023-09-18 12:00:00','2023-09-19 12:00:00','2023-09-18','2023-09-19');
INSERT INTO `calcms_studio_timeslot_dates` (`project_id`, `studio_id`, `schedule_id`, `start`, `end`, `start_date`, `end_date`) VALUES (1,1,152,'2023-06-01 12:00:00','2023-06-02 12:00:00','2023-06-01','2023-06-02');
INSERT INTO `calcms_studio_timeslot_dates` (`project_id`, `studio_id`, `schedule_id`, `start`, `end`, `start_date`, `end_date`) VALUES (1,1,152,'2023-08-26 12:00:00','2023-08-27 12:00:00','2023-08-26','2023-08-27');
INSERT INTO `calcms_studio_timeslot_dates` (`project_id`, `studio_id`, `schedule_id`, `start`, `end`, `start_date`, `end_date`) VALUES (1,1,152,'2023-05-19 12:00:00','2023-05-20 12:00:00','2023-05-19','2023-05-20');
INSERT INTO `calcms_studio_timeslot_dates` (`project_id`, `studio_id`, `schedule_id`, `start`, `end`, `start_date`, `end_date`) VALUES (1,1,152,'2023-12-15 12:00:00','2023-12-16 12:00:00','2023-12-15','2023-12-16');
INSERT INTO `calcms_studio_timeslot_dates` (`project_id`, `studio_id`, `schedule_id`, `start`, `end`, `start_date`, `end_date`) VALUES (1,1,152,'2023-07-20 12:00:00','2023-07-21 12:00:00','2023-07-20','2023-07-21');
INSERT INTO `calcms_studio_timeslot_dates` (`project_id`, `studio_id`, `schedule_id`, `start`, `end`, `start_date`, `end_date`) VALUES (1,1,152,'2023-09-21 12:00:00','2023-09-22 12:00:00','2023-09-21','2023-09-22');
INSERT INTO `calcms_studio_timeslot_dates` (`project_id`, `studio_id`, `schedule_id`, `start`, `end`, `start_date`, `end_date`) VALUES (1,1,152,'2023-07-19 12:00:00','2023-07-20 12:00:00','2023-07-19','2023-07-20');
INSERT INTO `calcms_studio_timeslot_dates` (`project_id`, `studio_id`, `schedule_id`, `start`, `end`, `start_date`, `end_date`) VALUES (1,1,152,'2023-05-20 12:00:00','2023-05-21 12:00:00','2023-05-20','2023-05-21');
INSERT INTO `calcms_studio_timeslot_dates` (`project_id`, `studio_id`, `schedule_id`, `start`, `end`, `start_date`, `end_date`) VALUES (1,1,152,'2023-06-11 12:00:00','2023-06-12 12:00:00','2023-06-11','2023-06-12');
INSERT INTO `calcms_studio_timeslot_dates` (`project_id`, `studio_id`, `schedule_id`, `start`, `end`, `start_date`, `end_date`) VALUES (1,1,152,'2023-09-08 12:00:00','2023-09-09 12:00:00','2023-09-08','2023-09-09');
INSERT INTO `calcms_studio_timeslot_dates` (`project_id`, `studio_id`, `schedule_id`, `start`, `end`, `start_date`, `end_date`) VALUES (1,1,152,'2023-11-16 12:00:00','2023-11-17 12:00:00','2023-11-16','2023-11-17');
INSERT INTO `calcms_studio_timeslot_dates` (`project_id`, `studio_id`, `schedule_id`, `start`, `end`, `start_date`, `end_date`) VALUES (1,1,152,'2023-10-18 12:00:00','2023-10-19 12:00:00','2023-10-18','2023-10-19');
INSERT INTO `calcms_studio_timeslot_dates` (`project_id`, `studio_id`, `schedule_id`, `start`, `end`, `start_date`, `end_date`) VALUES (1,1,152,'2023-05-25 12:00:00','2023-05-26 12:00:00','2023-05-25','2023-05-26');
INSERT INTO `calcms_studio_timeslot_dates` (`project_id`, `studio_id`, `schedule_id`, `start`, `end`, `start_date`, `end_date`) VALUES (1,1,152,'2024-01-26 12:00:00','2024-01-27 12:00:00','2024-01-26','2024-01-27');
INSERT INTO `calcms_studio_timeslot_dates` (`project_id`, `studio_id`, `schedule_id`, `start`, `end`, `start_date`, `end_date`) VALUES (1,1,152,'2023-05-09 12:00:00','2023-05-10 12:00:00','2023-05-09','2023-05-10');
INSERT INTO `calcms_studio_timeslot_dates` (`project_id`, `studio_id`, `schedule_id`, `start`, `end`, `start_date`, `end_date`) VALUES (1,1,152,'2023-10-21 12:00:00','2023-10-22 12:00:00','2023-10-21','2023-10-22');
INSERT INTO `calcms_studio_timeslot_dates` (`project_id`, `studio_id`, `schedule_id`, `start`, `end`, `start_date`, `end_date`) VALUES (1,1,152,'2023-03-26 12:00:00','2023-03-27 12:00:00','2023-03-26','2023-03-27');
INSERT INTO `calcms_studio_timeslot_dates` (`project_id`, `studio_id`, `schedule_id`, `start`, `end`, `start_date`, `end_date`) VALUES (1,1,152,'2023-06-28 12:00:00','2023-06-29 12:00:00','2023-06-28','2023-06-29');
INSERT INTO `calcms_studio_timeslot_dates` (`project_id`, `studio_id`, `schedule_id`, `start`, `end`, `start_date`, `end_date`) VALUES (1,1,152,'2023-12-05 12:00:00','2023-12-06 12:00:00','2023-12-05','2023-12-06');
INSERT INTO `calcms_studio_timeslot_dates` (`project_id`, `studio_id`, `schedule_id`, `start`, `end`, `start_date`, `end_date`) VALUES (1,1,152,'2023-12-29 12:00:00','2023-12-30 12:00:00','2023-12-29','2023-12-30');
INSERT INTO `calcms_studio_timeslot_dates` (`project_id`, `studio_id`, `schedule_id`, `start`, `end`, `start_date`, `end_date`) VALUES (1,1,152,'2023-04-08 12:00:00','2023-04-09 12:00:00','2023-04-08','2023-04-09');
INSERT INTO `calcms_studio_timeslot_dates` (`project_id`, `studio_id`, `schedule_id`, `start`, `end`, `start_date`, `end_date`) VALUES (1,1,152,'2023-08-31 12:00:00','2023-09-01 12:00:00','2023-08-31','2023-09-01');
INSERT INTO `calcms_studio_timeslot_dates` (`project_id`, `studio_id`, `schedule_id`, `start`, `end`, `start_date`, `end_date`) VALUES (1,1,152,'2023-12-13 12:00:00','2023-12-14 12:00:00','2023-12-13','2023-12-14');
INSERT INTO `calcms_studio_timeslot_dates` (`project_id`, `studio_id`, `schedule_id`, `start`, `end`, `start_date`, `end_date`) VALUES (1,1,152,'2023-07-23 12:00:00','2023-07-24 12:00:00','2023-07-23','2023-07-24');
INSERT INTO `calcms_studio_timeslot_dates` (`project_id`, `studio_id`, `schedule_id`, `start`, `end`, `start_date`, `end_date`) VALUES (1,1,152,'2023-02-16 12:00:00','2023-02-17 12:00:00','2023-02-16','2023-02-17');
INSERT INTO `calcms_studio_timeslot_dates` (`project_id`, `studio_id`, `schedule_id`, `start`, `end`, `start_date`, `end_date`) VALUES (1,1,152,'2023-10-17 12:00:00','2023-10-18 12:00:00','2023-10-17','2023-10-18');
INSERT INTO `calcms_studio_timeslot_dates` (`project_id`, `studio_id`, `schedule_id`, `start`, `end`, `start_date`, `end_date`) VALUES (1,1,152,'2023-09-07 12:00:00','2023-09-08 12:00:00','2023-09-07','2023-09-08');
INSERT INTO `calcms_studio_timeslot_dates` (`project_id`, `studio_id`, `schedule_id`, `start`, `end`, `start_date`, `end_date`) VALUES (1,1,152,'2024-01-29 12:00:00','2024-01-30 12:00:00','2024-01-29','2024-01-30');
INSERT INTO `calcms_studio_timeslot_dates` (`project_id`, `studio_id`, `schedule_id`, `start`, `end`, `start_date`, `end_date`) VALUES (1,1,152,'2023-05-06 12:00:00','2023-05-07 12:00:00','2023-05-06','2023-05-07');
INSERT INTO `calcms_studio_timeslot_dates` (`project_id`, `studio_id`, `schedule_id`, `start`, `end`, `start_date`, `end_date`) VALUES (1,1,152,'2024-01-05 12:00:00','2024-01-06 12:00:00','2024-01-05','2024-01-06');
INSERT INTO `calcms_studio_timeslot_dates` (`project_id`, `studio_id`, `schedule_id`, `start`, `end`, `start_date`, `end_date`) VALUES (1,1,152,'2023-08-10 12:00:00','2023-08-11 12:00:00','2023-08-10','2023-08-11');
INSERT INTO `calcms_studio_timeslot_dates` (`project_id`, `studio_id`, `schedule_id`, `start`, `end`, `start_date`, `end_date`) VALUES (1,1,152,'2023-03-05 12:00:00','2023-03-06 12:00:00','2023-03-05','2023-03-06');
INSERT INTO `calcms_studio_timeslot_dates` (`project_id`, `studio_id`, `schedule_id`, `start`, `end`, `start_date`, `end_date`) VALUES (1,1,152,'2023-03-29 12:00:00','2023-03-30 12:00:00','2023-03-29','2023-03-30');
INSERT INTO `calcms_studio_timeslot_dates` (`project_id`, `studio_id`, `schedule_id`, `start`, `end`, `start_date`, `end_date`) VALUES (1,1,152,'2023-12-26 12:00:00','2023-12-27 12:00:00','2023-12-26','2023-12-27');
INSERT INTO `calcms_studio_timeslot_dates` (`project_id`, `studio_id`, `schedule_id`, `start`, `end`, `start_date`, `end_date`) VALUES (1,1,152,'2023-04-24 12:00:00','2023-04-25 12:00:00','2023-04-24','2023-04-25');
INSERT INTO `calcms_studio_timeslot_dates` (`project_id`, `studio_id`, `schedule_id`, `start`, `end`, `start_date`, `end_date`) VALUES (1,1,152,'2023-02-23 12:00:00','2023-02-24 12:00:00','2023-02-23','2023-02-24');
INSERT INTO `calcms_studio_timeslot_dates` (`project_id`, `studio_id`, `schedule_id`, `start`, `end`, `start_date`, `end_date`) VALUES (1,1,152,'2023-06-27 12:00:00','2023-06-28 12:00:00','2023-06-27','2023-06-28');
INSERT INTO `calcms_studio_timeslot_dates` (`project_id`, `studio_id`, `schedule_id`, `start`, `end`, `start_date`, `end_date`) VALUES (1,1,152,'2023-07-16 12:00:00','2023-07-17 12:00:00','2023-07-16','2023-07-17');
INSERT INTO `calcms_studio_timeslot_dates` (`project_id`, `studio_id`, `schedule_id`, `start`, `end`, `start_date`, `end_date`) VALUES (1,1,152,'2023-08-15 12:00:00','2023-08-16 12:00:00','2023-08-15','2023-08-16');
INSERT INTO `calcms_studio_timeslot_dates` (`project_id`, `studio_id`, `schedule_id`, `start`, `end`, `start_date`, `end_date`) VALUES (1,1,152,'2023-11-19 12:00:00','2023-11-20 12:00:00','2023-11-19','2023-11-20');
INSERT INTO `calcms_studio_timeslot_dates` (`project_id`, `studio_id`, `schedule_id`, `start`, `end`, `start_date`, `end_date`) VALUES (1,1,152,'2023-02-19 12:00:00','2023-02-20 12:00:00','2023-02-19','2023-02-20');
INSERT INTO `calcms_studio_timeslot_dates` (`project_id`, `studio_id`, `schedule_id`, `start`, `end`, `start_date`, `end_date`) VALUES (1,1,152,'2023-06-12 12:00:00','2023-06-13 12:00:00','2023-06-12','2023-06-13');
INSERT INTO `calcms_studio_timeslot_dates` (`project_id`, `studio_id`, `schedule_id`, `start`, `end`, `start_date`, `end_date`) VALUES (1,1,152,'2023-09-24 12:00:00','2023-09-25 12:00:00','2023-09-24','2023-09-25');
INSERT INTO `calcms_studio_timeslot_dates` (`project_id`, `studio_id`, `schedule_id`, `start`, `end`, `start_date`, `end_date`) VALUES (1,1,152,'2023-06-30 12:00:00','2023-07-01 12:00:00','2023-06-30','2023-07-01');
INSERT INTO `calcms_studio_timeslot_dates` (`project_id`, `studio_id`, `schedule_id`, `start`, `end`, `start_date`, `end_date`) VALUES (1,1,152,'2023-08-03 12:00:00','2023-08-04 12:00:00','2023-08-03','2023-08-04');
INSERT INTO `calcms_studio_timeslot_dates` (`project_id`, `studio_id`, `schedule_id`, `start`, `end`, `start_date`, `end_date`) VALUES (1,1,152,'2023-11-23 12:00:00','2023-11-24 12:00:00','2023-11-23','2023-11-24');
INSERT INTO `calcms_studio_timeslot_dates` (`project_id`, `studio_id`, `schedule_id`, `start`, `end`, `start_date`, `end_date`) VALUES (1,1,152,'2023-04-07 12:00:00','2023-04-08 12:00:00','2023-04-07','2023-04-08');
INSERT INTO `calcms_studio_timeslot_dates` (`project_id`, `studio_id`, `schedule_id`, `start`, `end`, `start_date`, `end_date`) VALUES (1,1,152,'2023-06-04 12:00:00','2023-06-05 12:00:00','2023-06-04','2023-06-05');
INSERT INTO `calcms_studio_timeslot_dates` (`project_id`, `studio_id`, `schedule_id`, `start`, `end`, `start_date`, `end_date`) VALUES (1,1,152,'2023-10-22 12:00:00','2023-10-23 12:00:00','2023-10-22','2023-10-23');
INSERT INTO `calcms_studio_timeslot_dates` (`project_id`, `studio_id`, `schedule_id`, `start`, `end`, `start_date`, `end_date`) VALUES (1,1,152,'2024-01-13 12:00:00','2024-01-14 12:00:00','2024-01-13','2024-01-14');
INSERT INTO `calcms_studio_timeslot_dates` (`project_id`, `studio_id`, `schedule_id`, `start`, `end`, `start_date`, `end_date`) VALUES (1,1,152,'2023-03-13 12:00:00','2023-03-14 12:00:00','2023-03-13','2023-03-14');
INSERT INTO `calcms_studio_timeslot_dates` (`project_id`, `studio_id`, `schedule_id`, `start`, `end`, `start_date`, `end_date`) VALUES (1,1,152,'2023-10-24 12:00:00','2023-10-25 12:00:00','2023-10-24','2023-10-25');
INSERT INTO `calcms_studio_timeslot_dates` (`project_id`, `studio_id`, `schedule_id`, `start`, `end`, `start_date`, `end_date`) VALUES (1,1,152,'2023-06-02 12:00:00','2023-06-03 12:00:00','2023-06-02','2023-06-03');
INSERT INTO `calcms_studio_timeslot_dates` (`project_id`, `studio_id`, `schedule_id`, `start`, `end`, `start_date`, `end_date`) VALUES (1,1,152,'2023-12-31 12:00:00','2024-01-01 12:00:00','2023-12-31','2024-01-01');
INSERT INTO `calcms_studio_timeslot_dates` (`project_id`, `studio_id`, `schedule_id`, `start`, `end`, `start_date`, `end_date`) VALUES (1,1,152,'2023-02-25 12:00:00','2023-02-26 12:00:00','2023-02-25','2023-02-26');
INSERT INTO `calcms_studio_timeslot_dates` (`project_id`, `studio_id`, `schedule_id`, `start`, `end`, `start_date`, `end_date`) VALUES (1,1,152,'2023-02-09 12:00:00','2023-02-10 12:00:00','2023-02-09','2023-02-10');
INSERT INTO `calcms_studio_timeslot_dates` (`project_id`, `studio_id`, `schedule_id`, `start`, `end`, `start_date`, `end_date`) VALUES (1,1,152,'2023-04-17 12:00:00','2023-04-18 12:00:00','2023-04-17','2023-04-18');
INSERT INTO `calcms_studio_timeslot_dates` (`project_id`, `studio_id`, `schedule_id`, `start`, `end`, `start_date`, `end_date`) VALUES (1,1,152,'2023-08-13 12:00:00','2023-08-14 12:00:00','2023-08-13','2023-08-14');
INSERT INTO `calcms_studio_timeslot_dates` (`project_id`, `studio_id`, `schedule_id`, `start`, `end`, `start_date`, `end_date`) VALUES (1,1,152,'2023-09-22 12:00:00','2023-09-23 12:00:00','2023-09-22','2023-09-23');
INSERT INTO `calcms_studio_timeslot_dates` (`project_id`, `studio_id`, `schedule_id`, `start`, `end`, `start_date`, `end_date`) VALUES (1,1,152,'2024-01-03 12:00:00','2024-01-04 12:00:00','2024-01-03','2024-01-04');
INSERT INTO `calcms_studio_timeslot_dates` (`project_id`, `studio_id`, `schedule_id`, `start`, `end`, `start_date`, `end_date`) VALUES (1,1,152,'2023-06-14 12:00:00','2023-06-15 12:00:00','2023-06-14','2023-06-15');
INSERT INTO `calcms_studio_timeslot_dates` (`project_id`, `studio_id`, `schedule_id`, `start`, `end`, `start_date`, `end_date`) VALUES (1,1,152,'2023-02-20 12:00:00','2023-02-21 12:00:00','2023-02-20','2023-02-21');
INSERT INTO `calcms_studio_timeslot_dates` (`project_id`, `studio_id`, `schedule_id`, `start`, `end`, `start_date`, `end_date`) VALUES (1,1,152,'2023-03-03 12:00:00','2023-03-04 12:00:00','2023-03-03','2023-03-04');
INSERT INTO `calcms_studio_timeslot_dates` (`project_id`, `studio_id`, `schedule_id`, `start`, `end`, `start_date`, `end_date`) VALUES (1,1,152,'2023-05-16 12:00:00','2023-05-17 12:00:00','2023-05-16','2023-05-17');
INSERT INTO `calcms_studio_timeslot_dates` (`project_id`, `studio_id`, `schedule_id`, `start`, `end`, `start_date`, `end_date`) VALUES (1,1,152,'2024-01-15 12:00:00','2024-01-16 12:00:00','2024-01-15','2024-01-16');
INSERT INTO `calcms_studio_timeslot_dates` (`project_id`, `studio_id`, `schedule_id`, `start`, `end`, `start_date`, `end_date`) VALUES (1,1,152,'2023-09-17 12:00:00','2023-09-18 12:00:00','2023-09-17','2023-09-18');
INSERT INTO `calcms_studio_timeslot_dates` (`project_id`, `studio_id`, `schedule_id`, `start`, `end`, `start_date`, `end_date`) VALUES (1,1,152,'2023-11-20 12:00:00','2023-11-21 12:00:00','2023-11-20','2023-11-21');
INSERT INTO `calcms_studio_timeslot_dates` (`project_id`, `studio_id`, `schedule_id`, `start`, `end`, `start_date`, `end_date`) VALUES (1,1,152,'2023-10-07 12:00:00','2023-10-08 12:00:00','2023-10-07','2023-10-08');
INSERT INTO `calcms_studio_timeslot_dates` (`project_id`, `studio_id`, `schedule_id`, `start`, `end`, `start_date`, `end_date`) VALUES (1,1,152,'2023-03-15 12:00:00','2023-03-16 12:00:00','2023-03-15','2023-03-16');
INSERT INTO `calcms_studio_timeslot_dates` (`project_id`, `studio_id`, `schedule_id`, `start`, `end`, `start_date`, `end_date`) VALUES (1,1,152,'2023-03-10 12:00:00','2023-03-11 12:00:00','2023-03-10','2023-03-11');
INSERT INTO `calcms_studio_timeslot_dates` (`project_id`, `studio_id`, `schedule_id`, `start`, `end`, `start_date`, `end_date`) VALUES (1,1,152,'2023-07-06 12:00:00','2023-07-07 12:00:00','2023-07-06','2023-07-07');
INSERT INTO `calcms_studio_timeslot_dates` (`project_id`, `studio_id`, `schedule_id`, `start`, `end`, `start_date`, `end_date`) VALUES (1,1,152,'2023-04-22 12:00:00','2023-04-23 12:00:00','2023-04-22','2023-04-23');
INSERT INTO `calcms_studio_timeslot_dates` (`project_id`, `studio_id`, `schedule_id`, `start`, `end`, `start_date`, `end_date`) VALUES (1,1,152,'2023-11-25 12:00:00','2023-11-26 12:00:00','2023-11-25','2023-11-26');
INSERT INTO `calcms_studio_timeslot_dates` (`project_id`, `studio_id`, `schedule_id`, `start`, `end`, `start_date`, `end_date`) VALUES (1,1,152,'2023-11-09 12:00:00','2023-11-10 12:00:00','2023-11-09','2023-11-10');
INSERT INTO `calcms_studio_timeslot_dates` (`project_id`, `studio_id`, `schedule_id`, `start`, `end`, `start_date`, `end_date`) VALUES (1,1,152,'2023-08-29 12:00:00','2023-08-30 12:00:00','2023-08-29','2023-08-30');
INSERT INTO `calcms_studio_timeslot_dates` (`project_id`, `studio_id`, `schedule_id`, `start`, `end`, `start_date`, `end_date`) VALUES (1,1,152,'2024-01-10 12:00:00','2024-01-11 12:00:00','2024-01-10','2024-01-11');
INSERT INTO `calcms_studio_timeslot_dates` (`project_id`, `studio_id`, `schedule_id`, `start`, `end`, `start_date`, `end_date`) VALUES (1,1,152,'2023-08-05 12:00:00','2023-08-06 12:00:00','2023-08-05','2023-08-06');
INSERT INTO `calcms_studio_timeslot_dates` (`project_id`, `studio_id`, `schedule_id`, `start`, `end`, `start_date`, `end_date`) VALUES (1,1,152,'2023-03-27 12:00:00','2023-03-28 12:00:00','2023-03-27','2023-03-28');
INSERT INTO `calcms_studio_timeslot_dates` (`project_id`, `studio_id`, `schedule_id`, `start`, `end`, `start_date`, `end_date`) VALUES (1,1,152,'2023-07-18 12:00:00','2023-07-19 12:00:00','2023-07-18','2023-07-19');
INSERT INTO `calcms_studio_timeslot_dates` (`project_id`, `studio_id`, `schedule_id`, `start`, `end`, `start_date`, `end_date`) VALUES (1,1,152,'2023-10-19 12:00:00','2023-10-20 12:00:00','2023-10-19','2023-10-20');
INSERT INTO `calcms_studio_timeslot_dates` (`project_id`, `studio_id`, `schedule_id`, `start`, `end`, `start_date`, `end_date`) VALUES (1,1,152,'2024-01-27 12:00:00','2024-01-28 12:00:00','2024-01-27','2024-01-28');
INSERT INTO `calcms_studio_timeslot_dates` (`project_id`, `studio_id`, `schedule_id`, `start`, `end`, `start_date`, `end_date`) VALUES (1,1,152,'2023-12-11 12:00:00','2023-12-12 12:00:00','2023-12-11','2023-12-12');
INSERT INTO `calcms_studio_timeslot_dates` (`project_id`, `studio_id`, `schedule_id`, `start`, `end`, `start_date`, `end_date`) VALUES (1,1,152,'2023-09-25 12:00:00','2023-09-26 12:00:00','2023-09-25','2023-09-26');
INSERT INTO `calcms_studio_timeslot_dates` (`project_id`, `studio_id`, `schedule_id`, `start`, `end`, `start_date`, `end_date`) VALUES (1,1,152,'2023-09-09 12:00:00','2023-09-10 12:00:00','2023-09-09','2023-09-10');
INSERT INTO `calcms_studio_timeslot_dates` (`project_id`, `studio_id`, `schedule_id`, `start`, `end`, `start_date`, `end_date`) VALUES (1,1,152,'2023-05-08 12:00:00','2023-05-09 12:00:00','2023-05-08','2023-05-09');
INSERT INTO `calcms_studio_timeslot_dates` (`project_id`, `studio_id`, `schedule_id`, `start`, `end`, `start_date`, `end_date`) VALUES (1,1,152,'2023-09-20 12:00:00','2023-09-21 12:00:00','2023-09-20','2023-09-21');
INSERT INTO `calcms_studio_timeslot_dates` (`project_id`, `studio_id`, `schedule_id`, `start`, `end`, `start_date`, `end_date`) VALUES (1,1,152,'2023-07-21 12:00:00','2023-07-22 12:00:00','2023-07-21','2023-07-22');
INSERT INTO `calcms_studio_timeslot_dates` (`project_id`, `studio_id`, `schedule_id`, `start`, `end`, `start_date`, `end_date`) VALUES (1,1,152,'2023-11-17 12:00:00','2023-11-18 12:00:00','2023-11-17','2023-11-18');
INSERT INTO `calcms_studio_timeslot_dates` (`project_id`, `studio_id`, `schedule_id`, `start`, `end`, `start_date`, `end_date`) VALUES (1,1,152,'2023-02-22 12:00:00','2023-02-23 12:00:00','2023-02-22','2023-02-23');
INSERT INTO `calcms_studio_timeslot_dates` (`project_id`, `studio_id`, `schedule_id`, `start`, `end`, `start_date`, `end_date`) VALUES (1,1,152,'2023-12-28 12:00:00','2023-12-29 12:00:00','2023-12-28','2023-12-29');
INSERT INTO `calcms_studio_timeslot_dates` (`project_id`, `studio_id`, `schedule_id`, `start`, `end`, `start_date`, `end_date`) VALUES (1,1,152,'2023-06-05 12:00:00','2023-06-06 12:00:00','2023-06-05','2023-06-06');
INSERT INTO `calcms_studio_timeslot_dates` (`project_id`, `studio_id`, `schedule_id`, `start`, `end`, `start_date`, `end_date`) VALUES (1,1,152,'2023-06-29 12:00:00','2023-06-30 12:00:00','2023-06-29','2023-06-30');
INSERT INTO `calcms_studio_timeslot_dates` (`project_id`, `studio_id`, `schedule_id`, `start`, `end`, `start_date`, `end_date`) VALUES (1,1,152,'2023-03-04 12:00:00','2023-03-05 12:00:00','2023-03-04','2023-03-05');
INSERT INTO `calcms_studio_timeslot_dates` (`project_id`, `studio_id`, `schedule_id`, `start`, `end`, `start_date`, `end_date`) VALUES (1,1,152,'2023-08-02 12:00:00','2023-08-03 12:00:00','2023-08-02','2023-08-03');
INSERT INTO `calcms_studio_timeslot_dates` (`project_id`, `studio_id`, `schedule_id`, `start`, `end`, `start_date`, `end_date`) VALUES (1,1,152,'2023-11-22 12:00:00','2023-11-23 12:00:00','2023-11-22','2023-11-23');
INSERT INTO `calcms_studio_timeslot_dates` (`project_id`, `studio_id`, `schedule_id`, `start`, `end`, `start_date`, `end_date`) VALUES (1,1,152,'2023-04-25 12:00:00','2023-04-26 12:00:00','2023-04-25','2023-04-26');
INSERT INTO `calcms_studio_timeslot_dates` (`project_id`, `studio_id`, `schedule_id`, `start`, `end`, `start_date`, `end_date`) VALUES (1,1,152,'2023-04-09 12:00:00','2023-04-10 12:00:00','2023-04-09','2023-04-10');
INSERT INTO `calcms_studio_timeslot_dates` (`project_id`, `studio_id`, `schedule_id`, `start`, `end`, `start_date`, `end_date`) VALUES (1,1,152,'2023-02-17 12:00:00','2023-02-18 12:00:00','2023-02-17','2023-02-18');
INSERT INTO `calcms_studio_timeslot_dates` (`project_id`, `studio_id`, `schedule_id`, `start`, `end`, `start_date`, `end_date`) VALUES (1,1,152,'2023-06-13 12:00:00','2023-06-14 12:00:00','2023-06-13','2023-06-14');
INSERT INTO `calcms_studio_timeslot_dates` (`project_id`, `studio_id`, `schedule_id`, `start`, `end`, `start_date`, `end_date`) VALUES (1,1,152,'2024-01-04 12:00:00','2024-01-05 12:00:00','2024-01-04','2024-01-05');
INSERT INTO `calcms_studio_timeslot_dates` (`project_id`, `studio_id`, `schedule_id`, `start`, `end`, `start_date`, `end_date`) VALUES (1,1,152,'2023-03-12 12:00:00','2023-03-13 12:00:00','2023-03-12','2023-03-13');
INSERT INTO `calcms_studio_timeslot_dates` (`project_id`, `studio_id`, `schedule_id`, `start`, `end`, `start_date`, `end_date`) VALUES (1,1,152,'2023-08-14 12:00:00','2023-08-15 12:00:00','2023-08-14','2023-08-15');
INSERT INTO `calcms_studio_timeslot_dates` (`project_id`, `studio_id`, `schedule_id`, `start`, `end`, `start_date`, `end_date`) VALUES (1,1,152,'2024-01-30 12:00:00','2024-01-31 12:00:00','2024-01-30','2024-01-31');
INSERT INTO `calcms_studio_timeslot_dates` (`project_id`, `studio_id`, `schedule_id`, `start`, `end`, `start_date`, `end_date`) VALUES (1,1,152,'2023-10-23 12:00:00','2023-10-24 12:00:00','2023-10-23','2023-10-24');
INSERT INTO `calcms_studio_timeslot_dates` (`project_id`, `studio_id`, `schedule_id`, `start`, `end`, `start_date`, `end_date`) VALUES (1,1,152,'2023-03-30 12:00:00','2023-03-31 12:00:00','2023-03-30','2023-03-31');
INSERT INTO `calcms_studio_timeslot_dates` (`project_id`, `studio_id`, `schedule_id`, `start`, `end`, `start_date`, `end_date`) VALUES (1,1,152,'2023-04-20 12:00:00','2023-04-21 12:00:00','2023-04-20','2023-04-21');
INSERT INTO `calcms_studio_timeslot_dates` (`project_id`, `studio_id`, `schedule_id`, `start`, `end`, `start_date`, `end_date`) VALUES (1,1,152,'2024-01-12 12:00:00','2024-01-13 12:00:00','2024-01-12','2024-01-13');
INSERT INTO `calcms_studio_timeslot_dates` (`project_id`, `studio_id`, `schedule_id`, `start`, `end`, `start_date`, `end_date`) VALUES (1,1,152,'2023-04-19 12:00:00','2023-04-20 12:00:00','2023-04-19','2023-04-20');
INSERT INTO `calcms_studio_timeslot_dates` (`project_id`, `studio_id`, `schedule_id`, `start`, `end`, `start_date`, `end_date`) VALUES (1,1,152,'2023-08-12 12:00:00','2023-08-13 12:00:00','2023-08-12','2023-08-13');
INSERT INTO `calcms_studio_timeslot_dates` (`project_id`, `studio_id`, `schedule_id`, `start`, `end`, `start_date`, `end_date`) VALUES (1,1,152,'2023-03-14 12:00:00','2023-03-15 12:00:00','2023-03-14','2023-03-15');
INSERT INTO `calcms_studio_timeslot_dates` (`project_id`, `studio_id`, `schedule_id`, `start`, `end`, `start_date`, `end_date`) VALUES (1,1,152,'2024-01-14 12:00:00','2024-01-15 12:00:00','2024-01-14','2024-01-15');
INSERT INTO `calcms_studio_timeslot_dates` (`project_id`, `studio_id`, `schedule_id`, `start`, `end`, `start_date`, `end_date`) VALUES (1,1,152,'2023-06-03 12:00:00','2023-06-04 12:00:00','2023-06-03','2023-06-04');
INSERT INTO `calcms_studio_timeslot_dates` (`project_id`, `studio_id`, `schedule_id`, `start`, `end`, `start_date`, `end_date`) VALUES (1,1,152,'2023-02-07 12:00:00','2023-02-08 12:00:00','2023-02-07','2023-02-08');
INSERT INTO `calcms_studio_timeslot_dates` (`project_id`, `studio_id`, `schedule_id`, `start`, `end`, `start_date`, `end_date`) VALUES (1,1,152,'2023-08-30 12:00:00','2023-08-31 12:00:00','2023-08-30','2023-08-31');
INSERT INTO `calcms_studio_timeslot_dates` (`project_id`, `studio_id`, `schedule_id`, `start`, `end`, `start_date`, `end_date`) VALUES (1,1,152,'2023-11-24 12:00:00','2023-11-25 12:00:00','2023-11-24','2023-11-25');
INSERT INTO `calcms_studio_timeslot_dates` (`project_id`, `studio_id`, `schedule_id`, `start`, `end`, `start_date`, `end_date`) VALUES (1,1,152,'2023-08-04 12:00:00','2023-08-05 12:00:00','2023-08-04','2023-08-05');
INSERT INTO `calcms_studio_timeslot_dates` (`project_id`, `studio_id`, `schedule_id`, `start`, `end`, `start_date`, `end_date`) VALUES (1,1,152,'2023-03-02 12:00:00','2023-03-03 12:00:00','2023-03-02','2023-03-03');
INSERT INTO `calcms_studio_timeslot_dates` (`project_id`, `studio_id`, `schedule_id`, `start`, `end`, `start_date`, `end_date`) VALUES (1,1,152,'2024-01-02 12:00:00','2024-01-03 12:00:00','2024-01-02','2024-01-03');
INSERT INTO `calcms_studio_timeslot_dates` (`project_id`, `studio_id`, `schedule_id`, `start`, `end`, `start_date`, `end_date`) VALUES (1,1,152,'2023-09-23 12:00:00','2023-09-24 12:00:00','2023-09-23','2023-09-24');
INSERT INTO `calcms_studio_timeslot_dates` (`project_id`, `studio_id`, `schedule_id`, `start`, `end`, `start_date`, `end_date`) VALUES (1,1,152,'2023-06-10 12:00:00','2023-06-11 12:00:00','2023-06-10','2023-06-11');
INSERT INTO `calcms_studio_timeslot_dates` (`project_id`, `studio_id`, `schedule_id`, `start`, `end`, `start_date`, `end_date`) VALUES (1,1,152,'2023-05-21 12:00:00','2023-05-22 12:00:00','2023-05-21','2023-05-22');
INSERT INTO `calcms_studio_timeslot_dates` (`project_id`, `studio_id`, `schedule_id`, `start`, `end`, `start_date`, `end_date`) VALUES (1,1,152,'2023-07-08 12:00:00','2023-07-09 12:00:00','2023-07-08','2023-07-09');
INSERT INTO `calcms_studio_timeslot_dates` (`project_id`, `studio_id`, `schedule_id`, `start`, `end`, `start_date`, `end_date`) VALUES (1,1,152,'2023-09-19 12:00:00','2023-09-20 12:00:00','2023-09-19','2023-09-20');
INSERT INTO `calcms_studio_timeslot_dates` (`project_id`, `studio_id`, `schedule_id`, `start`, `end`, `start_date`, `end_date`) VALUES (1,1,152,'2023-12-01 12:00:00','2023-12-02 12:00:00','2023-12-01','2023-12-02');
INSERT INTO `calcms_studio_timeslot_dates` (`project_id`, `studio_id`, `schedule_id`, `start`, `end`, `start_date`, `end_date`) VALUES (1,1,152,'2023-10-25 12:00:00','2023-10-26 12:00:00','2023-10-25','2023-10-26');
INSERT INTO `calcms_studio_timeslot_dates` (`project_id`, `studio_id`, `schedule_id`, `start`, `end`, `start_date`, `end_date`) VALUES (1,1,152,'2023-10-09 12:00:00','2023-10-10 12:00:00','2023-10-09','2023-10-10');
INSERT INTO `calcms_studio_timeslot_dates` (`project_id`, `studio_id`, `schedule_id`, `start`, `end`, `start_date`, `end_date`) VALUES (1,1,152,'2023-02-24 12:00:00','2023-02-25 12:00:00','2023-02-24','2023-02-25');
INSERT INTO `calcms_studio_timeslot_dates` (`project_id`, `studio_id`, `schedule_id`, `start`, `end`, `start_date`, `end_date`) VALUES (1,1,152,'2023-11-07 12:00:00','2023-11-08 12:00:00','2023-11-07','2023-11-08');
INSERT INTO `calcms_studio_timeslot_dates` (`project_id`, `studio_id`, `schedule_id`, `start`, `end`, `start_date`, `end_date`) VALUES (1,1,152,'2023-04-23 12:00:00','2023-04-24 12:00:00','2023-04-23','2023-04-24');
INSERT INTO `calcms_studio_timeslot_dates` (`project_id`, `studio_id`, `schedule_id`, `start`, `end`, `start_date`, `end_date`) VALUES (1,1,152,'2023-10-20 12:00:00','2023-10-21 12:00:00','2023-10-20','2023-10-21');
INSERT INTO `calcms_studio_timeslot_dates` (`project_id`, `studio_id`, `schedule_id`, `start`, `end`, `start_date`, `end_date`) VALUES (1,1,152,'2023-08-27 12:00:00','2023-08-28 12:00:00','2023-08-27','2023-08-28');
INSERT INTO `calcms_studio_timeslot_dates` (`project_id`, `studio_id`, `schedule_id`, `start`, `end`, `start_date`, `end_date`) VALUES (1,1,152,'2023-05-18 12:00:00','2023-05-19 12:00:00','2023-05-18','2023-05-19');
INSERT INTO `calcms_studio_timeslot_dates` (`project_id`, `studio_id`, `schedule_id`, `start`, `end`, `start_date`, `end_date`) VALUES (1,1,152,'2023-06-15 12:00:00','2023-06-16 12:00:00','2023-06-15','2023-06-16');
/*!40000 ALTER TABLE `calcms_studio_timeslot_dates` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `calcms_studio_timeslot_schedule`
--

DROP TABLE IF EXISTS `calcms_studio_timeslot_schedule`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `calcms_studio_timeslot_schedule` (
  `id` int unsigned NOT NULL AUTO_INCREMENT,
  `project_id` int unsigned NOT NULL,
  `studio_id` int unsigned NOT NULL,
  `start` datetime NOT NULL,
  `end` datetime NOT NULL,
  `frequency` int unsigned NOT NULL,
  `end_date` date NOT NULL,
  PRIMARY KEY (`id`),
  KEY `project_id` (`project_id`),
  KEY `studio_id` (`studio_id`),
  KEY `start` (`start`),
  KEY `end` (`end`)
) ENGINE=MyISAM AUTO_INCREMENT=153 DEFAULT CHARSET=utf8mb3;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `calcms_studio_timeslot_schedule`
--

LOCK TABLES `calcms_studio_timeslot_schedule` WRITE;
/*!40000 ALTER TABLE `calcms_studio_timeslot_schedule` DISABLE KEYS */;
INSERT INTO `calcms_studio_timeslot_schedule` (`id`, `project_id`, `studio_id`, `start`, `end`, `frequency`, `end_date`) VALUES (152,1,1,'2023-02-01 12:00:00','2023-02-02 12:00:00',1,'2024-02-02');
/*!40000 ALTER TABLE `calcms_studio_timeslot_schedule` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `calcms_studios`
--

DROP TABLE IF EXISTS `calcms_studios`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `calcms_studios` (
  `id` int unsigned NOT NULL AUTO_INCREMENT,
  `name` varchar(32) NOT NULL,
  `description` text NOT NULL,
  `location` varchar(100) NOT NULL,
  `stream` varchar(100) NOT NULL,
  `image` varchar(200) NOT NULL,
  `google_calendar` varchar(100) NOT NULL,
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  `modified_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`) USING BTREE,
  UNIQUE KEY `name_2` (`name`),
  KEY `location` (`location`),
  KEY `name` (`name`)
) ENGINE=MyISAM AUTO_INCREMENT=45 DEFAULT CHARSET=utf8mb3;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `calcms_studios`
--

LOCK TABLES `calcms_studios` WRITE;
/*!40000 ALTER TABLE `calcms_studios` DISABLE KEYS */;
INSERT INTO `calcms_studios` (`id`, `name`, `description`, `location`, `stream`, `image`, `google_calendar`, `created_at`, `modified_at`) VALUES (1,'My Studio','My Radio Studio','studio','','','https://my-radio.org',NULL,'2023-02-19 21:17:18');
/*!40000 ALTER TABLE `calcms_studios` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `calcms_tags`
--

DROP TABLE IF EXISTS `calcms_tags`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `calcms_tags` (
  `id` bigint unsigned NOT NULL AUTO_INCREMENT,
  `name` varchar(100) DEFAULT NULL,
  `event_id` bigint unsigned NOT NULL,
  KEY `id` (`id`),
  KEY `event_id` (`event_id`)
) ENGINE=MyISAM AUTO_INCREMENT=8 DEFAULT CHARSET=utf8mb3;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `calcms_tags`
--

LOCK TABLES `calcms_tags` WRITE;
/*!40000 ALTER TABLE `calcms_tags` DISABLE KEYS */;
/*!40000 ALTER TABLE `calcms_tags` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `calcms_user_day_start`
--

DROP TABLE IF EXISTS `calcms_user_day_start`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `calcms_user_day_start` (
  `id` int unsigned NOT NULL AUTO_INCREMENT,
  `project_id` int unsigned NOT NULL,
  `studio_id` int unsigned NOT NULL,
  `user` varchar(45) NOT NULL,
  `day_start` int unsigned DEFAULT '0',
  PRIMARY KEY (`id`),
  UNIQUE KEY `select` (`project_id`,`studio_id`,`user`)
) ENGINE=InnoDB AUTO_INCREMENT=10 DEFAULT CHARSET=utf8mb3;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `calcms_user_day_start`
--

LOCK TABLES `calcms_user_day_start` WRITE;
/*!40000 ALTER TABLE `calcms_user_day_start` DISABLE KEYS */;
INSERT INTO `calcms_user_day_start` (`id`, `project_id`, `studio_id`, `user`, `day_start`) VALUES (1,1,1,'ccAdmin',0);
/*!40000 ALTER TABLE `calcms_user_day_start` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `calcms_user_default_studios`
--

DROP TABLE IF EXISTS `calcms_user_default_studios`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `calcms_user_default_studios` (
  `id` int NOT NULL AUTO_INCREMENT,
  `project_id` int NOT NULL,
  `studio_id` int NOT NULL,
  `user` varchar(50) NOT NULL,
  PRIMARY KEY (`id`),
  KEY `user` (`user`)
) ENGINE=InnoDB AUTO_INCREMENT=13 DEFAULT CHARSET=utf8mb3;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `calcms_user_default_studios`
--

LOCK TABLES `calcms_user_default_studios` WRITE;
/*!40000 ALTER TABLE `calcms_user_default_studios` DISABLE KEYS */;
INSERT INTO `calcms_user_default_studios` (`id`, `project_id`, `studio_id`, `user`) VALUES (4,1,1,'ccAdmin');
/*!40000 ALTER TABLE `calcms_user_default_studios` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `calcms_user_events`
--

DROP TABLE IF EXISTS `calcms_user_events`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `calcms_user_events` (
  `id` int unsigned NOT NULL AUTO_INCREMENT,
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
) ENGINE=MyISAM DEFAULT CHARSET=utf8mb3;
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
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `calcms_user_roles` (
  `id` int unsigned NOT NULL AUTO_INCREMENT,
  `project_id` int unsigned NOT NULL,
  `studio_id` int unsigned NOT NULL DEFAULT '0',
  `user_id` int unsigned NOT NULL,
  `role_id` int unsigned NOT NULL,
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  `modified_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`) USING BTREE,
  KEY `project_id` (`project_id`),
  KEY `studio_id` (`studio_id`),
  KEY `user_id` (`user_id`),
  KEY `role_id` (`role_id`)
) ENGINE=MyISAM AUTO_INCREMENT=745 DEFAULT CHARSET=utf8mb3;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `calcms_user_roles`
--

LOCK TABLES `calcms_user_roles` WRITE;
/*!40000 ALTER TABLE `calcms_user_roles` DISABLE KEYS */;
INSERT INTO `calcms_user_roles` (`id`, `project_id`, `studio_id`, `user_id`, `role_id`, `created_at`, `modified_at`) VALUES (47,1,1,4,7,NULL,'2013-04-14 13:06:38');
INSERT INTO `calcms_user_roles` (`id`, `project_id`, `studio_id`, `user_id`, `role_id`, `created_at`, `modified_at`) VALUES (48,1,1,4,3,NULL,'2013-04-14 13:06:38');
INSERT INTO `calcms_user_roles` (`id`, `project_id`, `studio_id`, `user_id`, `role_id`, `created_at`, `modified_at`) VALUES (66,1,1,4,1,NULL,'2013-04-14 13:06:38');
/*!40000 ALTER TABLE `calcms_user_roles` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `calcms_user_selected_events`
--

DROP TABLE IF EXISTS `calcms_user_selected_events`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `calcms_user_selected_events` (
  `id` int unsigned NOT NULL AUTO_INCREMENT,
  `project_id` int unsigned DEFAULT NULL,
  `studio_id` int unsigned DEFAULT NULL,
  `series_id` int unsigned DEFAULT NULL,
  `user` varchar(45) NOT NULL,
  `filter_project_studio` int unsigned DEFAULT NULL,
  `filter_series` int unsigned DEFAULT NULL,
  `selected_project` int unsigned DEFAULT NULL,
  `selected_studio` int unsigned DEFAULT NULL,
  `selected_series` int unsigned DEFAULT NULL,
  `selected_event` int unsigned DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `unique` (`user`,`project_id`,`studio_id`,`series_id`,`filter_project_studio`,`filter_series`),
  KEY `user` (`user`,`project_id`,`studio_id`,`series_id`)
) ENGINE=InnoDB AUTO_INCREMENT=136 DEFAULT CHARSET=utf8mb3;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `calcms_user_selected_events`
--

LOCK TABLES `calcms_user_selected_events` WRITE;
/*!40000 ALTER TABLE `calcms_user_selected_events` DISABLE KEYS */;
/*!40000 ALTER TABLE `calcms_user_selected_events` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `calcms_user_series`
--

DROP TABLE IF EXISTS `calcms_user_series`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `calcms_user_series` (
  `id` int unsigned NOT NULL AUTO_INCREMENT,
  `project_id` int unsigned NOT NULL,
  `studio_id` int unsigned NOT NULL,
  `series_id` int unsigned NOT NULL,
  `user_id` int unsigned NOT NULL,
  `modified_by` varchar(100) DEFAULT NULL,
  `modified_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `project_id` (`project_id`),
  KEY `studio_id` (`studio_id`),
  KEY `series_id` (`series_id`),
  KEY `user_id` (`user_id`),
) ENGINE=MyISAM AUTO_INCREMENT=1019 DEFAULT CHARSET=utf8mb3;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `calcms_user_series`
--

LOCK TABLES `calcms_user_series` WRITE;
/*!40000 ALTER TABLE `calcms_user_series` DISABLE KEYS */;
INSERT INTO `calcms_user_series` (`id`, `project_id`, `studio_id`, `series_id`, `user_id`, `active`, `modified_by`, `modified_at`) VALUES (800,1,1,1,4,'','ccAdmin','2023-02-19 20:15:03');
/*!40000 ALTER TABLE `calcms_user_series` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `calcms_user_sessions`
--

DROP TABLE IF EXISTS `calcms_user_sessions`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `calcms_user_sessions` (
  `id` int unsigned NOT NULL AUTO_INCREMENT,
  `session_id` varchar(64) NOT NULL,
  `user` varchar(30) NOT NULL,
  `start` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  `end` timestamp NULL DEFAULT NULL,
  `expires_at` timestamp NOT NULL DEFAULT '0000-00-00 00:00:00',
  `timeout` int unsigned NOT NULL,
  `pid` int unsigned NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `id_UNIQUE` (`id`),
  UNIQUE KEY `session_id_UNIQUE` (`session_id`),
  KEY `user` (`user`),
  KEY `session_id` (`session_id`)
) ENGINE=InnoDB AUTO_INCREMENT=4896 DEFAULT CHARSET=utf8mb3;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `calcms_user_sessions`
--

LOCK TABLES `calcms_user_sessions` WRITE;
/*!40000 ALTER TABLE `calcms_user_sessions` DISABLE KEYS */;
INSERT INTO `calcms_user_sessions` (`id`, `session_id`, `user`, `start`, `end`, `expires_at`, `timeout`, `pid`) VALUES (4895,'f2633a9294c6d3841dc4c98bba61b94a','ccAdmin','2023-02-19 20:53:39','2023-02-19 21:49:53','2023-02-19 23:49:20',7200,37487);
/*!40000 ALTER TABLE `calcms_user_sessions` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `calcms_user_settings`
--

DROP TABLE IF EXISTS `calcms_user_settings`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `calcms_user_settings` (
  `id` int unsigned NOT NULL AUTO_INCREMENT,
  `project_id` int unsigned DEFAULT NULL,
  `studio_id` int unsigned DEFAULT NULL,
  `user` varchar(20) CHARACTER SET latin1 COLLATE latin1_swedish_ci NOT NULL,
  `colors` longtext NOT NULL,
  `language` varchar(3) DEFAULT 'de',
  `period` varchar(16) DEFAULT 'month',
  `calendar_fontsize` smallint unsigned DEFAULT '12',
  PRIMARY KEY (`id`,`user`) USING BTREE,
  KEY `user` (`user`)
) ENGINE=MyISAM AUTO_INCREMENT=49 DEFAULT CHARSET=utf8mb3;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `calcms_user_settings`
--

LOCK TABLES `calcms_user_settings` WRITE;
/*!40000 ALTER TABLE `calcms_user_settings` DISABLE KEYS */;
INSERT INTO `calcms_user_settings` (`id`, `project_id`, `studio_id`, `user`, `colors`, `language`, `period`, `calendar_fontsize`) VALUES (5,1,1,'ccAdmin','#content .event=#c5e1a5\n#content .draft=#eeeeee\n#content .schedule=#dde4e6\n#content .event.published=#a5d6a7\n#content .event.no_series=#fff59d\n#content .event.marked=#81d4fa\n#content.conflicts .event.error=#ffab91\n#content.conflicts .schedule.error=#ffcc80\n#content .work=#b39ddb\n#content .play=#90caf9','en','14',12);
/*!40000 ALTER TABLE `calcms_user_settings` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `calcms_user_stats`
--

DROP TABLE IF EXISTS `calcms_user_stats`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `calcms_user_stats` (
  `project_id` int unsigned NOT NULL,
  `studio_id` int unsigned NOT NULL,
  `series_id` int unsigned NOT NULL DEFAULT '0',
  `user` varchar(32) NOT NULL,
  `modified_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `create_events` int unsigned DEFAULT '0',
  `update_events` int unsigned DEFAULT '0',
  `delete_events` int unsigned DEFAULT '0',
  `schedule_event` int unsigned DEFAULT '0',
  `create_series` int unsigned DEFAULT '0',
  `update_series` int unsigned DEFAULT '0',
  `delete_series` int unsigned DEFAULT '0',
  `upload_file` int unsigned DEFAULT '0',
  `download_file` int unsigned DEFAULT '0',
  PRIMARY KEY (`project_id`,`studio_id`,`series_id`,`user`) USING BTREE
) ENGINE=MyISAM DEFAULT CHARSET=utf8mb3;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `calcms_user_stats`
--

LOCK TABLES `calcms_user_stats` WRITE;
/*!40000 ALTER TABLE `calcms_user_stats` DISABLE KEYS */;
INSERT INTO `calcms_user_stats` (`project_id`, `studio_id`, `series_id`, `user`, `modified_at`, `create_events`, `update_events`, `delete_events`, `schedule_event`, `create_series`, `update_series`, `delete_series`, `upload_file`, `download_file`) VALUES (1,1,1,'ccAdmin','2023-02-19 21:33:05',0,0,0,0,0,1,0,0,0);
/*!40000 ALTER TABLE `calcms_user_stats` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `calcms_users`
--

DROP TABLE IF EXISTS `calcms_users`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `calcms_users` (
  `id` int unsigned NOT NULL AUTO_INCREMENT,
  `name` varchar(30) NOT NULL,
  `full_name` varchar(30) DEFAULT NULL,
  `email` varchar(300) NOT NULL,
  `pass` varchar(100) NOT NULL,
  `salt` varchar(32) NOT NULL,
  `disabled` int unsigned DEFAULT '0',
  `session_timeout` int unsigned NOT NULL DEFAULT '120',
  `created_by` varchar(30) DEFAULT NULL,
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  `modified_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`) USING BTREE,
  UNIQUE KEY `name` (`name`),
  UNIQUE KEY `email` (`email`) USING BTREE,
  KEY `disabled` (`disabled`)
) ENGINE=MyISAM AUTO_INCREMENT=260 DEFAULT CHARSET=utf8mb3;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `calcms_users`
--

LOCK TABLES `calcms_users` WRITE;
/*!40000 ALTER TABLE `calcms_users` DISABLE KEYS */;
INSERT INTO `calcms_users` (`id`, `name`, `full_name`, `email`, `pass`, `salt`, `disabled`, `session_timeout`, `created_by`, `created_at`, `modified_at`) VALUES (4,'ccAdmin','ccAdmin','mc@radiopiloten.de','$2a$08$oLiwMC1vYD8ZzfjKdpTG3OBFAXbiKslWIe0w005ysdxO0kE/A/12G','oLiwMC1vYD8ZzfjKdpTG3O',0,120,NULL,NULL,'2021-12-10 15:43:48');
/*!40000 ALTER TABLE `calcms_users` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `calcms_work_dates`
--

DROP TABLE IF EXISTS `calcms_work_dates`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `calcms_work_dates` (
  `schedule_id` int unsigned NOT NULL AUTO_INCREMENT,
  `project_id` int unsigned NOT NULL,
  `studio_id` int unsigned NOT NULL,
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
) ENGINE=MyISAM AUTO_INCREMENT=25 DEFAULT CHARSET=utf8mb3;
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
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `calcms_work_schedule` (
  `schedule_id` int unsigned NOT NULL AUTO_INCREMENT,
  `project_id` int unsigned NOT NULL,
  `studio_id` int unsigned NOT NULL,
  `start` datetime NOT NULL,
  `end` date DEFAULT NULL,
  `frequency` int unsigned DEFAULT NULL,
  `duration` int unsigned DEFAULT NULL,
  `exclude` tinyint unsigned DEFAULT NULL,
  `weekday` int unsigned DEFAULT NULL,
  `week_of_month` int unsigned DEFAULT NULL,
  `period_type` varchar(16) DEFAULT NULL,
  `month` int unsigned NOT NULL,
  `type` varchar(32) NOT NULL,
  `title` varchar(200) NOT NULL,
  PRIMARY KEY (`schedule_id`),
  KEY `project_id` (`project_id`),
  KEY `studio_id` (`studio_id`),
  KEY `type` (`type`)
) ENGINE=MyISAM AUTO_INCREMENT=25 DEFAULT CHARSET=utf8mb3;
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

-- Dump completed on 2023-02-19 23:01:42

CREATE TABLE `calcms_help_texts` (
  `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `project_id` INT UNSIGNED NOT NULL,
  `studio_id` INT UNSIGNED NOT NULL,
  `lang` VARCHAR(5) NOT NULL,
  `table` VARCHAR(45) NOT NULL,
  `column` VARCHAR(45) NOT NULL,
  `text` TEXT(500) NOT NULL,
  PRIMARY KEY (`id`));
