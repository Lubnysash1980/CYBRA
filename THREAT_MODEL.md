# CYBRA v1 — Threat Model

## Scope

CYBRAEscrow.sol поверх CYBRAResponsibilityContract.sol.
CYBRAP2PPurchase.sol (ERC-20 escrow).

Це не юридична гарантія стягнення. Контракти реалізують
заздалегідь визначене правило розподілу депонованого активу
на основі сигналів, які самі сторони подають у мережі.

## Trust assumptions

- Responsibility core immutable для escrow.
- Arbiter — довірена роль. У v1 це EOA.
- Покупець самостійно підтверджує відповідність invoiceHash
  документу рахунку. Контракт не перевіряє вміст PDF.
- Event Controller має лише прапорець ONLINE/OFFLINE.

## Trust model по контрактах

### Сильна модель (multi-party)
- CYBRAResponsibilityContract — buyer + seller + controller
- CYBRAEscrow — buyer + seller + arbiter + immutable timeout
- CYBRAP2PPurchase — parliament + buyer + seller (mutual signatures)

### Single-key модель (централізоване схвалення)
Ці контракти мають onlyOwner/onlyAuthority без timelock:
- CYBRABinaryMixerLicense (onlyAuthority)
- CYBRADualLicenseRoyalty15 (onlyAuthority + 2 verifiers)
- CYBRAExoskeletonAIParliament (owner + verifier)
- CYBRALevelController (onlyAuthority)
- CYBRARefundClaim (owner + verifiers)
- CYBRASelfLearning (owner + verifier)
- CYBRASelfLearningV2 (owner + verifier)

Це архітектурне рішення, а не баг. Один ключ керує
схваленням. Компроміс ключа = компроміс контракту.
Заміна на multisig/timelock — окремий versioned реліз.

## RESPONSIBILITY_ID

Escrow перевіряє responsibility.RESPONSIBILITY_ID() проти
власної EXPECTED_RESPONSIBILITY_ID у конструкторі.

Це ABI/version binding, НЕ authentication mechanism.

Захищає від: випадкової помилкової конфігурації, підключення
невідповідної версії.

Не захищає від: навмисно задеплоєного fake з правильним ID.
Deployer verification — trust boundary.

## Forced ETH invariant

depositedAmount — єдина база розрахунку. Встановлюється один
раз у deposit(), не змінюється ніколи.

ETH, примусово надісланий (selfdestruct, coinbase,
pre-funding), не входить в accounting і не розподіляється.
Надлишок залишається на контракті назавжди. Свідомий trade-off.

## P2PPurchase — USDT compatibility

v1.0.1: transfer/transferFrom виконуються через low-level
_safeTransfer/_safeTransferFrom. Приймають:
- порожню відповідь (USDT-style);
- bool true.
Ревертять на: bool false, будь-який revert.

Фіксовано тестами: usdtStyle_fund, usdtStyle_releaseToSeller,
falseReturningToken_revert.

## Safety properties (proof by test)

- Продавець не отримує кошти без TRUE_100 або рішення arbiter.
- Покупець не отримує кошти без рішення arbiter або timeout.
- Кошти не можуть застрягти назавжди: timeout refund permissionless.
- Обидва виходи одноразові.
- Сума завжди дорівнює depositedAmount.
- Контракт без RESPONSIBILITY_ID відсікається в конструкторі.
- Контракт із чужим RESPONSIBILITY_ID відсікається.
- Forced ETH не змінює payout.
- P2PPurchase fund/releaseToSeller/refund мають nonReentrant.
- P2PPurchase працює з USDT-style токенами.

## Known limitations (v1)

1. Timeout refund — safety fallback, не доказ права покупця.
2. Partial settlement не підтримується.
3. verifiedExpenseAmount з ядра escrow НЕ читає.
4. Ротація arbiter не вбудована.
5. Немає механізму forced upgrade. Контракт immutable.
6. RESPONSIBILITY_ID не є authentication.
7. Forced excess ETH залишається на контракті назавжди.
8. 7 контрактів мають single-key модель без timelock.

## Intentional out of scope

- CYBRASplitSettlement (часткові виплати);
- CYBRAArbiterGovernance (ротація, multisig);
- CYBRAEscrowERC20 (окремий від P2PPurchase);
- повернення forced excess ETH;
- юридична кваліфікація рішення arbiter.

## Failure modes

Втрата arbiter-ключа:
    Не блокує кошти. Після settlementTimeout — permissionless
    settleToBuyer().

Втрата parliament-ключа (P2PPurchase):
    createAgreement() стає недоступним. Існуючі угоди
    завершуються штатно.

Відмова покупця підтвердити або відхилити (Responsibility):
    Стан CONFIRMATION_REQUIRED назавжди. Escrow залишається
    FUNDED. Це свідомо.
