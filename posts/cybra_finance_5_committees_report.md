# CYBRA Finance 5 Committees

Status: active

## Committees

- Комітет-Шукач / finder: Шукати, яких модулів, реквізитів, proof, SWIFT/Bank/PSP адаптерів, cold-wallet записів і процедур не вистачає.
- Комітет-Навчач / teacher: Створювати правила, інструкції, політики безпечної роботи фінансової системи.
- Комітет-Воркер / worker: Виконувати роботу через бінарник cybra-finance-bin і допоміжні модулі.
- Комітет Завдань Кіберпарламенту / parliament_tasker: Формувати AI-завдання для Кіберпарламенту і передавати їх через mining blocks.
- Комітет-Тестер / tester: Тестувати фінансовий модуль під екосистему власника: status, proof, queues, reports, бінарник, безпечність.

## Target

System: CYBRA Cold Finance Binary System
Binary: bin/cybra-finance-bin

## Current state

Binary exists: True
Cold finance report exists: True
Payment requisites exists: True
KYBRA valid exists: True
Redis ping: True

## Queues

block_inbox: 0
parliament_queue: 0
parliament_failed: 0
task_block_mempool: 0
pool_mining_blocks: 4
task_blocks_mined: 4

## Rules

No private keys.
No seed phrase.
No automatic SWIFT.
No automatic external crypto transaction.
No automatic real payment.
All AI tasks go to mining blocks.
OWNER approval required.

## Double SHA

229830f31850f571927b50cb7fc0902003a6da0f58b6abc637528be49fad3dbe