--- Create DBs
CREATE DATABASE IF NOT EXISTS calcms;
CREATE DATABASE IF NOT EXISTS calcms_test;

--- Create admin user
CREATE USER IF NOT EXISTS 'calcms_admin'@'localhost' IDENTIFIED BY 'caladmin000';
GRANT ALL PRIVILEGES ON calcms.* TO 'calcms_admin'@'localhost';
GRANT ALL PRIVILEGES ON calcms_test.* TO 'calcms_admin'@'localhost';
--- Create write user
CREATE USER IF NOT EXISTS 'calcms_write'@'localhost' IDENTIFIED BY 'calwrite000';
GRANT SELECT, INSERT, UPDATE, DELETE ON calcms.* TO 'calcms_write'@'localhost';
GRANT ALL PRIVILEGES ON calcms_test.* TO 'calcms_write'@'localhost';
--- Create read user
CREATE USER IF NOT EXISTS 'calcms_read'@'localhost' IDENTIFIED BY 'calread000';
GRANT SELECT ON calcms.* TO 'calcms_read'@'localhost';
GRANT ALL PRIVILEGES ON calcms_test.* TO 'calcms_read'@'localhost';

