# CYBRA Owner Orchestrator / Finance Risk / External Anchor / Car Purchase Preflight

Status: **ready**

## Owner role

- OWNER role: **MAIN_ORCHESTRATOR**
- Real payment execution: **false**
- Real external blockchain transaction: **false**
- Manual OWNER approval required: **true**

## Finance risk decision

- Decision: **conditional_hold_until_documents**
- Payment execution allowed: **false**
- Allowed next stage: **document_collection_and_manual_review**

Reason:

Завтрашня купівля авто можлива тільки після перевірки документів, продавця, VIN, обтяжень, договору і ручного підтвердження OWNER.

## External blockchain anchor

- Status: **manual_anchor_package_ready**
- Automatic on-chain tx: **false**
- Manual wallet signature required: **true**
- Anchor queue count: **10**
- Latest KIBRA hash: `003a676ebdf5bf79ef0e082efcbaaf77bc58bbbab0e94544a0672ce8b9d7713e`
- Anchor root hash: `ada77daecca5212a5523a95c45a50154dbfb04beec302414da2a38b5c3ef78d2`

## Car purchase tomorrow: preflight

Before any payment, collect and verify:

- VIN або номер кузова
- ціна і валюта
- продавець / дилер / компанія
- договір або рахунок
- акт прийому-передачі
- умови оплати
- перевірка обтяжень/арештів/застав
- перевірка права продавця продавати авто
- реєстраційні платежі
- фінальне ручне підтвердження OWNER

## Blocked

- automatic payment
- full prepayment without guarantees
- payment without VIN/documents
- payment without seller authority check
- payment without ownership transfer terms

## Redis state

- Parliament queue: 0
- Parliament results: 56
- Finance ledger: 11
- Finance audit: 7
- Anchor queue: 10
- KIBRA audit: 7

## Proof

Double SHA:

`6031bdd1749f4ba09fadede66126b100be692fe964c6c40f487fd1cf4984e9fe`

Anchor root hash:

`ada77daecca5212a5523a95c45a50154dbfb04beec302414da2a38b5c3ef78d2`
