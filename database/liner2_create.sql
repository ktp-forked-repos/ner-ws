CREATE DATABASE IF NOT EXISTS `nerws` CHARACTER SET utf8;
-- Uncomment the following lines if you need to create whole db
USE `nerws`;

-- Uncomment the following lines if you want to have a clean state of the database 
DROP TABLE IF EXISTS `liner2_daemons`;
DROP TABLE IF EXISTS `liner2_requests`;
DROP TABLE IF EXISTS `liner2_requests_contents`;
DROP TABLE IF EXISTS `liner2_requests_results`;

CREATE TABLE IF NOT EXISTS `liner2_daemons` (
	`id` integer NOT NULL auto_increment,
    `address` varchar(50) NOT NULL,
    `threads` integer NOT NULL,
    PRIMARY KEY (`id`),
	UNIQUE KEY (`address`)
) ENGINE=InnoDB CHARACTER SET=utf8 COLLATE utf8_general_ci;

CREATE TABLE IF NOT EXISTS `liner2_daemons_activity` (
	`id` integer NOT NULL,
	`last_answered_ping` bigint NOT NULL DEFAULT 0,
	`unanswered_pings` tinyint DEFAULT 0,
	PRIMARY KEY(`id`),
	FOREIGN KEY (`id`) REFERENCES `liner2_daemons`(`id`)
		ON UPDATE CASCADE
		ON DELETE CASCADE
) ENGINE=InnoDB CHARACTER SET=utf8 COLLATE utf8_general_ci;

-- Request states:
-- QUEUED - waiting for processing
-- PROCESSING - processing in progress
-- READY - processing completed, result waiting in database
-- ERROR - processing terminated with error, message waiting in database
-- FINISHED - result received by client, no longer in the database

CREATE TABLE IF NOT EXISTS `liner2_requests` (
	`request_id` bigint(20) NOT NULL auto_increment,
	`token` char(64) NOT NULL,
	`datetime` datetime NOT NULL,
	`datetime_started` DATETIME DEFAULT NULL,
	`datetime_finished` DATETIME DEFAULT NULL,
	`size` bigint,
	`input_format` enum('CCL', 'IOB', 'PLAIN:WCRFT') NOT NULL,
	`output_format` enum('CCL', 'IOB', 'TUPLES') NOT NULL,
	`model_name` varchar(50) NOT NULL,
	`state` enum('QUEUED', 'PROCESSING', 'READY', 'ERROR', 'FINISHED') NOT NULL,
	`ip` varchar(15) NOT NULL,
	`daemon_id` integer,
	PRIMARY KEY (`request_id`)
) ENGINE=InnoDB CHARACTER SET=utf8 COLLATE utf8_general_ci;

CREATE TABLE IF NOT EXISTS `liner2_requests_contents` (
	`request_id` bigint(20) NOT NULL,
	`text` longtext NOT NULL,
	PRIMARY KEY (`request_id`),
	FOREIGN KEY (request_id) REFERENCES liner2_requests (request_id) 
		ON UPDATE CASCADE 
		ON DELETE CASCADE
) ENGINE=InnoDB CHARACTER SET=utf8 COLLATE utf8_general_ci;

CREATE TABLE IF NOT EXISTS `liner2_requests_results` (
	`request_id` bigint(20) NOT NULL,
	`text` longtext NOT NULL,
	PRIMARY KEY (`request_id`),
	FOREIGN KEY (request_id) REFERENCES liner2_requests (request_id)
		ON UPDATE CASCADE
		ON DELETE CASCADE
) ENGINE=InnoDB CHARACTER SET=utf8 COLLATE utf8_general_ci;

CREATE TABLE IF NOT EXISTS `liner2_requests_errors` (
	`request_id` bigint(20) NOT NULL,
	`msg` longtext,
	PRIMARY KEY (`request_id`),
	FOREIGN KEY (request_id) REFERENCES liner2_requests (request_id)
		ON UPDATE CASCADE
		ON DELETE CASCADE
) ENGINE=InnoDB CHARACTER SET=utf8 COLLATE utf8_general_ci;

CREATE TABLE IF NOT EXISTS `liner2_requests_stats` (
	`request_id` bigint(20) NOT NULL,
	`tokens` integer,
	`sentences` integer,
	`paragraphs` integer,
	`chunks` integer,
	PRIMARY KEY (`request_id`),
	FOREIGN KEY (request_id) REFERENCES liner2_requests (request_id)
		ON UPDATE CASCADE
		ON DELETE CASCADE
) ENGINE=InnoDB CHARACTER SET=utf8 COLLATE utf8_general_ci;

-- uncomment the following lines if you want to set up the default user
-- CREATE USER 'clarin'@'localhost' IDENTIFIED BY 'clarin';
GRANT SELECT, EXECUTE, LOCK TABLES ON clarinws.* TO 'clarin'@'localhost';

DELIMITER |

-- TRIGGER daemon_preempt
-- queue again requests, that were being processed by the deleted daemon
CREATE TRIGGER `daemon_preempt` AFTER DELETE ON `liner2_daemons` FOR EACH ROW
BEGIN
	UPDATE `liner2_requests` SET `state`='QUEUED', `daemon_id`=NULL
		WHERE `state`='PROCESSING' AND `daemon_id`=old.`id`;
END|

CREATE PROCEDURE register_daemon (IN `p_address` varchar(50))
BEGIN
	INSERT INTO `liner2_daemons`(`address`, `threads`) VALUES (`p_address`, 0);
	INSERT INTO `liner2_daemons_activity`(`id`, `last_answered_ping`) 
		VALUES (LAST_INSERT_ID(), UNIX_TIMESTAMP(NOW()));
	SELECT LAST_INSERT_ID();
END|

CREATE PROCEDURE unregister_daemon (IN `p_id` integer)
BEGIN
	DELETE FROM `liner2_daemons` WHERE `id`=`p_id`;
END|

CREATE PROCEDURE daemon_ready (IN `p_id` integer)
BEGIN
	UPDATE `liner2_daemons`
		SET `threads` = `threads` - 1
		WHERE `id` = `p_id`;
END|

CREATE PROCEDURE daemon_not_ready (IN `p_id` integer)
BEGIN
	UPDATE `liner2_daemons`
		SET `threads` = `threads` + 1
		WHERE `id` = `p_id`;
END|

CREATE PROCEDURE daemon_reset_activity (IN `p_id` integer)
BEGIN
	UPDATE `liner2_daemons_activity`
		SET
			`last_answered_ping` = UNIX_TIMESTAMP(NOW()),
			`unanswered_pings` = 0
		WHERE `id` = `p_id`;
END|

CREATE PROCEDURE daemon_unanswered_ping (IN `p_id` integer)
BEGIN
	UPDATE `liner2_daemons_activity`
		SET `unanswered_pings` = `unanswered_pings` + 1
		WHERE `id` = `p_id`;
END|

CREATE PROCEDURE submit_request (
	IN `p_token` char(64),
	IN `p_size` bigint,
	IN `p_input_format` enum('CCL', 'IOB', 'PLAIN:WCRFT'),
	IN `p_output_format` enum('CCL', 'IOB', 'TUPLES'),
	IN `p_model_name` varchar(50),
	IN `p_text` longtext,
	IN `p_ip` varchar(15))
BEGIN
	INSERT INTO `liner2_requests` (`token`, `size`, `datetime`, `input_format`, `output_format`, `model_name`, `state`, `ip`)
		VALUES (`p_token`, `p_size`, NOW(), `p_input_format`, `p_output_format`, `p_model_name`, 'QUEUED', `p_ip`);
	INSERT INTO `liner2_requests_contents` (`request_id`, `text`)
		VALUES (LAST_INSERT_ID(), `p_text`);
END|

CREATE PROCEDURE start_processing (
	IN `p_request_id` bigint(20),
	IN `p_daemon_id` integer)
BEGIN
	UPDATE liner2_requests AS write_liner2_requests
		SET 
			`state`='PROCESSING', 
			`daemon_id`=`p_daemon_id`,
			`datetime_started`=NOW() 
		WHERE `request_id` = `p_request_id`;
END|

CREATE PROCEDURE submit_result (
	IN `p_request_id` bigint(20),
	IN `p_text` longtext,
	IN `p_tokens` integer,
	IN `p_sentences` integer,
	IN `p_paragraphs` integer,
	IN `p_chunks` integer)
BEGIN
	INSERT INTO `liner2_requests_results` (`request_id`, `text`)
		VALUES (`p_request_id`, `p_text`);
	INSERT INTO	`liner2_requests_stats` (`request_id`, `tokens`, `sentences`, `paragraphs`, `chunks`)
		VALUES (`p_request_id`, `p_tokens`, `p_sentences`, `p_paragraphs`, `p_chunks`);
	UPDATE `liner2_requests`
		SET `datetime_finished`=NOW(), `state`='READY'
		WHERE `request_id` = `p_request_id`;
	DELETE FROM `liner2_requests_contents` WHERE `request_id` = `p_request_id`;
END|

CREATE PROCEDURE submit_error (
	IN `p_request_id` bigint(20),
	IN `p_msg` longtext)
BEGIN
	INSERT INTO `liner2_requests_errors` (`request_id`, `msg`)
		VALUES (`p_request_id`, `p_msg`);
	UPDATE `liner2_requests`
		SET `datetime_finished`=NOW(), `state`='ERROR'
		WHERE `request_id` = `p_request_id`;
	DELETE FROM `liner2_requests_contents` WHERE `request_id` = `p_request_id`;
END|

CREATE PROCEDURE retrieve_result (
	IN `p_request_id` bigint(20),
	OUT `p_text` longtext)
BEGIN
	DECLARE previous_state enum('QUEUED', 'PROCESSING', 'READY', 'ERROR', 'FINISHED'); 
	SELECT `state` INTO previous_state FROM `liner2_requests` WHERE `request_id`=`p_request_id`;
	IF previous_state = 'READY' THEN
		UPDATE `liner2_requests` SET `state`='FINISHED' WHERE `request_id`=`p_request_id`;
		SELECT rr.`text` INTO `p_text`
		    FROM `liner2_requests` AS r LEFT JOIN `liner2_requests_results` AS rr
		    ON r.`request_id` = rr.`request_id`
		    WHERE r.`request_id`=`p_request_id`;
		DELETE FROM `liner2_requests_results` WHERE `request_id`=`p_request_id`;
	END IF;
END|

DELIMITER ;
