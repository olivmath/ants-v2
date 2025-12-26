import Database from 'better-sqlite3';

export function createTables(db: Database.Database) {
  // Ants table
  db.exec(`
    CREATE TABLE IF NOT EXISTS ants (
      id INTEGER PRIMARY KEY,
      owner TEXT NOT NULL,
      last_egg_lay_time INTEGER NOT NULL,
      total_eggs_laid INTEGER NOT NULL,
      color TEXT NOT NULL,
      egg_color TEXT NOT NULL,
      is_alive BOOLEAN NOT NULL,
      created_at INTEGER NOT NULL,
      updated_at INTEGER NOT NULL
    )
  `);

  // Events table
  db.exec(`
    CREATE TABLE IF NOT EXISTS events (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      event_type TEXT NOT NULL,
      ant_id INTEGER,
      owner TEXT NOT NULL,
      amount INTEGER,
      block_number INTEGER NOT NULL,
      transaction_hash TEXT NOT NULL,
      timestamp INTEGER NOT NULL,
      UNIQUE(transaction_hash, event_type, ant_id)
    )
  `);

  // Sync status table
  db.exec(`
    CREATE TABLE IF NOT EXISTS sync_status (
      id INTEGER PRIMARY KEY CHECK (id = 1),
      last_synced_block INTEGER NOT NULL,
      last_synced_at INTEGER NOT NULL
    )
  `);

  // Initialize sync status if not exists
  db.exec(`
    INSERT OR IGNORE INTO sync_status (id, last_synced_block, last_synced_at)
    VALUES (1, 0, 0)
  `);

  // Create indexes
  db.exec(`
    CREATE INDEX IF NOT EXISTS idx_ants_owner ON ants(owner);
    CREATE INDEX IF NOT EXISTS idx_ants_is_alive ON ants(is_alive);
    CREATE INDEX IF NOT EXISTS idx_events_ant_id ON events(ant_id);
    CREATE INDEX IF NOT EXISTS idx_events_owner ON events(owner);
    CREATE INDEX IF NOT EXISTS idx_events_type ON events(event_type);
    CREATE INDEX IF NOT EXISTS idx_events_block ON events(block_number);
  `);
}
