# Crypto Ants v2 - Setup Guide

Este guia explica como configurar e executar o projeto Crypto Ants v2 com a nova arquitetura usando **Envio (Indexer)** + **GraphQL** + **Supabase** + **IPFS**.

## 📋 Arquitetura

```
┌─────────────┐
│   Frontend  │
│  (Next.js)  │
└─────┬───────┘
      │
      ├─────────────► GraphQL API (Envio/Hasura)
      │               └─► Supabase PostgreSQL
      │                   └─► Envio Indexer
      │                       └─► Blockchain eventos
      │
      ├─────────────► IPFS (SVG template)
      │
      └─────────────► Blockchain (write operations)
                      - buyEggs()
                      - createAnt()
                      - layEggs()
                      - sellAnt()
```

### Componentes:

1. **Envio**: Indexa eventos da blockchain e expõe API GraphQL
2. **Supabase**: Banco de dados PostgreSQL (ou PostgreSQL local)
3. **IPFS**: Armazena template SVG das formigas
4. **Frontend**: Next.js + Apollo Client para consumir GraphQL

## 🚀 Passo 1: Upload do SVG para IPFS

O SVG template está localizado em `packages/dapp/public/ant-template.svg`

### Opção A: Usando Pinata (Recomendado)

1. Crie uma conta em https://pinata.cloud
2. Faça upload do arquivo `ant-template.svg`
3. Copie o CID gerado (ex: `QmXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX`)

### Opção B: Usando NFT.Storage

1. Crie uma conta em https://nft.storage
2. Faça upload do arquivo `ant-template.svg`
3. Copie o CID gerado

### Opção C: Usando IPFS local (desenvolvimento)

```bash
ipfs daemon
ipfs add packages/dapp/public/ant-template.svg
```

## 🗄️ Passo 2: Configurar Supabase

### Opção A: Supabase Cloud (Recomendado)

1. Crie uma conta em https://supabase.com
2. Crie um novo projeto
3. Vá em **SQL Editor** e execute o script:
   ```bash
   cat packages/indexer/supabase-setup.sql
   ```
4. Copie as credenciais:
   - Project URL
   - `anon` key
   - `service_role` key (para o indexer)

### Opção B: PostgreSQL Local

```bash
# Instalar PostgreSQL
brew install postgresql  # macOS
sudo apt-get install postgresql  # Linux

# Iniciar serviço
brew services start postgresql  # macOS
sudo service postgresql start  # Linux

# Criar banco de dados
createdb envio-indexer
```

## 📦 Passo 3: Configurar Envio Indexer

```bash
cd packages/indexer

# Instalar dependências
pnpm install

# Instalar Envio CLI globalmente
npm install -g envio

# Copiar arquivo de configuração
cp .env.example .env
```

### Editar `.env`:

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

### Atualizar endereços dos contratos:

Edite `packages/indexer/config.yaml`:

```yaml
networks:
  - id: 31337
    contracts:
      - name: CryptoAnts
        address:
          - "0xe7f1725E7734CE288F8367e1Bb143E90bb3F0512"  # Seu endereço
```

### Gerar código TypeScript:

```bash
cd packages/indexer
pnpm run codegen
```

Isso gera:
- Tipos TypeScript em `generated/`
- Schema do banco de dados
- ABIs dos contratos

## 🎨 Passo 4: Deploy dos Contratos

O contrato `CryptoAnts.sol` foi modificado para aceitar `baseTokenURI` no construtor.

### Exemplo de script de deploy:

```typescript
const ipfsGateway = "https://ipfs.io/ipfs/";
const antSvgCid = "QmXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX";
const baseTokenURI = `${ipfsGateway}${antSvgCid}`;

const CryptoAnts = await ethers.deployContract("CryptoAnts", [
  eggAddress,
  baseTokenURI
]);
```

Deploy:
```bash
cd packages/contracts
pnpm run deploy:local
```

## 🌐 Passo 5: Configurar Frontend

```bash
cd packages/dapp

# Copiar arquivo de configuração
cp .env.example .env.local
```

Edite `.env.local`:

```env
NEXT_PUBLIC_GRAPHQL_ENDPOINT=http://localhost:8080/v1/graphql
NEXT_PUBLIC_IPFS_GATEWAY=https://ipfs.io/ipfs/
NEXT_PUBLIC_ANT_SVG_CID=QmXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
```

## ▶️ Passo 6: Executar o Projeto

### Terminal 1 - Blockchain (Hardhat local)
```bash
cd packages/contracts
pnpm run node
```

### Terminal 2 - Envio Indexer
```bash
cd packages/indexer
pnpm run dev
```

O Envio irá:
- ✅ Conectar ao banco de dados
- ✅ Criar tabelas automaticamente
- ✅ Sincronizar eventos históricos
- ✅ Escutar novos eventos em tempo real
- ✅ Expor GraphQL em `http://localhost:8080/v1/graphql`
- ✅ GraphQL Playground em `http://localhost:8080/console`

### Terminal 3 - Frontend
```bash
cd packages/dapp
pnpm run dev
```

Acesse: http://localhost:3000/index-graphql

## 🔄 Usando a Nova Versão

### Substituir página principal:

```bash
# Renomear página antiga
mv packages/dapp/src/pages/index.tsx packages/dapp/src/pages/index-old.tsx

# Usar nova versão com GraphQL
mv packages/dapp/src/pages/index-graphql.tsx packages/dapp/src/pages/index.tsx
```

## 📊 GraphQL API

### Playground

Acesse: `http://localhost:8080/console`

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
    events {
      type
      amount
      blockTimestamp
    }
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
  }
}
```

## 🧪 Testando a Integração

1. **Compre Eggs**: Use a interface para comprar ovos
2. **Verifique Indexer**: Logs devem mostrar evento `EggsBought`
3. **Verifique GraphQL**:
   ```bash
   curl -X POST http://localhost:8080/v1/graphql \
     -H "Content-Type: application/json" \
     -d '{"query": "{ GlobalStats { totalEggsBought } }"}'
   ```
4. **Crie Ant**: Crie uma formiga e veja o evento `AntCreated` nos logs
5. **Verifique Frontend**: A formiga deve aparecer com imagem do IPFS

## 🐛 Troubleshooting

### Indexer não inicia

- Verifique se PostgreSQL/Supabase está acessível
- Verifique credenciais no `.env`
- Execute: `pnpm run codegen` novamente

### GraphQL retorna erro

- Verifique se o indexer está rodando: `http://localhost:8080/health`
- Teste no playground: `http://localhost:8080/console`

### Frontend não carrega dados

- Verifique `NEXT_PUBLIC_GRAPHQL_ENDPOINT` no `.env.local`
- Abra DevTools e veja erros de rede
- Teste query diretamente no playground

### Imagens não aparecem

- Verifique `NEXT_PUBLIC_ANT_SVG_CID` no `.env.local`
- Teste IPFS gateway: `https://ipfs.io/ipfs/<CID>`

## 📁 Estrutura do Projeto

```
ants-v2/
├── packages/
│   ├── contracts/              # Smart contracts (Solidity)
│   │   └── src/
│   │       └── CryptoAnts.sol  # Contrato principal
│   │
│   ├── indexer/                # Envio indexer (NOVO!)
│   │   ├── config.yaml         # Configuração do Envio
│   │   ├── schema.graphql      # Schema GraphQL
│   │   ├── src/
│   │   │   └── EventHandlers.ts # Handlers de eventos
│   │   ├── supabase-setup.sql  # Setup do Supabase
│   │   └── README.md
│   │
│   └── dapp/                   # Frontend (Next.js)
│       ├── src/
│       │   ├── components/
│       │   │   ├── AntImage.tsx
│       │   │   ├── AntCardBackend.tsx
│       │   │   └── AntColonyGraphQL.tsx  # NOVO!
│       │   ├── lib/
│       │   │   ├── apollo-client.ts      # NOVO!
│       │   │   ├── graphql/
│       │   │   │   ├── queries.ts        # NOVO!
│       │   │   │   ├── types.ts          # NOVO!
│       │   │   │   └── hooks.ts          # NOVO!
│       │   │   └── svg.ts
│       │   └── pages/
│       │       ├── index.tsx
│       │       └── index-graphql.tsx     # NOVO!
│       └── public/
│           └── ant-template.svg
```

## 🚀 Deploy em Produção

### 1. Deploy Envio Indexer

**Opção A: Envio Cloud (Recomendado)**

```bash
cd packages/indexer
envio login
envio deploy
```

**Opção B: Self-hosted**

Use Docker + PostgreSQL + Hasura

### 2. Deploy Frontend

```bash
cd packages/dapp
pnpm run build

# Deploy em Vercel
vercel deploy --prod
```

Configurar variáveis de ambiente:
- `NEXT_PUBLIC_GRAPHQL_ENDPOINT`: URL do GraphQL em produção
- `NEXT_PUBLIC_IPFS_GATEWAY`: Gateway IPFS
- `NEXT_PUBLIC_ANT_SVG_CID`: CID do SVG

## 💡 Vantagens da Nova Arquitetura

✅ **Performance**: GraphQL permite queries otimizadas
✅ **Escalabilidade**: Envio indexa automaticamente todos os eventos
✅ **Real-time**: Suporte a subscriptions GraphQL
✅ **Custo**: Indexer cacheia dados, reduzindo chamadas RPC
✅ **Flexibilidade**: Adicionar novos eventos é simples
✅ **Developer Experience**: Playground GraphQL para testar queries
✅ **Supabase**: Auth, Storage e Edge Functions quando precisar

## 📚 Recursos

- [Envio Documentation](https://docs.envio.dev)
- [Supabase Documentation](https://supabase.com/docs)
- [Apollo Client](https://www.apollographql.com/docs/react/)
- [Hasura GraphQL](https://hasura.io/docs)
