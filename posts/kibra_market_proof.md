# KIBRA Market Proof

Status: KIBRA_MARKET_PROOF_REPORT
Timestamp: 2026-06-08T01:09:40+0300
Token: KIBRA

## Market

PRICE_USD_PER_KIBRA: 0.01
REAL_MARKET_CONFIRMED: True
VALID_SOURCES: 1
TOTAL_SOURCES: 2
LIQUIDITY_USD_TOTAL: 500.0
VOLUME_24H_USD_TOTAL: 100.0

## Evidence

- file: `data/kibra_market_proof/evidence/1780869814_REAL_PROVIDER_NAME_KIBRA_USDT.json`
  provider: REAL_PROVIDER_NAME
  pair: KIBRA/USDT
  price: 0.01
  liquidity: 500.0
  volume_24h: 100.0
  valid: True
  problems: none

- file: `data/kibra_market_proof/evidence/market_source_template.json`
  provider: PUT_REAL_PROVIDER_NAME_HERE
  pair: KIBRA/USDT
  price: 0
  liquidity: 0
  volume_24h: 0
  valid: False
  problems: price_not_positive, liquidity_too_low, volume_too_low, real_orderbook_or_pool_not_confirmed

## Safety

real_payment_now: False
automatic_SWIFT: False
automatic_external_tx: False
automatic_price_manipulation: False
mainnet_deploy_allowed: False
manual_OWNER_approval_required: True
price_must_be_evidence_based: True

## Double SHA

fb9923eb93e2776284da6e9eab7f8f3be5d0d60a8548dc4902be91ce5a147ec2