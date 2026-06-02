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
- Anchor root hash: `ef54f3f36e1b30fd262962bcdb8e578f27daf70f6d46193068f2f66f566b934c`

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
- Parliament results: 55
- Finance ledger: 11
- Finance audit: 7
- Anchor queue: 10
- KIBRA audit: 7

## Proof

Double SHA:

`142ad5e6cb8f9530cc97afeb81a2deb22e45bd12b904b34c7ac77644b02265bd`

Anchor root hash:

`ef54f3f36e1b30fd262962bcdb8e578f27daf70f6d46193068f2f66f566b934c`
