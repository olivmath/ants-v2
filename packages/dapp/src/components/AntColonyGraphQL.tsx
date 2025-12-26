import { useState, useEffect, useMemo } from 'react';
import { AntCardBackend } from './AntCardBackend';
import { useAnts, useAntsByOwner } from '@/lib/graphql/hooks';
import type { Ant } from '@/lib/graphql/types';

interface AntColonyGraphQLProps {
  userAddress?: `0x${string}`;
  layEggs?: (id: bigint) => void;
  sellAnt?: (id: bigint) => void;
  refreshTrigger?: boolean;
}

export function AntColonyGraphQL({
  userAddress,
  layEggs,
  sellAnt,
  refreshTrigger = false,
}: AntColonyGraphQLProps) {
  const [svgUri, setSvgUri] = useState<string | null>(null);

  // Fetch ants based on whether user is connected
  const { ants: allAnts, loading: loadingAll, error: errorAll, refetch: refetchAll } = useAnts({
    limit: 1000,
  });

  const { ants: userAnts, loading: loadingUser, error: errorUser, refetch: refetchUser } =
    useAntsByOwner(userAddress || '', {
      limit: 1000,
    });

  // Determine which ants to show
  const ants = userAddress ? userAnts : allAnts;
  const loading = userAddress ? loadingUser : loadingAll;
  const error = userAddress ? errorUser : errorAll;
  const refetch = userAddress ? refetchUser : refetchAll;

  // Global timer for synchronized countdowns
  const [now, setNow] = useState(Math.floor(Date.now() / 1000));
  useEffect(() => {
    const timer = setInterval(() => setNow(Math.floor(Date.now() / 1000)), 1000);
    return () => clearInterval(timer);
  }, []);

  // Fetch IPFS URI from config (in a real app, this would come from backend or env)
  useEffect(() => {
    const ipfsGateway = process.env.NEXT_PUBLIC_IPFS_GATEWAY || 'https://ipfs.io/ipfs/';
    const antSvgCid = process.env.NEXT_PUBLIC_ANT_SVG_CID || '';
    if (antSvgCid) {
      setSvgUri(`${ipfsGateway}${antSvgCid}`);
    }
  }, []);

  // Refetch when transactions complete
  useEffect(() => {
    if (refreshTrigger) {
      refetch();
    }
  }, [refreshTrigger, refetch]);

  // Sort ants by priority
  const sortedAnts = useMemo(() => {
    const COOLDOWN = 600;

    return [...ants]
      .map((ant) => {
        const lastEggLayTime = Number(ant.lastEggLayTime);
        const timeSinceLastLay = now - lastEggLayTime;
        const isReady = ant.isAlive && (lastEggLayTime === 0 || timeSinceLastLay >= COOLDOWN);

        return { ant, isReady };
      })
      .sort((a, b) => {
        // 1. Alive vs Dead
        if (a.ant.isAlive !== b.ant.isAlive) {
          return a.ant.isAlive ? -1 : 1;
        }
        // 2. Ready vs Cooldown
        if (a.isReady !== b.isReady) {
          return a.isReady ? -1 : 1;
        }
        // 3. ID (newest first)
        return Number(b.ant.id) - Number(a.ant.id);
      });
  }, [ants, now]);

  if (loading) {
    return (
      <div style={{ textAlign: 'center', padding: '2rem' }}>
        <p>⏳ Loading colony data from GraphQL...</p>
      </div>
    );
  }

  if (error) {
    return (
      <div style={{ textAlign: 'center', padding: '2rem', color: 'red' }}>
        <p>❌ Error loading data: {error.message}</p>
        <p style={{ fontSize: '0.8rem', color: '#666', marginTop: '0.5rem' }}>
          Make sure the Envio indexer is running on port 8080
        </p>
        <button
          className="button"
          onClick={() => refetch()}
          style={{ marginTop: '1rem' }}
        >
          Retry
        </button>
      </div>
    );
  }

  if (ants.length === 0) {
    return (
      <div style={{ textAlign: 'center', padding: '2rem' }}>
        <p>🔍 No ants found in the colony.</p>
        {userAddress && (
          <p style={{ fontSize: '0.8rem', color: '#666', marginTop: '0.5rem' }}>
            Create your first ant to get started!
          </p>
        )}
      </div>
    );
  }

  // Convert GraphQL Ant type to component props
  const convertAnt = (ant: Ant) => ({
    id: Number(ant.id),
    owner: ant.owner,
    last_egg_lay_time: Number(ant.lastEggLayTime),
    total_eggs_laid: ant.totalEggsLaid,
    color: ant.color,
    egg_color: ant.eggColor,
    is_alive: ant.isAlive,
    created_at: Number(ant.createdAt),
    updated_at: Number(ant.updatedAt),
    svg_uri: svgUri,
  });

  return (
    <div className="grid">
      {sortedAnts.map(({ ant }) => (
        <AntCardBackend
          key={ant.id}
          ant={convertAnt(ant)}
          layEggs={layEggs ? (id) => layEggs(BigInt(id)) : undefined}
          sellAnt={sellAnt ? (id) => sellAnt(BigInt(id)) : undefined}
          isOwner={!!userAddress && ant.owner.toLowerCase() === userAddress.toLowerCase()}
          globalNow={now}
        />
      ))}
    </div>
  );
}
