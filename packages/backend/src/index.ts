import express from 'express';
import cors from 'cors';
import { config } from './config';
import { initDatabase, closeDatabase } from './db';
import { BlockchainIndexer } from './indexer';
import routes from './routes';

const app = express();
let indexer: BlockchainIndexer;

// Middleware
app.use(cors());
app.use(express.json());

// Health check
app.get('/health', (req, res) => {
  res.json({ status: 'ok', timestamp: Date.now() });
});

// API routes
app.use('/api', routes);

// Error handling
app.use((err: Error, req: express.Request, res: express.Response, next: express.NextFunction) => {
  console.error('Error:', err);
  res.status(500).json({
    success: false,
    error: err.message || 'Internal server error',
  });
});

// Start server
async function start() {
  try {
    // Initialize database
    console.log('📦 Initializing database...');
    initDatabase(config.database.path);

    // Start blockchain indexer
    indexer = new BlockchainIndexer();
    await indexer.start();

    // Start HTTP server
    app.listen(config.port, () => {
      console.log(`\n🚀 Backend server running on http://localhost:${config.port}`);
      console.log(`📊 API endpoints available at http://localhost:${config.port}/api`);
      console.log(`\nAvailable routes:`);
      console.log(`  GET  /api/ants              - Get all ants`);
      console.log(`  GET  /api/ants/:id          - Get specific ant`);
      console.log(`  GET  /api/ants/:id/events   - Get events for ant`);
      console.log(`  GET  /api/events            - Get all events`);
      console.log(`  GET  /api/stats             - Get global stats`);
      console.log(`  GET  /api/users/:address/stats - Get user stats`);
      console.log(`  GET  /api/config            - Get public config`);
    });
  } catch (error) {
    console.error('Failed to start server:', error);
    process.exit(1);
  }
}

// Graceful shutdown
process.on('SIGINT', () => {
  console.log('\n🛑 Shutting down...');
  if (indexer) indexer.stop();
  closeDatabase();
  process.exit(0);
});

process.on('SIGTERM', () => {
  console.log('\n🛑 Shutting down...');
  if (indexer) indexer.stop();
  closeDatabase();
  process.exit(0);
});

start();
