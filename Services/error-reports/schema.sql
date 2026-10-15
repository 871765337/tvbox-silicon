-- One row per error group per upload; the app has already summed repeats into `count`.
CREATE TABLE IF NOT EXISTS reports (
  id INTEGER PRIMARY KEY,
  received INTEGER NOT NULL,   -- unix seconds
  install TEXT NOT NULL,       -- random per install, nothing else identifies it
  platform TEXT NOT NULL,      -- macos, ios, tvos
  os TEXT NOT NULL,
  model TEXT NOT NULL DEFAULT '',  -- hardware model, e.g. AppleTV14,1 (added 2026-10-16: migrations/0002)
  lang TEXT NOT NULL DEFAULT '',   -- the app's language
  app TEXT NOT NULL,
  build TEXT NOT NULL,
  country TEXT NOT NULL,
  signature TEXT NOT NULL,     -- groups one bug across installs and versions
  category TEXT NOT NULL,
  message TEXT NOT NULL,
  count INTEGER NOT NULL,
  first INTEGER NOT NULL,
  last INTEGER NOT NULL
);
-- The only index: each one costs a write per row.
CREATE INDEX IF NOT EXISTS reports_received ON reports(received);
