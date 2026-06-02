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
- Anchor queue count: **1**
- Latest KIBRA hash: `008a14703eb452470cbbed74931d44f6220897823d71c436b3dacb5fab11f896`
- Anchor root hash: `3973be230516fb8898c720c253cebb7eb5eb048118636ba028597cfe919bfcbd`

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
- Parliament results: 73
- Finance ledger: 17
- Finance audit: 36
- Anchor queue: 1
- KIBRA audit: 11

## Proof

Double SHA:

`720b0b855edeb78551a4b7001bea8e5f42a6e46faed1738db84dacb0b5f93e5e`

Anchor root hash:

`3973be230516fb8898c720c253cebb7eb5eb048118636ba028597cfe919bfcbd`
