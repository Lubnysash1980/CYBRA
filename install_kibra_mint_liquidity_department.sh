#!/data/data/com.termux/files/usr/bin/bash
set -e
cd "$HOME/CYBRA"

echo "=== INSTALL KIBRA MINT LIQUIDITY DEPARTMENT ==="

mkdir -p \
  parliament/departments/kibra_mint_repair_department/liquidity_department \
  parliament/kibra_mint_liquidity \
  data/kibra_mint_liquidity \
  data/kibra_market \
  posts feeds proofs logs/kibra_mint_liquidity

redis-cli ping >/dev/null 2>&1 || redis-server --daemonize yes || true
sleep 1

python3 - <<'PY' >/dev/null 2>&1 || python3 -m pip install redis
import redis
PY

cat > parliament/departments/kibra_mint_repair_department/liquidity_department/department.json <<'JSON'
{
  "department_id": "kibra_mint_liquidity_department",
  "name": "KIBRA Mint Liquidity Department",
  "parent_department": "kibra_mint_repair_department",
  "status": "active",
  "mission": "Створювати і перевіряти ліквідність KIBRA: pool reserves, orderbook readiness, depth, slippage, staged sell limits, market price proof, utility liquidity і AI-завдання через mining blocks.",
  "responsibilities": [
    "liquidity_readiness",
    "pool_reserve_model",
    "orderbook_depth_model",
    "market_price_proof",
    "slippage_check",
    "sell_without_crash",
    "liquidity_gap_detection",
    "utility_liquidity_plan",
    "bridge_liquidity_proof",
    "AI_task_block_liquidity_flow"
  ],
  "blocked": [
    "fake_price",
    "fake_volume",
    "wash_trading",
    "pump_and_dump",
    "guaranteed_profit",
    "automatic_real_pool",
    "automatic_real_sell",
    "automatic_payment",
    "external_tx_without_OWNER_approval"
  ],
  "manual_OWNER_approval_required": true
}
JSON

cat > parliament/kibra_mint_liquidity/policy.json <<'JSON'
{
  "name": "KIBRA Mint Liquidity Policy",
  "status": "active",
  "native_coin": true,
  "external_mint": false,
  "main_rule": "Ліквідність створює ринкову ціну. Блоки підтверджують emission/proof, але не створюють ринкову ціну без liquidity/orderbook/buyers.",
  "liquidity_sources": [
    "utility_demand",
    "AI_task_credits",
    "proof_services",
    "bridge_package_services",
    "developer_marketplace",
    "pool_mining_participation",
    "real_pool_reserves_after_OWNER_approval",
    "orderbook_depth_after_PROVIDER_review"
  ],
  "risk_controls": [
    "slippage_limit",
    "daily_volume_limit",
    "staged_sell",
    "reserve_ratio",
    "no_fake_volume",
    "no_wash_trading",
    "market_price_from_real_liquidity_only"
  ],
  "execution": {
    "real_pool_now": false,
    "real_sell_now": false,
    "real_payment_now": false,
    "real_external_tx_now": false,
    "manual_OWNER_approval_required": true
  }
}
JSON

cat > cybra_kibra_mint_liquidity.py <<'PY'
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
r = redis.Redis(host="127.0.0.1", port=6379, decode_responses=True)

AUDIT = "cybra:kibra:mint_liquidity:audit"
RECS = "cybra:kibra:mint_liquidity:recommendations"
PLANS = "cybra:kibra:mint_liquidity:plans"
AI_BLOCK_INBOX = "cybra:ai:tasks:block_inbox"

def sha(x):
    return hashlib.sha256(x.encode("utf-8")).hexdigest()

def dsha(x):
    return sha(sha(x))

def now_iso():
    return time.strftime("%Y-%m-%dT%H:%M:%S%z")

def exists(path):
    return (ROOT / path).exists()

def redis_len(k):
    try:
        return r.llen(k)
    except Exception:
        return 0

def file_sha(path):
    p = ROOT / path
    if not p.exists():
        return None
    h = hashlib.sha256()
    with p.open("rb") as f:
        for c in iter(lambda: f.read(1024 * 1024), b""):
            h.update(c)
    return h.hexdigest()

def load_json(path):
    p = ROOT / path
    if not p.exists():
        return {}
    try:
        return json.loads(p.read_text(encoding="utf-8"))
    except Exception:
        return {}

def latest_hash():
    p = ROOT / "blockchain/kibra_chain/latest.block.hash"
    return p.read_text().strip() if p.exists() else None

def count_files(pattern):
    return len(list(ROOT.glob(pattern)))

def git_cmd(cmd):
    try:
        return subprocess.check_output(cmd, cwd=ROOT, text=True, stderr=subprocess.DEVNULL).strip()
    except Exception:
        return ""

def mined_accounting():
    reward = load_json("data/kibra_mint_finance/reward_policy.json")
    block_reward = Decimal(str(reward.get("block_reward_kibra", "100")))
    task_block_reward = Decimal(str(reward.get("task_block_reward_kibra", "100")))

    main_blocks = Decimal(count_files("blockchain/kibra_chain/blocks/block_*.json"))
    task_blocks = Decimal(count_files("blockchain/kibra_chain/task_blocks/*.json"))

    total = main_blocks * block_reward + task_blocks * task_block_reward

    return {
        "main_blocks": int(main_blocks),
        "task_blocks": int(task_blocks),
        "block_reward_kibra": str(block_reward),
        "task_block_reward_kibra": str(task_block_reward),
        "total_mined_kibra": str(total),
        "accounting_only": True,
        "real_payout_now": False
    }

def current_pool_reserves():
    reserves = load_json("data/kibra_market/pool_reserves.json")
    if not reserves:
        return {
            "status": "no_pool_reserves",
            "quote_reserve_usd": "0",
            "kibra_reserve": "0",
            "price_usd_per_kibra": "0",
            "real_market_confirmed": False
        }

    try:
        quote = Decimal(str(reserves.get("quote_reserve_usd", "0")))
        kibra = Decimal(str(reserves.get("kibra_reserve", "0")))
        price = quote / kibra if quote > 0 and kibra > 0 else Decimal("0")
        return {
            "status": "pool_reserves_found" if price > 0 else "pool_reserves_invalid_or_zero",
            "source": reserves.get("source", "pool_reserves"),
            "quote_reserve_usd": str(quote),
            "kibra_reserve": str(kibra),
            "price_usd_per_kibra": str(price),
            "real_market_confirmed": bool(reserves.get("real_market_confirmed", False)),
            "time": reserves.get("time")
        }
    except Exception as e:
        return {
            "status": "pool_reserves_error",
            "error": str(e),
            "quote_reserve_usd": "0",
            "kibra_reserve": "0",
            "price_usd_per_kibra": "0",
            "real_market_confirmed": False
        }

def liquidity_score(accounting, reserves):
    score = 0

    if Decimal(accounting["total_mined_kibra"]) > 0:
        score += 20

    if exists("feeds/kibra_pool_confirm_report.json"):
        score += 15

    if exists("feeds/kibra_bridge_pool_monetization_report.json"):
        score += 15

    if exists("feeds/kibra_mint_management_finance_report.json"):
        score += 15

    if exists("website/kibra/promotion.html"):
        score += 10

    if Decimal(reserves.get("price_usd_per_kibra", "0")) > 0:
        score += 15

    if reserves.get("real_market_confirmed"):
        score += 10

    return min(100, score)

def build_liquidity_plan(accounting, reserves):
    total = Decimal(str(accounting["total_mined_kibra"]))
    price = Decimal(str(reserves.get("price_usd_per_kibra", "0")))

    reserve_targets = {
        "pilot_pool_1_percent_kibra": str(total * Decimal("0.01")),
        "starter_pool_5_percent_kibra": str(total * Decimal("0.05")),
        "growth_pool_10_percent_kibra": str(total * Decimal("0.10")),
        "treasury_hold_90_percent_or_more": str(total * Decimal("0.90"))
    }

    sell_limits = {
        "max_single_sell_percent_of_pool": "1",
        "max_daily_sell_percent_of_real_volume": "5",
        "slippage_warning_percent": "2",
        "slippage_block_percent": "5"
    }

    plan = {
        "status": "liquidity_plan_created",
        "time": time.time(),
        "time_iso": now_iso(),
        "native_coin": "KIBRA",
        "latest_kibra_hash": latest_hash(),
        "accounting": accounting,
        "pool_reserves": reserves,
        "reserve_targets": reserve_targets,
        "sell_limits": sell_limits,
        "estimated_value_usd": str(total * price),
        "liquidity_method": [
            "utility demand first",
            "AI credits",
            "proof services",
            "bridge packages",
            "developer marketplace",
            "pool mining participation",
            "real pool only after OWNER approval"
        ],
        "execution": {
            "real_pool_now": False,
            "real_sell_now": False,
            "real_payment_now": False,
            "manual_OWNER_approval_required": True
        },
        "blocked": {
            "fake_price": True,
            "fake_volume": True,
            "wash_trading": True,
            "guaranteed_profit": True
        }
    }

    plan["double_sha"] = dsha(json.dumps(plan, ensure_ascii=False, sort_keys=True))

    (ROOT / "data/kibra_mint_liquidity/liquidity_plan.json").write_text(
        json.dumps(plan, ensure_ascii=False, indent=2),
        encoding="utf-8"
    )

    r.lpush(PLANS, json.dumps(plan, ensure_ascii=False))
    return plan

def recommendations(score, accounting, reserves):
    recs = []

    if Decimal(reserves.get("price_usd_per_kibra", "0")) == 0:
        recs.append({
            "level": "critical",
            "area": "market_price",
            "recommendation": "Ринкової ціни ще нема. Потрібно створити liquidity proof або orderbook/pool reserves.",
            "task_type": "kibra_mint_liquidity_task",
            "action": "bash cybra_mint_liquidity.sh plan"
        })

    if not reserves.get("real_market_confirmed"):
        recs.append({
            "level": "important",
            "area": "real_liquidity",
            "recommendation": "Pool reserves не підтверджені реальним ринком. Спочатку manual OWNER approval + provider/legal/AML review.",
            "task_type": "kibra_market_exchange_task",
            "action": "bash cybra_kibra_market.sh report"
        })

    if redis_len("cybra:kibra:task_blocks:mempool") > 0:
        recs.append({
            "level": "important",
            "area": "task_block_mempool",
            "recommendation": "Перед ліквідністю домайнити AI task-block mempool.",
            "task_type": "ai_tasks_to_blocks_task",
            "action": "bash cybra_ai_blocks.sh until-done"
        })

    if redis_len("cybra:kibra:mint_repair:queue") > 0:
        recs.append({
            "level": "repair",
            "area": "mint_repair",
            "recommendation": "Перед ліквідністю закрити repair queue монетного двору.",
            "task_type": "kibra_mint_audit_task",
            "action": "bash cybra_mint_audit.sh until-done"
        })

    recs.append({
        "level": "growth",
        "area": "utility_liquidity",
        "recommendation": "Піднімати ліквідність через utility: AI credits, proof services, bridge packages, developer marketplace.",
        "task_type": "kibra_mint_promotion_task",
        "action": "bash cybra_mint_promo.sh report"
    })

    recs.append({
        "level": "finance",
        "area": "sell_without_crash",
        "recommendation": "Реалізація тільки staged: 1%, 3%, 5%, з перевіркою slippage і depth.",
        "task_type": "kibra_mint_management_task",
        "action": "bash cybra_mint_manage.sh report"
    })

    return recs

def build_ai_tasks(recs, plan):
    tasks = []
    for i, rec in enumerate(recs, 1):
        tasks.append({
            "topic": f"KIBRA Mint Liquidity Recommendation {i}: {rec['area']}",
            "type": rec["task_type"],
            "priority": "high",
            "payload": {
                "source": "kibra_mint_liquidity_department",
                "area": rec["area"],
                "recommendation": rec["recommendation"],
                "suggested_action": rec["action"],
                "liquidity_plan_sha": plan["double_sha"],
                "convert_to_mining_block_first": True,
                "real_pool_now": False,
                "real_sell_now": False,
                "real_payment_now": False,
                "fake_price": False,
                "fake_volume": False,
                "wash_trading": False,
                "manual_OWNER_approval_required": True
            }
        })
    return tasks

def report(submit_ai=False):
    for d in ["posts", "feeds", "proofs", "data/kibra_mint_liquidity"]:
        (ROOT / d).mkdir(parents=True, exist_ok=True)

    accounting = mined_accounting()
    reserves = current_pool_reserves()
    score = liquidity_score(accounting, reserves)
    plan = build_liquidity_plan(accounting, reserves)
    recs = recommendations(score, accounting, reserves)
    tasks = build_ai_tasks(recs, plan)

    if submit_ai:
        for t in tasks:
            r.lpush(AI_BLOCK_INBOX, json.dumps(t, ensure_ascii=False))

    obj = {
        "status": "kibra_mint_liquidity_report_generated",
        "time": time.time(),
        "time_iso": now_iso(),
        "submit_ai": submit_ai,
        "liquidity_score": score,
        "latest_kibra_hash": latest_hash(),
        "accounting": accounting,
        "pool_reserves": reserves,
        "liquidity_plan_file": "data/kibra_mint_liquidity/liquidity_plan.json",
        "recommendations": recs,
        "ai_tasks_prepared": len(tasks),
        "ai_tasks_submitted_to_block_inbox": len(tasks) if submit_ai else 0,
        "redis": {
            "liquidity_audit": redis_len(AUDIT),
            "liquidity_plans": redis_len(PLANS),
            "block_inbox": redis_len(AI_BLOCK_INBOX),
            "task_block_mempool": redis_len("cybra:kibra:task_blocks:mempool"),
            "task_blocks_mined": redis_len("cybra:kibra:task_blocks:mined"),
            "pool_mining_blocks": redis_len("cybra:kibra:pool:mining_blocks"),
            "parliament_queue": redis_len("cybra:parliament:queue"),
            "parliament_failed": redis_len("cybra:parliament:failed")
        },
        "git": {
            "branch": git_cmd(["git", "branch", "--show-current"]),
            "commit": git_cmd(["git", "rev-parse", "--short", "HEAD"]),
            "dirty_files": len(git_cmd(["git", "status", "--short"]).splitlines())
        },
        "safety": {
            "real_pool_now": False,
            "real_sell_now": False,
            "real_payment_now": False,
            "fake_price": False,
            "fake_volume": False,
            "wash_trading": False,
            "manual_OWNER_approval_required": True
        }
    }

    obj["double_sha"] = dsha(json.dumps(obj, ensure_ascii=False, sort_keys=True))

    (ROOT / "feeds/kibra_mint_liquidity_report.json").write_text(
        json.dumps(obj, ensure_ascii=False, indent=2),
        encoding="utf-8"
    )

    rec_md = ""
    for rec in recs:
        rec_md += f"- **{rec['level']}** / `{rec['area']}`: {rec['recommendation']} Action: `{rec['action']}`\n"

    md = f"""# KIBRA Mint Liquidity Department

Status: **active**  
Parent: **KIBRA Mint Repair Department**

## Liquidity score

- Score: **{score}/100**
- Latest hash: `{latest_hash()}`

## Mined accounting

- Main blocks: **{accounting['main_blocks']}**
- Task blocks: **{accounting['task_blocks']}**
- Total mined KIBRA: **{accounting['total_mined_kibra']}**

## Pool reserves

- Status: **{reserves.get('status')}**
- Quote reserve USD: **{reserves.get('quote_reserve_usd')}**
- KIBRA reserve: **{reserves.get('kibra_reserve')}**
- Price USD/KIBRA: **{reserves.get('price_usd_per_kibra')}**
- Real market confirmed: **{reserves.get('real_market_confirmed')}**

## Liquidity plan

- File: `data/kibra_mint_liquidity/liquidity_plan.json`
- Real pool now: **false**
- Real sell now: **false**
- Manual OWNER approval required: **true**

## Recommendations

{rec_md}

## AI tasks

- Prepared: **{len(tasks)}**
- Submitted to block inbox: **{len(tasks) if submit_ai else 0}**

## Safety

- Fake price: **false**
- Fake volume: **false**
- Wash trading: **false**
- Guaranteed profit: **false**
- Real pool/sell/payment: **false**
- Manual OWNER approval required: **true**

## Double SHA

`{obj['double_sha']}`
"""

    (ROOT / "posts/kibra_mint_liquidity_report.md").write_text(md, encoding="utf-8")

    with (ROOT / "proofs/kibra_mint_liquidity.sha256").open("w") as f:
        subprocess.run([
            "sha256sum",
            "parliament/departments/kibra_mint_repair_department/liquidity_department/department.json",
            "parliament/kibra_mint_liquidity/policy.json",
            "data/kibra_mint_liquidity/liquidity_plan.json",
            "feeds/kibra_mint_liquidity_report.json",
            "posts/kibra_mint_liquidity_report.md"
        ], cwd=ROOT, stdout=f, stderr=subprocess.DEVNULL)

    r.lpush(AUDIT, json.dumps({
        "status": "kibra_mint_liquidity_report_generated",
        "score": score,
        "submit_ai": submit_ai,
        "double_sha": obj["double_sha"],
        "time": obj["time"]
    }, ensure_ascii=False))

    r.lpush(RECS, json.dumps({
        "status": "recommendations_generated",
        "recommendations": recs,
        "time": obj["time"],
        "double_sha": obj["double_sha"]
    }, ensure_ascii=False))

    print("✅ KIBRA mint liquidity report generated")
    print("LIQUIDITY_SCORE:", score)
    print("TOTAL_MINED_KIBRA:", accounting["total_mined_kibra"])
    print("PRICE_USD_PER_KIBRA:", reserves.get("price_usd_per_kibra"))
    print("AI_TASKS_PREPARED:", len(tasks))
    print("AI_SUBMITTED_TO_BLOCK_INBOX:", len(tasks) if submit_ai else 0)
    print("REPORT: posts/kibra_mint_liquidity_report.md")
    print("PROOF: proofs/kibra_mint_liquidity.sha256")

def set_reserves(quote_usd, kibra_reserve, source="manual_liquidity_reference"):
    obj = {
        "status": "manual_pool_reserves_recorded",
        "source": source,
        "quote_reserve_usd": str(quote_usd),
        "kibra_reserve": str(kibra_reserve),
        "real_market_confirmed": False,
        "note": "Reference reserves only. Real market confirmation requires verified provider/orderbook/pool proof and OWNER approval.",
        "time": time.time(),
        "time_iso": now_iso()
    }
    (ROOT / "data/kibra_market").mkdir(parents=True, exist_ok=True)
    (ROOT / "data/kibra_market/pool_reserves.json").write_text(
        json.dumps(obj, ensure_ascii=False, indent=2),
        encoding="utf-8"
    )
    print("✅ pool reserves reference recorded")
    print("Run: bash cybra_mint_liquidity.sh report")

def main():
    import sys
    cmd = sys.argv[1] if len(sys.argv) > 1 else "report"

    if cmd == "report":
        report(False)
    elif cmd == "submit-ai":
        report(True)
    elif cmd == "set-reserves":
        if len(sys.argv) < 4:
            raise SystemExit("Usage: set-reserves <quote_usd> <kibra_reserve> [source]")
        set_reserves(sys.argv[2], sys.argv[3], sys.argv[4] if len(sys.argv) > 4 else "manual_liquidity_reference")
    else:
        raise SystemExit("Usage: report|submit-ai|set-reserves")

if __name__ == "__main__":
    main()
PY

chmod +x cybra_kibra_mint_liquidity.py

cat > kibra_mint_liquidity_handler.sh <<'EOF2'
#!/data/data/com.termux/files/usr/bin/bash
set -e
cd "$HOME/CYBRA"

python3 cybra_kibra_mint_liquidity.py submit-ai

bash cybra_ai_block_enforcer.sh enforce 3 >/dev/null 2>&1 || true
bash cybra_mint_manage.sh report >/dev/null 2>&1 || true
bash cybra_kibra_stats.sh report >/dev/null 2>&1 || true
EOF2

chmod +x kibra_mint_liquidity_handler.sh

cat > cybra_mint_liquidity.sh <<'EOF2'
#!/data/data/com.termux/files/usr/bin/bash
set -e
cd "$HOME/CYBRA"

case "${1:-status}" in
  report|plan)
    python3 cybra_kibra_mint_liquidity.py report
    cat posts/kibra_mint_liquidity_report.md
    ;;
  submit-ai)
    python3 cybra_kibra_mint_liquidity.py submit-ai
    bash cybra_ai_block_enforcer.sh enforce 3 || true
    ;;
  set-reserves)
    python3 cybra_kibra_mint_liquidity.py set-reserves "$2" "$3" "${4:-manual_liquidity_reference}"
    ;;
  task)
    cybra parliament '{"topic":"KIBRA Mint Liquidity Department","type":"kibra_mint_liquidity_task","priority":"critical","payload":{"liquidity_department":true,"pool_reserves":true,"orderbook_depth":true,"sell_without_crash":true,"fake_price":false,"fake_volume":false,"real_pool_now":false,"real_sell_now":false,"manual_OWNER_approval_required":true}}'
    ;;
  cycle)
    python3 cybra_kibra_mint_liquidity.py submit-ai
    bash cybra_ai_block_enforcer.sh enforce 3 || true
    cybra parliament '{"topic":"KIBRA Mint Liquidity Department","type":"kibra_mint_liquidity_task","priority":"critical","payload":{"liquidity_department":true,"manual_OWNER_approval_required":true}}'
    python3 parliament_executor_v6.py || true
    python3 cybra_kibra_mint_liquidity.py report
    ;;
  until-done)
    python3 cybra_kibra_mint_liquidity.py submit-ai
    bash cybra_ai_block_enforcer.sh until-done 20 || true
    bash cybra_ai_until_done.sh run 300 || true
    python3 cybra_kibra_mint_liquidity.py report
    ;;
  status)
    redis-cli ping
    echo "MINT_LIQUIDITY_AUDIT: $(redis-cli LLEN cybra:kibra:mint_liquidity:audit)"
    echo "MINT_LIQUIDITY_RECS: $(redis-cli LLEN cybra:kibra:mint_liquidity:recommendations)"
    echo "MINT_LIQUIDITY_PLANS: $(redis-cli LLEN cybra:kibra:mint_liquidity:plans)"
    echo "BLOCK_INBOX: $(redis-cli LLEN cybra:ai:tasks:block_inbox)"
    echo "TASK_BLOCK_MEMPOOL: $(redis-cli LLEN cybra:kibra:task_blocks:mempool)"
    echo "TASK_BLOCKS_MINED: $(redis-cli LLEN cybra:kibra:task_blocks:mined)"
    echo "POOL_MINING_BLOCKS: $(redis-cli LLEN cybra:kibra:pool:mining_blocks)"
    echo "PARLIAMENT_QUEUE: $(redis-cli LLEN cybra:parliament:queue)"
    echo "PARLIAMENT_FAILED: $(redis-cli LLEN cybra:parliament:failed)"
    test -f posts/kibra_mint_liquidity_report.md && echo "REPORT: exists" || echo "REPORT: missing"
    test -f data/kibra_mint_liquidity/liquidity_plan.json && echo "LIQUIDITY_PLAN: exists" || echo "LIQUIDITY_PLAN: missing"
    ;;
  liquidity-plan)
    cat data/kibra_mint_liquidity/liquidity_plan.json
    ;;
  reserves)
    cat data/kibra_market/pool_reserves.json
    ;;
  proof)
    cat proofs/kibra_mint_liquidity.sha256
    ;;
  *)
    echo "Usage:"
    echo "  bash cybra_mint_liquidity.sh report"
    echo "  bash cybra_mint_liquidity.sh submit-ai"
    echo "  bash cybra_mint_liquidity.sh set-reserves <quote_usd> <kibra_reserve> <source>"
    echo "  bash cybra_mint_liquidity.sh task"
    echo "  bash cybra_mint_liquidity.sh cycle"
    echo "  bash cybra_mint_liquidity.sh until-done"
    echo "  bash cybra_mint_liquidity.sh status"
    echo "  bash cybra_mint_liquidity.sh liquidity-plan"
    echo "  bash cybra_mint_liquidity.sh reserves"
    ;;
esac
EOF2

chmod +x cybra_mint_liquidity.sh

redis-cli HSET cybra:executor:mapping kibra_mint_liquidity_task kibra_mint_liquidity_handler.sh >/dev/null

python3 - <<'PY'
from pathlib import Path

p = Path("parliament_executor_v6.py")
s = p.read_text()

if 'r.hget("cybra:executor:mapping", task_type)' not in s:
    old = "script_name = SCRIPT_MAP.get(task_type)"
    new = 'script_name = r.hget("cybra:executor:mapping", task_type) or SCRIPT_MAP.get(task_type)'
    if old in s:
        s = s.replace(old, new, 1)

if '"kibra_mint_liquidity_task"' not in s:
    i = s.find("SCRIPT_MAP")
    j = s.find("{", i)
    if i >= 0 and j >= 0:
        s = s[:j+1] + '\n    "kibra_mint_liquidity_task": "kibra_mint_liquidity_handler.sh",' + s[j+1:]

p.write_text(s)
print("✅ kibra_mint_liquidity_task mapping ready")
PY

rm -rf __pycache__
python3 -m py_compile cybra_kibra_mint_liquidity.py
python3 -m py_compile parliament_executor_v6.py
rm -rf __pycache__

echo
echo "=== CREATE LIQUIDITY REPORT ==="
bash cybra_mint_liquidity.sh submit-ai

echo
echo "=== ADD MASTER TASK TO PARLIAMENT ==="
bash cybra_mint_liquidity.sh task

echo
echo "=== EXECUTE ONE ROUND ==="
python3 parliament_executor_v6.py || true

echo
echo "=== STATUS ==="
bash cybra_mint_liquidity.sh status

echo
echo "=== PROOF CHECK ==="
sha256sum -c proofs/kibra_mint_liquidity.sha256 || true

echo
echo "✅ KIBRA MINT LIQUIDITY DEPARTMENT INSTALLED"
