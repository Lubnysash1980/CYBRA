#!/data/data/com.termux/files/usr/bin/bash
set -e
cd "$HOME/CYBRA"

echo "=== INSTALL KIBRA MINT MANAGEMENT + FINANCE DEPARTMENT ==="

mkdir -p \
  parliament/departments/kibra_mint_repair_department/management_department \
  parliament/departments/kibra_mint_repair_department/finance_department \
  parliament/kibra_mint_management \
  data/kibra_mint_management \
  data/kibra_mint_finance \
  posts feeds proofs logs/kibra_mint_management

redis-cli ping >/dev/null 2>&1 || redis-server --daemonize yes || true
sleep 1

python3 - <<'PY' >/dev/null 2>&1 || python3 -m pip install redis
import redis
PY

cat > parliament/departments/kibra_mint_repair_department/management_department/department.json <<'JSON'
{
  "department_id": "kibra_mint_management_department",
  "name": "KIBRA Mint Management Department",
  "parent_department": "kibra_mint_repair_department",
  "status": "active",
  "mission": "Менеджмент намайнених KIBRA: визначати найвигідніший спосіб реалізації через utility, пули, marketplace, OTC proposal, liquidity plan, staged sell plan та AI Parliament tasks.",
  "responsibilities": [
    "manage_mined_kibra_accounting",
    "choose_best_realization_strategy",
    "prepare_sell_without_crash_plan",
    "prepare_utility_monetization_plan",
    "prepare_liquidity_strategy",
    "coordinate_with_mint_finance_department",
    "coordinate_with_mint_audit_department",
    "coordinate_with_promotion_department",
    "send_ai_tasks_to_parliament"
  ],
  "blocked": [
    "automatic_real_sell",
    "automatic_exchange_trade",
    "fake_price",
    "fake_volume",
    "wash_trading",
    "guaranteed_profit",
    "external_tx_without_OWNER_approval"
  ],
  "manual_OWNER_approval_required": true
}
JSON

cat > parliament/departments/kibra_mint_repair_department/finance_department/department.json <<'JSON'
{
  "department_id": "kibra_mint_finance_department",
  "name": "KIBRA Mint Finance Department",
  "parent_department": "kibra_mint_repair_department",
  "status": "active",
  "mission": "Фінансовий облік і план реалізації намайнених KIBRA: reward accounting, treasury, liquidity, market-price check, slippage, staged sale proposal, reserve policy.",
  "responsibilities": [
    "mined_kibra_accounting",
    "pool_reward_accounting",
    "treasury_policy",
    "market_price_check",
    "sell_proposal",
    "slippage_risk_check",
    "daily_volume_limit",
    "OWNER_approval_gate",
    "profit_optimization_recommendations"
  ],
  "blocked": [
    "automatic_payment",
    "automatic_sell",
    "automatic_liquidity_pool",
    "fake_price",
    "fake_volume",
    "guaranteed_profit"
  ],
  "manual_OWNER_approval_required": true
}
JSON

cat > parliament/kibra_mint_management/policy.json <<'JSON'
{
  "name": "KIBRA Mint Management and Finance Policy",
  "status": "active",
  "native_coin": true,
  "external_mint": false,
  "goal": "Вигідно реалізувати намайнені KIBRA без фейкової ціни, без фейкового обʼєму і без автоматичного продажу.",
  "realization_methods": [
    "utility_sale",
    "AI_task_credits",
    "proof_services",
    "bridge_package_services",
    "developer_marketplace",
    "miner_pool_participation",
    "liquidity_plan",
    "staged_sell_proposal",
    "OTC_proposal_after_OWNER_approval"
  ],
  "rules": {
    "market_price_requires_liquidity": true,
    "blocks_confirm_emission_not_price": true,
    "sell_requires_market_price": true,
    "sell_requires_slippage_check": true,
    "sell_requires_OWNER_approval": true,
    "no_fake_price": true,
    "no_fake_volume": true,
    "no_guaranteed_profit": true
  },
  "execution": {
    "real_sell_now": false,
    "real_payment_now": false,
    "real_exchange_trade_now": false,
    "manual_OWNER_approval_required": true
  }
}
JSON

cat > cybra_kibra_mint_management.py <<'PY'
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

AUDIT = "cybra:kibra:mint_management:audit"
FIN_AUDIT = "cybra:kibra:mint_finance:audit"
SELL_PLANS = "cybra:kibra:mint_finance:sell_plans"
RECS = "cybra:kibra:mint_management:recommendations"
AIQ = "cybra:ai:tasks:kibra_mint_management"

DEFAULT_BLOCK_REWARD = Decimal("100")

def sha(x):
    return hashlib.sha256(x.encode("utf-8")).hexdigest()

def dsha(x):
    return sha(sha(x))

def now_iso():
    return time.strftime("%Y-%m-%dT%H:%M:%S%z")

def exists(path):
    return (ROOT / path).exists()

def redis_len(key):
    try:
        return r.llen(key)
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

def git_cmd(cmd):
    try:
        return subprocess.check_output(cmd, cwd=ROOT, text=True, stderr=subprocess.DEVNULL).strip()
    except Exception:
        return ""

def count_main_blocks():
    d = ROOT / "blockchain/kibra_chain/blocks"
    if not d.exists():
        return 0
    return len(list(d.glob("block_*.json")))

def count_task_blocks():
    d = ROOT / "blockchain/kibra_chain/task_blocks"
    if not d.exists():
        return 0
    return len(list(d.glob("*.json")))

def read_reward_policy():
    path = ROOT / "data/kibra_mint_finance/reward_policy.json"
    if not path.exists():
        obj = {
            "status": "default_reward_policy_created",
            "block_reward_kibra": str(DEFAULT_BLOCK_REWARD),
            "task_block_reward_kibra": str(DEFAULT_BLOCK_REWARD),
            "real_payout_now": False,
            "note": "Accounting only. Edit this file if KIBRA reward policy changes."
        }
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(json.dumps(obj, ensure_ascii=False, indent=2), encoding="utf-8")
        return obj
    return load_json("data/kibra_mint_finance/reward_policy.json")

def market_price():
    reserves = load_json("data/kibra_market/pool_reserves.json")
    if reserves:
        try:
            quote = Decimal(str(reserves.get("quote_reserve_usd", "0")))
            kibra = Decimal(str(reserves.get("kibra_reserve", "0")))
            if quote > 0 and kibra > 0:
                price = quote / kibra
                return {
                    "status": "reference_price_available",
                    "price_usd_per_kibra": str(price),
                    "source": reserves.get("source", "pool_reserves"),
                    "real_market_confirmed": bool(reserves.get("real_market_confirmed", False)),
                    "quote_reserve_usd": str(quote),
                    "kibra_reserve": str(kibra)
                }
        except Exception as e:
            return {
                "status": "invalid_price_source",
                "price_usd_per_kibra": "0",
                "error": str(e),
                "real_market_confirmed": False
            }

    price_report = load_json("feeds/kibra_price_sell_repair_report.json")
    p = price_report.get("market_price", {}) if price_report else {}
    if p.get("price_usd_per_kibra") and p.get("price_usd_per_kibra") != "0":
        return p

    return {
        "status": "no_real_market_price_yet",
        "price_usd_per_kibra": "0",
        "real_market_confirmed": False,
        "reason": "Blocks and mining confirm emission/proof, but sell price requires real liquidity/orderbook/buyers."
    }

def mined_accounting():
    reward = read_reward_policy()
    block_reward = Decimal(str(reward.get("block_reward_kibra", DEFAULT_BLOCK_REWARD)))
    task_block_reward = Decimal(str(reward.get("task_block_reward_kibra", DEFAULT_BLOCK_REWARD)))

    main_blocks = count_main_blocks()
    task_blocks = count_task_blocks()

    main_reward = Decimal(main_blocks) * block_reward
    task_reward = Decimal(task_blocks) * task_block_reward
    total = main_reward + task_reward

    pool_confirm = load_json("feeds/kibra_pool_confirm_report.json")
    shares_total = pool_confirm.get("shares_total", 0) if pool_confirm else 0

    return {
        "main_blocks": main_blocks,
        "task_blocks": task_blocks,
        "block_reward_kibra": str(block_reward),
        "task_block_reward_kibra": str(task_block_reward),
        "main_reward_accounting_kibra": str(main_reward),
        "task_reward_accounting_kibra": str(task_reward),
        "total_mined_accounting_kibra": str(total),
        "pool_shares_total": shares_total,
        "real_payout_now": False,
        "accounting_only": True
    }

def choose_strategy(accounting, price):
    total = Decimal(str(accounting["total_mined_accounting_kibra"]))
    price_usd = Decimal(str(price.get("price_usd_per_kibra", "0")))

    if price_usd > 0 and price.get("real_market_confirmed"):
        value = total * price_usd
        strategy = "staged_market_sell_proposal"
        reason = "Real market price confirmed. Prepare staged sell proposal with slippage and volume limits."
    elif price_usd > 0 and not price.get("real_market_confirmed"):
        value = total * price_usd
        strategy = "reference_price_hold_or_utility_sale"
        reason = "Reference price exists but real market is not confirmed. Do not sell automatically; prepare utility sale and verification."
    else:
        value = Decimal("0")
        strategy = "utility_first_no_market_sell"
        reason = "No market price yet. Best realization is utility monetization: AI credits, proof services, bridge packages, marketplace."

    return {
        "strategy": strategy,
        "reason": reason,
        "estimated_value_usd": str(value),
        "market_price_usd_per_kibra": str(price_usd),
        "real_market_confirmed": bool(price.get("real_market_confirmed", False)),
        "sell_allowed_now": False,
        "owner_approval_required": True
    }

def build_sell_plan(accounting, price, strategy):
    total = Decimal(str(accounting["total_mined_accounting_kibra"]))
    price_usd = Decimal(str(price.get("price_usd_per_kibra", "0")))

    conservative_sell = total * Decimal("0.01")
    moderate_sell = total * Decimal("0.03")
    max_sell = total * Decimal("0.05")

    plan = {
        "status": "sell_plan_created",
        "time": time.time(),
        "time_iso": now_iso(),
        "native_coin": "KIBRA",
        "accounting": accounting,
        "market_price": price,
        "strategy": strategy,
        "sell_tiers": {
            "conservative_1_percent": {
                "kibra": str(conservative_sell),
                "estimated_usd": str(conservative_sell * price_usd)
            },
            "moderate_3_percent": {
                "kibra": str(moderate_sell),
                "estimated_usd": str(moderate_sell * price_usd)
            },
            "maximum_planned_5_percent": {
                "kibra": str(max_sell),
                "estimated_usd": str(max_sell * price_usd)
            }
        },
        "risk_controls": [
            "do not sell without real liquidity",
            "check orderbook depth",
            "check slippage",
            "sell in stages",
            "avoid dumping",
            "no fake volume",
            "no wash trading",
            "manual OWNER approval required"
        ],
        "real_sell_now": False,
        "automatic_exchange_trade": False,
        "manual_OWNER_approval_required": True
    }

    plan["double_sha"] = dsha(json.dumps(plan, ensure_ascii=False, sort_keys=True))

    (ROOT / "data/kibra_mint_finance/sell_plan.json").write_text(
        json.dumps(plan, ensure_ascii=False, indent=2),
        encoding="utf-8"
    )

    r.lpush(SELL_PLANS, json.dumps(plan, ensure_ascii=False))
    return plan

def build_recommendations(accounting, price, strategy):
    recs = []

    if Decimal(str(price.get("price_usd_per_kibra", "0"))) == 0:
        recs.append({
            "level": "critical",
            "area": "market_price",
            "recommendation": "Ринкової ціни ще нема. Не продавати. Спочатку створити liquidity/orderbook/buyers або utility-marketplace.",
            "action": "bash cybra_kibra_price.sh report"
        })

    if not price.get("real_market_confirmed", False):
        recs.append({
            "level": "important",
            "area": "liquidity",
            "recommendation": "Підготувати реальний liquidity proof або marketplace demand proof перед продажем.",
            "action": "bash cybra_kibra_market.sh report"
        })

    if redis_len("cybra:kibra:task_blocks:mempool") > 0:
        recs.append({
            "level": "important",
            "area": "ai_task_blocks",
            "recommendation": "Є AI task-block mempool. Спочатку домайнити блоки пулами.",
            "action": "bash cybra_ai_blocks.sh until-done"
        })

    if redis_len("cybra:kibra:mint_repair:queue") > 0:
        recs.append({
            "level": "repair",
            "area": "mint_repair",
            "recommendation": "Є черга ремонту монетного двору. Перед реалізацією закрити repair queue.",
            "action": "bash cybra_kibra_price.sh report"
        })

    recs.append({
        "level": "growth",
        "area": "utility_realization",
        "recommendation": "Вигідна реалізація без ринку: продавати не монету напряму, а utility-пакети: AI credits, proof, bridge, developer marketplace.",
        "action": "bash cybra_mint_promo.sh report"
    })

    recs.append({
        "level": "finance",
        "area": "staged_sell",
        "recommendation": "Коли зʼявиться реальний ринок — реалізовувати staged sell: 1%, 3%, максимум 5% партіями, з перевіркою slippage.",
        "action": "manual OWNER approval only"
    })

    return recs

def build_ai_tasks(recs):
    tasks = []
    for i, rec in enumerate(recs, 1):
        task_type = "kibra_mint_management_task"

        if rec["area"] == "market_price":
            task_type = "kibra_price_sell_repair_task"
        elif rec["area"] == "liquidity":
            task_type = "kibra_market_exchange_task"
        elif rec["area"] == "ai_task_blocks":
            task_type = "ai_tasks_to_blocks_task"
        elif rec["area"] == "mint_repair":
            task_type = "kibra_mint_audit_task"
        elif rec["area"] == "utility_realization":
            task_type = "kibra_mint_promotion_task"

        tasks.append({
            "topic": f"KIBRA Mint Management Finance Recommendation {i}: {rec['area']}",
            "type": task_type,
            "priority": "high",
            "payload": {
                "source": "kibra_mint_management_department",
                "finance_department": "kibra_mint_finance_department",
                "area": rec["area"],
                "recommendation": rec["recommendation"],
                "suggested_action": rec["action"],
                "real_sell_now": False,
                "automatic_exchange_trade": False,
                "fake_price": False,
                "fake_volume": False,
                "guaranteed_profit": False,
                "manual_OWNER_approval_required": True
            }
        })

    return tasks

def report(submit_ai=False):
    for d in ["posts", "feeds", "proofs", "data/kibra_mint_management", "data/kibra_mint_finance"]:
        (ROOT / d).mkdir(parents=True, exist_ok=True)

    accounting = mined_accounting()
    price = market_price()
    strategy = choose_strategy(accounting, price)
    sell_plan = build_sell_plan(accounting, price, strategy)
    recs = build_recommendations(accounting, price, strategy)
    tasks = build_ai_tasks(recs)

    if submit_ai:
        for t in tasks:
            r.lpush(AIQ, json.dumps(t, ensure_ascii=False))

    report_obj = {
        "status": "kibra_mint_management_finance_report_generated",
        "time": time.time(),
        "time_iso": now_iso(),
        "submit_ai": submit_ai,
        "latest_kibra_hash": latest_hash(),
        "accounting": accounting,
        "market_price": price,
        "strategy": strategy,
        "sell_plan_file": "data/kibra_mint_finance/sell_plan.json",
        "recommendations": recs,
        "ai_tasks_prepared": len(tasks),
        "ai_tasks_submitted": len(tasks) if submit_ai else 0,
        "redis": {
            "management_audit": redis_len(AUDIT),
            "finance_audit": redis_len(FIN_AUDIT),
            "sell_plans": redis_len(SELL_PLANS),
            "ai_queue": redis_len(AIQ),
            "parliament_queue": redis_len("cybra:parliament:queue"),
            "parliament_failed": redis_len("cybra:parliament:failed"),
            "task_blocks_mined": redis_len("cybra:kibra:task_blocks:mined"),
            "pool_mining_blocks": redis_len("cybra:kibra:pool:mining_blocks"),
            "mint_repair_queue": redis_len("cybra:kibra:mint_repair:queue")
        },
        "git": {
            "branch": git_cmd(["git", "branch", "--show-current"]),
            "commit": git_cmd(["git", "rev-parse", "--short", "HEAD"]),
            "dirty_files": len(git_cmd(["git", "status", "--short"]).splitlines())
        },
        "safety": {
            "real_sell_now": False,
            "automatic_exchange_trade": False,
            "real_payment_now": False,
            "fake_price": False,
            "fake_volume": False,
            "guaranteed_profit": False,
            "manual_OWNER_approval_required": True
        }
    }

    report_obj["double_sha"] = dsha(json.dumps(report_obj, ensure_ascii=False, sort_keys=True))

    (ROOT / "feeds/kibra_mint_management_finance_report.json").write_text(
        json.dumps(report_obj, ensure_ascii=False, indent=2),
        encoding="utf-8"
    )

    rec_md = ""
    for rec in recs:
        rec_md += f"- **{rec['level']}** / `{rec['area']}`: {rec['recommendation']} Action: `{rec['action']}`\n"

    md = f"""# KIBRA Mint Management + Finance Department

Status: **active**  
Parent: **KIBRA Mint Repair Department**

## Purpose

Відділ менеджменту і фінвідділ монетного двору готують найвигіднішу реалізацію намайнених KIBRA.

## Accounting

- Main blocks: **{accounting['main_blocks']}**
- Task blocks: **{accounting['task_blocks']}**
- Block reward KIBRA: **{accounting['block_reward_kibra']}**
- Task block reward KIBRA: **{accounting['task_block_reward_kibra']}**
- Total mined accounting KIBRA: **{accounting['total_mined_accounting_kibra']}**
- Pool shares total: **{accounting['pool_shares_total']}**

## Market price

- Status: **{price.get('status')}**
- Price USD per KIBRA: `{price.get('price_usd_per_kibra')}`
- Real market confirmed: **{price.get('real_market_confirmed')}**

## Strategy

- Selected strategy: **{strategy['strategy']}**
- Reason: {strategy['reason']}
- Estimated value USD: `{strategy['estimated_value_usd']}`
- Sell allowed now: **false**
- Manual OWNER approval required: **true**

## Sell plan

- File: `data/kibra_mint_finance/sell_plan.json`
- Conservative: 1%
- Moderate: 3%
- Max planned: 5%
- Real sell now: **false**

## Recommendations

{rec_md}

## Safety

- Real sell now: **false**
- Automatic exchange trade: **false**
- Fake price: **false**
- Fake volume: **false**
- Guaranteed profit: **false**
- Manual OWNER approval required: **true**

## Double SHA

`{report_obj['double_sha']}`
"""

    (ROOT / "posts/kibra_mint_management_finance_report.md").write_text(md, encoding="utf-8")

    with (ROOT / "proofs/kibra_mint_management_finance.sha256").open("w") as f:
        subprocess.run([
            "sha256sum",
            "parliament/departments/kibra_mint_repair_department/management_department/department.json",
            "parliament/departments/kibra_mint_repair_department/finance_department/department.json",
            "parliament/kibra_mint_management/policy.json",
            "data/kibra_mint_finance/reward_policy.json",
            "data/kibra_mint_finance/sell_plan.json",
            "feeds/kibra_mint_management_finance_report.json",
            "posts/kibra_mint_management_finance_report.md"
        ], cwd=ROOT, stdout=f, stderr=subprocess.DEVNULL)

    r.lpush(AUDIT, json.dumps({
        "status": "kibra_mint_management_report_generated",
        "strategy": strategy["strategy"],
        "estimated_value_usd": strategy["estimated_value_usd"],
        "ai_tasks": len(tasks),
        "submit_ai": submit_ai,
        "double_sha": report_obj["double_sha"],
        "time": report_obj["time"]
    }, ensure_ascii=False))

    r.lpush(FIN_AUDIT, json.dumps({
        "status": "kibra_mint_finance_report_generated",
        "total_mined_accounting_kibra": accounting["total_mined_accounting_kibra"],
        "market_price": price,
        "sell_plan": sell_plan["double_sha"],
        "time": report_obj["time"]
    }, ensure_ascii=False))

    r.lpush(RECS, json.dumps({
        "status": "recommendations_generated",
        "recommendations": recs,
        "time": report_obj["time"],
        "double_sha": report_obj["double_sha"]
    }, ensure_ascii=False))

    print("✅ KIBRA mint management + finance report generated")
    print("TOTAL_MINED_ACCOUNTING_KIBRA:", accounting["total_mined_accounting_kibra"])
    print("STRATEGY:", strategy["strategy"])
    print("ESTIMATED_VALUE_USD:", strategy["estimated_value_usd"])
    print("AI_TASKS_PREPARED:", len(tasks))
    print("AI_SUBMITTED:", submit_ai)
    print("REPORT: posts/kibra_mint_management_finance_report.md")
    print("PROOF: proofs/kibra_mint_management_finance.sha256")

def main():
    import sys
    cmd = sys.argv[1] if len(sys.argv) > 1 else "report"
    if cmd == "report":
        report(False)
    elif cmd == "submit-ai":
        report(True)
    else:
        raise SystemExit("Usage: report|submit-ai")

if __name__ == "__main__":
    main()
PY

chmod +x cybra_kibra_mint_management.py

cat > kibra_mint_management_handler.sh <<'EOF2'
#!/data/data/com.termux/files/usr/bin/bash
set -e
cd "$HOME/CYBRA"

python3 cybra_kibra_mint_management.py submit-ai

bash cybra_kibra_price.sh report >/dev/null 2>&1 || true
bash cybra_mint_audit.sh submit-ai >/dev/null 2>&1 || true
bash cybra_mint_promo.sh submit-ai >/dev/null 2>&1 || true
bash cybra_ai_blocks.sh cycle >/dev/null 2>&1 || true
EOF2

chmod +x kibra_mint_management_handler.sh

cat > cybra_mint_manage.sh <<'EOF2'
#!/data/data/com.termux/files/usr/bin/bash
set -e
cd "$HOME/CYBRA"

case "${1:-status}" in
  report)
    python3 cybra_kibra_mint_management.py report
    cat posts/kibra_mint_management_finance_report.md
    ;;
  submit-ai)
    python3 cybra_kibra_mint_management.py submit-ai
    ;;
  task)
    cybra parliament '{"topic":"KIBRA Mint Management and Finance Department","type":"kibra_mint_management_task","priority":"critical","payload":{"manage_mined_kibra":true,"profitable_realization_plan":true,"sell_without_crash":true,"utility_monetization":true,"finance_department":true,"real_sell_now":false,"fake_price":false,"fake_volume":false,"manual_OWNER_approval_required":true}}'
    ;;
  cycle)
    python3 cybra_kibra_mint_management.py submit-ai
    cybra parliament '{"topic":"KIBRA Mint Management and Finance Department","type":"kibra_mint_management_task","priority":"critical","payload":{"manage_mined_kibra":true,"profitable_realization_plan":true,"finance_department":true,"manual_OWNER_approval_required":true}}'
    python3 parliament_executor_v6.py || true
    python3 cybra_kibra_mint_management.py report
    cat posts/kibra_mint_management_finance_report.md
    ;;
  until-done)
    python3 cybra_kibra_mint_management.py submit-ai
    bash cybra_ai_blocks.sh until-done || true
    bash cybra_ai_until_done.sh run 300 || true
    python3 cybra_kibra_mint_management.py report
    ;;
  status)
    redis-cli ping
    echo "MINT_MANAGEMENT_AUDIT: $(redis-cli LLEN cybra:kibra:mint_management:audit)"
    echo "MINT_FINANCE_AUDIT: $(redis-cli LLEN cybra:kibra:mint_finance:audit)"
    echo "MINT_FINANCE_SELL_PLANS: $(redis-cli LLEN cybra:kibra:mint_finance:sell_plans)"
    echo "MINT_MANAGEMENT_RECS: $(redis-cli LLEN cybra:kibra:mint_management:recommendations)"
    echo "MINT_MANAGEMENT_AI_QUEUE: $(redis-cli LLEN cybra:ai:tasks:kibra_mint_management)"
    echo "TASK_BLOCKS_MINED: $(redis-cli LLEN cybra:kibra:task_blocks:mined)"
    echo "POOL_MINING_BLOCKS: $(redis-cli LLEN cybra:kibra:pool:mining_blocks)"
    echo "PARLIAMENT_QUEUE: $(redis-cli LLEN cybra:parliament:queue)"
    echo "PARLIAMENT_FAILED: $(redis-cli LLEN cybra:parliament:failed)"
    test -f posts/kibra_mint_management_finance_report.md && echo "REPORT: exists" || echo "REPORT: missing"
    test -f data/kibra_mint_finance/sell_plan.json && echo "SELL_PLAN: exists" || echo "SELL_PLAN: missing"
    ;;
  sell-plan)
    cat data/kibra_mint_finance/sell_plan.json
    ;;
  reward-policy)
    cat data/kibra_mint_finance/reward_policy.json
    ;;
  feed)
    cat feeds/kibra_mint_management_finance_report.json
    ;;
  proof)
    cat proofs/kibra_mint_management_finance.sha256
    ;;
  *)
    echo "Usage:"
    echo "  bash cybra_mint_manage.sh report"
    echo "  bash cybra_mint_manage.sh submit-ai"
    echo "  bash cybra_mint_manage.sh task"
    echo "  bash cybra_mint_manage.sh cycle"
    echo "  bash cybra_mint_manage.sh until-done"
    echo "  bash cybra_mint_manage.sh status"
    echo "  bash cybra_mint_manage.sh sell-plan"
    echo "  bash cybra_mint_manage.sh reward-policy"
    echo "  bash cybra_mint_manage.sh feed"
    echo "  bash cybra_mint_manage.sh proof"
    ;;
esac
EOF2

chmod +x cybra_mint_manage.sh

redis-cli HSET cybra:executor:mapping kibra_mint_management_task kibra_mint_management_handler.sh >/dev/null

python3 - <<'PY'
from pathlib import Path

p = Path("parliament_executor_v6.py")
s = p.read_text()

if 'r.hget("cybra:executor:mapping", task_type)' not in s:
    old = "script_name = SCRIPT_MAP.get(task_type)"
    new = 'script_name = r.hget("cybra:executor:mapping", task_type) or SCRIPT_MAP.get(task_type)'
    if old in s:
        s = s.replace(old, new, 1)

if '"kibra_mint_management_task"' not in s:
    i = s.find("SCRIPT_MAP")
    j = s.find("{", i)
    if i >= 0 and j >= 0:
        s = s[:j+1] + '\n    "kibra_mint_management_task": "kibra_mint_management_handler.sh",' + s[j+1:]

p.write_text(s)
print("✅ kibra_mint_management_task mapping ready")
PY

rm -rf __pycache__
python3 -m py_compile cybra_kibra_mint_management.py
python3 -m py_compile parliament_executor_v6.py
rm -rf __pycache__

echo
echo "=== CREATE MANAGEMENT + FINANCE REPORT ==="
bash cybra_mint_manage.sh submit-ai

echo
echo "=== ADD MASTER TASK TO PARLIAMENT ==="
bash cybra_mint_manage.sh task

echo
echo "=== EXECUTE ONE ROUND ==="
python3 parliament_executor_v6.py || true

echo
echo "=== STATUS ==="
bash cybra_mint_manage.sh status

echo
echo "=== PROOF CHECK ==="
sha256sum -c proofs/kibra_mint_management_finance.sha256 || true

echo
echo "✅ KIBRA MINT MANAGEMENT + FINANCE DEPARTMENT INSTALLED"
