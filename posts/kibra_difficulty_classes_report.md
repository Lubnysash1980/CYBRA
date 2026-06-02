# KIBRA Difficulty Classes

Status: **created**

## Naming

- Exact difficulty: `KIBRA-D<difficulty>`
- Open interval: `KIBRA(<difficulty>,+inf)`

## Current chain

- Total blocks: **10**
- Difficulties found: **[2, 3, 4]**
- Latest hash: `00510d744e45cfee9e7889daaf0209b5efadb5bf90b14f36493cb26494bdcaab`

## Exact classes

- `KIBRA-D2`: blocks=6, shares=159, indexes=[0, 5, 6, 7, 8, 9]
- `KIBRA-D3`: blocks=2, shares=23, indexes=[1, 4]
- `KIBRA-D4`: blocks=2, shares=28, indexes=[2, 3]


## Open interval classes

- `KIBRA(2,+inf)`: blocks=10, shares=210, indexes=[0, 1, 2, 3, 4, 5, 6, 7, 8, 9]
- `KIBRA(3,+inf)`: blocks=4, shares=51, indexes=[1, 2, 3, 4]
- `KIBRA(4,+inf)`: blocks=2, shares=28, indexes=[2, 3]


## Meaning

`KIBRA(2,+inf)` означає всі блоки зі складністю **2 і вище**.  
`KIBRA(3,+inf)` означає всі блоки зі складністю **3 і вище**.  
`KIBRA(4,+inf)` означає всі блоки зі складністю **4 і вище**.

## Market note

Складність дає proof-grade монети/блоку.  
Ринкова ціна все одно потребує liquidity/orderbook/buyers.

## Proof

Double SHA:

`be95a463c8edf0334b743009bdfda5e1921e98c82123c9cfe950f241f6c2641b`
