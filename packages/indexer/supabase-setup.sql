-- Supabase Database Schema for Crypto Ants Indexer
-- Run this in your Supabase SQL Editor

-- Enable UUID extension
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Ant table
CREATE TABLE IF NOT EXISTS ants (
  id TEXT PRIMARY KEY, -- Token ID as string
  owner TEXT NOT NULL,
  last_egg_lay_time BIGINT NOT NULL DEFAULT 0,
  total_eggs_laid INTEGER NOT NULL DEFAULT 0,
  color TEXT NOT NULL,
  egg_color TEXT NOT NULL,
  is_alive BOOLEAN NOT NULL DEFAULT true,
  created_at BIGINT NOT NULL,
  updated_at BIGINT NOT NULL,
  created_at_block BIGINT NOT NULL
);

-- Event type enum
CREATE TYPE event_type AS ENUM (
  'EGGS_BOUGHT',
  'ANT_CREATED',
  'ANT_SOLD',
  'EGGS_LAID',
  'ANT_DIED'
);

-- Events table
CREATE TABLE IF NOT EXISTS events (
  id TEXT PRIMARY KEY, -- txHash-logIndex
  type event_type NOT NULL,
  ant_id TEXT REFERENCES ants(id),
  owner TEXT NOT NULL,
  amount INTEGER,
  block_number BIGINT NOT NULL,
  block_timestamp BIGINT NOT NULL,
  transaction_hash TEXT NOT NULL
);

-- Global stats table (singleton)
CREATE TABLE IF NOT EXISTS global_stats (
  id TEXT PRIMARY KEY DEFAULT 'global',
  total_ants INTEGER NOT NULL DEFAULT 0,
  alive_ants INTEGER NOT NULL DEFAULT 0,
  dead_ants INTEGER NOT NULL DEFAULT 0,
  total_eggs_laid INTEGER NOT NULL DEFAULT 0,
  total_eggs_bought INTEGER NOT NULL DEFAULT 0,
  last_updated_at BIGINT NOT NULL DEFAULT 0,
  CONSTRAINT single_row CHECK (id = 'global')
);

-- User stats table
CREATE TABLE IF NOT EXISTS user_stats (
  id TEXT PRIMARY KEY, -- User address (lowercase)
  address TEXT NOT NULL UNIQUE,
  owned_ants INTEGER NOT NULL DEFAULT 0,
  alive_ants INTEGER NOT NULL DEFAULT 0,
  dead_ants INTEGER NOT NULL DEFAULT 0,
  total_eggs_laid INTEGER NOT NULL DEFAULT 0,
  total_eggs_bought INTEGER NOT NULL DEFAULT 0,
  last_activity BIGINT NOT NULL DEFAULT 0
);

-- Indexes for better query performance
CREATE INDEX IF NOT EXISTS idx_ants_owner ON ants(owner);
CREATE INDEX IF NOT EXISTS idx_ants_is_alive ON ants(is_alive);
CREATE INDEX IF NOT EXISTS idx_events_ant_id ON events(ant_id);
CREATE INDEX IF NOT EXISTS idx_events_owner ON events(owner);
CREATE INDEX IF NOT EXISTS idx_events_type ON events(type);
CREATE INDEX IF NOT EXISTS idx_events_block ON events(block_number);
CREATE INDEX IF NOT EXISTS idx_user_stats_address ON user_stats(address);

-- Initialize global stats
INSERT INTO global_stats (id) VALUES ('global')
ON CONFLICT (id) DO NOTHING;

-- Row Level Security (RLS)
ALTER TABLE ants ENABLE ROW LEVEL SECURITY;
ALTER TABLE events ENABLE ROW LEVEL SECURITY;
ALTER TABLE global_stats ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_stats ENABLE ROW LEVEL SECURITY;

-- Policies for public read access
CREATE POLICY "Allow public read access on ants"
  ON ants FOR SELECT
  USING (true);

CREATE POLICY "Allow public read access on events"
  ON events FOR SELECT
  USING (true);

CREATE POLICY "Allow public read access on global_stats"
  ON global_stats FOR SELECT
  USING (true);

CREATE POLICY "Allow public read access on user_stats"
  ON user_stats FOR SELECT
  USING (true);

-- Policies for service role (indexer) write access
-- Note: The indexer will use the service_role key which bypasses RLS
-- But we can still define policies for clarity

CREATE POLICY "Allow service role write access on ants"
  ON ants FOR ALL
  USING (auth.role() = 'service_role');

CREATE POLICY "Allow service role write access on events"
  ON events FOR ALL
  USING (auth.role() = 'service_role');

CREATE POLICY "Allow service role write access on global_stats"
  ON global_stats FOR ALL
  USING (auth.role() = 'service_role');

CREATE POLICY "Allow service role write access on user_stats"
  ON user_stats FOR ALL
  USING (auth.role() = 'service_role');

-- Functions for GraphQL queries

-- Get ants by owner
CREATE OR REPLACE FUNCTION get_ants_by_owner(owner_address TEXT)
RETURNS SETOF ants AS $$
BEGIN
  RETURN QUERY
  SELECT * FROM ants
  WHERE owner = LOWER(owner_address)
  ORDER BY CAST(id AS INTEGER) DESC;
END;
$$ LANGUAGE plpgsql STABLE;

-- Get recent events
CREATE OR REPLACE FUNCTION get_recent_events(limit_count INTEGER DEFAULT 100)
RETURNS SETOF events AS $$
BEGIN
  RETURN QUERY
  SELECT * FROM events
  ORDER BY block_number DESC, id DESC
  LIMIT limit_count;
END;
$$ LANGUAGE plpgsql STABLE;

-- Get ant with events
CREATE OR REPLACE FUNCTION get_ant_with_events(ant_id TEXT)
RETURNS JSON AS $$
DECLARE
  result JSON;
BEGIN
  SELECT json_build_object(
    'ant', row_to_json(a.*),
    'events', (
      SELECT json_agg(row_to_json(e.*))
      FROM events e
      WHERE e.ant_id = a.id
      ORDER BY e.block_number DESC
    )
  ) INTO result
  FROM ants a
  WHERE a.id = ant_id;

  RETURN result;
END;
$$ LANGUAGE plpgsql STABLE;
