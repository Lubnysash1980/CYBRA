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
- Anchor queue count: **2**
- Latest KIBRA hash: `00f957b0f5cda9f673bf10d8d440279ea89e7834787871183b14c5540b8d3aa5`
- Anchor root hash: `6433cf661562b7df2d4fdc162ad8a85a3561e1a42bc4da695a98ee712fa8dfa5`

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

- Parliament queue: 4
- Parliament results: 78
- Finance ledger: 18
- Finance audit: 37
- Anchor queue: 2
- KIBRA audit: 12

## Proof

Double SHA:

`06a3e5da16ef18d56df7a6a593cdd4828e20574dd780442cc98be73646804a72`

Anchor root hash:

`6433cf661562b7df2d4fdc162ad8a85a3561e1a42bc4da695a98ee712fa8dfa5`
