import { useQuery, useLazyQuery, useSubscription } from '@apollo/client';
import {
  GET_ANTS,
  GET_ANTS_BY_OWNER,
  GET_ANT,
  GET_EVENTS,
  GET_ANT_EVENTS,
  GET_GLOBAL_STATS,
  GET_USER_STATS,
  SUBSCRIBE_TO_ANTS,
  SUBSCRIBE_TO_EVENTS,
} from './queries';
import type { Ant, Event, GlobalStats, UserStats } from './types';

// Hook to get all ants
export function useAnts(options?: { limit?: number; offset?: number; where?: any }) {
  const { data, loading, error, refetch } = useQuery<{ Ant: Ant[] }>(GET_ANTS, {
    variables: {
      limit: options?.limit || 100,
      offset: options?.offset || 0,
      where: options?.where,
    },
    pollInterval: 5000, // Refetch every 5 seconds
  });

  return {
    ants: data?.Ant || [],
    loading,
    error,
    refetch,
  };
}

// Hook to get ants by owner
export function useAntsByOwner(owner: string, options?: { limit?: number }) {
  const { data, loading, error, refetch } = useQuery<{ Ant: Ant[] }>(GET_ANTS_BY_OWNER, {
    variables: {
      owner: owner.toLowerCase(),
      limit: options?.limit || 100,
    },
    skip: !owner,
    pollInterval: 5000,
  });

  return {
    ants: data?.Ant || [],
    loading,
    error,
    refetch,
  };
}

// Hook to get single ant
export function useAnt(id: string) {
  const { data, loading, error, refetch } = useQuery<{ Ant: Ant[] }>(GET_ANT, {
    variables: { id },
    skip: !id,
  });

  return {
    ant: data?.Ant?.[0],
    loading,
    error,
    refetch,
  };
}

// Hook to get events
export function useEvents(options?: { limit?: number; offset?: number; where?: any }) {
  const { data, loading, error, refetch } = useQuery<{ Event: Event[] }>(GET_EVENTS, {
    variables: {
      limit: options?.limit || 100,
      offset: options?.offset || 0,
      where: options?.where,
    },
    pollInterval: 5000,
  });

  return {
    events: data?.Event || [],
    loading,
    error,
    refetch,
  };
}

// Hook to get events for specific ant
export function useAntEvents(antId: string) {
  const { data, loading, error, refetch } = useQuery<{ Event: Event[] }>(GET_ANT_EVENTS, {
    variables: { antId },
    skip: !antId,
  });

  return {
    events: data?.Event || [],
    loading,
    error,
    refetch,
  };
}

// Hook to get global stats
export function useGlobalStats() {
  const { data, loading, error, refetch } = useQuery<{ GlobalStats: GlobalStats[] }>(
    GET_GLOBAL_STATS,
    {
      pollInterval: 10000, // Refetch every 10 seconds
    }
  );

  return {
    stats: data?.GlobalStats?.[0],
    loading,
    error,
    refetch,
  };
}

// Hook to get user stats
export function useUserStats(address: string) {
  const { data, loading, error, refetch } = useQuery<{ UserStats: UserStats[] }>(GET_USER_STATS, {
    variables: { address: address.toLowerCase() },
    skip: !address,
    pollInterval: 10000,
  });

  return {
    stats: data?.UserStats?.[0],
    loading,
    error,
    refetch,
  };
}

// Hook to subscribe to ant updates (real-time)
export function useAntsSubscription(options?: { where?: any }) {
  const { data, loading, error } = useSubscription<{ Ant: Ant[] }>(SUBSCRIBE_TO_ANTS, {
    variables: { where: options?.where },
  });

  return {
    ants: data?.Ant || [],
    loading,
    error,
  };
}

// Hook to subscribe to events (real-time)
export function useEventsSubscription() {
  const { data, loading, error } = useSubscription<{ Event: Event[] }>(SUBSCRIBE_TO_EVENTS);

  return {
    events: data?.Event || [],
    loading,
    error,
  };
}

// Lazy query for on-demand fetching
export function useLazyAnts() {
  const [fetch, { data, loading, error }] = useLazyQuery<{ Ant: Ant[] }>(GET_ANTS);

  return {
    fetchAnts: fetch,
    ants: data?.Ant || [],
    loading,
    error,
  };
}
