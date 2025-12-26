import { useState, useEffect, useMemo } from 'react';
import { AntCardBackend } from './AntCardBackend';
import { antsAPI, Ant } from '@/lib/api';

interface AntColonyBackendProps {
  userAddress?: `0x${string}`;
  layEggs?: (id: bigint) => void;
  sellAnt?: (id: bigint) => void;
  refreshTrigger?: boolean;
}

export function AntColonyBackend({
  userAddress,
  layEggs,
  sellAnt,
  refreshTrigger = false,
}: AntColonyBackendProps) {
  const [ants, setAnts] = useState<Ant[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  // Global timer for synchronized countdowns
  const [now, setNow] = useState(Math.floor(Date.now() / 1000));
  useEffect(() => {
    const timer = setInterval(() => setNow(Math.floor(Date.now() / 1000)), 1000);
    return () => clearInterval(timer);
  }, []);

  // Fetch ants from backend
  useEffect(() => {
    const fetchAnts = async () => {
      try {
        setLoading(true);
        setError(null);

        // Fetch all ants (or filter by owner if userAddress is provided)
        const fetchedAnts = await antsAPI.getAnts({
          owner: userAddress,
          limit: 1000,
        });

        setAnts(fetchedAnts);
      } catch (err) {
        console.error('Failed to fetch ants:', err);
        setError('Failed to load ants from backend');
      } finally {
        setLoading(false);
      }
    };

    fetchAnts();
  }, [userAddress, refreshTrigger]);

  // Sort ants by priority
  const sortedAnts = useMemo(() => {
    const COOLDOWN = 600;

    return [...ants]
      .map((ant) => {
        const timeSinceLastLay = now - ant.last_egg_lay_time;
        const isReady =
          ant.is_alive && (ant.last_egg_lay_time === 0 || timeSinceLastLay >= COOLDOWN);

        return { ant, isReady };
      })
      .sort((a, b) => {
        // 1. Alive vs Dead
        if (a.ant.is_alive !== b.ant.is_alive) {
          return a.ant.is_alive ? -1 : 1;
        }
        // 2. Ready vs Cooldown
        if (a.isReady !== b.isReady) {
          return a.isReady ? -1 : 1;
        }
        // 3. ID (newest first)
        return b.ant.id - a.ant.id;
      });
  }, [ants, now]);

  if (loading) {
    return (
      <div style={{ textAlign: 'center', padding: '2rem' }}>
        <p>Loading colony data...</p>
      </div>
    );
  }

  if (error) {
    return (
      <div style={{ textAlign: 'center', padding: '2rem', color: 'red' }}>
        <p>{error}</p>
        <p style={{ fontSize: '0.8rem', color: '#666', marginTop: '0.5rem' }}>
          Make sure the backend server is running on port 3001
        </p>
      </div>
    );
  }

  if (ants.length === 0) {
    return (
      <div style={{ textAlign: 'center', padding: '2rem' }}>
        <p>No ants found in the colony.</p>
        {userAddress && <p style={{ fontSize: '0.8rem', color: '#666', marginTop: '0.5rem' }}>
          Create your first ant to get started!
        </p>}
      </div>
    );
  }

  return (
    <div className="grid">
      {sortedAnts.map(({ ant }) => (
        <AntCardBackend
          key={ant.id}
          ant={ant}
          layEggs={layEggs ? (id) => layEggs(BigInt(id)) : undefined}
          sellAnt={sellAnt ? (id) => sellAnt(BigInt(id)) : undefined}
          isOwner={!!userAddress && ant.owner.toLowerCase() === userAddress.toLowerCase()}
          globalNow={now}
        />
      ))}
    </div>
  );
}
