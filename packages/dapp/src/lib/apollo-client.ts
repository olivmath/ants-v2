import { ApolloClient, InMemoryCache, HttpLink } from '@apollo/client';

const GRAPHQL_ENDPOINT =
  process.env.NEXT_PUBLIC_GRAPHQL_ENDPOINT || 'http://localhost:8080/v1/graphql';

export const apolloClient = new ApolloClient({
  link: new HttpLink({
    uri: GRAPHQL_ENDPOINT,
  }),
  cache: new InMemoryCache({
    typePolicies: {
      Ant: {
        keyFields: ['id'],
      },
      Event: {
        keyFields: ['id'],
      },
      UserStats: {
        keyFields: ['id'],
      },
      GlobalStats: {
        keyFields: ['id'],
      },
    },
  }),
  defaultOptions: {
    watchQuery: {
      fetchPolicy: 'cache-and-network',
    },
    query: {
      fetchPolicy: 'network-only',
    },
  },
});
