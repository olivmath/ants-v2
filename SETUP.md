# Crypto Ants v2 - Setup Guide

Este guia explica como configurar e executar o projeto Crypto Ants v2 com a nova arquitetura usando IPFS, Backend e Frontend integrados.

## 📋 Arquitetura

```
┌─────────────┐
│   Frontend  │
│  (Next.js)  │
└─────┬───────┘
      │
      ├─────────────► Backend API (dados das formigas e eventos)
      │               └─► Indexador blockchain
      │
      ├─────────────► IPFS (SVG template)
      │
      └─────────────► Blockchain (write operations)
                      - buyEggs()
                      - createAnt()
                      - layEggs()
                      - sellAnt()
```

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
# Instalar IPFS
# https://docs.ipfs.tech/install/

# Iniciar daemon
ipfs daemon

# Fazer upload
ipfs add packages/dapp/public/ant-template.svg

# Copiar o CID retornado
```

## 🔧 Passo 2: Configurar Backend

```bash
cd packages/backend

# Instalar dependências
pnpm install

# Copiar arquivo de configuração
cp .env.example .env

# Editar .env e configurar:
# - ANT_SVG_CID=<CID_DO_IPFS>
# - RPC_URL=http://127.0.0.1:8545 (ou sua rede)
# - CRYPTO_ANTS_ADDRESS=<endereço_do_contrato>
# - EGG_ADDRESS=<endereço_do_egg_token>
```

Exemplo de `.env`:
```
PORT=3001
NODE_ENV=development

RPC_URL=http://127.0.0.1:8545
CRYPTO_ANTS_ADDRESS=0xe7f1725E7734CE288F8367e1Bb143E90bb3F0512
EGG_ADDRESS=0x5FbDB2315678afecb367f032d93F642f64180aa3
START_BLOCK=0

IPFS_GATEWAY=https://ipfs.io/ipfs/
ANT_SVG_CID=QmXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX

DB_PATH=./data/ants.db
```

## 📦 Passo 3: Deploy dos Contratos

O contrato `CryptoAnts.sol` foi modificado para aceitar um `baseTokenURI` no construtor.

```bash
cd packages/contracts

# Modificar o script de deploy para incluir o IPFS URI
# Em scripts/deploy.ts ou similar, passar:
# - ipfsUri = "ipfs://QmXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX"
# ou
# - ipfsUri = "https://ipfs.io/ipfs/QmXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX"

# Deploy
pnpm run deploy:local
# ou
forge script script/Deploy.s.sol --rpc-url $RPC_URL --broadcast
```

### Modificar Deploy Script

O construtor do `CryptoAnts` agora precisa de 2 parâmetros:

```solidity
constructor(address _eggs, string memory _baseTokenURI)
```

Exemplo de script de deploy:
```typescript
const ipfsGateway = "https://ipfs.io/ipfs/";
const antSvgCid = "QmXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX";
const baseTokenURI = `${ipfsGateway}${antSvgCid}`;

const CryptoAnts = await ethers.deployContract("CryptoAnts", [
  eggAddress,
  baseTokenURI
]);
```

## 🎨 Passo 4: Configurar Frontend

```bash
cd packages/dapp

# Copiar arquivo de configuração
cp .env.example .env.local

# Editar .env.local
NEXT_PUBLIC_API_URL=http://localhost:3001/api
NEXT_PUBLIC_IPFS_GATEWAY=https://ipfs.io/ipfs/
```

## ▶️ Passo 5: Executar o Projeto

### Terminal 1 - Blockchain (Hardhat local)
```bash
cd packages/contracts
pnpm run node
```

### Terminal 2 - Backend Indexer
```bash
cd packages/backend
pnpm run dev
```

O backend irá:
- ✅ Conectar à blockchain
- ✅ Criar banco de dados SQLite
- ✅ Sincronizar eventos históricos
- ✅ Escutar novos eventos em tempo real
- ✅ Expor API REST em `http://localhost:3001/api`

### Terminal 3 - Frontend
```bash
cd packages/dapp
pnpm run dev
```

Acesse: http://localhost:3000

## 🔄 Usando a Nova Versão

### Opção A: Substituir página principal

```bash
# Renomear página antiga
mv packages/dapp/src/pages/index.tsx packages/dapp/src/pages/index-old.tsx

# Usar nova versão com backend
mv packages/dapp/src/pages/index-backend.tsx packages/dapp/src/pages/index.tsx
```

### Opção B: Acessar rota separada

Acesse: http://localhost:3000/index-backend

## 🧪 Testando a Integração

1. **Compre Eggs**: Use a interface para comprar ovos
2. **Crie Ant**: Crie uma formiga (consome 1 ovo)
3. **Verifique Backend**: Acesse http://localhost:3001/api/ants - deve mostrar sua formiga
4. **Verifique Imagem**: A imagem deve carregar do IPFS com as cores corretas
5. **Lay Eggs**: Faça a formiga pôr ovos
6. **Verifique Eventos**: Acesse http://localhost:3001/api/events

## 📊 Endpoints da API

```
GET  /api/ants                     # Lista todas as formigas
GET  /api/ants/:id                 # Detalhes de uma formiga
GET  /api/ants/:id/events          # Eventos de uma formiga
GET  /api/events                   # Todos os eventos
GET  /api/stats                    # Estatísticas globais
GET  /api/users/:address/stats     # Estatísticas de um usuário
GET  /api/config                   # Configuração pública (IPFS CID, etc)
```

## 🐛 Troubleshooting

### Backend não conecta à blockchain
- Verifique se o `RPC_URL` está correto
- Verifique se o node local está rodando (Hardhat ou Anvil)

### Imagens não carregam
- Verifique se o `ANT_SVG_CID` está correto no `.env` do backend
- Teste acessar diretamente: `https://ipfs.io/ipfs/<CID>`
- Tente usar outro gateway IPFS se houver problemas de rede

### Frontend não busca dados do backend
- Verifique se o backend está rodando em `http://localhost:3001`
- Verifique o console do browser para erros de CORS
- Verifique se `NEXT_PUBLIC_API_URL` está correto

### Cores não aparecem corretamente
- As cores são armazenadas como hex strings no formato `#RRGGBB`
- O frontend busca as cores do backend e injeta no SVG do IPFS
- Verifique se o SVG template tem os placeholders `{{ANT_COLOR}}` e `{{EGG_COLOR}}`

## 📝 Estrutura do Projeto

```
ants-v2/
├── packages/
│   ├── contracts/              # Smart contracts (Solidity)
│   │   └── src/
│   │       └── CryptoAnts.sol  # Contrato principal (modificado)
│   │
│   ├── backend/                # Backend indexer + API (NOVO!)
│   │   ├── src/
│   │   │   ├── index.ts        # Servidor Express
│   │   │   ├── indexer.ts      # Indexador blockchain
│   │   │   ├── routes.ts       # Rotas da API
│   │   │   └── db/             # Schema e migrations
│   │   └── package.json
│   │
│   └── dapp/                   # Frontend (Next.js)
│       ├── src/
│       │   ├── components/
│       │   │   ├── AntImage.tsx          # Renderiza SVG do IPFS
│       │   │   ├── AntCardBackend.tsx    # Card com dados do backend
│       │   │   └── AntColonyBackend.tsx  # Lista de formigas
│       │   ├── lib/
│       │   │   ├── api.ts                # Cliente da API
│       │   │   └── svg.ts                # Utilitários SVG
│       │   └── pages/
│       │       ├── index.tsx              # Página original
│       │       └── index-backend.tsx      # Nova versão com backend
│       └── public/
│           └── ant-template.svg           # Template SVG para IPFS
```

## 🎯 Próximos Passos

- [ ] Fazer upload do SVG para IPFS
- [ ] Configurar `.env` do backend com o CID do IPFS
- [ ] Deploy dos contratos com o novo construtor
- [ ] Testar integração completa
- [ ] Substituir página principal pelo `index-backend.tsx`
- [ ] Deploy em produção

## 💡 Vantagens da Nova Arquitetura

✅ **Performance**: Frontend não faz múltiplas chamadas RPC
✅ **Escalabilidade**: Backend indexa e cacheia dados
✅ **Flexibilidade**: Imagens no IPFS podem ser atualizadas sem redeploy
✅ **Custo**: Menos chamadas à blockchain = menos custos de RPC
✅ **UX**: Carregamento mais rápido e interface mais responsiva
