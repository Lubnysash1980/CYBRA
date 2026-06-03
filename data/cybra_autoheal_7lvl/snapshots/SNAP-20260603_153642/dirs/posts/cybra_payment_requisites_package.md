# CYBRA Payment Requisites Package

Status: not_ready_missing_real_requisites

## Платник

Payment System ID: CYBRA-PAY-541883964C95E7EC
Payer type: personal_or_company
Legal name: NOT_FILLED
Display name: NOT_FILLED
Tax ID / EDRPOU: NOT_FILLED
Address: NOT_FILLED
Phone: NOT_FILLED
Email: NOT_FILLED

## Bank / PSP

Bank name: NOT_FILLED
IBAN: NOT_FILLED
Currency: UAH
PSP provider: NOT_FILLED
PSP merchant/account: NOT_FILLED

## Готовність

Ready for invoice/payment details: False
Bank ready: False
PSP ready: False
Dealer crypto acceptance ready: False

Errors:
[
  "Не заповнено legal/display name платника",
  "Нема реального платіжного каналу: bank IBAN / PSP / офіційне crypto acceptance автосалону"
]

Warnings:
[
  "Не заповнено tax_id_or_edrpou"
]

## Для автосалону

Готовий текст:
posts/car_dealer_invoice_request.txt

## Маршрут оплати

1. Отримати рахунок/фактуру від автосалону.
2. Перевірити реквізити отримувача.
3. Перевірити реальні реквізити платника: bank IBAN або PSP.
4. Якщо оплата з KIBRA/tokens: потрібна ліквідність, підтвердження ціни, sell proposal.
5. Після OWNER approval: fiat bank/PSP payment.
6. Реальна оплата зараз: false.

## KIBRA funding state

Total mined KIBRA: 3300
Confirmed market USD: 33.00
Price USD/KIBRA: 0.01
Real sell now: false

## Double SHA

b024e563ee67ea5757a6fba680f68668a8eae2949a2b33d41814a1b3467a0c98
