import { ConnectButton } from "@rainbow-me/rainbowkit";
import { useAccount, useReadContract, useWriteContract, useWaitForTransactionReceipt, useReadContracts, usePublicClient } from "wagmi";
import { useState, useEffect, useMemo } from "react";
import { formatEther, parseAbiItem } from "viem";
import { cryptoAntsABI, eggABI, CRYPTO_ANTS_ADDRESS, EGG_ADDRESS } from "@/contracts/abis";

export default function Home() {
  const { address } = useAccount();
  const [eggsToBuy, setEggsToBuy] = useState(1);

  const { data: eggPrice } = useReadContract({
    address: CRYPTO_ANTS_ADDRESS,
    abi: cryptoAntsABI,
    functionName: "eggPrice",
  });

  const { data: eggBalance, refetch: refetchEggs } = useReadContract({
    address: EGG_ADDRESS,
    abi: eggABI,
    functionName: "balanceOf",
    args: [address || "0x0000000000000000000000000000000000000000"],
  });

  // Write hooks
  const { writeContract: buyEggs, data: buyEggsHash } = useWriteContract();
  const { writeContract: createAnt, data: createAntHash } = useWriteContract();
  const { writeContract: layEggs, data: layEggsHash } = useWriteContract();
  const { writeContract: sellAnt, data: sellAntHash } = useWriteContract();

  const { isSuccess: buySuccess } = useWaitForTransactionReceipt({ hash: buyEggsHash });
  const { isSuccess: createSuccess } = useWaitForTransactionReceipt({ hash: createAntHash });
  const { isSuccess: laySuccess } = useWaitForTransactionReceipt({ hash: layEggsHash });
  const { isSuccess: sellSuccess } = useWaitForTransactionReceipt({ hash: sellAntHash });

  useEffect(() => {
    if (buySuccess || createSuccess || laySuccess || sellSuccess) {
      refetchEggs();
    }
  }, [buySuccess, createSuccess, laySuccess, sellSuccess, refetchEggs]);

  const handleBuyEggs = () => {
    if (!eggPrice) return;
    const price = BigInt(eggsToBuy) * eggPrice;
    buyEggs({
      address: CRYPTO_ANTS_ADDRESS,
      abi: cryptoAntsABI,
      functionName: "buyEggs",
      args: [BigInt(eggsToBuy)],
      value: price,
    });
  };

  const handleLayEggs = (id: bigint) => {
    layEggs({ 
      address: CRYPTO_ANTS_ADDRESS, 
      abi: cryptoAntsABI, 
      functionName: "layEggs", 
      args: [id] 
    });
  };

  const handleSellAnt = (id: bigint) => {
    sellAnt({ 
      address: CRYPTO_ANTS_ADDRESS, 
      abi: cryptoAntsABI, 
      functionName: "sellAnt", 
      args: [id] 
    });
  };

  return (
    <div className="container">
      <header className="header">
        <h1>🐜 Crypto Ants</h1>
        <ConnectButton />
      </header>

      {address ? (
        <main>
          <div className="card">
            <h2>🥚 Market</h2>
            <p>Egg Price: {eggPrice ? formatEther(eggPrice) : "..."} ETH</p>
            <p>Your Eggs: {eggBalance?.toString() || "0"}</p>
            <div style={{ marginTop: "1rem" }}>
              <input
                type="number"
                min="1"
                className="input"
                value={eggsToBuy}
                onChange={(e) => setEggsToBuy(Number(e.target.value))}
              />
              <button className="button" onClick={handleBuyEggs}>
                Buy Eggs
              </button>
            </div>
          </div>

          <div className="card">
            <h2>🐜 Nursery</h2>
            <p>Create a new Ant (Costs 1 Egg)</p>
            <button className="button" onClick={() => createAnt({
              address: CRYPTO_ANTS_ADDRESS,
              abi: cryptoAntsABI,
              functionName: "createAnt",
            })}>
              Create Ant
            </button>
          </div>

          <div className="card">
            <h2>🎮 Ant Colony</h2>
            <AntColony 
              userAddress={address} 
              layEggs={handleLayEggs} 
              sellAnt={handleSellAnt} 
              refreshTrigger={createSuccess || laySuccess || sellSuccess}
            />
          </div>
        </main>
      ) : (
        <main>
          <div className="card">
             <h2>🌎 Global Ant Colony</h2>
             <p>Connect your wallet to manage your own ants.</p>
             <AntColony 
              layEggs={() => {}} 
              sellAnt={() => {}} 
              refreshTrigger={false}
            />
          </div>
        </main>
      )}
    </div>
  );
}

function AntColony({ 
  userAddress, 
  layEggs, 
  sellAnt,
  refreshTrigger
}: { 
  userAddress?: `0x${string}`, 
  layEggs: (id: bigint) => void, 
  sellAnt: (id: bigint) => void,
  refreshTrigger: boolean
}) {
  const publicClient = usePublicClient();
  // Map of Ant ID -> Last Owner (for dead ants)
  const [deadAntOwners, setDeadAntOwners] = useState<Record<string, string>>({});

  // 1. Get total ants
  const { data: antsCreated, refetch: refetchTotal } = useReadContract({
    address: CRYPTO_ANTS_ADDRESS,
    abi: cryptoAntsABI,
    functionName: "getAntsCreated",
  });

  useEffect(() => {
    if (refreshTrigger) {
      refetchTotal();
    }
  }, [refreshTrigger, refetchTotal]);

  // 2. Fetch dead ants logs to know who owned them
  useEffect(() => {
    if (!publicClient) return;

    const fetchDeadAnts = async () => {
      try {
        // Fetch ALL AntDied events if no userAddress (public view), or just user's if logged in?
        // Actually, for public view we need ALL dead ants owners.
        // For user view, we need user's dead ants.
        // Let's just fetch all dead ants always to keep it simple, or filter if userAddress is set.
        // But wait, if I am logged in, I only want to see MY dead ants.
        // If I am NOT logged in, I want to see ALL dead ants (and their owners).
        
        const args = userAddress ? { owner: userAddress } : {};

        const logs = await publicClient.getLogs({
          address: CRYPTO_ANTS_ADDRESS,
          event: parseAbiItem('event AntDied(uint256 indexed antId, address indexed owner)'),
          args,
          fromBlock: 'earliest'
        });
        
        const mapping: Record<string, string> = {};
        logs.forEach(l => {
            if (l.args.antId && l.args.owner) {
                mapping[l.args.antId.toString()] = l.args.owner;
            }
        });
        setDeadAntOwners(mapping);
      } catch (e) {
        console.error("Failed to fetch dead ants logs", e);
      }
    };
    
    fetchDeadAnts();
  }, [userAddress, publicClient, refreshTrigger]);

  // 3. Prepare calls for ownerOf for all ants
  const antIds = useMemo(() => {
    if (!antsCreated) return [];
    const count = Number(antsCreated);
    // Create array from 1 to count
    return Array.from({ length: count }, (_, i) => BigInt(i + 1));
  }, [antsCreated]);

  const { data: owners, refetch: refetchOwners } = useReadContracts({
    contracts: antIds.map(id => ({
      address: CRYPTO_ANTS_ADDRESS,
      abi: cryptoAntsABI,
      functionName: "ownerOf",
      args: [id],
    })),
    query: {
        enabled: antIds.length > 0
    }
  });

  useEffect(() => {
    if (refreshTrigger) {
        refetchOwners();
    }
  }, [refreshTrigger, refetchOwners]);

  // 4. Filter ants
    const visibleAntIds = useMemo(() => {
        if (!owners) return [];

        const all = antIds.map((id, index) => {
            const ownerResult = owners[index];
            let owner: string | undefined;

            if (ownerResult.status === "success") {
                owner = ownerResult.result as string;
            } else {
                // If ownerOf failed, check if it's in deadAntOwners
                owner = deadAntOwners[id.toString()];
            }

            return { id, owner };
        });

        // Show all ants, even if owner is unknown (e.g. Sold ants)
        return all.map(a => a.id);
    }, [owners, userAddress, antIds, deadAntOwners]);

  // 5. Get metadata for visible ants
  const { data: antsMetadata, refetch: refetchMetadata } = useReadContracts({
    contracts: visibleAntIds.map(id => ({
      address: CRYPTO_ANTS_ADDRESS,
      abi: cryptoAntsABI,
      functionName: "antsMetadata",
      args: [id],
    })),
    query: {
        enabled: visibleAntIds.length > 0
    }
  });

  useEffect(() => {
    if (refreshTrigger) {
        refetchMetadata();
    }
  }, [refreshTrigger, refetchMetadata]);

  // Global timer for sorting
  const [now, setNow] = useState(Math.floor(Date.now() / 1000));
  useEffect(() => {
      const timer = setInterval(() => setNow(Math.floor(Date.now() / 1000)), 1000);
      return () => clearInterval(timer);
  }, []);

  // Sort ants
  const sortedAnts = useMemo(() => {
    return visibleAntIds.map((id, index) => {
        const metadata = antsMetadata?.[index]?.result;
        let lastEggLayTime = 0;
        let totalEggsLaid = 0;
        let isAlive = true;

        if (metadata) {
             [lastEggLayTime, totalEggsLaid, isAlive] = metadata;
        } else if (deadAntOwners[id.toString()]) {
            isAlive = false;
        }
        
        // Find owner for display
        let owner = deadAntOwners[id.toString()];
        if (!owner && owners) {
            const originalIndex = Number(id) - 1; 
            if (owners[originalIndex]?.status === "success") {
                owner = owners[originalIndex].result as string;
            }
        }

        // Check if ready to lay eggs
        const COOLDOWN = 600;
        const isReady = isAlive && (lastEggLayTime === 0 || (now - lastEggLayTime >= COOLDOWN));

        return { id, lastEggLayTime, totalEggsLaid, isAlive, owner, isReady };
    }).sort((a, b) => {
        // 1. Alive vs Dead
        if (a.isAlive !== b.isAlive) {
            return a.isAlive ? -1 : 1;
        }
        // 2. Active (Ready) vs Cooldown
        if (a.isReady !== b.isReady) {
            return a.isReady ? -1 : 1;
        }
        // 3. ID
        return Number(a.id - b.id);
    });
  }, [visibleAntIds, antsMetadata, deadAntOwners, owners, now]);

  if (!antsCreated) return <p>Loading colony data...</p>;
  if (visibleAntIds.length === 0) return <p>No ants found in the colony.</p>;

  return (
    <div className="grid">
      {sortedAnts.map(({ id, lastEggLayTime, totalEggsLaid, isAlive, owner }) => (
        <AntCard 
            key={id.toString()}
            id={id}
            lastEggLayTime={lastEggLayTime}
            totalEggsLaid={totalEggsLaid}
            isAlive={isAlive}
            layEggs={layEggs}
            sellAnt={sellAnt}
            owner={owner}
            isOwner={!!userAddress && owner === userAddress}
            globalNow={now}
        />
      ))}
    </div>
  );
}

function AntCard({
    id,
    lastEggLayTime,
    totalEggsLaid,
    isAlive,
    layEggs,
    sellAnt,
    owner,
    isOwner,
    globalNow
}: {
    id: bigint;
    lastEggLayTime: number;
    totalEggsLaid: number;
    isAlive: boolean;
    layEggs: (id: bigint) => void;
    sellAnt: (id: bigint) => void;
    owner?: string;
    isOwner?: boolean;
    globalNow: number;
}) {
    // Use globalNow to sync countdowns across cards
    const now = globalNow;

    const COOLDOWN = 600;
    const timeSinceLastLay = now - lastEggLayTime;
    const canLay = isAlive && (lastEggLayTime === 0 || timeSinceLastLay >= COOLDOWN);
    const remainingCooldown = lastEggLayTime === 0 ? 0 : (COOLDOWN - timeSinceLastLay);

    const formatTimeSince = (seconds: number) => {
        if (seconds < 60) return `${Math.floor(seconds)}s ago`;
        if (seconds < 3600) return `${Math.floor(seconds / 60)}m ago`;
        return `${Math.floor(seconds / 3600)}h ago`;
    };
    
    const formatCountdown = (seconds: number) => {
        if (seconds <= 0) return "0s";
        const m = Math.floor(seconds / 60);
        const s = Math.floor(seconds % 60);
        return `${m}m ${s}s`;
    };

    return (
        <div className="ant-card">
            <h3>Ant #{id.toString()}</h3>
            <div className="ant-status">
                <span style={{ 
                    fontSize: "2rem", 
                    display: "inline-block", 
                    transform: isAlive ? "none" : "rotate(180deg)",
                    transition: "transform 0.5s"
                }}>
                    🐜
                </span>
                <span style={{ color: isAlive ? "green" : (owner ? "red" : "gray"), marginLeft: "0.5rem" }}>
                    {isAlive ? "Alive" : (owner ? "Dead" : "Sold")}
                </span>
            </div>
            <p><strong>Eggs Laid:</strong> {totalEggsLaid.toString()}</p>
            {lastEggLayTime > 0 && (
                <p style={{ fontSize: "0.8rem", color: "#666", marginTop: "0.2rem" }}>
                    Last laid: {formatTimeSince(timeSinceLastLay)}
                </p>
            )}
            {owner ? (
                !isOwner && (
                    <p style={{ fontSize: "0.7rem", color: "#888", marginTop: "0.5rem", wordBreak: "break-all" }}>
                        Owner: {owner}
                    </p>
                )
            ) : (
                <p style={{ fontSize: "0.7rem", color: "#888", marginTop: "0.5rem", fontStyle: "italic" }}>
                    Owner: Unknown (Sold)
                </p>
            )}
            
            {isOwner && isAlive && (
                <div className="actions">
                    <button 
                        className="button" 
                        disabled={!canLay}
                        onClick={() => layEggs(id)}
                        title={canLay ? "Lay Eggs (10% chance of death)" : `Cooldown: ${formatCountdown(remainingCooldown)}`}
                    >
                        {canLay ? "Lay Eggs" : `Wait ${formatCountdown(remainingCooldown)}`}
                    </button>
                    <button 
                        className="button delete" 
                        onClick={() => sellAnt(id)}
                        title="Sell Ant for 0.004 ETH"
                    >
                        Sell
                    </button>
                </div>
            )}
        </div>
    );
}
