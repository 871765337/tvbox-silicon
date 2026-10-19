-- Feedback sent from Settings, one row per GitHub issue: caps how much one install (and everyone)
-- can post a day, and ties an issue to the install's error reports. Kept 30 days like the reports.
CREATE TABLE IF NOT EXISTS feedback (
  id INTEGER PRIMARY KEY,
  received INTEGER NOT NULL,   -- unix seconds
  install TEXT NOT NULL,
  platform TEXT NOT NULL,
  app TEXT NOT NULL,
  issue INTEGER NOT NULL       -- the GitHub issue number
);
CREATE INDEX IF NOT EXISTS feedback_received ON feedback(received);
