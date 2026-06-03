# CYBRA Cold Finance Binary System

Status: cybra_cold_finance_binary_report_generated

## Web payment requisites

System name: CYBRA Cold Payment System
Valid ID: CYBRA-COLD-FIN-6D484C54BB3C5575
Merchant ID: CYBRA-MERCHANT-1EB196021A0A
Internal wallet: kybra:c702a1b6d36314a0ad58995701d1b0e92c8a3eaa
Network: KYBRA_INTERNAL
Asset: KIBRA

## Balance

Main blocks: 10
Task blocks: 40
Total mined KIBRA: 5000
Reserved KIBRA: 0
Internal sent KIBRA: 0
Available KIBRA: 5000

Price USD/KIBRA: 0
Estimated USD if confirmed: 0
Real market confirmed: False

## Payment rails

KYBRA_INTERNAL: internal ledger/proposal.
SWIFT: bank instruction draft only.
BANK_IBAN: bank instruction draft only.
PSP: licensed provider instruction draft only.
COLD_WALLET: public wallet registry and manual external tx proposal.

## Commands

cybra-finance-bin status
cybra-finance-bin add-wallet NETWORK ADDRESS LABEL
cybra-finance-bin add-recipient ID NAME RAIL ACCOUNT CURRENCY
cybra-finance-bin verify-recipient ID PROOF_REFERENCE
cybra-finance-bin propose RECIPIENT_ID AMOUNT CURRENCY PURPOSE
cybra-finance-bin swift-template PROPOSAL_ID
cybra-finance-bin task
cybra-finance-bin mine

## Safety

No private keys.
No seed phrase.
No automatic SWIFT.
No automatic external crypto transaction.
No automatic real payment.
OWNER approval required.

## Double SHA

54b0d8d0657045769ab9db592804130fbcbb7f09c462022fd36cebb71314cf6a
