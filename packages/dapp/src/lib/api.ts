// Backend API client

const API_BASE_URL = process.env.NEXT_PUBLIC_API_URL || 'http://localhost:3001/api';

export interface Ant {
  id: number;
  owner: string;
  last_egg_lay_time: number;
  total_eggs_laid: number;
  color: string;
  egg_color: string;
  is_alive: boolean;
  created_at: number;
  updated_at: number;
  svg_uri: string | null;
}

export interface Event {
  id: number;
  event_type: 'EggsBought' | 'AntCreated' | 'AntSold' | 'EggsLaid' | 'AntDied';
  ant_id: number | null;
  owner: string;
  amount: number | null;
  block_number: number;
  transaction_hash: string;
  timestamp: number;
}

export interface Stats {
  total_ants: number;
  alive_ants: number;
  dead_ants: number;
  total_eggs_laid: number;
  sync_status: {
    id: number;
    last_synced_block: number;
    last_synced_at: number;
  };
  ipfs_svg_cid: string;
  ipfs_gateway: string;
}

export interface UserStats {
  address: string;
  owned_ants: number;
  alive_ants: number;
  total_eggs_laid: number;
  recent_events: Event[];
}

export interface ApiConfig {
  ipfs_gateway: string;
  ant_svg_cid: string;
  crypto_ants_address: string;
  egg_address: string;
}

export class AntsAPI {
  private baseUrl: string;

  constructor(baseUrl: string = API_BASE_URL) {
    this.baseUrl = baseUrl;
  }

  private async fetch<T>(endpoint: string, options?: RequestInit): Promise<{ success: boolean; data: T; count?: number; error?: string }> {
    try {
      const response = await fetch(`${this.baseUrl}${endpoint}`, {
        ...options,
        headers: {
          'Content-Type': 'application/json',
          ...options?.headers,
        },
      });

      if (!response.ok) {
        throw new Error(`HTTP error! status: ${response.status}`);
      }

      return await response.json();
    } catch (error) {
      console.error('API Error:', error);
      throw error;
    }
  }

  async getAnts(params?: { owner?: string; isAlive?: boolean; limit?: number; offset?: number }): Promise<Ant[]> {
    const queryParams = new URLSearchParams();
    if (params?.owner) queryParams.append('owner', params.owner);
    if (params?.isAlive !== undefined) queryParams.append('isAlive', String(params.isAlive));
    if (params?.limit) queryParams.append('limit', String(params.limit));
    if (params?.offset) queryParams.append('offset', String(params.offset));

    const query = queryParams.toString() ? `?${queryParams.toString()}` : '';
    const response = await this.fetch<Ant[]>(`/ants${query}`);
    return response.data;
  }

  async getAnt(id: number): Promise<Ant> {
    const response = await this.fetch<Ant>(`/ants/${id}`);
    return response.data;
  }

  async getAntEvents(id: number): Promise<Event[]> {
    const response = await this.fetch<Event[]>(`/ants/${id}/events`);
    return response.data;
  }

  async getEvents(params?: { eventType?: string; owner?: string; antId?: number; limit?: number; offset?: number }): Promise<Event[]> {
    const queryParams = new URLSearchParams();
    if (params?.eventType) queryParams.append('eventType', params.eventType);
    if (params?.owner) queryParams.append('owner', params.owner);
    if (params?.antId) queryParams.append('antId', String(params.antId));
    if (params?.limit) queryParams.append('limit', String(params.limit));
    if (params?.offset) queryParams.append('offset', String(params.offset));

    const query = queryParams.toString() ? `?${queryParams.toString()}` : '';
    const response = await this.fetch<Event[]>(`/events${query}`);
    return response.data;
  }

  async getStats(): Promise<Stats> {
    const response = await this.fetch<Stats>('/stats');
    return response.data;
  }

  async getUserStats(address: string): Promise<UserStats> {
    const response = await this.fetch<UserStats>(`/users/${address}/stats`);
    return response.data;
  }

  async getConfig(): Promise<ApiConfig> {
    const response = await this.fetch<ApiConfig>('/config');
    return response.data;
  }
}

// Singleton instance
export const antsAPI = new AntsAPI();
