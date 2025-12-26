# Crypto Ants Indexer (Envio)

Este indexer usa [Envio](https://envio.dev) para indexar eventos da blockchain do Crypto Ants NFT e expor uma API GraphQL.

## 🏗️ Arquitetura

```
Blockchain (Hardhat/Mainnet)
    ↓ eventos
Envio Indexer
    ↓ processa eventos
Supabase PostgreSQL
    ↓ GraphQL API
Frontend (Apollo Client)
```

## 📋 Pré-requisitos

1. **Node.js 18+** e **pnpm**
2. **Envio CLI** instalado globalmente:
   ```bash
   npm install -g envio
   ```
3. **Conta Supabase** (ou PostgreSQL local)
4. **Contratos deployados** com endereços conhecidos

## 🚀 Setup

### 1. Instalar Dependências

```bash
cd packages/indexer
pnpm install
```

### 2. Configurar Supabase

#### Opção A: Usar Supabase Cloud

1. Crie um projeto em https://supabase.com
2. Vá em **SQL Editor** e execute o script `supabase-setup.sql`
3. Copie as credenciais do projeto (URL + keys)

#### Opção B: Usar PostgreSQL Local

```bash
# Instalar PostgreSQL
# macOS
brew install postgresql

# Linux
sudo apt-get install postgresql

# Iniciar serviço
brew services start postgresql  # macOS
sudo service postgresql start   # Linux

# Criar banco de dados
createdb envio-indexer
```

### 3. Configurar Variáveis de Ambiente

```bash
cp .env.example .env
```

Edite `.env`:

**Para Supabase:**
```env
SUPABASE_URL=https://xxxxx.supabase.co
SUPABASE_SERVICE_ROLE_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...
RPC_URL_31337=http://127.0.0.1:8545
ANT_SVG_CID=QmXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
```

**Para PostgreSQL Local:**
```env
ENVIO_PG_HOST=localhost
ENVIO_PG_PORT=5432
ENVIO_PG_DATABASE=envio-indexer
ENVIO_PG_USER=postgres
ENVIO_PG_PASSWORD=postgres
RPC_URL_31337=http://127.0.0.1:8545
```

### 4. Atualizar Endereços dos Contratos

Edite `config.yaml` e atualize os endereços dos contratos:

```yaml
networks:
  - id: 31337
    contracts:
      - name: CryptoAnts
        address:
          - "0xSEU_ENDERECO_AQUI"
```

### 5. Gerar Código

```bash
pnpm run codegen
```

Isso irá:
- Ler `config.yaml` e `schema.graphql`
- Gerar tipos TypeScript em `generated/`
- Criar schema do banco de dados

### 6. Iniciar Indexer

**Modo desenvolvimento (com Hasura GraphQL):**
```bash
pnpm run dev
```

**Modo produção:**
```bash
pnpm run start
```

O indexer irá:
1. ✅ Conectar ao banco de dados
2. ✅ Sincronizar eventos históricos desde o bloco inicial
3. ✅ Escutar novos eventos em tempo real
4. ✅ Expor API GraphQL em `http://localhost:8080/v1/graphql`

## 📊 GraphQL API

### Endpoint

- **Desenvolvimento**: `http://localhost:8080/v1/graphql`
- **Produção**: Configurável via Envio Cloud ou self-hosted

### Exemplos de Queries

#### Buscar todas as formigas

```graphql
query GetAllAnts {
  Ant(limit: 100, order_by: { id: desc }) {
    id
    owner
    totalEggsLaid
    color
    eggColor
    isAlive
    lastEggLayTime
    createdAt
  }
}
```

#### Buscar formigas de um usuário

```graphql
query GetUserAnts($owner: String!) {
  Ant(where: { owner: { _eq: $owner } }) {
    id
    totalEggsLaid
    color
    eggColor
    isAlive
    lastEggLayTime
    events {
      type
      amount
      blockTimestamp
      transactionHash
    }
  }
}
```

#### Buscar eventos recentes

```graphql
query GetRecentEvents {
  Event(limit: 50, order_by: { blockNumber: desc }) {
    id
    type
    ant {
      id
      color
    }
    owner
    amount
    blockTimestamp
    transactionHash
  }
}
```

#### Estatísticas globais

```graphql
query GetGlobalStats {
  GlobalStats {
    totalAnts
    aliveAnts
    deadAnts
    totalEggsLaid
    totalEggsBought
    lastUpdatedAt
  }
}
```

#### Estatísticas de usuário

```graphql
query GetUserStats($address: String!) {
  UserStats(where: { address: { _eq: $address } }) {
    ownedAnts
    aliveAnts
    deadAnts
    totalEggsLaid
    totalEggsBought
    lastActivity
  }
}
```

## 🛠️ Comandos

```bash
# Gerar tipos TypeScript
pnpm run codegen

# Desenvolvimento (com hot reload)
pnpm run dev

# Produção
pnpm run start

# Parar indexer
pnpm run stop

# Rodar testes
pnpm run test
```

## 📁 Estrutura

```
packages/indexer/
├── config.yaml              # Configuração do Envio
├── schema.graphql           # Schema GraphQL
├── src/
│   └── EventHandlers.ts     # Handlers de eventos
├── generated/               # Código gerado (auto)
├── abis/                    # ABIs dos contratos (auto)
├── supabase-setup.sql       # Setup do banco Supabase
└── README.md
```

## 🐛 Troubleshooting

### Indexer não conecta ao banco

- Verifique as credenciais do Supabase/PostgreSQL
- Teste conexão: `psql -h localhost -U postgres -d envio-indexer`

### Eventos não aparecem

- Verifique se o RPC_URL está correto
- Verifique se os endereços dos contratos estão corretos em `config.yaml`
- Verifique o bloco inicial (`start_block`)

### GraphQL retorna erros

- Verifique se o indexer está rodando
- Verifique se o Hasura GraphQL está acessível
- Teste queries no playground: `http://localhost:8080/console`

## 🚀 Deploy em Produção

### Opção 1: Envio Cloud (Recomendado)

```bash
# Login no Envio
envio login

# Deploy
envio deploy
```

### Opção 2: Self-hosted

1. Configure PostgreSQL em produção
2. Configure variáveis de ambiente
3. Execute `pnpm run start`
4. Configure reverse proxy (Nginx/Caddy) para GraphQL endpoint

## 📚 Recursos

- [Envio Documentation](https://docs.envio.dev)
- [Supabase Documentation](https://supabase.com/docs)
- [Hasura GraphQL](https://hasura.io/docs)
