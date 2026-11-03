-- v1.5 : scores fusionnés sur R2D2
CREATE TABLE IF NOT EXISTS bluesky_scores (name TEXT PRIMARY KEY, data JSONB NOT NULL);
-- Dernier Scores.lua lu par serveur : ce qui a été gagné depuis s'ajoute au total, même après une coupure de R2D2
CREATE TABLE IF NOT EXISTS bluesky_scores_base (server TEXT PRIMARY KEY, data JSONB NOT NULL);
