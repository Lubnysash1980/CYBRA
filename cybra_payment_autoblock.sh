#!/data/data/com.termux/files/usr/bin/bash
set -e
cd "$HOME/CYBRA"

echo "=== CYBRA PAYMENT REQUISITES AUTOBLOCK ==="

mkdir -p \
  parliament/departments/finance_department/payment_requisites_department \
  parliament/departments/cybra_finance_department/payment_requisites_department \
  data/cybra_payment_requisites/car_purchase \
  posts feeds proofs logs/cybra_payment_requisites runtime

# Redis
if command -v bash >/dev/null 2>&1 && [ -f cybra_redis_committee.sh ]; then
  bash cybra_redis_committee.sh ensure >/dev/null 2>&1 || true
fi

if ! redis-cli ping >/dev/null 2>&1; then
  redis-server --daemonize yes --bind 127.0.0.1 --port 6379 --dir "$HOME/CYBRA/runtime" --save "" --appendonly no >/dev/null 2>&1 || true
fi

sleep 1

python3 - <<'PY'
import json
import time
import hashlib
import subprocess
from pathlib import Path

ROOT = Path.home() / "CYBRA"

def sha(text):
    return hashlib.sha256(text.encode("utf-8")).hexdigest()

def dsha(text):
    return sha(sha(text))

def now_iso():
    return time.strftime("%Y-%m-%dT%H:%M:%S%z")

def save(path, text):
    p = ROOT / path
    p.parent.mkdir(parents=True, exist_ok=True)
    p.write_text(text, encoding="utf-8")

def save_json(path, obj):
    save(path, json.dumps(obj, ensure_ascii=False, indent=2))

def load_json(path, default=None):
    p = ROOT / path
    if not p.exists():
        return default if default is not None else {}
    try:
        return json.loads(p.read_text(encoding="utf-8"))
    except Exception:
        return default if default is not None else {}

def run(cmd):
    try:
        p = subprocess.run(cmd, cwd=ROOT, text=True, capture_output=True)
        return p.returncode, p.stdout.strip(), p.stderr.strip()
    except Exception as e:
        return 1, "", str(e)

def redis_len(key):
    code, out, err = run(["redis-cli", "LLEN", key])
    if code == 0 and out.strip().isdigit():
        return int(out.strip())
    return 0

def redis_lpush(key, obj):
    run(["redis-cli", "LPUSH", key, json.dumps(obj, ensure_ascii=False)])

def redis_hset(key, field, value):
    run(["redis-cli", "HSET", key, field, value])

def file_sha(path):
    p = ROOT / path
    if not p.exists():
        return None
    h = hashlib.sha256()
    with p.open("rb") as f:
        for chunk in iter(lambda: f.read(1024 * 1024), b""):
            h.update(chunk)
    return h.hexdigest()

department = {
    "department_id": "cybra_payment_requisites_department",
    "name": "CYBRA Payment Requisites Department",
    "parent_department": "finance_department",
    "status": "active",
    "mission": "Підготувати пакет реквізитів платника для автосалону, рахунку/фактури, bank/PSP оплати або оплати після законної конвертації KIBRA у фіат.",
    "rule": "Не створювати фейковий IBAN, фейковий банк або фейкову платіжну установу. Реальна оплата тільки через реальні bank/PSP реквізити, рахунок/фактуру, ліквідність і OWNER approval.",
    "payment_routes": [
        "BANK_FIAT_TRANSFER",
        "LICENSED_PSP",
        "DEALER_CRYPTO_ACCEPTANCE_IF_EXISTS",
        "TOKEN_TO_FIAT_AFTER_LIQUIDITY_AND_OWNER_APPROVAL"
    ],
    "blocked": [
        "fake_bank_details",
        "fake_iban",
        "fake_payment_provider",
        "automatic_real_payment",
        "automatic_token_sell",
        "payment_without_invoice",
        "payment_without_owner_approval"
    ],
    "manual_OWNER_approval_required": True
}

save_json("parliament/departments/finance_department/payment_requisites_department/department.json", department)
save_json("parliament/departments/cybra_finance_department/payment_requisites_department/department.json", department)

profile_path = "data/cybra_payment_requisites/payer_profile.json"
if not (ROOT / profile_path).exists():
    payment_system_id = "CYBRA-PAY-" + dsha(str(time.time()))[:16].upper()
    profile = {
        "status": "draft_not_ready_for_real_payment",
        "payment_system_id": payment_system_id,
        "payer_type": "personal_or_company",
        "payer_display_name": "",
        "payer_full_legal_name": "",
        "payer_tax_id_or_edrpou": "",
        "payer_address": "",
        "payer_phone": "",
        "payer_email": "",
        "bank": {
            "bank_name": "",
            "iban": "",
            "currency": "UAH",
            "swift_bic": "",
            "mfo_or_bank_code": ""
        },
        "psp": {
            "provider_name": "",
            "merchant_id": "",
            "account_id": "",
            "contract_number": ""
        },
        "crypto_acceptance": {
            "dealer_accepts_crypto": False,
            "network": "",
            "wallet_address": "",
            "token": "KIBRA",
            "note": "Only if dealer officially accepts crypto and issues invoice."
        },
        "token_funding_source": {
            "source": "KIBRA mined/accounting balance",
            "real_market_confirmed_required": True,
            "liquidity_required": True,
            "sell_or_conversion_now": False,
            "owner_approval_required": True
        },
        "real_payment_ready": False,
        "note": "Заповнити тільки реальні реквізити банку або PSP."
    }
    save_json(profile_path, profile)

invoice_path = "data/cybra_payment_requisites/car_purchase/invoice_request.json"
if not (ROOT / invoice_path).exists():
    invoice = {
        "status": "draft",
        "purpose": "Запит рахунку/фактури від автосалону для купівлі авто.",
        "dealer_name": "",
        "dealer_contact": "",
        "vehicle": {
            "brand": "",
            "model": "",
            "vin": "",
            "price": "",
            "currency": "UAH"
        },
        "needed_from_dealer": [
            "рахунок/фактура",
            "договір купівлі-продажу або замовлення",
            "реквізити отримувача",
            "призначення платежу",
            "термін дії рахунку",
            "умови повернення/скасування",
            "акт/документи передачі авто"
        ],
        "payment_from_cybra": {
            "route": "tokens_to_fiat_then_bank_or_psp_payment",
            "real_payment_now": False,
            "owner_approval_required": True
        }
    }
    save_json(invoice_path, invoice)

def validate(profile):
    errors = []
    warnings = []

    payer_name = profile.get("payer_full_legal_name") or profile.get("payer_display_name")
    if not payer_name:
        errors.append("Не заповнено legal/display name платника")

    if not profile.get("payer_tax_id_or_edrpou"):
        warnings.append("Не заповнено tax_id_or_edrpou")

    bank = profile.get("bank", {})
    psp = profile.get("psp", {})
    crypto = profile.get("crypto_acceptance", {})

    iban = str(bank.get("iban", "")).replace(" ", "")
    bank_ready = bool(bank.get("bank_name") and iban)
    psp_ready = bool(psp.get("provider_name") and (psp.get("merchant_id") or psp.get("account_id")))
    crypto_ready = bool(crypto.get("dealer_accepts_crypto") and crypto.get("wallet_address") and crypto.get("network"))

    if iban and not (iban.startswith("UA") and len(iban) == 29):
        warnings.append("IBAN не схожий на український UA IBAN довжиною 29 символів. Перевір вручну.")

    if not bank_ready and not psp_ready and not crypto_ready:
        errors.append("Нема реального платіжного каналу: bank IBAN / PSP / офіційне crypto acceptance автосалону")

    return {
        "ready": len(errors) == 0,
        "bank_ready": bank_ready,
        "psp_ready": psp_ready,
        "crypto_ready": crypto_ready,
        "errors": errors,
        "warnings": warnings
    }

profile = load_json(profile_path, {})
invoice = load_json(invoice_path, {})
validation = validate(profile)

mined = load_json("feeds/kibra_mined_money_report.json", {})
mined_info = mined.get("mined", {})
market_info = mined.get("market", {})

package = {
    "status": "ready_for_invoice_package" if validation["ready"] else "not_ready_missing_real_requisites",
    "time": time.time(),
    "time_iso": now_iso(),
    "payer_profile": profile,
    "validation": validation,
    "car_invoice_request": invoice,
    "funding_plan": {
        "source": "KIBRA tokens / mined accounting / liquidity plan",
        "token_to_fiat_required_if_dealer_requires_bank_payment": True,
        "real_market_price_required": True,
        "liquidity_or_buyer_required": True,
        "real_sell_now": False,
        "real_payment_now": False,
        "owner_approval_required": True
    },
    "mined_money": {
        "total_mined_kibra": mined_info.get("total_mined_kibra", "0"),
        "confirmed_market_usd": market_info.get("confirmed_market_usd", "0"),
        "price_usd_per_kibra": market_info.get("price_usd_per_kibra", "0"),
        "real_sell_now": False
    },
    "queues": {
        "block_inbox": redis_len("cybra:ai:tasks:block_inbox"),
        "parliament_queue": redis_len("cybra:parliament:queue"),
        "parliament_failed": redis_len("cybra:parliament:failed"),
        "task_block_mempool": redis_len("cybra:kibra:task_blocks:mempool")
    },
    "safety": {
        "fake_bank_details": False,
        "fake_iban": False,
        "automatic_real_payment": False,
        "automatic_token_sell": False,
        "manual_OWNER_approval_required": True
    }
}

package["double_sha"] = dsha(json.dumps(package, ensure_ascii=False, sort_keys=True))

save_json("data/cybra_payment_requisites/payment_package.json", package)
save_json("feeds/cybra_payment_requisites_package.json", package)

dealer_text = f"""ЗАПИТ ДО АВТОСАЛОНУ ЩОДО РАХУНКУ / ФАКТУРИ

Просимо надати офіційний рахунок/фактуру для купівлі автомобіля.

Платник:
Назва / ПІБ: {profile.get('payer_full_legal_name') or profile.get('payer_display_name') or 'НЕ ЗАПОВНЕНО'}
ІПН / ЄДРПОУ: {profile.get('payer_tax_id_or_edrpou') or 'НЕ ЗАПОВНЕНО'}
Адреса: {profile.get('payer_address') or 'НЕ ЗАПОВНЕНО'}
Телефон: {profile.get('payer_phone') or 'НЕ ЗАПОВНЕНО'}
Email: {profile.get('payer_email') or 'НЕ ЗАПОВНЕНО'}

Платіжна система:
CYBRA Payment System ID: {profile.get('payment_system_id')}
Статус: внутрішній ID системи, не є банківським IBAN.

Банківські/PSP реквізити платника:
Банк: {profile.get('bank', {}).get('bank_name') or 'НЕ ЗАПОВНЕНО'}
IBAN: {profile.get('bank', {}).get('iban') or 'НЕ ЗАПОВНЕНО'}
Валюта: {profile.get('bank', {}).get('currency') or 'UAH'}
PSP: {profile.get('psp', {}).get('provider_name') or 'НЕ ЗАПОВНЕНО'}
PSP merchant/account: {profile.get('psp', {}).get('merchant_id') or profile.get('psp', {}).get('account_id') or 'НЕ ЗАПОВНЕНО'}

Автомобіль:
Бренд: {invoice.get('vehicle', {}).get('brand') or 'НЕ ЗАПОВНЕНО'}
Модель: {invoice.get('vehicle', {}).get('model') or 'НЕ ЗАПОВНЕНО'}
VIN: {invoice.get('vehicle', {}).get('vin') or 'НЕ ЗАПОВНЕНО'}
Сума: {invoice.get('vehicle', {}).get('price') or 'НЕ ЗАПОВНЕНО'} {invoice.get('vehicle', {}).get('currency') or 'UAH'}

Просимо надати:
1. Офіційний рахунок/фактуру.
2. Реквізити отримувача.
3. Призначення платежу.
4. Договір або замовлення.
5. Термін дії рахунку.
6. Умови повернення/скасування.
7. Документи передачі авто.

Важливо:
Реальна оплата буде можлива тільки після перевірки рахунку, реквізитів отримувача та OWNER approval.
"""

save("posts/car_dealer_invoice_request.txt", dealer_text)

report = f"""# CYBRA Payment Requisites Package

Status: {package['status']}

## Платник

Payment System ID: {profile.get('payment_system_id')}
Payer type: {profile.get('payer_type')}
Legal name: {profile.get('payer_full_legal_name') or 'NOT_FILLED'}
Display name: {profile.get('payer_display_name') or 'NOT_FILLED'}
Tax ID / EDRPOU: {profile.get('payer_tax_id_or_edrpou') or 'NOT_FILLED'}
Address: {profile.get('payer_address') or 'NOT_FILLED'}
Phone: {profile.get('payer_phone') or 'NOT_FILLED'}
Email: {profile.get('payer_email') or 'NOT_FILLED'}

## Bank / PSP

Bank name: {profile.get('bank', {}).get('bank_name') or 'NOT_FILLED'}
IBAN: {profile.get('bank', {}).get('iban') or 'NOT_FILLED'}
Currency: {profile.get('bank', {}).get('currency') or 'UAH'}
PSP provider: {profile.get('psp', {}).get('provider_name') or 'NOT_FILLED'}
PSP merchant/account: {profile.get('psp', {}).get('merchant_id') or profile.get('psp', {}).get('account_id') or 'NOT_FILLED'}

## Готовність

Ready for invoice/payment details: {validation['ready']}
Bank ready: {validation['bank_ready']}
PSP ready: {validation['psp_ready']}
Dealer crypto acceptance ready: {validation['crypto_ready']}

Errors:
{json.dumps(validation['errors'], ensure_ascii=False, indent=2)}

Warnings:
{json.dumps(validation['warnings'], ensure_ascii=False, indent=2)}

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

Total mined KIBRA: {package['mined_money']['total_mined_kibra']}
Confirmed market USD: {package['mined_money']['confirmed_market_usd']}
Price USD/KIBRA: {package['mined_money']['price_usd_per_kibra']}
Real sell now: false

## Double SHA

{package['double_sha']}
"""

save("posts/cybra_payment_requisites_package.md", report)

with (ROOT / "proofs/cybra_payment_requisites_package.sha256").open("w") as f:
    subprocess.run([
        "sha256sum",
        "parliament/departments/finance_department/payment_requisites_department/department.json",
        "data/cybra_payment_requisites/payer_profile.json",
        "data/cybra_payment_requisites/car_purchase/invoice_request.json",
        "feeds/cybra_payment_requisites_package.json",
        "posts/cybra_payment_requisites_package.md",
        "posts/car_dealer_invoice_request.txt"
    ], cwd=ROOT, stdout=f, stderr=subprocess.DEVNULL)

redis_lpush("cybra:finance:payment_requisites:audit", {
    "status": package["status"],
    "ready": validation["ready"],
    "double_sha": package["double_sha"],
    "time": package["time"]
})

ai_task = {
    "topic": "CYBRA payment requisites and car invoice package",
    "type": "cybra_payment_requisites_task",
    "priority": "critical",
    "payload": {
        "source": "cybra_payment_requisites_department",
        "goal": "Підготувати реальні реквізити платника для автосалону, отримати рахунок/фактуру, створити план оплати через bank/PSP після OWNER approval.",
        "package_status": package["status"],
        "ready": validation["ready"],
        "errors": validation["errors"],
        "payment_package_sha": package["double_sha"],
        "convert_to_mining_block_first": True,
        "real_payment_now": False,
        "real_token_sell_now": False,
        "manual_OWNER_approval_required": True
    }
}
redis_lpush("cybra:ai:tasks:block_inbox", ai_task)

redis_hset("cybra:executor:mapping", "cybra_payment_requisites_task", "cybra_payment_requisites_handler.sh")

print("✅ CYBRA payment requisites package generated")
print("STATUS:", package["status"])
print("READY:", validation["ready"])
print("REPORT: posts/cybra_payment_requisites_package.md")
print("DEALER_TEXT: posts/car_dealer_invoice_request.txt")
print("PROOF: proofs/cybra_payment_requisites_package.sha256")
PY

cat > cybra_payment_requisites.sh <<'EOF'
#!/data/data/com.termux/files/usr/bin/bash
set -e
cd "$HOME/CYBRA"

case "${1:-status}" in
  edit)
    nano data/cybra_payment_requisites/payer_profile.json
    ;;
  edit-car)
    nano data/cybra_payment_requisites/car_purchase/invoice_request.json
    ;;
  report)
    bash cybra_payment_autoblock.sh
    cat posts/cybra_payment_requisites_package.md
    ;;
  dealer)
    cat posts/car_dealer_invoice_request.txt
    ;;
  status)
    test -f data/cybra_payment_requisites/payer_profile.json && echo "PROFILE=exists" || echo "PROFILE=missing"
    test -f posts/cybra_payment_requisites_package.md && echo "REPORT=exists" || echo "REPORT=missing"
    echo "PAYMENT_AUDIT=$(redis-cli LLEN cybra:finance:payment_requisites:audit 2>/dev/null || echo 0)"
    echo "BLOCK_INBOX=$(redis-cli LLEN cybra:ai:tasks:block_inbox 2>/dev/null || echo 0)"
    ;;
  proof)
    cat proofs/cybra_payment_requisites_package.sha256
    ;;
  *)
    echo "Usage:"
    echo "  bash cybra_payment_requisites.sh edit"
    echo "  bash cybra_payment_requisites.sh edit-car"
    echo "  bash cybra_payment_requisites.sh report"
    echo "  bash cybra_payment_requisites.sh dealer"
    echo "  bash cybra_payment_requisites.sh status"
    ;;
esac
EOF

chmod +x cybra_payment_requisites.sh

cat > cybra_payment_requisites_handler.sh <<'EOF'
#!/data/data/com.termux/files/usr/bin/bash
set -e
cd "$HOME/CYBRA"

bash cybra_payment_autoblock.sh >/dev/null 2>&1 || true
bash cybra_closed_sha_bridge.sh cycle >/dev/null 2>&1 || true
EOF

chmod +x cybra_payment_requisites_handler.sh

python3 - <<'PY'
from pathlib import Path

p = Path("parliament_executor_v6.py")
if p.exists():
    s = p.read_text(encoding="utf-8")

    if 'r.hget("cybra:executor:mapping", task_type)' not in s:
        old = "script_name = SCRIPT_MAP.get(task_type)"
        new = 'script_name = r.hget("cybra:executor:mapping", task_type) or SCRIPT_MAP.get(task_type)'
        if old in s:
            s = s.replace(old, new, 1)

    if '"cybra_payment_requisites_task"' not in s:
        i = s.find("SCRIPT_MAP")
        j = s.find("{", i)
        if i >= 0 and j >= 0:
            s = s[:j+1] + '\n    "cybra_payment_requisites_task": "cybra_payment_requisites_handler.sh",' + s[j+1:]

    p.write_text(s, encoding="utf-8")
    print("✅ parliament executor patched")
else:
    print("⚠ parliament_executor_v6.py missing")
PY

rm -rf __pycache__
test -f parliament_executor_v6.py && python3 -m py_compile parliament_executor_v6.py || true
rm -rf __pycache__

sha256sum -c proofs/cybra_payment_requisites_package.sha256 || true

echo
echo "=== STATUS ==="
bash cybra_payment_requisites.sh status

echo
echo "✅ CYBRA PAYMENT AUTOBLOCK DONE"
