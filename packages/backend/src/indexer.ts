import { ethers } from 'ethers';
import { getDatabase } from './db';
import { config } from './config';

const CRYPTO_ANTS_ABI = [
  'event EggsBought(address buyer, uint256 amount)',
  'event AntCreated()',
  'event AntSold()',
  'event EggsLaid(uint256 indexed antId, address indexed owner, uint256 eggCount)',
  'event AntDied(uint256 indexed antId, address indexed owner)',
  'function antsMetadata(uint256) view returns (uint40 lastEggLayTime, uint16 totalEggsLaid, uint24 color, uint24 eggColor, bool isAlive)',
  'function ownerOf(uint256 tokenId) view returns (address)',
  'function getAntsCreated() view returns (uint256)',
];

export class BlockchainIndexer {
  private provider: ethers.JsonRpcProvider;
  private contract: ethers.Contract;
  private db: ReturnType<typeof getDatabase>;
  private isRunning = false;

  constructor() {
    this.provider = new ethers.JsonRpcProvider(config.blockchain.rpcUrl);
    this.contract = new ethers.Contract(
      config.blockchain.cryptoAntsAddress,
      CRYPTO_ANTS_ABI,
      this.provider
    );
    this.db = getDatabase();
  }

  async start() {
    if (this.isRunning) {
      console.log('Indexer already running');
      return;
    }

    this.isRunning = true;
    console.log('🚀 Starting blockchain indexer...');

    // Sync historical data
    await this.syncHistoricalData();

    // Listen to new events
    this.listenToEvents();

    console.log('✅ Indexer started successfully');
  }

  private async syncHistoricalData() {
    const syncStatus = this.db.prepare('SELECT last_synced_block FROM sync_status WHERE id = 1').get() as { last_synced_block: number };
    const fromBlock = syncStatus.last_synced_block + 1;
    const currentBlock = await this.provider.getBlockNumber();

    console.log(`📊 Syncing from block ${fromBlock} to ${currentBlock}...`);

    if (fromBlock > currentBlock) {
      console.log('✅ Already up to date');
      return;
    }

    // Sync in batches to avoid RPC limits
    const BATCH_SIZE = 1000;
    for (let start = fromBlock; start <= currentBlock; start += BATCH_SIZE) {
      const end = Math.min(start + BATCH_SIZE - 1, currentBlock);
      await this.syncBlockRange(start, end);
      console.log(`Synced blocks ${start} to ${end}`);
    }

    console.log('✅ Historical sync complete');
  }

  private async syncBlockRange(fromBlock: number, toBlock: number) {
    // Get all events in this range
    const [eggsBoughtEvents, antCreatedEvents, antSoldEvents, eggsLaidEvents, antDiedEvents] = await Promise.all([
      this.contract.queryFilter(this.contract.filters.EggsBought(), fromBlock, toBlock),
      this.contract.queryFilter(this.contract.filters.AntCreated(), fromBlock, toBlock),
      this.contract.queryFilter(this.contract.filters.AntSold(), fromBlock, toBlock),
      this.contract.queryFilter(this.contract.filters.EggsLaid(), fromBlock, toBlock),
      this.contract.queryFilter(this.contract.filters.AntDied(), fromBlock, toBlock),
    ]);

    // Process events
    const insertEvent = this.db.prepare(`
      INSERT OR IGNORE INTO events (event_type, ant_id, owner, amount, block_number, transaction_hash, timestamp)
      VALUES (?, ?, ?, ?, ?, ?, ?)
    `);

    const processEvents = async (events: ethers.EventLog[], eventType: string) => {
      for (const event of events) {
        const block = await event.getBlock();
        const timestamp = block.timestamp;

        let antId: number | null = null;
        let owner: string = '';
        let amount: number | null = null;

        switch (eventType) {
          case 'EggsBought':
            owner = event.args![0];
            amount = Number(event.args![1]);
            break;
          case 'AntCreated':
            // We'll update the ant table separately
            break;
          case 'EggsLaid':
            antId = Number(event.args![0]);
            owner = event.args![1];
            amount = Number(event.args![2]);
            break;
          case 'AntDied':
            antId = Number(event.args![0]);
            owner = event.args![1];
            break;
        }

        insertEvent.run(
          eventType,
          antId,
          owner || '0x0',
          amount,
          event.blockNumber,
          event.transactionHash,
          timestamp
        );
      }
    };

    await processEvents(eggsBoughtEvents as ethers.EventLog[], 'EggsBought');
    await processEvents(antCreatedEvents as ethers.EventLog[], 'AntCreated');
    await processEvents(antSoldEvents as ethers.EventLog[], 'AntSold');
    await processEvents(eggsLaidEvents as ethers.EventLog[], 'EggsLaid');
    await processEvents(antDiedEvents as ethers.EventLog[], 'AntDied');

    // Update all ants data
    await this.updateAntsData();

    // Update sync status
    this.db.prepare('UPDATE sync_status SET last_synced_block = ?, last_synced_at = ? WHERE id = 1').run(
      toBlock,
      Math.floor(Date.now() / 1000)
    );
  }

  private async updateAntsData() {
    const antsCreated = await this.contract.getAntsCreated();
    const now = Math.floor(Date.now() / 1000);

    const upsertAnt = this.db.prepare(`
      INSERT INTO ants (id, owner, last_egg_lay_time, total_eggs_laid, color, egg_color, is_alive, created_at, updated_at)
      VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
      ON CONFLICT(id) DO UPDATE SET
        owner = excluded.owner,
        last_egg_lay_time = excluded.last_egg_lay_time,
        total_eggs_laid = excluded.total_eggs_laid,
        is_alive = excluded.is_alive,
        updated_at = excluded.updated_at
    `);

    for (let antId = 1; antId <= Number(antsCreated); antId++) {
      try {
        const [owner, metadata] = await Promise.all([
          this.contract.ownerOf(antId).catch(() => '0x0000000000000000000000000000000000000000'),
          this.contract.antsMetadata(antId),
        ]);

        const color = `#${metadata[2].toString(16).padStart(6, '0').toUpperCase()}`;
        const eggColor = `#${metadata[3].toString(16).padStart(6, '0').toUpperCase()}`;

        upsertAnt.run(
          antId,
          owner,
          Number(metadata[0]),
          Number(metadata[1]),
          color,
          eggColor,
          metadata[4],
          now,
          now
        );
      } catch (error) {
        console.error(`Error updating ant ${antId}:`, error);
      }
    }
  }

  private listenToEvents() {
    // Listen to new AntCreated events
    this.contract.on('AntCreated', async () => {
      console.log('🐜 New ant created');
      await this.updateAntsData();
      const currentBlock = await this.provider.getBlockNumber();
      this.db.prepare('UPDATE sync_status SET last_synced_block = ?, last_synced_at = ? WHERE id = 1').run(
        currentBlock,
        Math.floor(Date.now() / 1000)
      );
    });

    // Listen to EggsLaid events
    this.contract.on('EggsLaid', async (antId: bigint, owner: string, eggCount: bigint, event: ethers.EventLog) => {
      console.log(`🥚 Ant #${antId} laid ${eggCount} eggs`);

      const block = await event.getBlock();
      this.db.prepare(`
        INSERT OR IGNORE INTO events (event_type, ant_id, owner, amount, block_number, transaction_hash, timestamp)
        VALUES (?, ?, ?, ?, ?, ?, ?)
      `).run('EggsLaid', Number(antId), owner, Number(eggCount), event.blockNumber, event.transactionHash, block.timestamp);

      await this.updateAntsData();
    });

    // Listen to AntDied events
    this.contract.on('AntDied', async (antId: bigint, owner: string, event: ethers.EventLog) => {
      console.log(`💀 Ant #${antId} died`);

      const block = await event.getBlock();
      this.db.prepare(`
        INSERT OR IGNORE INTO events (event_type, ant_id, owner, amount, block_number, transaction_hash, timestamp)
        VALUES (?, ?, ?, ?, ?, ?, ?)
      `).run('AntDied', Number(antId), owner, null, event.blockNumber, event.transactionHash, block.timestamp);

      await this.updateAntsData();
    });

    console.log('👂 Listening to blockchain events...');
  }

  stop() {
    this.isRunning = false;
    this.contract.removeAllListeners();
    console.log('⏹ Indexer stopped');
  }
}
