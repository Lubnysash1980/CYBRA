# KYBRA Valid Wallet Gateway

Status: kybra_valid_wallet_gateway_report_generated

## Web payment requisites

Payment system: KYBRA Valid Wallet Gateway
Valid ID: KYBRA-VALID-686B7F6432361516
Merchant ID: KYBRA-MERCHANT-55C26A020E73
Internal wallet address: kybra:2b8748e8a37adc94afc4efbc15f7d5b6876bcf95
Network: KYBRA_INTERNAL
Token: KIBRA

## Balance

Main blocks: 10
Task blocks: 40
Main KIBRA: 1000
Task KIBRA: 4000
Total mined KIBRA: 5000
Sent internal KIBRA: 0
Available KIBRA: 5000

Price USD/KIBRA: 0
Estimated USD if price confirmed: 0
Real market confirmed: False
Real sell now: false

## Destination wallet

Status: destination_wallet_set
To address: АДРЕСА_ОТРИМУВАЧА
Network: KYBRA_INTERNAL
Label: мій отримувач

## How to use

Set recipient public wallet:
bash kybra_valid.sh set-destination ADDRESS NETWORK LABEL

Create KIBRA transfer proposal:
bash kybra_valid.sh propose AMOUNT ADDRESS NETWORK MEMO

Approve only internal KYBRA transfer:
bash kybra_valid.sh approve-internal PROPOSAL_ID

## Rules

Do not enter private key or seed.
External transfer requires bridge/manual tx/OWNER approval.
Real car payment requires invoice, bank or PSP rail, liquidity, confirmed price, OWNER approval.

## Double SHA

028710155e6a3fcb5576dc50b39ccff082bc2315bebcafab00c7e1f4069366b9
