-- v1.3 : nombre de places choisi à la publication de la mission
ALTER TABLE bluesky_missions ADD COLUMN IF NOT EXISTS slots INTEGER;
