# Crypto Ants v2 - Development Scripts

Scripts para facilitar o desenvolvimento local do projeto.

## 📋 Scripts Disponíveis

### 1. `dev.sh` - Desenvolvimento Local Completo

Inicia todos os serviços necessários para desenvolvimento:
- ⛓️ Anvil (blockchain local)
- 🚀 Deploy automático dos contratos
- 🔍 Envio Indexer (GraphQL API)
- 🌐 Frontend (Next.js)

**Uso:**
```bash
./scripts/dev.sh
```

Ou via pnpm (na raiz):
```bash
pnpm run dev:all
```

**Serviços iniciados:**
- Blockchain: `http://localhost:8545`
- GraphQL API: `http://localhost:8080/v1/graphql`
- GraphQL Console: `http://localhost:8080/console`
- Frontend: `http://localhost:3000`

**Logs:**
```bash
# Anvil
tail -f packages/contracts/anvil.log

# Indexer
tail -f packages/indexer/indexer.log

# Frontend
tail -f packages/dapp/frontend.log
```

**Parar serviços:**
Pressione `Ctrl+C` no terminal onde o script está rodando.

---

### 2. `deploy-local.sh` - Deploy Local

Faz deploy dos contratos no Anvil e atualiza configurações:

**Uso:**
```bash
# Certifique-se que Anvil está rodando
anvil

# Em outro terminal
./scripts/deploy-local.sh
```

Ou via pnpm:
```bash
pnpm run deploy:local
```

**O que faz:**
1. ✅ Verifica se Anvil está rodando
2. 🏗️ Compila contratos
3. 🚀 Deploy do Egg token
4. 🚀 Deploy do CryptoAnts NFT
5. 💾 Salva endereços em `addresses.json`
6. 📝 Atualiza `indexer/config.yaml`
7. 📝 Atualiza `dapp/src/contracts/abis.ts`

**Variáveis de ambiente:**
```bash
# Opcional: Definir CID do SVG no IPFS
export ANT_SVG_CID=QmXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
./scripts/deploy-local.sh
```

---

### 3. `test-e2e.sh` - Testes End-to-End

Testa o fluxo completo do aplicativo:

**Uso:**
```bash
# Certifique-se que todos os serviços estão rodando
./scripts/test-e2e.sh
```

Ou via pnpm:
```bash
pnpm run test:e2e
```

**Testes executados:**
1. 🥚 Comprar ovos
2. ✅ Aprovar gasto de ovos
3. 🐜 Criar formiga
4. 📊 Buscar metadados da formiga
5. 🥚 Fazer formiga pôr ovos
6. 🔍 Verificar GraphQL API
7. 🌐 Verificar Frontend

---

## 🚀 Quick Start

### Primeira vez:

```bash
# 1. Instalar dependências
pnpm install

# 2. Fazer upload do SVG para IPFS
# Veja SETUP.md para instruções

# 3. Configurar variáveis de ambiente
cd packages/indexer
cp .env.example .env
# Editar .env com suas credenciais

cd ../dapp
cp .env.example .env.local
# Editar .env.local

# 4. Voltar para raiz
cd ../..

# 5. Rodar tudo
./scripts/dev.sh
```

### Desenvolvimento diário:

```bash
# Opção 1: Script all-in-one
./scripts/dev.sh

# Opção 2: Serviços separados (mais controle)

# Terminal 1: Blockchain
anvil

# Terminal 2: Deploy
./scripts/deploy-local.sh

# Terminal 3: Indexer
cd packages/indexer
pnpm run dev

# Terminal 4: Frontend
cd packages/dapp
pnpm run dev
```

---

## 🔧 Requisitos

### Instalados globalmente:

```bash
# Node.js 18+
node --version

# pnpm
npm install -g pnpm

# Foundry (Anvil)
curl -L https://foundry.paradigm.xyz | bash
foundryup

# Envio CLI
npm install -g envio

# jq (para scripts)
# macOS
brew install jq

# Linux
sudo apt-get install jq
```

### Banco de dados:

Escolha uma opção:

**Opção A: Supabase (Recomendado)**
- Crie conta em https://supabase.com
- Execute SQL em `packages/indexer/supabase-setup.sql`
- Configure credenciais em `packages/indexer/.env`

**Opção B: PostgreSQL Local**
```bash
# macOS
brew install postgresql
brew services start postgresql

# Linux
sudo apt-get install postgresql
sudo service postgresql start

# Criar banco
createdb envio-indexer
```

---

## 📝 Variáveis de Ambiente

### `packages/indexer/.env`

```env
# Supabase
SUPABASE_URL=https://xxxxx.supabase.co
SUPABASE_SERVICE_ROLE_KEY=eyJhbGc...

# Ou PostgreSQL local
ENVIO_PG_HOST=localhost
ENVIO_PG_PORT=5432
ENVIO_PG_DATABASE=envio-indexer
ENVIO_PG_USER=postgres
ENVIO_PG_PASSWORD=postgres

# RPC
RPC_URL_31337=http://localhost:8545

# IPFS
ANT_SVG_CID=QmXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
```

### `packages/dapp/.env.local`

```env
NEXT_PUBLIC_GRAPHQL_ENDPOINT=http://localhost:8080/v1/graphql
NEXT_PUBLIC_IPFS_GATEWAY=https://ipfs.io/ipfs/
NEXT_PUBLIC_ANT_SVG_CID=QmXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
```

---

## 🐛 Troubleshooting

### Script não inicia

```bash
# Verificar permissões
chmod +x scripts/*.sh

# Verificar dependências
which pnpm
which anvil
which envio
which jq
```

### Anvil não conecta

```bash
# Verificar se porta 8545 está livre
lsof -i :8545

# Matar processos
kill $(lsof -t -i:8545)
```

### Indexer falha

```bash
# Verificar banco de dados
psql -h localhost -U postgres -d envio-indexer -c "SELECT 1"

# Ou testar Supabase
curl https://xxxxx.supabase.co/rest/v1/
```

### GraphQL não responde

```bash
# Verificar se Hasura está rodando
curl http://localhost:8080/healthz

# Ver logs do indexer
tail -f packages/indexer/indexer.log
```

---

## 📚 Recursos

- [SETUP.md](../SETUP.md) - Setup completo
- [packages/indexer/README.md](../packages/indexer/README.md) - Envio Indexer
- [Anvil Documentation](https://book.getfoundry.sh/anvil/)
- [Envio Documentation](https://docs.envio.dev)
