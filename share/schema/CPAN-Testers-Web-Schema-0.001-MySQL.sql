-- 
-- Created by SQL::Translator::Producer::MySQL
-- Created on Sat Nov 10 13:41:51 2018
-- 
SET foreign_key_checks=0;

DROP TABLE IF EXISTS `users`;

--
-- Table: `users`
--
CREATE TABLE `users` (
  `id` integer unsigned NOT NULL auto_increment,
  `github_login` varchar(255) NOT NULL,
  `pause_id` varchar(255) NULL,
  `pause_token` varchar(255) NULL,
  PRIMARY KEY (`id`),
  UNIQUE `github_login` (`github_login`)
);

SET foreign_key_checks=1;

