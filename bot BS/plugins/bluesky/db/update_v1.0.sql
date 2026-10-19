-- Activité Discord pour le site (messages par jour, membres en ligne)
CREATE TABLE IF NOT EXISTS bluesky_activity (day DATE PRIMARY KEY, messages INTEGER NOT NULL DEFAULT 0);
CREATE TABLE IF NOT EXISTS bluesky_presence (time TIMESTAMP WITH TIME ZONE PRIMARY KEY, online INTEGER NOT NULL);
