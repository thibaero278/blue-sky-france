-- v1.4 : participants choisis par le staff (événements à places limitées) + message « participants / liste d'attente »
ALTER TABLE bluesky_missions ADD COLUMN IF NOT EXISTS status_message_id BIGINT;
CREATE TABLE IF NOT EXISTS bluesky_selected (event_id BIGINT NOT NULL, user_id BIGINT NOT NULL, PRIMARY KEY (event_id, user_id));
