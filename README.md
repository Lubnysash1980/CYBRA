# CYBRA v1

Escrow + responsibility core та супутні контракти для угоди
за рахунком № РБ0518-00742 від 06.10.2026.

Версія v1.0.1 — frozen. Подальші можливості — тільки новими
versioned контрактами, не тихою зміною v1.

## Склад

src/CYBRAResponsibilityContract.sol
    Логічне ядро відповідальності.
    Фіксує сторони, рахунок, докази, рішення покупця,
    ONLINE/OFFLINE контролера і TRUE_100.

src/CYBRAEscrow.sol
    Фінансовий шар (native ETH). Тримає депозит покупця.
    Читає з ядра лише true100() і responsibilityOpen().
    Не змінює рішення ядра.

src/CYBRAP2PPurchase.sol
    P2P-угода з ERC-20 escrow. Mutual signatures, evidence,
    parliament-only створення. v1.0.1: nonReentrant + USDT-compatible
    safe transfers.

Решта src/*.sol — супутні контролери рівнів, ліцензій і research.
Дивись THREAT_MODEL.md, розділ "Trust model".

## Модель

RESPONSIBILITY v1
        │
        │ RESPONSIBILITY_ID
        ▼
     ESCROW v1
        │
        ├── deposit()
        │      └── depositedAmount = єдина база розрахунку
        │
        ├── TRUE_100
        │      └── release() → SELLER
        │
        ├── RESPONSIBILITY_OPEN
        │      └── SETTLEMENT
        │            ├── arbiter  → buyer або seller
        │            └── timeout  → buyer (permissionless)
        │
        └── ...

## Головні принципи

TRUE_100             → SELLER
RESPONSIBILITY_OPEN  → ARBITER (до timeout)
SETTLEMENT_TIMEOUT   → BUYER (після timeout, permissionless)

Escrow не читає verifiedExpenseAmount з ядра.
Escrow не змінює рішення ядра.
Settlement одноразовий.
Сума кожної успішної виплати = depositedAmount.
Timeout рахується тільки від моменту входу в SETTLEMENT.

## Фінансовий інваріант

    payout == depositedAmount
    payout != address(escrow).balance

depositedAmount встановлюється один раз у deposit() і не
змінюється. Будь-який ETH, примусово надісланий на контракт,
не входить в accounting і не розподіляється.

## Тести

    forge test

Покриття v1.0.1:
- state machine ядра (TRUE_100, REJECT, RESPONSIBILITY_OPEN);
- deadline на стороні ядра;
- escrow accounting (deposit, release, settle, timeout);
- access control (buyer / seller / arbiter / stranger);
- one-shot гарантії для обох виходів;
- fingerprint binding (RESPONSIBILITY_ID);
- forced ETH не впливає на payout;
- P2PPurchase: USDT-style токени (без повернення bool);
- P2PPurchase: false-returning токени revert на fund.

107 tests passed, 0 failed.

## Що НЕ входить у v1

- partial settlement;
- ERC-20 escrow (окрім P2PPurchase);
- arbiter rotation / multisig governance;
- повернення forced excess ETH.

Усе це — окремі versioned контракти, не патчі v1.

## Аудит

- CYBRAResponsibilityContract.sol, CYBRAEscrow.sol — рев'ю пройдено.
- CYBRAP2PPurchase.sol — рев'ю + виправлення v1.0.1.
- Решта src/*.sol — тести проходять, зовнішній аудит не проводився.
