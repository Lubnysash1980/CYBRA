# KIBRA Real Market Price Gate

Status: **real_market_price_not_confirmed**

## Verification

- Verified: **False**
- Real market confirmed: **False**
- Provider: ``
- Pair: `KIBRA/USD`
- Method: `none`
- Price USD/KIBRA: **0**

## Required proof

- Pool proof / orderbook proof / provider proof
- Provider review passed: **False**
- OWNER approval: **False**
- Real sell now: **false**

## Errors

`['provider_name порожній', 'нема proof_source або proof_reference', 'нема коректних резервів або bid/ask для розрахунку ціни', 'provider_review_passed має бути true', 'owner_approval має бути true']`

## Rule

Без real pool/orderbook/provider proof ціна не підтверджується як ринкова.  
Reference price може існувати тільки для внутрішнього обліку.

## Double SHA

`537fcf026a0313544ba03611b62db4314b4204d12d54e616361df96f4d1388a2`
