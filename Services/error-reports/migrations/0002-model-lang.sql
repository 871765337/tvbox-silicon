-- Hardware model and app language, for playback and layout bugs.
ALTER TABLE reports ADD COLUMN model TEXT NOT NULL DEFAULT '';
ALTER TABLE reports ADD COLUMN lang TEXT NOT NULL DEFAULT '';
