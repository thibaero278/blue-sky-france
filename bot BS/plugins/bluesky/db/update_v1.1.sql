-- v1.2 : temps en vocal (total par jour) et missions publiées sur le site
CREATE TABLE IF NOT EXISTS bluesky_voice (day DATE PRIMARY KEY, seconds BIGINT NOT NULL DEFAULT 0);
CREATE TABLE IF NOT EXISTS bluesky_missions (event_id BIGINT PRIMARY KEY, channel_id BIGINT NOT NULL, message_id BIGINT NOT NULL, poll_channel_id BIGINT, poll_message_id BIGINT, start_time TIMESTAMP WITH TIME ZONE);
