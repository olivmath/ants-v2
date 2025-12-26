# 🐜 Regras Completas do AntGame

## Ovos
- Ovo custa: 0.01 ETH (preço dinâmico)
- 1 Ovo → 1 Formiga (sempre)
- Ovos podem ser vendidos/transferidos livremente

## Formigas (NFT)
- Cada formiga é única (ERC-721)
- Atributos: ovosTotal, tentativas, ultimaVez
- Pode fazer breeding para gerar ovos
- Pode ser listada para venda P2P

## Breeding
- Produz: 0 a 5 ovos
- 40% chance de morrer (sempre)
- Distribuição se sobrevive:
  - 30% → 1 ovo
  - 20% → 2 ovos
  - 8% → 3 ovos
  - 1.8% → 4 ovos
  - 0.2% → 5 ovos
- Bônus: +0.5% chance de 5 ovos a cada 10 ovosTotal (máx +5%)
- Cooldown: 10min × (1.5^tentativas), máximo 7 dias
- Se morrer: formiga é queimada (destruída)
- Atualiza: ovosTotal += ovos gerados, tentativas += 1

## Marketplace P2P
- Vendedor define preço livremente em ETH
- Taxa para listar: 0.001 ETH (não reembolsável)
- Taxa para comprar: 0.001 ETH
- Formiga listada vai para escrow (contrato)
- Formiga listada NÃO pode fazer breeding
- Vendedor pode cancelar (formiga volta, taxa perdida)
- Na venda: vendedor recebe (preço - 0.001 ETH)
- Protocolo recebe: 0.002 ETH por venda completa

## Preço Dinâmico
- Base: 0.01 ETH
- Sobe: muitas compras em 24h ou alta oferta total
- Desce: poucas compras em 24h
- Limites: mínimo 0.005 ETH, máximo 0.05 ETH
- Fórmula: 70% demanda + 30% oferta total

## Bloqueios
- Formiga em cooldown: não pode breeding
- Formiga listada: não pode breeding
- Formiga listada: não pode transferir