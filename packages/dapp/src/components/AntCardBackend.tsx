import { AntImage } from './AntImage';
import { Ant } from '@/lib/api';

interface AntCardBackendProps {
  ant: Ant;
  layEggs?: (id: number) => void;
  sellAnt?: (id: number) => void;
  isOwner?: boolean;
  globalNow: number;
}

export function AntCardBackend({
  ant,
  layEggs,
  sellAnt,
  isOwner = false,
  globalNow,
}: AntCardBackendProps) {
  const COOLDOWN = 600;
  const timeSinceLastLay = globalNow - ant.last_egg_lay_time;
  const canLay = ant.is_alive && (ant.last_egg_lay_time === 0 || timeSinceLastLay >= COOLDOWN);
  const remainingCooldown = ant.last_egg_lay_time === 0 ? 0 : COOLDOWN - timeSinceLastLay;

  const formatTimeSince = (seconds: number) => {
    if (seconds < 60) return `${Math.floor(seconds)}s ago`;
    if (seconds < 3600) return `${Math.floor(seconds / 60)}m ago`;
    return `${Math.floor(seconds / 3600)}h ago`;
  };

  const formatCountdown = (seconds: number) => {
    if (seconds <= 0) return '0s';
    const m = Math.floor(seconds / 60);
    const s = Math.floor(seconds % 60);
    return `${m}m ${s}s`;
  };

  return (
    <div className="ant-card">
      {/* Ant Image from IPFS */}
      <div style={{ marginBottom: '1rem' }}>
        <AntImage
          antColor={ant.color}
          eggColor={ant.egg_color}
          isAlive={ant.is_alive}
          totalEggsLaid={ant.total_eggs_laid}
          svgUri={ant.svg_uri}
          alt={`Crypto Ant #${ant.id}`}
          className="ant-image"
        />
      </div>

      <h3>Ant #{ant.id}</h3>

      <div className="ant-status">
        <span
          style={{
            fontSize: '2rem',
            display: 'inline-block',
            transform: ant.is_alive ? 'none' : 'rotate(180deg)',
            transition: 'transform 0.5s',
          }}
        >
          🐜
        </span>
        <span
          style={{
            color: ant.is_alive ? 'green' : ant.owner ? 'red' : 'gray',
            marginLeft: '0.5rem',
          }}
        >
          {ant.is_alive ? 'Alive' : ant.owner ? 'Dead' : 'Sold'}
        </span>
      </div>

      <div style={{ marginTop: '1rem', fontSize: '0.9rem' }}>
        <p>
          <strong>🥚 Eggs Laid:</strong> {ant.total_eggs_laid}
        </p>
        <p>
          <strong>🎨 Ant Color:</strong>{' '}
          <span
            style={{
              display: 'inline-block',
              width: '20px',
              height: '20px',
              backgroundColor: ant.color,
              border: '1px solid #ccc',
              borderRadius: '3px',
              verticalAlign: 'middle',
              marginLeft: '5px',
            }}
          />
          {' '}
          {ant.color}
        </p>
        <p>
          <strong>🥚 Egg Color:</strong>{' '}
          <span
            style={{
              display: 'inline-block',
              width: '20px',
              height: '20px',
              backgroundColor: ant.egg_color,
              border: '1px solid #ccc',
              borderRadius: '3px',
              verticalAlign: 'middle',
              marginLeft: '5px',
            }}
          />
          {' '}
          {ant.egg_color}
        </p>
      </div>

      {ant.last_egg_lay_time > 0 && (
        <p style={{ fontSize: '0.8rem', color: '#666', marginTop: '0.5rem' }}>
          Last laid: {formatTimeSince(timeSinceLastLay)}
        </p>
      )}

      {ant.owner && !isOwner && (
        <p
          style={{
            fontSize: '0.7rem',
            color: '#888',
            marginTop: '0.5rem',
            wordBreak: 'break-all',
          }}
        >
          Owner: {ant.owner.slice(0, 6)}...{ant.owner.slice(-4)}
        </p>
      )}

      {isOwner && ant.is_alive && layEggs && sellAnt && (
        <div className="actions" style={{ marginTop: '1rem' }}>
          <button
            className="button"
            disabled={!canLay}
            onClick={() => layEggs(ant.id)}
            title={
              canLay
                ? 'Lay Eggs (10% chance of death)'
                : `Cooldown: ${formatCountdown(remainingCooldown)}`
            }
          >
            {canLay ? '🥚 Lay Eggs' : `⏱ Wait ${formatCountdown(remainingCooldown)}`}
          </button>
          <button
            className="button delete"
            onClick={() => sellAnt(ant.id)}
            title="Sell Ant for 0.004 ETH"
          >
            💰 Sell
          </button>
        </div>
      )}
    </div>
  );
}
