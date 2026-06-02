# CYBRA Finance Infrastructure

Status: **active**  
Mode: proposal ledger + manual execution

## Included

- Token mint / монетний двір токенів: **proposal only**
- Multipayment rails: **proposal only**
- IBAN: **masked only, manual provider execution**
- Cards: **PSP token only, no PAN/CVV/PIN storage**
- Gold treasury / XAU accounting: **proposal only**
- Multi-currency calculations: **automatic**
- Real transfers: **manual OWNER approval only**

## Hard limits

- Real payment execution: **false**
- Automatic bank transfer: **false**
- Automatic card charge: **false**
- Automatic gold purchase: **false**
- Automatic token mint: **false**
- Automatic FX conversion: **false**

## Supported calculation currencies

- UAH
- USD
- EUR
- PLN
- GBP
- USDT
- BTC
- SOL
- KIBRA
- XAU

## Redis

- Mint proposals: 1
- Payment proposals: 1
- Gold proposals: 1
- Finance ledger: 19
- Finance audit: 40

## Proof

Double SHA:

`11e7ce14d2fbdd9f2d3c8fc25e0504f5d64c29db89fd620057810515798c6b6b`

## Files

- `parliament/finance/infrastructure/finance_infrastructure_policy.json`
- `payments/rails/payment_rails.json`
- `token/kibra/mint/kibra_mint_policy.json`
- `treasury/gold/gold_treasury_policy.json`
- `feeds/finance_infrastructure_report.json`
- `posts/finance_infrastructure_report.md`
- `proofs/finance_infrastructure.sha256`
