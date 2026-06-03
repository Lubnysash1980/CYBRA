# CYBRA AutoHeal 7 Sealed Levels

Status: active

## Systems
AUTOHEAL_ALPHA repairs AUTOHEAL_BETA
AUTOHEAL_BETA repairs AUTOHEAL_ALPHA
SEAL_DISPATCHER distributes tasks

## Levels
L1_REDIS_HEALTH: ok=True bad=[]
L2_BINARY_HEALTH: ok=True bad=[]
L3_FINANCE_DATA_HEALTH: ok=True bad=[]
L4_WALLET_REQUISITES_HEALTH: ok=True bad=[]
L5_PARLIAMENT_TASK_HEALTH: ok=True bad=[]
L6_MARKET_SAFETY_HEALTH: ok=True bad=[]
L7_SEAL_DISPATCHER_HEALTH: ok=False bad=['autoheal_report_first_run_or_missing']

## Queues
audit: 1
repair_queue: 0
seal_queue: 1
block_inbox: 0
task_block_mempool: 0
pool_mining_blocks: 0
parliament_queue: 0
parliament_failed: 0

## Seal
200fd96ee420c7893494306b2e4b7e0d8a554e27e30d77d433c378fe68ce509a

## Safety
private_keys: false
seed_phrase: false
automatic_real_payment: false
automatic_external_tx: false
OWNER approval required: true

## Double SHA
64e1b8347e7b9eb9f778808571b4344105a44ac452b8b7dc7e1767811a5ea309