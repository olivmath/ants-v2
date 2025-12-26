import dotenv from 'dotenv';

dotenv.config();

export const config = {
  port: parseInt(process.env.PORT || '3001'),
  nodeEnv: process.env.NODE_ENV || 'development',

  blockchain: {
    rpcUrl: process.env.RPC_URL || 'http://127.0.0.1:8545',
    cryptoAntsAddress: process.env.CRYPTO_ANTS_ADDRESS || '0xe7f1725E7734CE288F8367e1Bb143E90bb3F0512',
    eggAddress: process.env.EGG_ADDRESS || '0x5FbDB2315678afecb367f032d93F642f64180aa3',
    startBlock: parseInt(process.env.START_BLOCK || '0'),
  },

  ipfs: {
    gateway: process.env.IPFS_GATEWAY || 'https://ipfs.io/ipfs/',
    antSvgCid: process.env.ANT_SVG_CID || '',
  },

  database: {
    path: process.env.DB_PATH || './data/ants.db',
  },
};
