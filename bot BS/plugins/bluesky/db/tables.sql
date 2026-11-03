-- Activité Discord pour le site (messages par jour, membres en ligne)
CREATE TABLE IF NOT EXISTS bluesky_activity (day DATE PRIMARY KEY, messages INTEGER NOT NULL DEFAULT 0);
CREATE TABLE IF NOT EXISTS bluesky_presence (time TIMESTAMP WITH TIME ZONE PRIMARY KEY, online INTEGER NOT NULL);
-- Temps passé en vocal, tous membres confondus (secondes par jour)
CREATE TABLE IF NOT EXISTS bluesky_voice (day DATE PRIMARY KEY, seconds BIGINT NOT NULL DEFAULT 0);
-- Missions publiées (clic droit « Publier sur le site ») : événement Discord → briefing + sondage d'inscription
CREATE TABLE IF NOT EXISTS bluesky_missions (event_id BIGINT PRIMARY KEY, channel_id BIGINT NOT NULL, message_id BIGINT NOT NULL, poll_channel_id BIGINT, poll_message_id BIGINT, start_time TIMESTAMP WITH TIME ZONE, slots INTEGER, status_message_id BIGINT);
-- Participants retenus par le staff (événements à places limitées)
CREATE TABLE IF NOT EXISTS bluesky_selected (event_id BIGINT NOT NULL, user_id BIGINT NOT NULL, PRIMARY KEY (event_id, user_id));
-- Scores fusionnés de tous les serveurs DCS (le Scores.lua de chaque serveur n'est plus qu'une source)
CREATE TABLE IF NOT EXISTS bluesky_scores (name TEXT PRIMARY KEY, data JSONB NOT NULL);
-- Dernier Scores.lua lu par serveur : ce qui a été gagné depuis s'ajoute au total, même après une coupure de R2D2
CREATE TABLE IF NOT EXISTS bluesky_scores_base (server TEXT PRIMARY KEY, data JSONB NOT NULL);
