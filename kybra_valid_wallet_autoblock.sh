#!/data/data/com.termux/files/usr/bin/bash
set -e
cd "$HOME/CYBRA"

echo "=== KYBRA VALID WALLET GATEWAY AUTOBLOCK ==="

mkdir -p \
  parliament/departments/finance_department/kybra_valid_wallet_department \
  parliament/departments/cybra_finance_department/kybra_valid_wallet_department \
  data/kybra_valid/proposals \
  data/kybra_valid/transfers \
  posts feeds proofs logs/kybra_valid runtime/redis runtime

if ! command -v redis-server >/dev/null 2>&1; then
  pkg update -y || true
  pkg install -y redis || true
fi

if [ -f cybra_redis_committee.sh ]; then
  bash cybra_redis_committee.sh ensure >/dev/null 2>&1 || true
fi

if ! redis-cli ping >/dev/null 2>&1; then
  redis-server --daemonize yes --bind 127.0.0.1 --port 6379 --dir "$HOME/CYBRA/runtime/redis" --save "" --appendonly no >/dev/null 2>&1 || true
fi

sleep 1

python3 - <<'PY'
import sys, subprocess
try:
    import redis
except Exception:
    subprocess.check_call([sys.executable, "-m", "pip", "install", "redis"])
PY

cat > parliament/departments/finance_department/kybra_valid_wallet_department/department.json <<'JSON'
{
  "department_id": "kybra_valid_wallet_department",
  "name": "KYBRA Valid Wallet Gateway",
  "parent_department": "finance_department",
  "status": "active",
  "mission": "Створити внутрішній valid/wallet для KYBRA, реквізити веб-платіжної системи, облік намайнених KIBRA і proposal-механізм для переказів.",
  "rules": [
    "Не просити private key, seed phrase, CVV або банківські паролі.",
    "Публічна адреса отримувача може бути записана як destination wallet.",
    "Внутрішній переказ KIBRA можливий тільки як ledger/proposal у системі KYBRA.",
    "Зовнішній переказ або оплата авто можливі тільки після bridge/liquidity/price proof/OWNER approval.",
    "Усі AI-завдання йдуть через mining blocks."
  ],
  "outputs": [
    "valid_wallet",
    "web_payment_requisites",
    "balance_report",
    "transfer_proposal",
    "internal_ledger",
    "AI tasks to block inbox",
    "sha256 proof"
  ],
  "blocked": [
    "private_keys",
    "seed_phrase",
    "automatic_external_tx",
    "automatic_real_payment",
    "automatic_token_sell",
    "fake_balance",
    "fake_price"
  ],
  "manual_OWNER_approval_required": true
}
JSON

cp parliament/departments/finance_department/kybra_valid_wallet_department/department.json \
   parliament/departments/cybra_finance_department/kybra_valid_wallet_department/department.json 2>/dev/null || true

cat > kybra_valid_gateway.py <<'PY'
#!/usr/bin/env python3
import json
import time
import hashlib
import subprocess
from decimal import Decimal, getcontext
from pathlib import Path

import redis

getcontext().prec = 50

ROOT = Path.home() / "CYBRA"
DATA = ROOT / "data/kybra_valid"

AUDIT = "cybra:kybra_valid:audit"
PROPOSALS_Q = "cybra:kybra_valid:transfer_proposals"
AI_BLOCK_INBOX = "cybra:ai:tasks:block_inbox"

def sha(text):
    return hashlib.sha256(text.encode("utf-8")).hexdigest()

def dsha(text):
    return sha(sha(text))

def now_iso():
    return time.strftime("%Y-%m-%dT%H:%M:%S%z")

def rds():
    return redis.Redis(host="127.0.0.1", port=6379, decode_responses=True)

def redis_len(key):
    try:
        return rds().llen(key)
    except Exception:
        return 0

def redis_lpush(key, obj):
    try:
        rds().lpush(key, json.dumps(obj, ensure_ascii=False))
    except Exception:
        pass

def redis_hset(key, field, value):
    try:
        rds().hset(key, field, value)
    except Exception:
        pass

def save_json(path, obj):
    p = ROOT / path
    p.parent.mkdir(parents=True, exist_ok=True)
    p.write_text(json.dumps(obj, ensure_ascii=False, indent=2), encoding="utf-8")

def load_json(path, default=None):
    p = ROOT / path
    if not p.exists():
        return default if default is not None else {}
    try:
        return json.loads(p.read_text(encoding="utf-8"))
    except Exception:
        return default if default is not None else {}

def file_sha(path):
    p = ROOT / path
    if not p.exists():
        return None
    h = hashlib.sha256()
    with p.open("rb") as f:
        for c in iter(lambda: f.read(1024 * 1024), b""):
            h.update(c)
    return h.hexdigest()

def run(cmd):
    try:
        p = subprocess.run(cmd, cwd=ROOT, text=True, capture_output=True)
        return p.returncode, p.stdout.strip(), p.stderr.strip()
    except Exception as e:
        return 1, "", str(e)

def git_cmd(cmd):
    code, out, err = run(cmd)
    return out if code == 0 else ""

def count_files(pattern):
    return len(list(ROOT.glob(pattern)))

def dec(x):
    try:
        return Decimal(str(x))
    except Exception:
        return Decimal("0")

def wallet_default():
    seed = dsha(str(time.time()) + str(ROOT))
    valid_id = "KYBRA-VALID-" + seed[:16].upper()
    internal_address = "kybra:" + dsha(valid_id)[:40]
    merchant_id = "KYBRA-MERCHANT-" + dsha(internal_address)[:12].upper()

    return {
        "status": "active_internal_valid_wallet",
        "valid_id": valid_id,
        "wallet_type": "KYBRA_INTERNAL_VALID",
        "internal_address": internal_address,
        "merchant_id": merchant_id,
        "display_name": "KYBRA Web Payment System",
        "public_requisites": {
            "network": "KYBRA_INTERNAL",
            "token": "KIBRA",
            "accepted_token": "KIBRA",
            "payment_system": "KYBRA Valid Wallet Gateway",
            "internal_address": internal_address,
            "merchant_id": merchant_id
        },
        "external_wallets": [],
        "security": {
            "private_key_stored": False,
            "seed_phrase_required": False,
            "public_address_only": True
        },
        "real_external_tx_now": False,
        "manual_OWNER_approval_required": True,
        "created_at": time.time(),
        "created_at_iso": now_iso()
    }

def init():
    DATA.mkdir(parents=True, exist_ok=True)
    (DATA / "proposals").mkdir(parents=True, exist_ok=True)
    (DATA / "transfers").mkdir(parents=True, exist_ok=True)

    if not (ROOT / "data/kybra_valid/wallet.json").exists():
        save_json("data/kybra_valid/wallet.json", wallet_default())

    if not (ROOT / "data/kybra_valid/destination_wallet.json").exists():
        save_json("data/kybra_valid/destination_wallet.json", {
            "status": "empty",
            "to_address": "",
            "network": "KYBRA_INTERNAL",
            "label": "",
            "note": "Сюди можна вписати public wallet/address отримувача. Не seed/private key.",
            "created_at": time.time(),
            "created_at_iso": now_iso()
        })

    if not (ROOT / "data/kybra_valid/ledger.json").exists():
        save_json("data/kybra_valid/ledger.json", {
            "status": "active",
            "entries": []
        })

def reward_policy():
    p = load_json("data/kibra_mint_finance/reward_policy.json", {})
    return {
        "block_reward_kibra": dec(p.get("block_reward_kibra", "100")),
        "task_block_reward_kibra": dec(p.get("task_block_reward_kibra", "100"))
    }

def mined_balance():
    rp = reward_policy()
    main_blocks = Decimal(count_files("blockchain/kibra_chain/blocks/block_*.json"))
    task_blocks = Decimal(count_files("blockchain/kibra_chain/task_blocks/*.json"))

    main_kibra = main_blocks * rp["block_reward_kibra"]
    task_kibra = task_blocks * rp["task_block_reward_kibra"]
    total = main_kibra + task_kibra

    ledger = load_json("data/kybra_valid/ledger.json", {"entries": []})
    sent_internal = Decimal("0")
    for e in ledger.get("entries", []):
        if e.get("status") == "internal_transfer_recorded":
            sent_internal += dec(e.get("amount_kibra", "0"))

    available = total - sent_internal
    if available < 0:
        available = Decimal("0")

    market = load_json("feeds/kibra_real_market_price_gate.json", {})
    mined_money = load_json("feeds/kibra_mined_money_report.json", {})

    price = dec(
        market.get("price_usd_per_kibra") or
        mined_money.get("market", {}).get("price_usd_per_kibra") or
        "0"
    )

    real_market_confirmed = bool(market.get("real_market_confirmed", False))

    return {
        "main_blocks": int(main_blocks),
        "task_blocks": int(task_blocks),
        "block_reward_kibra": str(rp["block_reward_kibra"]),
        "task_block_reward_kibra": str(rp["task_block_reward_kibra"]),
        "main_kibra": str(main_kibra),
        "task_kibra": str(task_kibra),
        "total_mined_kibra": str(total),
        "sent_internal_kibra": str(sent_internal),
        "available_kibra": str(available),
        "price_usd_per_kibra": str(price),
        "estimated_usd_if_price_confirmed": str(available * price),
        "real_market_confirmed": real_market_confirmed,
        "real_sell_now": False
    }

def web_requisites():
    init()
    wallet = load_json("data/kybra_valid/wallet.json", {})
    bal = mined_balance()

    req = {
        "status": "active_internal_web_payment_requisites",
        "payment_system": "KYBRA Valid Wallet Gateway",
        "valid_id": wallet.get("valid_id"),
        "merchant_id": wallet.get("merchant_id"),
        "internal_wallet_address": wallet.get("internal_address"),
        "network": "KYBRA_INTERNAL",
        "token": "KIBRA",
        "accepted_for": [
            "internal KYBRA transfer proposals",
            "invoice reference",
            "AI Parliament accounting",
            "future bridge/liquidity/payment route"
        ],
        "not_a_bank_iban": True,
        "not_a_licensed_psp_by_itself": True,
        "requires_for_real_payment": [
            "real bank/PSP details",
            "invoice/facture",
            "liquidity or buyer",
            "confirmed market price",
            "OWNER approval"
        ],
        "balance": bal,
        "public_safe_to_share": {
            "valid_id": wallet.get("valid_id"),
            "merchant_id": wallet.get("merchant_id"),
            "internal_wallet_address": wallet.get("internal_address"),
            "network": "KYBRA_INTERNAL",
            "token": "KIBRA"
        },
        "private_do_not_share": {
            "private_key": "NOT_STORED",
            "seed_phrase": "NOT_REQUIRED"
        }
    }

    save_json("data/kybra_valid/web_payment_requisites.json", req)
    return req

def is_internal_address(address):
    a = str(address).strip()
    return a.startswith("kybra:") or a.startswith("KIBRA-") or a.startswith("KYBRA-")

def set_destination(address, network="KYBRA_INTERNAL", label=""):
    init()
    obj = {
        "status": "destination_wallet_set",
        "to_address": address,
        "network": network,
        "label": label,
        "public_address_only": True,
        "warning": "Не вставляти seed/private key. Тільки public address.",
        "real_external_tx_now": False,
        "time": time.time(),
        "time_iso": now_iso()
    }
    obj["destination_sha"] = dsha(json.dumps(obj, ensure_ascii=False, sort_keys=True))
    save_json("data/kybra_valid/destination_wallet.json", obj)
    print("✅ destination wallet saved")
    print("ADDRESS:", address)
    print("NETWORK:", network)

def make_proposal(amount, to_address, network="KYBRA_INTERNAL", memo=""):
    init()
    amount_d = dec(amount)
    bal = mined_balance()

    proposal_id = "KYBRA-TRANSFER-" + dsha(str(time.time()) + to_address + str(amount))[:16].upper()

    errors = []
    if amount_d <= 0:
        errors.append("amount must be > 0")
    if not to_address:
        errors.append("to_address is empty")
    if amount_d > dec(bal["available_kibra"]):
        errors.append("insufficient available KIBRA")

    internal = is_internal_address(to_address)

    proposal = {
        "status": "pending_owner_approval" if not errors else "invalid",
        "proposal_id": proposal_id,
        "amount_kibra": str(amount_d),
        "to_address": to_address,
        "network": network,
        "memo": memo,
        "internal_transfer_possible": internal,
        "external_transfer_possible_now": False,
        "external_transfer_requires": [
            "bridge/wrapped representation",
            "liquidity if fiat payment",
            "confirmed market price if sell/conversion",
            "manual OWNER approval",
            "manual external wallet transaction"
        ],
        "balance_snapshot": bal,
        "errors": errors,
        "real_external_tx_now": False,
        "real_payment_now": False,
        "manual_OWNER_approval_required": True,
        "created_at": time.time(),
        "created_at_iso": now_iso()
    }

    proposal["double_sha"] = dsha(json.dumps(proposal, ensure_ascii=False, sort_keys=True))

    save_json(f"data/kybra_valid/proposals/{proposal_id}.json", proposal)
    redis_lpush(PROPOSALS_Q, proposal)

    ai_task = {
        "topic": "KYBRA Valid transfer proposal",
        "type": "kybra_valid_wallet_task",
        "priority": "critical",
        "payload": {
            "source": "kybra_valid_wallet_gateway",
            "proposal_id": proposal_id,
            "amount_kibra": str(amount_d),
            "to_address": to_address,
            "network": network,
            "proposal_sha": proposal["double_sha"],
            "convert_to_mining_block_first": True,
            "real_external_tx_now": False,
            "real_payment_now": False,
            "manual_OWNER_approval_required": True
        }
    }
    redis_lpush(AI_BLOCK_INBOX, ai_task)

    print("✅ transfer proposal created")
    print("PROPOSAL_ID:", proposal_id)
    print("STATUS:", proposal["status"])
    print("AMOUNT_KIBRA:", amount_d)
    print("TO:", to_address)
    print("INTERNAL_TRANSFER_POSSIBLE:", internal)
    print("ERRORS:", errors)

def approve_internal(proposal_id):
    init()
    path = f"data/kybra_valid/proposals/{proposal_id}.json"
    proposal = load_json(path, {})
    if not proposal:
        raise SystemExit("proposal not found")

    if proposal.get("status") == "internal_transfer_recorded":
        print("already recorded")
        return

    if proposal.get("errors"):
        raise SystemExit("proposal invalid: " + json.dumps(proposal.get("errors"), ensure_ascii=False))

    to_address = proposal.get("to_address", "")
    amount = dec(proposal.get("amount_kibra", "0"))

    if not is_internal_address(to_address):
        proposal["status"] = "external_manual_tx_required_not_recorded"
        proposal["note"] = "External address requires bridge/manual external tx. Internal ledger not recorded."
        save_json(path, proposal)
        print("❌ external address: manual bridge/external tx required")
        print("No internal transfer recorded.")
        return

    bal = mined_balance()
    if amount > dec(bal["available_kibra"]):
        raise SystemExit("insufficient available KIBRA")

    ledger = load_json("data/kybra_valid/ledger.json", {"entries": []})
    entry = {
        "status": "internal_transfer_recorded",
        "proposal_id": proposal_id,
        "amount_kibra": str(amount),
        "to_address": to_address,
        "network": proposal.get("network", "KYBRA_INTERNAL"),
        "memo": proposal.get("memo", ""),
        "time": time.time(),
        "time_iso": now_iso()
    }
    entry["double_sha"] = dsha(json.dumps(entry, ensure_ascii=False, sort_keys=True))

    ledger.setdefault("entries", []).append(entry)
    save_json("data/kybra_valid/ledger.json", ledger)

    proposal["status"] = "internal_transfer_recorded"
    proposal["ledger_entry_sha"] = entry["double_sha"]
    save_json(path, proposal)

    save_json(f"data/kybra_valid/transfers/{proposal_id}.json", entry)

    redis_lpush(AUDIT, {
        "status": "internal_transfer_recorded",
        "proposal_id": proposal_id,
        "amount_kibra": str(amount),
        "to_address": to_address,
        "time": entry["time"],
        "double_sha": entry["double_sha"]
    })

    print("✅ internal KIBRA transfer recorded")
    print("PROPOSAL_ID:", proposal_id)
    print("AMOUNT:", amount)
    print("TO:", to_address)

def report(submit_ai=True):
    init()
    wallet = load_json("data/kybra_valid/wallet.json", {})
    destination = load_json("data/kybra_valid/destination_wallet.json", {})
    req = web_requisites()
    bal = mined_balance()

    package = {
        "status": "kybra_valid_wallet_gateway_report_generated",
        "time": time.time(),
        "time_iso": now_iso(),
        "wallet": wallet,
        "destination_wallet": destination,
        "web_payment_requisites": req,
        "balance": bal,
        "queues": {
            "proposals": redis_len(PROPOSALS_Q),
            "block_inbox": redis_len(AI_BLOCK_INBOX),
            "parliament_queue": redis_len("cybra:parliament:queue"),
            "parliament_failed": redis_len("cybra:parliament:failed"),
            "task_block_mempool": redis_len("cybra:kibra:task_blocks:mempool")
        },
        "safety": {
            "private_key_stored": False,
            "seed_phrase_required": False,
            "automatic_external_tx": False,
            "automatic_real_payment": False,
            "automatic_token_sell": False,
            "manual_OWNER_approval_required": True
        },
        "git": {
            "branch": git_cmd(["git", "branch", "--show-current"]),
            "commit": git_cmd(["git", "rev-parse", "--short", "HEAD"])
        }
    }

    package["double_sha"] = dsha(json.dumps(package, ensure_ascii=False, sort_keys=True))

    save_json("feeds/kybra_valid_wallet_gateway_report.json", package)
    save_json("data/kybra_valid/latest_report.json", package)

    public = req.get("public_safe_to_share", {})

    md = f"""# KYBRA Valid Wallet Gateway

Status: {package['status']}

## Web payment requisites

Payment system: KYBRA Valid Wallet Gateway
Valid ID: {public.get('valid_id')}
Merchant ID: {public.get('merchant_id')}
Internal wallet address: {public.get('internal_wallet_address')}
Network: {public.get('network')}
Token: {public.get('token')}

## Balance

Main blocks: {bal['main_blocks']}
Task blocks: {bal['task_blocks']}
Main KIBRA: {bal['main_kibra']}
Task KIBRA: {bal['task_kibra']}
Total mined KIBRA: {bal['total_mined_kibra']}
Sent internal KIBRA: {bal['sent_internal_kibra']}
Available KIBRA: {bal['available_kibra']}

Price USD/KIBRA: {bal['price_usd_per_kibra']}
Estimated USD if price confirmed: {bal['estimated_usd_if_price_confirmed']}
Real market confirmed: {bal['real_market_confirmed']}
Real sell now: false

## Destination wallet

Status: {destination.get('status')}
To address: {destination.get('to_address')}
Network: {destination.get('network')}
Label: {destination.get('label')}

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

{package['double_sha']}
"""

    (ROOT / "posts/kybra_valid_wallet_gateway_report.md").write_text(md, encoding="utf-8")

    dealer = f"""KYBRA WEB PAYMENT REQUISITES

Payment system: KYBRA Valid Wallet Gateway
Valid ID: {public.get('valid_id')}
Merchant ID: {public.get('merchant_id')}
Internal wallet address: {public.get('internal_wallet_address')}
Network: {public.get('network')}
Token: {public.get('token')}

Purpose:
Internal KYBRA payment reference / invoice reference / future bank or PSP route after liquidity and OWNER approval.

Important:
This is not a bank IBAN.
For real car payment, dealer invoice and real bank/PSP payment rail are required.
"""
    (ROOT / "posts/kybra_valid_web_payment_requisites.txt").write_text(dealer, encoding="utf-8")

    with (ROOT / "proofs/kybra_valid_wallet_gateway.sha256").open("w") as f:
        subprocess.run([
            "sha256sum",
            "parliament/departments/finance_department/kybra_valid_wallet_department/department.json",
            "data/kybra_valid/wallet.json",
            "data/kybra_valid/web_payment_requisites.json",
            "data/kybra_valid/latest_report.json",
            "feeds/kybra_valid_wallet_gateway_report.json",
            "posts/kybra_valid_wallet_gateway_report.md",
            "posts/kybra_valid_web_payment_requisites.txt"
        ], cwd=ROOT, stdout=f, stderr=subprocess.DEVNULL)

    redis_lpush(AUDIT, {
        "status": "kybra_valid_wallet_gateway_report_generated",
        "available_kibra": bal["available_kibra"],
        "total_mined_kibra": bal["total_mined_kibra"],
        "double_sha": package["double_sha"],
        "time": package["time"]
    })

    if submit_ai:
        ai_task = {
            "topic": "KYBRA Valid Wallet Gateway report and transfer readiness",
            "type": "kybra_valid_wallet_task",
            "priority": "critical",
            "payload": {
                "source": "kybra_valid_wallet_gateway",
                "available_kibra": bal["available_kibra"],
                "total_mined_kibra": bal["total_mined_kibra"],
                "valid_id": public.get("valid_id"),
                "internal_wallet_address": public.get("internal_wallet_address"),
                "convert_to_mining_block_first": True,
                "real_external_tx_now": False,
                "real_payment_now": False,
                "manual_OWNER_approval_required": True
            }
        }
        redis_lpush(AI_BLOCK_INBOX, ai_task)

    print("✅ KYBRA Valid Wallet Gateway report generated")
    print("VALID_ID:", public.get("valid_id"))
    print("INTERNAL_ADDRESS:", public.get("internal_wallet_address"))
    print("TOTAL_MINED_KIBRA:", bal["total_mined_kibra"])
    print("AVAILABLE_KIBRA:", bal["available_kibra"])
    print("REPORT: posts/kybra_valid_wallet_gateway_report.md")
    print("REQUISITES: posts/kybra_valid_web_payment_requisites.txt")
    print("PROOF: proofs/kybra_valid_wallet_gateway.sha256")

def status():
    init()
    bal = mined_balance()
    wallet = load_json("data/kybra_valid/wallet.json", {})
    print("VALID_ID:", wallet.get("valid_id"))
    print("INTERNAL_ADDRESS:", wallet.get("internal_address"))
    print("TOTAL_MINED_KIBRA:", bal["total_mined_kibra"])
    print("AVAILABLE_KIBRA:", bal["available_kibra"])
    print("PRICE_USD_PER_KIBRA:", bal["price_usd_per_kibra"])
    print("REAL_MARKET_CONFIRMED:", bal["real_market_confirmed"])
    print("PROPOSALS:", redis_len(PROPOSALS_Q))
    print("BLOCK_INBOX:", redis_len(AI_BLOCK_INBOX))

def main():
    import sys
    cmd = sys.argv[1] if len(sys.argv) > 1 else "status"

    if cmd == "init":
        init()
        report(False)
    elif cmd == "status":
        status()
    elif cmd == "report":
        report(True)
    elif cmd == "set-destination":
        if len(sys.argv) < 3:
            raise SystemExit("Usage: set-destination ADDRESS [NETWORK] [LABEL]")
        set_destination(sys.argv[2], sys.argv[3] if len(sys.argv) > 3 else "KYBRA_INTERNAL", sys.argv[4] if len(sys.argv) > 4 else "")
        report(True)
    elif cmd == "propose":
        if len(sys.argv) < 4:
            raise SystemExit("Usage: propose AMOUNT TO_ADDRESS [NETWORK] [MEMO]")
        make_proposal(sys.argv[2], sys.argv[3], sys.argv[4] if len(sys.argv) > 4 else "KYBRA_INTERNAL", sys.argv[5] if len(sys.argv) > 5 else "")
        report(True)
    elif cmd == "approve-internal":
        if len(sys.argv) < 3:
            raise SystemExit("Usage: approve-internal PROPOSAL_ID")
        approve_internal(sys.argv[2])
        report(True)
    else:
        raise SystemExit("Usage: init|status|report|set-destination|propose|approve-internal")

if __name__ == "__main__":
    main()
PY

chmod +x kybra_valid_gateway.py

cat > kybra_valid.sh <<'EOF'
#!/data/data/com.termux/files/usr/bin/bash
set -e
cd "$HOME/CYBRA"

case "${1:-status}" in
  init)
    python3 kybra_valid_gateway.py init
    ;;
  status|balance)
    python3 kybra_valid_gateway.py status
    ;;
  report)
    python3 kybra_valid_gateway.py report
    cat posts/kybra_valid_wallet_gateway_report.md
    ;;
  requisites)
    cat posts/kybra_valid_web_payment_requisites.txt
    ;;
  set-destination)
    python3 kybra_valid_gateway.py set-destination "$2" "${3:-KYBRA_INTERNAL}" "${4:-}"
    ;;
  propose)
    python3 kybra_valid_gateway.py propose "$2" "$3" "${4:-KYBRA_INTERNAL}" "${5:-}"
    ;;
  approve-internal)
    python3 kybra_valid_gateway.py approve-internal "$2"
    ;;
  proposals)
    ls -lah data/kybra_valid/proposals 2>/dev/null || true
    ;;
  ledger)
    cat data/kybra_valid/ledger.json
    ;;
  wallet)
    cat data/kybra_valid/wallet.json
    ;;
  destination)
    cat data/kybra_valid/destination_wallet.json
    ;;
  proof)
    cat proofs/kybra_valid_wallet_gateway.sha256
    ;;
  *)
    echo "Usage:"
    echo "  bash kybra_valid.sh status"
    echo "  bash kybra_valid.sh report"
    echo "  bash kybra_valid.sh requisites"
    echo "  bash kybra_valid.sh set-destination ADDRESS NETWORK LABEL"
    echo "  bash kybra_valid.sh propose AMOUNT ADDRESS NETWORK MEMO"
    echo "  bash kybra_valid.sh approve-internal PROPOSAL_ID"
    echo "  bash kybra_valid.sh proposals"
    echo "  bash kybra_valid.sh ledger"
    ;;
esac
EOF

chmod +x kybra_valid.sh

cat > kybra_valid_wallet_handler.sh <<'EOF'
#!/data/data/com.termux/files/usr/bin/bash
set -e
cd "$HOME/CYBRA"

python3 kybra_valid_gateway.py report >/dev/null 2>&1 || true
bash cybra_closed_sha_bridge.sh cycle >/dev/null 2>&1 || true
EOF

chmod +x kybra_valid_wallet_handler.sh

redis-cli HSET cybra:executor:mapping kybra_valid_wallet_task kybra_valid_wallet_handler.sh >/dev/null || true

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
    if '"kybra_valid_wallet_task"' not in s:
        i = s.find("SCRIPT_MAP")
        j = s.find("{", i)
        if i >= 0 and j >= 0:
            s = s[:j+1] + '\n    "kybra_valid_wallet_task": "kybra_valid_wallet_handler.sh",' + s[j+1:]
    p.write_text(s, encoding="utf-8")
    print("✅ executor patched")
else:
    print("⚠ parliament_executor_v6.py not found")
PY

rm -rf __pycache__
python3 -m py_compile kybra_valid_gateway.py
test -f parliament_executor_v6.py && python3 -m py_compile parliament_executor_v6.py || true
rm -rf __pycache__

echo
echo "=== INIT + REPORT ==="
bash kybra_valid.sh init
bash kybra_valid.sh status

echo
echo "=== PROOF CHECK ==="
sha256sum -c proofs/kybra_valid_wallet_gateway.sha256 || true

echo
echo "✅ KYBRA VALID WALLET GATEWAY INSTALLED"
