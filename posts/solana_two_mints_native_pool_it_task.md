# IT Task: Two Solana Mints + Native Token + Pool

Status: IT_TASK_TWO_SOLANA_MINTS_NATIVE_TOKEN_POOL_CREATED  
Timestamp: 2026-06-08T02:51:43+0300

## Mints

ALEX mint: `BNhNw6waDiEobccELrZ483aYEqFRzYGwwHB6DLk5VnFr`  
EFI mint: `EfiCgx3svRwZ1voPXsnYdZo35kzyt5Ct7UHLuvnm6fcR`  
Native KIBRA token mint: `F5zxQyxq8qWdyauN8ArPofkKKVFxbeTAWSd1oeyazfeU`  
USDC mint: `EPjFWdd5AufqSSqeM2qN1xzybapC8G4wEGGkZwyTDt1v`  

## Pool target

Pairs:

- ALEX/USDC
- EFI/USDC

Base tokens: 32000  
Target USDC: 2000000  
Target price reference: 62.5 USD/token  

Base raw: 32000000000000  
USDC raw: 2000000000000

## IT tasks

- Prepare ALEX/USDC safe pool plan.
- Prepare EFI/USDC safe pool plan.
- Attach native KIBRA NFT-proof.
- Require clean RPC before blockchain proof.
- Require owner balance check before live transaction.
- Keep live DEX creation disabled.

## Safety

real_payment_now: false  
automatic_external_tx: false  
automatic_price_manipulation: false  
mainnet_deploy_allowed: false  
real_mainnet_tx_executed: false  
real_market_confirmed: false  
live_dex_create: false  
manual_OWNER_approval_required: true  

## Double SHA

36f0a9e20a7ffba20a6d8ff19b223dea75fb5c3b236867dd4d7e65ce8049178a
