#!/data/data/com.termux/files/usr/bin/bash
set -e
cd "$HOME/CYBRA"

mkdir -p data/kibra_market posts feeds proofs

CMD="${1:-status}"

case "$CMD" in
  template)
    cat > data/kibra_market/real_market_proof.json <<'JSON'
{
  "status": "draft",
  "proof_type": "pool_or_orderbook_or_provider",
  "provider_name": "",
  "market_pair": "KIBRA/USD",
  "quote_reserve_usd": "0",
  "kibra_reserve": "0",
  "orderbook_bid_usd": "0",
  "orderbook_ask_usd": "0",
  "proof_source": "",
  "proof_reference": "",
  "proof_file_sha256": "",
  "provider_review_passed": false,
  "owner_approval": false,
  "aml_legal_review_required": true,
  "note": "Заповнити тільки після реального pool/orderbook/provider proof."
}
JSON
    echo "✅ template created: data/kibra_market/real_market_proof.json"
    echo "Редагуй: nano data/kibra_market/real_market_proof.json"
    ;;

  verify|confirm)
    python3 - <<'PY'
import json, time, hashlib, subprocess
from decimal import Decimal, getcontext
from pathlib import Path
import redis

getcontext().prec = 50

ROOT = Path.home() / "CYBRA"
r = redis.Redis(host="127.0.0.1", port=6379, decode_responses=True)

proof_path = ROOT / "data/kibra_market/real_market_proof.json"

def sha(x):
    return hashlib.sha256(x.encode()).hexdigest()

def dsha(x):
    return sha(sha(x))

def load(path):
    if not path.exists():
        raise SystemExit("❌ Нема real_market_proof.json. Запусти: bash cybra_real_market_price_gate.sh template")
    return json.loads(path.read_text(encoding="utf-8"))

proof = load(proof_path)

proof_type = str(proof.get("proof_type", "")).strip()
provider = str(proof.get("provider_name", "")).strip()
pair = str(proof.get("market_pair", "KIBRA/USD")).strip()
proof_source = str(proof.get("proof_source", "")).strip()
proof_reference = str(proof.get("proof_reference", "")).strip()

quote = Decimal(str(proof.get("quote_reserve_usd", "0")))
kibra = Decimal(str(proof.get("kibra_reserve", "0")))
bid = Decimal(str(proof.get("orderbook_bid_usd", "0")))
ask = Decimal(str(proof.get("orderbook_ask_usd", "0")))

provider_review = bool(proof.get("provider_review_passed", False))
owner_approval = bool(proof.get("owner_approval", False))

errors = []

if proof_type not in ["pool", "orderbook", "provider", "pool_or_orderbook_or_provider"]:
    errors.append("proof_type має бути pool / orderbook / provider")

if not provider:
    errors.append("provider_name порожній")

if not proof_source and not proof_reference:
    errors.append("нема proof_source або proof_reference")

price = Decimal("0")
price_method = "none"

if quote > 0 and kibra > 0:
    price = quote / kibra
    price_method = "pool_reserves"

elif bid > 0 and ask > 0:
    price = (bid + ask) / Decimal("2")
    price_method = "orderbook_mid_price"

else:
    errors.append("нема коректних резервів або bid/ask для розрахунку ціни")

if not provider_review:
    errors.append("provider_review_passed має бути true")

if not owner_approval:
    errors.append("owner_approval має бути true")

verified = len(errors) == 0

result = {
    "status": "real_market_price_confirmed" if verified else "real_market_price_not_confirmed",
    "verified": verified,
    "errors": errors,
    "proof_type": proof_type,
    "provider_name": provider,
    "market_pair": pair,
    "price_method": price_method,
    "price_usd_per_kibra": str(price if verified else Decimal("0")),
    "quote_reserve_usd": str(quote),
    "kibra_reserve": str(kibra),
    "orderbook_bid_usd": str(bid),
    "orderbook_ask_usd": str(ask),
    "proof_source": proof_source,
    "proof_reference": proof_reference,
    "provider_review_passed": provider_review,
    "owner_approval": owner_approval,
    "real_market_confirmed": verified,
    "real_sell_now": False,
    "manual_OWNER_approval_required_for_sell": True,
    "time": time.time(),
    "time_iso": time.strftime("%Y-%m-%dT%H:%M:%S%z")
}

result["double_sha"] = dsha(json.dumps(result, ensure_ascii=False, sort_keys=True))

(ROOT / "feeds/kibra_real_market_price_gate.json").write_text(
    json.dumps(result, ensure_ascii=False, indent=2),
    encoding="utf-8"
)

if verified:
    (ROOT / "data/kibra_market/confirmed_price.json").write_text(
        json.dumps(result, ensure_ascii=False, indent=2),
        encoding="utf-8"
    )

    pool_reserves = {
        "status": "verified_real_market_reserves",
        "source": provider,
        "quote_reserve_usd": str(quote),
        "kibra_reserve": str(kibra),
        "orderbook_bid_usd": str(bid),
        "orderbook_ask_usd": str(ask),
        "price_usd_per_kibra": str(price),
        "real_market_confirmed": True,
        "proof_reference": proof_reference,
        "time": result["time"],
        "time_iso": result["time_iso"]
    }

    (ROOT / "data/kibra_market/pool_reserves.json").write_text(
        json.dumps(pool_reserves, ensure_ascii=False, indent=2),
        encoding="utf-8"
    )

md = f"""# KIBRA Real Market Price Gate

Status: **{result['status']}**

## Verification

- Verified: **{verified}**
- Real market confirmed: **{result['real_market_confirmed']}**
- Provider: `{provider}`
- Pair: `{pair}`
- Method: `{price_method}`
- Price USD/KIBRA: **{result['price_usd_per_kibra']}**

## Required proof

- Pool proof / orderbook proof / provider proof
- Provider review passed: **{provider_review}**
- OWNER approval: **{owner_approval}**
- Real sell now: **false**

## Errors

`{errors}`

## Rule

Без real pool/orderbook/provider proof ціна не підтверджується як ринкова.  
Reference price може існувати тільки для внутрішнього обліку.

## Double SHA

`{result['double_sha']}`
"""

(ROOT / "posts/kibra_real_market_price_gate.md").write_text(md, encoding="utf-8")

with (ROOT / "proofs/kibra_real_market_price_gate.sha256").open("w") as f:
    subprocess.run([
        "sha256sum",
        "data/kibra_market/real_market_proof.json",
        "feeds/kibra_real_market_price_gate.json",
        "posts/kibra_real_market_price_gate.md"
    ], cwd=ROOT, stdout=f, stderr=subprocess.DEVNULL)

r.lpush("cybra:kibra:real_market_price_gate:audit", json.dumps(result, ensure_ascii=False))

ai_task = {
    "topic": "KIBRA real market price proof gate",
    "type": "kibra_mint_liquidity_task",
    "priority": "critical",
    "payload": {
        "source": "real_market_price_gate",
        "verified": verified,
        "real_market_confirmed": verified,
        "price_usd_per_kibra": result["price_usd_per_kibra"],
        "convert_to_mining_block_first": True,
        "real_sell_now": False,
        "manual_OWNER_approval_required": True
    }
}
r.lpush("cybra:ai:tasks:block_inbox", json.dumps(ai_task, ensure_ascii=False))

print("✅ real market price gate checked")
print("VERIFIED:", verified)
print("PRICE_USD_PER_KIBRA:", result["price_usd_per_kibra"])
print("ERRORS:", errors)
print("REPORT: posts/kibra_real_market_price_gate.md")
print("PROOF: proofs/kibra_real_market_price_gate.sha256")
PY

    sha256sum -c proofs/kibra_real_market_price_gate.sha256 || true

    echo
    echo "=== UPDATE LIQUIDITY / MANAGEMENT / MONEY ==="
    bash cybra_mint_liquidity.sh report || true
    bash cybra_mint_manage.sh report || true
    bash cybra_mined_money_report.sh || true

    echo
    echo "=== ENFORCE PRICE GATE AI TASK INTO MINING BLOCK ==="
    bash cybra_ai_block_enforcer.sh enforce 3 || true
    ;;

  status)
    echo "REAL_MARKET_PRICE_GATE_AUDIT=$(redis-cli LLEN cybra:kibra:real_market_price_gate:audit)"
    test -f data/kibra_market/real_market_proof.json && echo "REAL_MARKET_PROOF=exists" || echo "REAL_MARKET_PROOF=missing"
    test -f data/kibra_market/confirmed_price.json && echo "CONFIRMED_PRICE=exists" || echo "CONFIRMED_PRICE=missing"
    test -f posts/kibra_real_market_price_gate.md && cat posts/kibra_real_market_price_gate.md || true
    ;;

  *)
    echo "Usage:"
    echo "  bash cybra_real_market_price_gate.sh template"
    echo "  bash cybra_real_market_price_gate.sh verify"
    echo "  bash cybra_real_market_price_gate.sh confirm"
    echo "  bash cybra_real_market_price_gate.sh status"
    ;;
esac
