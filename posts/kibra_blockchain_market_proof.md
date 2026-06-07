# KIBRA Blockchain Market Proof

Status: KIBRA_BLOCKCHAIN_MARKET_PROOF
Timestamp: 2026-06-08T01:09:58+0300
Chain: solana

## Market

PRICE_USD_PER_KIBRA: 0
REAL_MARKET_CONFIRMED: False
VALID_BLOCKCHAIN_SOURCES: 0
TOTAL_BLOCKCHAIN_SOURCES: 2
LIQUIDITY_USD_ESTIMATED_TOTAL: 0

## Sources

- file: `data/kibra_blockchain_market_proof/evidence/1780870175_KIBRA_USDC_POOL.json`
  name: KIBRA_USDC_POOL
  pool: PUT_REAL_POOL_ADDRESS_HERE
  base_vault_amount: None
  quote_vault_amount: None
  price_usd_per_kibra: None
  liquidity_usd_estimated: None
  valid: False
  problems: missing_base_mint, missing_base_vault, missing_quote_vault, missing_pool_address, missing_source_url

- file: `data/kibra_blockchain_market_proof/evidence/pool_template.json`
  name: KIBRA_USDC_POOL_EXAMPLE
  pool: PUT_REAL_POOL_ADDRESS_HERE
  base_vault_amount: None
  quote_vault_amount: None
  price_usd_per_kibra: None
  liquidity_usd_estimated: None
  valid: False
  problems: missing_base_mint, missing_base_vault, missing_quote_vault, missing_pool_address, missing_source_url

## Safety

real_payment_now: False
automatic_SWIFT: False
automatic_external_tx: False
automatic_price_manipulation: False
mainnet_deploy_allowed: False
manual_OWNER_approval_required: True
price_must_be_evidence_based: True

## Double SHA
453e6489ac5adbcd6c266d31053c2e85eee699cbcf324c1bce57d429c9a8cce6