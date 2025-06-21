-- K6 Performance Lab InfluxDB Initialization
-- This script sets up the database and retention policies for K6 metrics

-- Create database for K6 metrics
CREATE DATABASE k6;

-- Create user for K6 with appropriate permissions
CREATE USER "k6" WITH PASSWORD 'k6password';
GRANT ALL ON "k6" TO "k6";

-- Use the k6 database
USE k6;

-- Create retention policies for different data retention needs
-- Default policy: keep data for 1 hour (for real-time dashboard)
CREATE RETENTION POLICY "realtime" ON "k6" DURATION 1h REPLICATION 1 DEFAULT;

-- Extended policy: keep data for 7 days (for historical analysis)
CREATE RETENTION POLICY "historical" ON "k6" DURATION 7d REPLICATION 1;

-- Create continuous queries to downsample data for long-term storage
-- Aggregate 1-minute averages for historical retention
CREATE CONTINUOUS QUERY "cq_1m_avg" ON "k6"
BEGIN
  SELECT mean("value") AS "value"
  INTO "k6"."historical"."http_req_duration_1m"
  FROM "k6"."realtime"."http_req_duration"
  GROUP BY time(1m), *
END;

CREATE CONTINUOUS QUERY "cq_1m_http_reqs" ON "k6"
BEGIN
  SELECT sum("value") AS "value"
  INTO "k6"."historical"."http_reqs_1m"
  FROM "k6"."realtime"."http_reqs"
  GROUP BY time(1m), *
END;

CREATE CONTINUOUS QUERY "cq_1m_vus" ON "k6"
BEGIN
  SELECT mean("value") AS "value"
  INTO "k6"."historical"."vus_1m"
  FROM "k6"."realtime"."vus"
  GROUP BY time(1m), *
END;

-- Show created databases and policies
SHOW DATABASES;
SHOW RETENTION POLICIES ON "k6";
SHOW USERS;