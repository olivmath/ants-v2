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