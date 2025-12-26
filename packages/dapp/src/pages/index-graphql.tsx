import { ConnectButton } from "@rainbow-me/rainbowkit";
import { useAccount, useReadContract, useWriteContract, useWaitForTransactionReceipt } from "wagmi";
import { useState, useEffect } from "react";
import { formatEther } from "viem";
import { cryptoAntsABI, eggABI, CRYPTO_ANTS_ADDRESS, EGG_ADDRESS } from "@/contracts/abis";
import { AntColonyGraphQL } from "@/components/AntColonyGraphQL";
import { useGlobalStats, useUserStats } from "@/lib/graphql/hooks";

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

  // Fetch stats from GraphQL
  const { stats: globalStats } = useGlobalStats();
  const { stats: userStats } = useUserStats(address || '');

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
      args: [id],
    });
  };

  const handleSellAnt = (id: bigint) => {
    sellAnt({
      address: CRYPTO_ANTS_ADDRESS,
      abi: cryptoAntsABI,
      functionName: "sellAnt",
      args: [id],
    });
  };

  return (
    <div className="container">
      <header className="header">
        <h1>🐜 Crypto Ants v2</h1>
        <ConnectButton />
      </header>

      {/* Global Stats */}
      {globalStats && (
        <div className="card" style={{ background: 'linear-gradient(135deg, #667eea 0%, #764ba2 100%)', color: 'white' }}>
          <h2 style={{ marginTop: 0 }}>📊 Global Stats</h2>
          <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(150px, 1fr))', gap: '1rem' }}>
            <div>
              <div style={{ fontSize: '2rem', fontWeight: 'bold' }}>{globalStats.totalAnts}</div>
              <div style={{ fontSize: '0.9rem', opacity: 0.9 }}>Total Ants</div>
            </div>
            <div>
              <div style={{ fontSize: '2rem', fontWeight: 'bold' }}>{globalStats.aliveAnts}</div>
              <div style={{ fontSize: '0.9rem', opacity: 0.9 }}>Alive</div>
            </div>
            <div>
              <div style={{ fontSize: '2rem', fontWeight: 'bold' }}>{globalStats.deadAnts}</div>
              <div style={{ fontSize: '0.9rem', opacity: 0.9 }}>Dead</div>
            </div>
            <div>
              <div style={{ fontSize: '2rem', fontWeight: 'bold' }}>{globalStats.totalEggsLaid}</div>
              <div style={{ fontSize: '0.9rem', opacity: 0.9 }}>Eggs Laid</div>
            </div>
          </div>
        </div>
      )}

      {address ? (
        <main>
          {/* User Stats */}
          {userStats && (
            <div className="card" style={{ background: '#f8f9fa' }}>
              <h3 style={{ marginTop: 0 }}>👤 Your Stats</h3>
              <div style={{ display: 'flex', gap: '2rem', flexWrap: 'wrap' }}>
                <div>
                  <strong>Owned Ants:</strong> {userStats.ownedAnts}
                </div>
                <div>
                  <strong>Alive:</strong> {userStats.aliveAnts}
                </div>
                <div>
                  <strong>Dead:</strong> {userStats.deadAnts}
                </div>
                <div>
                  <strong>Total Eggs Laid:</strong> {userStats.totalEggsLaid}
                </div>
              </div>
            </div>
          )}

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
            <button
              className="button"
              onClick={() =>
                createAnt({
                  address: CRYPTO_ANTS_ADDRESS,
                  abi: cryptoAntsABI,
                  functionName: "createAnt",
                })
              }
            >
              Create Ant
            </button>
          </div>

          <div className="card">
            <h2>🎮 My Ant Colony</h2>
            <p style={{ fontSize: '0.9rem', color: '#666', marginBottom: '1rem' }}>
              💾 Data from Envio GraphQL • 🖼️ Images from IPFS
            </p>
            <AntColonyGraphQL
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
            <p style={{ fontSize: '0.9rem', color: '#666', marginTop: '1rem' }}>
              💾 Data from Envio GraphQL • 🖼️ Images from IPFS
            </p>
            <AntColonyGraphQL refreshTrigger={false} />
          </div>
        </main>
      )}
    </div>
  );
}
