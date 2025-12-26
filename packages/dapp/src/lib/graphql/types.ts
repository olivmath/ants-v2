// GraphQL types matching the Envio schema

export interface Ant {
  id: string;
  owner: string;
  lastEggLayTime: string; // BigInt as string
  totalEggsLaid: number;
  color: string;
  eggColor: string;
  isAlive: boolean;
  createdAt: string; // BigInt as string
  updatedAt: string; // BigInt as string
  createdAtBlock: string; // BigInt as string
  events?: Event[];
}

export enum EventType {
  EGGS_BOUGHT = 'EGGS_BOUGHT',
  ANT_CREATED = 'ANT_CREATED',
  ANT_SOLD = 'ANT_SOLD',
  EGGS_LAID = 'EGGS_LAID',
  ANT_DIED = 'ANT_DIED',
}

export interface Event {
  id: string;
  type: EventType;
  ant?: Ant | null;
  owner: string;
  amount?: number | null;
  blockNumber: string; // BigInt as string
  blockTimestamp: string; // BigInt as string
  transactionHash: string;
}

export interface GlobalStats {
  id: string;
  totalAnts: number;
  aliveAnts: number;
  deadAnts: number;
  totalEggsLaid: number;
  totalEggsBought: number;
  lastUpdatedAt: string; // BigInt as string
}

export interface UserStats {
  id: string;
  address: string;
  ownedAnts: number;
  aliveAnts: number;
  deadAnts: number;
  totalEggsLaid: number;
  totalEggsBought: number;
  lastActivity: string; // BigInt as string
}
