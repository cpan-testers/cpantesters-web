-- 
-- Created by SQL::Translator::Producer::SQLite
-- Created on Sat Nov 10 13:41:51 2018
-- 

BEGIN TRANSACTION;

--
-- Table: users
--
DROP TABLE users;

CREATE TABLE users (
  id INTEGER PRIMARY KEY NOT NULL,
  github_login varchar NOT NULL,
  pause_id varchar,
  pause_token varchar
);

CREATE UNIQUE INDEX github_login ON users (github_login);

COMMIT;
