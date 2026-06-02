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
- Finance ledger: 17
- Finance audit: 37

## Proof

Double SHA:

`7ed1726bdadc0aaf095d79d1c1bfaa3460345568dae61d474e9f788b26073e9e`

## Files

- `parliament/finance/infrastructure/finance_infrastructure_policy.json`
- `payments/rails/payment_rails.json`
- `token/kibra/mint/kibra_mint_policy.json`
- `treasury/gold/gold_treasury_policy.json`
- `feeds/finance_infrastructure_report.json`
- `posts/finance_infrastructure_report.md`
- `proofs/finance_infrastructure.sha256`
