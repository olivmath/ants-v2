# 1 li o contrato e fiz alguns comentários

# 2 tentei instalar/compilar mas tinha um erro no package.json relacionado a versão

```json
WRONG: "forge-std": "github:foundry-rs/forge-std#1.9.2",
RIGHT: "forge-std": "github:foundry-rs/forge-std#v1.9.2",
```

# 3 troquei o uso de yarn por pnpm

# 4 Otimização de storage padding

Reorganizei as variáveis de estado do contrato para otimizar o uso de storage:
- Agrupei as variáveis `bool` (`locked` e `notLocked`) no mesmo slot de storage
- Reordenei as variáveis seguindo a ordem: bools, uint256s, mappings, arrays
- Economia de 1 slot de storage (32 bytes)
- Adicionei comentário explicativo sobre a otimização

# 5 Substituição do reentrancy guard custom por ReentrancyGuard do OpenZeppelin

Melhorei a segurança contra reentrancy usando o padrão do OpenZeppelin:
- Adicionei import de `@openzeppelin/utils/ReentrancyGuard.sol`
- Fiz o contrato herdar de `ReentrancyGuard`
- Removi as variáveis `locked` e `notLocked` (não mais necessárias)
- Removi a função `notLocked()` da interface `ICryptoAnts`
- Substituí o modifier `lock` customizado pelo `nonReentrant` do OpenZeppelin
- Removi o modifier `lock()` que tinha lógica manual
- Economia adicional de 2 slots de storage (64 bytes) das variáveis removidas
- Maior segurança usando biblioteca battle-tested

# 6 Correção do cálculo inseguro em buyEggs

Corrigi a vulnerabilidade crítica na função `buyEggs`:
- **Problema**: A função calculava `eggsCallerCanBuy` mas mintava `_amount`, permitindo comprar qualquer quantidade sem pagar
- Adicionei validação do valor enviado: `totalCost = _amount * eggPrice`
- Adicionei verificação `if (msg.value < totalCost) revert WrongEtherSent()`
- Implementei refund automático do ether excedente
- Corrigi o evento para emitir a quantidade correta (`_amount` em vez de `eggsCallerCanBuy`)
- Instalei biblioteca `@prb/math` para futuras operações matemáticas complexas
- Proteção contra overflow garantida pelo Solidity 0.8.x

# 7 Correção de warnings do linter Forge

Corrigi todos os warnings reportados pelo linter do Forge:
- **Named imports**: Mudei todos os plain imports para named imports (ex: `import {Ownable} from '@openzeppelin/...'`)
- **Unused imports**: Removi imports não utilizados (`console.sol` em CryptoAnts.sol e CryptoAnts.t.sol)
- **Mixed-case variables**: Renomeei `__ants` para `antsAddress` no construtor do Egg.sol
- **Immutable naming**: Renomeei variável `eggs` para `EGGS` (SCREAMING_SNAKE_CASE para immutables)
- **Unsafe typecasts**: Adicionei comentários `forge-lint: disable-next-line` nos typecasts em TestUtils.sol
- **Ordering**: Reorganizei ordem das declarações de estado (immutables primeiro)
- Resultado: Build limpo sem warnings de linter

# 8 Substituição de require por custom errors

Substituí todos os statements `require` por `revert` com custom errors:
- Adicionei custom errors: `RefundFailed()`, `Unauthorized()`, `TransferFailed()`
- `buyEggs`: Substituí `require(success, 'Refund failed')` por `if (!success) revert RefundFailed()`
- `sellAnt`: Substituí `require(antToOwner[_antId] == msg.sender, 'Unauthorized')` por `if (antToOwner[_antId] != msg.sender) revert Unauthorized()`
- `sellAnt`: Substituí `require(success, 'Whoops, this call failed!')` por `if (!success) revert TransferFailed()`
- Economia de gas: custom errors são mais eficientes que strings em require

# 9 Adição de verificação de mint e burn de eggs ao criar ant

Implementei melhorias na segurança e lógica do jogo:
- **buyEggs**: Adicionei `try/catch` para capturar falhas no mint e reverter com `MintFailed()`
- **createAnt**: Adicionei queima de 1 egg usando `transferFrom` para transferir do usuário para o contrato
- Isso garante que criar uma ant realmente custa 1 egg (antes só verificava balance mas não queimava)
- Adicionei verificação de sucesso no transferFrom
- Custom error `MintFailed()` para melhor tratamento de erros

# 10 Implementação de mecânica de postura de ovos (Egg-Laying)

Implementei sistema completo onde formigas podem colocar ovos periodicamente:

**Estrutura de Dados:**
- Criada struct `Ant` com packing otimizado (1 slot de storage):
  - `uint40 lastEggLayTime`: timestamp da última postura (válido até ano 2106)
  - `uint16 totalEggsLaid`: contador total de ovos colocados
  - `bool isAlive`: status de vida da formiga
- Novo mapping `ants` para armazenar dados por formiga
- Constante `EGG_LAY_COOLDOWN = 600` (10 minutos em segundos)

**Função layEggs():**
- Cooldown de 10 minutos entre posturas
- Quantidade de ovos: 0-20 com distribuição triangular (aproxima curva normal, favorece ~10)
- 10% de chance de morte ao colocar ovos
- Quando morre: formiga é queimada (burn do NFT) e não produz ovos
- Proteção contra reentrancy com `nonReentrant`
- Backward compatibility: formigas antigas inicializadas lazy na primeira chamada

**RNG (Random Number Generation):**
- `_generateRandomNumber()`: usa block.prevrandao + timestamp + antId + nonce + msg.sender
- `_getNormalDistributedEggs()`: distribuição triangular (média de 2 uniformes 0-20)
- Não é criptograficamente seguro mas adequado para mecânicas de jogo

**Modificações em createAnt():**
- Inicializa struct Ant ao criar formiga
- `lastEggLayTime` definido como `block.timestamp` para cooldown inicial
- `isAlive` definido como `true`

**Modificações em sellAnt():**
- Verifica se formiga está viva antes de vender
- Marca formiga como morta antes de queimar
- **Correção de bug**: `if (isok)` → `if (!isok)` para tratamento correto de erro de pagamento

**Eventos:**
- `EggsLaid(antId, owner, eggCount)`: emitido quando ovos são colocados
- `AntDied(antId, owner)`: emitido quando formiga morre

**Erros:**
- `CooldownNotMet()`: tentativa de colocar ovos antes do cooldown
- `AntIsDead()`: tentativa de usar formiga morta

**Otimizações de Gas:**
- Struct packing: 64 bits em slot de 256 bits (economia de 4x)
- Single SLOAD: usa `storage` pointer para ler struct uma vez
- Early return quando formiga morre (não calcula ovos)