import {
  CryptoAnts,
  Ant,
  Event,
  GlobalStats,
  UserStats,
  EventType,
} from "generated";

// Helper to convert uint24 to hex color string
function uint24ToHexColor(value: bigint): string {
  const hex = value.toString(16).padStart(6, '0').toUpperCase();
  return `#${hex}`;
}

// Helper to get or create global stats
async function getOrCreateGlobalStats(context: any): Promise<GlobalStats> {
  let stats = await context.GlobalStats.get("global");

  if (!stats) {
    stats = {
      id: "global",
      totalAnts: 0,
      aliveAnts: 0,
      deadAnts: 0,
      totalEggsLaid: 0,
      totalEggsBought: 0,
      lastUpdatedAt: BigInt(0),
    };
  }

  return stats;
}

// Helper to get or create user stats
async function getOrCreateUserStats(address: string, context: any): Promise<UserStats> {
  let stats = await context.UserStats.get(address.toLowerCase());

  if (!stats) {
    stats = {
      id: address.toLowerCase(),
      address: address.toLowerCase(),
      ownedAnts: 0,
      aliveAnts: 0,
      deadAnts: 0,
      totalEggsLaid: 0,
      totalEggsBought: 0,
      lastActivity: BigInt(0),
    };
  }

  return stats;
}

/**
 * Handler for EggsBought event
 * Triggered when a user purchases eggs
 */
CryptoAnts.EggsBought.handler(async ({ event, context }) => {
  const { buyer, amount } = event.params;

  // Create event record
  const eventEntity: Event = {
    id: `${event.transaction.hash}-${event.logIndex}`,
    type: EventType.EGGS_BOUGHT,
    ant: undefined,
    owner: buyer.toLowerCase(),
    amount: Number(amount),
    blockNumber: BigInt(event.block.number),
    blockTimestamp: BigInt(event.block.timestamp),
    transactionHash: event.transaction.hash,
  };

  context.Event.set(eventEntity);

  // Update global stats
  const globalStats = await getOrCreateGlobalStats(context);
  globalStats.totalEggsBought += Number(amount);
  globalStats.lastUpdatedAt = BigInt(event.block.timestamp);
  context.GlobalStats.set(globalStats);

  // Update user stats
  const userStats = await getOrCreateUserStats(buyer, context);
  userStats.totalEggsBought += Number(amount);
  userStats.lastActivity = BigInt(event.block.timestamp);
  context.UserStats.set(userStats);
});

/**
 * Handler for AntCreated event
 * Triggered when a new ant NFT is minted
 */
CryptoAnts.AntCreated.handler(async ({ event, context }) => {
  // We need to query the contract to get the ant details
  // Since Envio doesn't pass tokenId in AntCreated event, we'll use the transaction
  // In practice, you'd query getAntsCreated() and use that as the tokenId

  // For now, we'll create a placeholder and update it when we see Transfer event
  // OR we can use the contract's getAntsCreated() view function

  const eventEntity: Event = {
    id: `${event.transaction.hash}-${event.logIndex}`,
    type: EventType.ANT_CREATED,
    ant: undefined, // Will be linked when we process the ant metadata
    owner: event.transaction.from.toLowerCase(),
    amount: undefined,
    blockNumber: BigInt(event.block.number),
    blockTimestamp: BigInt(event.block.timestamp),
    transactionHash: event.transaction.hash,
  };

  context.Event.set(eventEntity);

  // Update global stats
  const globalStats = await getOrCreateGlobalStats(context);
  globalStats.totalAnts += 1;
  globalStats.aliveAnts += 1;
  globalStats.lastUpdatedAt = BigInt(event.block.timestamp);
  context.GlobalStats.set(globalStats);

  // Update user stats
  const userStats = await getOrCreateUserStats(event.transaction.from, context);
  userStats.ownedAnts += 1;
  userStats.aliveAnts += 1;
  userStats.lastActivity = BigInt(event.block.timestamp);
  context.UserStats.set(userStats);

  // Note: The actual Ant entity will be created/updated by polling or by processing Transfer events
});

/**
 * Handler for EggsLaid event
 * Triggered when an ant successfully lays eggs
 */
CryptoAnts.EggsLaid.handler(async ({ event, context }) => {
  const { antId, owner, eggCount } = event.params;

  // Create event record
  const eventEntity: Event = {
    id: `${event.transaction.hash}-${event.logIndex}`,
    type: EventType.EGGS_LAID,
    ant: antId.toString(),
    owner: owner.toLowerCase(),
    amount: Number(eggCount),
    blockNumber: BigInt(event.block.number),
    blockTimestamp: BigInt(event.block.timestamp),
    transactionHash: event.transaction.hash,
  };

  context.Event.set(eventEntity);

  // Update ant entity
  let ant = await context.Ant.get(antId.toString());
  if (ant) {
    ant.totalEggsLaid += Number(eggCount);
    ant.lastEggLayTime = BigInt(event.block.timestamp);
    ant.updatedAt = BigInt(event.block.timestamp);
    context.Ant.set(ant);

    // Update global stats
    const globalStats = await getOrCreateGlobalStats(context);
    globalStats.totalEggsLaid += Number(eggCount);
    globalStats.lastUpdatedAt = BigInt(event.block.timestamp);
    context.GlobalStats.set(globalStats);

    // Update user stats
    const userStats = await getOrCreateUserStats(owner, context);
    userStats.totalEggsLaid += Number(eggCount);
    userStats.lastActivity = BigInt(event.block.timestamp);
    context.UserStats.set(userStats);
  }
});

/**
 * Handler for AntDied event
 * Triggered when an ant dies during breeding
 */
CryptoAnts.AntDied.handler(async ({ event, context }) => {
  const { antId, owner } = event.params;

  // Create event record
  const eventEntity: Event = {
    id: `${event.transaction.hash}-${event.logIndex}`,
    type: EventType.ANT_DIED,
    ant: antId.toString(),
    owner: owner.toLowerCase(),
    amount: undefined,
    blockNumber: BigInt(event.block.number),
    blockTimestamp: BigInt(event.block.timestamp),
    transactionHash: event.transaction.hash,
  };

  context.Event.set(eventEntity);

  // Update ant entity
  let ant = await context.Ant.get(antId.toString());
  if (ant) {
    ant.isAlive = false;
    ant.owner = owner.toLowerCase(); // Keep last owner
    ant.updatedAt = BigInt(event.block.timestamp);
    context.Ant.set(ant);

    // Update global stats
    const globalStats = await getOrCreateGlobalStats(context);
    globalStats.aliveAnts -= 1;
    globalStats.deadAnts += 1;
    globalStats.lastUpdatedAt = BigInt(event.block.timestamp);
    context.GlobalStats.set(globalStats);

    // Update user stats
    const userStats = await getOrCreateUserStats(owner, context);
    userStats.aliveAnts -= 1;
    userStats.deadAnts += 1;
    userStats.ownedAnts -= 1; // No longer owned since it's burned
    userStats.lastActivity = BigInt(event.block.timestamp);
    context.UserStats.set(userStats);
  }
});

/**
 * Handler for AntSold event
 * Triggered when an ant is sold
 */
CryptoAnts.AntSold.handler(async ({ event, context }) => {
  // Note: This event doesn't include antId, so we need to infer from transaction
  // In a real implementation, you might want to add antId to the event

  const eventEntity: Event = {
    id: `${event.transaction.hash}-${event.logIndex}`,
    type: EventType.ANT_SOLD,
    ant: undefined, // Can't determine without antId in event
    owner: event.transaction.from.toLowerCase(),
    amount: undefined,
    blockNumber: BigInt(event.block.number),
    blockTimestamp: BigInt(event.block.timestamp),
    transactionHash: event.transaction.hash,
  };

  context.Event.set(eventEntity);

  // Note: Without antId in the event, we can't update the specific ant
  // Consider adding antId to the AntSold event in the smart contract
});

/**
 * Contract-level handler for creating Ant entities
 * This handler runs for all contract events and syncs ant metadata
 */
CryptoAnts.contractRegister(async ({ event, context }) => {
  // This is a special handler that can query contract state
  // We can use it to sync ant metadata after events

  // Note: Envio will provide contract instance to query state
  // For now, this is a placeholder for the sync logic
});
