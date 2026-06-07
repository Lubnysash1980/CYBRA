# CYBRA Payment Requisites Package

Status: not_ready_missing_real_requisites

## Платник

Payment System ID: CYBRA-PAY-541883964C95E7EC
Payer type: personal_or_company
Legal name: Грабовський Олександр Миколайович
Display name: Грабовський Олександр Миколайович
Tax ID / EDRPOU: 2937******
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
  "Нема реального платіжного каналу: bank IBAN / PSP / офіційне crypto acceptance автосалону"
]

Warnings:
[]

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

327b3d8ea55d6ccf5f61f51b3f85080391d7ea57b851ba5c6bd5a64f1337e29e
