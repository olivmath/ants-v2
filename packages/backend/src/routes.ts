import { Router, Request, Response } from 'express';
import { getDatabase } from './db';
import { config } from './config';

const router = Router();

// GET /api/ants - Get all ants with optional filters
router.get('/ants', (req: Request, res: Response) => {
  const db = getDatabase();
  const { owner, isAlive, limit = '100', offset = '0' } = req.query;

  let query = 'SELECT * FROM ants WHERE 1=1';
  const params: any[] = [];

  if (owner) {
    query += ' AND owner = ?';
    params.push(owner);
  }

  if (isAlive !== undefined) {
    query += ' AND is_alive = ?';
    params.push(isAlive === 'true' ? 1 : 0);
  }

  query += ' ORDER BY id DESC LIMIT ? OFFSET ?';
  params.push(parseInt(limit as string), parseInt(offset as string));

  const ants = db.prepare(query).all(...params);

  // Add IPFS SVG URI to each ant
  const antsWithUri = ants.map((ant: any) => ({
    ...ant,
    svg_uri: config.ipfs.antSvgCid ? `${config.ipfs.gateway}${config.ipfs.antSvgCid}` : null,
  }));

  res.json({
    success: true,
    data: antsWithUri,
    count: antsWithUri.length,
  });
});

// GET /api/ants/:id - Get specific ant
router.get('/ants/:id', (req: Request, res: Response) => {
  const db = getDatabase();
  const { id } = req.params;

  const ant = db.prepare('SELECT * FROM ants WHERE id = ?').get(id);

  if (!ant) {
    return res.status(404).json({
      success: false,
      error: 'Ant not found',
    });
  }

  res.json({
    success: true,
    data: {
      ...ant,
      svg_uri: config.ipfs.antSvgCid ? `${config.ipfs.gateway}${config.ipfs.antSvgCid}` : null,
    },
  });
});

// GET /api/ants/:id/events - Get events for specific ant
router.get('/ants/:id/events', (req: Request, res: Response) => {
  const db = getDatabase();
  const { id } = req.params;

  const events = db.prepare(`
    SELECT * FROM events
    WHERE ant_id = ?
    ORDER BY block_number DESC
  `).all(id);

  res.json({
    success: true,
    data: events,
    count: events.length,
  });
});

// GET /api/events - Get all events with optional filters
router.get('/events', (req: Request, res: Response) => {
  const db = getDatabase();
  const { eventType, owner, antId, limit = '100', offset = '0' } = req.query;

  let query = 'SELECT * FROM events WHERE 1=1';
  const params: any[] = [];

  if (eventType) {
    query += ' AND event_type = ?';
    params.push(eventType);
  }

  if (owner) {
    query += ' AND owner = ?';
    params.push(owner);
  }

  if (antId) {
    query += ' AND ant_id = ?';
    params.push(antId);
  }

  query += ' ORDER BY block_number DESC LIMIT ? OFFSET ?';
  params.push(parseInt(limit as string), parseInt(offset as string));

  const events = db.prepare(query).all(...params);

  res.json({
    success: true,
    data: events,
    count: events.length,
  });
});

// GET /api/stats - Get global statistics
router.get('/stats', (req: Request, res: Response) => {
  const db = getDatabase();

  const totalAnts = db.prepare('SELECT COUNT(*) as count FROM ants').get() as { count: number };
  const aliveAnts = db.prepare('SELECT COUNT(*) as count FROM ants WHERE is_alive = 1').get() as { count: number };
  const deadAnts = db.prepare('SELECT COUNT(*) as count FROM ants WHERE is_alive = 0').get() as { count: number };
  const totalEggsLaid = db.prepare('SELECT SUM(total_eggs_laid) as total FROM ants').get() as { total: number };
  const syncStatus = db.prepare('SELECT * FROM sync_status WHERE id = 1').get();

  res.json({
    success: true,
    data: {
      total_ants: totalAnts.count,
      alive_ants: aliveAnts.count,
      dead_ants: deadAnts.count,
      total_eggs_laid: totalEggsLaid.total || 0,
      sync_status: syncStatus,
      ipfs_svg_cid: config.ipfs.antSvgCid,
      ipfs_gateway: config.ipfs.gateway,
    },
  });
});

// GET /api/users/:address/stats - Get user statistics
router.get('/users/:address/stats', (req: Request, res: Response) => {
  const db = getDatabase();
  const { address } = req.params;

  const ownedAnts = db.prepare('SELECT COUNT(*) as count FROM ants WHERE owner = ?').get(address) as { count: number };
  const aliveAnts = db.prepare('SELECT COUNT(*) as count FROM ants WHERE owner = ? AND is_alive = 1').get(address) as { count: number };
  const totalEggsLaid = db.prepare('SELECT SUM(total_eggs_laid) as total FROM ants WHERE owner = ?').get(address) as { total: number };
  const recentEvents = db.prepare('SELECT * FROM events WHERE owner = ? ORDER BY block_number DESC LIMIT 10').all(address);

  res.json({
    success: true,
    data: {
      address,
      owned_ants: ownedAnts.count,
      alive_ants: aliveAnts.count,
      total_eggs_laid: totalEggsLaid.total || 0,
      recent_events: recentEvents,
    },
  });
});

// GET /api/config - Get public configuration
router.get('/config', (req: Request, res: Response) => {
  res.json({
    success: true,
    data: {
      ipfs_gateway: config.ipfs.gateway,
      ant_svg_cid: config.ipfs.antSvgCid,
      crypto_ants_address: config.blockchain.cryptoAntsAddress,
      egg_address: config.blockchain.eggAddress,
    },
  });
});

export default router;
