import { gql } from '@apollo/client';

// Get all ants with optional filters
export const GET_ANTS = gql`
  query GetAnts($where: Ant_bool_exp, $limit: Int = 100, $offset: Int = 0) {
    Ant(where: $where, limit: $limit, offset: $offset, order_by: { id: desc }) {
      id
      owner
      lastEggLayTime
      totalEggsLaid
      color
      eggColor
      isAlive
      createdAt
      updatedAt
      createdAtBlock
    }
  }
`;

// Get ants by owner
export const GET_ANTS_BY_OWNER = gql`
  query GetAntsByOwner($owner: String!, $limit: Int = 100) {
    Ant(where: { owner: { _eq: $owner } }, limit: $limit, order_by: { id: desc }) {
      id
      owner
      lastEggLayTime
      totalEggsLaid
      color
      eggColor
      isAlive
      createdAt
      updatedAt
    }
  }
`;

// Get single ant with events
export const GET_ANT = gql`
  query GetAnt($id: String!) {
    Ant(where: { id: { _eq: $id } }) {
      id
      owner
      lastEggLayTime
      totalEggsLaid
      color
      eggColor
      isAlive
      createdAt
      updatedAt
      createdAtBlock
      events {
        id
        type
        owner
        amount
        blockNumber
        blockTimestamp
        transactionHash
      }
    }
  }
`;

// Get recent events
export const GET_EVENTS = gql`
  query GetEvents($where: Event_bool_exp, $limit: Int = 100, $offset: Int = 0) {
    Event(where: $where, limit: $limit, offset: $offset, order_by: { blockNumber: desc }) {
      id
      type
      ant {
        id
        color
        eggColor
        isAlive
      }
      owner
      amount
      blockNumber
      blockTimestamp
      transactionHash
    }
  }
`;

// Get events for specific ant
export const GET_ANT_EVENTS = gql`
  query GetAntEvents($antId: String!) {
    Event(where: { ant: { _eq: $antId } }, order_by: { blockNumber: desc }) {
      id
      type
      owner
      amount
      blockNumber
      blockTimestamp
      transactionHash
    }
  }
`;

// Get global stats
export const GET_GLOBAL_STATS = gql`
  query GetGlobalStats {
    GlobalStats {
      id
      totalAnts
      aliveAnts
      deadAnts
      totalEggsLaid
      totalEggsBought
      lastUpdatedAt
    }
  }
`;

// Get user stats
export const GET_USER_STATS = gql`
  query GetUserStats($address: String!) {
    UserStats(where: { address: { _eq: $address } }) {
      id
      address
      ownedAnts
      aliveAnts
      deadAnts
      totalEggsLaid
      totalEggsBought
      lastActivity
    }
  }
`;

// Subscription for real-time ant updates
export const SUBSCRIBE_TO_ANTS = gql`
  subscription SubscribeToAnts($where: Ant_bool_exp) {
    Ant(where: $where, order_by: { updatedAt: desc }) {
      id
      owner
      lastEggLayTime
      totalEggsLaid
      color
      eggColor
      isAlive
      updatedAt
    }
  }
`;

// Subscription for real-time events
export const SUBSCRIBE_TO_EVENTS = gql`
  subscription SubscribeToEvents {
    Event(order_by: { blockNumber: desc }, limit: 50) {
      id
      type
      ant {
        id
      }
      owner
      amount
      blockTimestamp
    }
  }
`;
