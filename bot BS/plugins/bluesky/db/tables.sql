-- Activité Discord pour le site (messages par jour, membres en ligne)
CREATE TABLE IF NOT EXISTS bluesky_activity (day DATE PRIMARY KEY, messages INTEGER NOT NULL DEFAULT 0);
CREATE TABLE IF NOT EXISTS bluesky_presence (time TIMESTAMP WITH TIME ZONE PRIMARY KEY, online INTEGER NOT NULL);
-- Temps passé en vocal, tous membres confondus (secondes par jour)
CREATE TABLE IF NOT EXISTS bluesky_voice (day DATE PRIMARY KEY, seconds BIGINT NOT NULL DEFAULT 0);
-- Missions publiées (clic droit « Publier sur le site ») : événement Discord → briefing + sondage d'inscription
CREATE TABLE IF NOT EXISTS bluesky_missions (event_id BIGINT PRIMARY KEY, channel_id BIGINT NOT NULL, message_id BIGINT NOT NULL, poll_channel_id BIGINT, poll_message_id BIGINT, start_time TIMESTAMP WITH TIME ZONE);
