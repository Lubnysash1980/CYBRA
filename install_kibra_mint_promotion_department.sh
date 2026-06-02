#!/data/data/com.termux/files/usr/bin/bash
set -e
cd "$HOME/CYBRA"

echo "=== INSTALL KIBRA MINT PROMOTION DEPARTMENT ==="

mkdir -p \
  parliament/departments/kibra_mint_repair_department/promotion_department \
  parliament/kibra_mint_promotion \
  data/kibra_mint_promotion \
  website/kibra \
  posts feeds proofs logs/kibra_mint_promotion

redis-cli ping >/dev/null 2>&1 || redis-server --daemonize yes || true
sleep 1

python3 - <<'PY' >/dev/null 2>&1 || python3 -m pip install redis
import redis
PY

cat > parliament/departments/kibra_mint_repair_department/promotion_department/department.json <<'JSON'
{
  "department_id": "kibra_mint_promotion_department",
  "name": "KIBRA Mint Promotion Department",
  "parent_department": "kibra_mint_repair_department",
  "status": "active",
  "mission": "Просувати KIBRA native coin, AI-task mining blocks, pool mining, bridge proof, difficulty classes, website/explorer, utility and marketplace adoption.",
  "promotion_targets": [
    "native_kibra_coin",
    "ai_tasks_to_mining_blocks",
    "pool_mining_blocks",
    "difficulty_classes",
    "closed_sha_bridge",
    "block_ai_support",
    "website_explorer",
    "utility_marketplace",
    "developer_services",
    "proof_services"
  ],
  "allowed": [
    "promotion_plan",
    "utility_plan",
    "documentation",
    "website_page",
    "community_outreach_plan",
    "miner_onboarding_plan",
    "listing_readiness_plan",
    "ai_parliament_tasks",
    "proof_report"
  ],
  "blocked": [
    "fake_price",
    "fake_volume",
    "wash_trading",
    "pump_and_dump",
    "guaranteed_profit",
    "automatic_real_ads_payment",
    "automatic_token_sell",
    "automatic_exchange_trade"
  ],
  "manual_OWNER_approval_required": true
}
JSON

cat > parliament/kibra_mint_promotion/policy.json <<'JSON'
{
  "name": "KIBRA Mint Promotion Policy",
  "status": "active",
  "mode": "promotion_and_adoption_only",
  "native_coin": true,
  "external_mint": false,
  "main_rule": "Promotion must be based on utility, proof, miners, blocks, AI tasks, bridge packages and real adoption. No fake market activity.",
  "goals": [
    "explain_native_kibra_coin",
    "show_confirmed_blocks",
    "show_pool_mined_ai_task_blocks",
    "show_difficulty_classes",
    "show_closed_sha_bridge",
    "show_explorer",
    "prepare_miner_onboarding",
    "prepare_utility_marketplace",
    "prepare_listing_readiness",
    "prepare_community_growth"
  ],
  "safety": {
    "no_fake_price": true,
    "no_fake_volume": true,
    "no_wash_trading": true,
    "no_guaranteed_profit": true,
    "real_ads_payment_now": false,
    "real_sell_now": false,
    "manual_OWNER_approval_required": true
  }
}
JSON

cat > cybra_kibra_mint_promotion.py <<'PY'
#!/usr/bin/env python3
import json
import time
import hashlib
import subprocess
from pathlib import Path

import redis

ROOT = Path.home() / "CYBRA"
r = redis.Redis(host="127.0.0.1", port=6379, decode_responses=True)

AUDIT = "cybra:kibra:mint_promotion:audit"
RECS = "cybra:kibra:mint_promotion:recommendations"
AIQ = "cybra:ai:tasks:kibra_mint_promotion"

def sha(x):
    return hashlib.sha256(x.encode("utf-8")).hexdigest()

def dsha(x):
    return sha(sha(x))

def now_iso():
    return time.strftime("%Y-%m-%dT%H:%M:%S%z")

def redis_len(k):
    try:
        return r.llen(k)
    except Exception:
        return 0

def file_exists(path):
    return (ROOT / path).exists()

def file_sha(path):
    p = ROOT / path
    if not p.exists():
        return None
    h = hashlib.sha256()
    with p.open("rb") as f:
        for c in iter(lambda: f.read(1024 * 1024), b""):
            h.update(c)
    return h.hexdigest()

def latest_hash():
    p = ROOT / "blockchain/kibra_chain/latest.block.hash"
    return p.read_text().strip() if p.exists() else None

def load_json(path):
    p = ROOT / path
    if not p.exists():
        return {}
    try:
        return json.loads(p.read_text(encoding="utf-8"))
    except Exception:
        return {}

def build_state():
    return {
        "native_kibra": file_exists("feeds/native_kibra_ai_task_package.json"),
        "kibra_chain": file_exists("feeds/kibra_token_chain_status.json"),
        "pool_confirm": file_exists("feeds/kibra_pool_confirm_report.json"),
        "difficulty_classes": file_exists("feeds/kibra_difficulty_classes_report.json"),
        "bridge": file_exists("feeds/kibra_bridge_pool_monetization_report.json"),
        "block_ai_support": file_exists("feeds/kibra_block_ai_support_report.json"),
        "ai_tasks_to_blocks": file_exists("feeds/ai_tasks_to_mining_blocks_report.json"),
        "price_sell_repair": file_exists("feeds/kibra_price_sell_repair_report.json"),
        "website": file_exists("website/kibra/index.html"),
        "explorer": file_exists("website/kibra/explorer.html"),
        "logo": file_exists("token/kibra/native/assets/kibra_token.png")
    }

def build_recommendations(state):
    recs = []

    if not state["native_kibra"]:
        recs.append({
            "area": "native_coin",
            "level": "critical",
            "recommendation": "Створити або оновити Native KIBRA package: policy, PNG, website, explorer.",
            "action": "bash cybra_native_kibra.sh build"
        })

    if not state["pool_confirm"]:
        recs.append({
            "area": "pool_blocks",
            "level": "critical",
            "recommendation": "Зафіксувати pool-confirmation report для блоків і shares.",
            "action": "bash cybra_pool_confirm_report.sh"
        })

    if not state["ai_tasks_to_blocks"]:
        recs.append({
            "area": "ai_task_blocks",
            "level": "critical",
            "recommendation": "Переводити незавершені AI-завдання у mining task-blocks для пулів.",
            "action": "bash cybra_ai_blocks.sh cycle"
        })

    if not state["block_ai_support"]:
        recs.append({
            "area": "block_ai_support",
            "level": "important",
            "recommendation": "Кожен mined block має створювати AI-support task для парламенту.",
            "action": "bash cybra_kibra_block_ai.sh submit"
        })

    if not state["difficulty_classes"]:
        recs.append({
            "area": "difficulty_classes",
            "level": "important",
            "recommendation": "Просувати KIBRA по класах складності: KIBRA(2,+inf), KIBRA-D2/D3/D4.",
            "action": "bash cybra_kibra_difficulty.sh submit-ai"
        })

    if not state["bridge"]:
        recs.append({
            "area": "bridge",
            "level": "important",
            "recommendation": "Оновити closed SHA bridge package для доказу блоків.",
            "action": "bash cybra_kibra_bridge.sh submit-ai"
        })

    recs.append({
        "area": "promotion",
        "level": "growth",
        "recommendation": "Створити сторінку просування KIBRA: що це native coin, блоки, пули, AI tasks, bridge proof, utility.",
        "action": "generate website/kibra/promotion.html"
    })

    recs.append({
        "area": "miners",
        "level": "growth",
        "recommendation": "Підготувати onboarding для майнерів: як блоки з AI-завданнями попадають у пул і підтверджуються.",
        "action": "create miner onboarding plan"
    })

    recs.append({
        "area": "utility",
        "level": "growth",
        "recommendation": "Просувати KIBRA через корисність: AI task credits, proof services, bridge packages, developer marketplace.",
        "action": "create utility marketplace promotion plan"
    })

    recs.append({
        "area": "listing_readiness",
        "level": "growth",
        "recommendation": "Готувати listing-readiness пакет: docs, explorer, proof, supply/emission, pool accounting, community.",
        "action": "create listing readiness checklist"
    })

    return recs

def build_ai_tasks(recs):
    tasks = []
    for i, rec in enumerate(recs, 1):
        task_type = "kibra_mint_promotion_task"

        if rec["area"] == "ai_task_blocks":
            task_type = "ai_tasks_to_blocks_task"
        elif rec["area"] == "block_ai_support":
            task_type = "kibra_block_ai_support_task"
        elif rec["area"] == "difficulty_classes":
            task_type = "kibra_difficulty_classes_task"
        elif rec["area"] == "bridge":
            task_type = "kibra_bridge_pool_task"
        elif rec["area"] == "native_coin":
            task_type = "native_kibra_evolution_task"

        tasks.append({
            "topic": f"KIBRA Mint Promotion: {rec['area']}",
            "type": task_type,
            "priority": "high",
            "payload": {
                "source": "kibra_mint_promotion_department",
                "area": rec["area"],
                "recommendation": rec["recommendation"],
                "suggested_action": rec["action"],
                "promotion_allowed": True,
                "fake_price": False,
                "fake_volume": False,
                "wash_trading": False,
                "guaranteed_profit": False,
                "real_ads_payment_now": False,
                "real_sell_now": False,
                "manual_OWNER_approval_required": True
            }
        })

    return tasks

def create_promotion_assets(state, recs):
    plan = {
        "status": "kibra_mint_promotion_plan_created",
        "time": time.time(),
        "time_iso": now_iso(),
        "native_coin": "KIBRA",
        "latest_kibra_hash": latest_hash(),
        "promotion_message": {
            "headline": "KIBRA — native AI-task blockchain coin",
            "points": [
                "KIBRA is native coin of own proof chain",
                "AI tasks are converted into mining task-blocks",
                "Pools mine blocks with AI tasks",
                "Difficulty classes identify proof grade",
                "Closed SHA bridge prepares proof packages",
                "Utility-first monetization, no fake price"
            ]
        },
        "channels": [
            "website",
            "explorer",
            "whitepaper",
            "GitHub",
            "miner onboarding",
            "developer marketplace",
            "AI Parliament reports",
            "proof certificates"
        ],
        "utility": [
            "AI task credits",
            "block proof verification",
            "bridge package proof",
            "developer support credits",
            "marketplace services",
            "pool mining participation"
        ],
        "state": state,
        "recommendations": recs,
        "safety": {
            "no_fake_price": True,
            "no_fake_volume": True,
            "no_guaranteed_profit": True,
            "manual_OWNER_approval_required": True
        }
    }

    (ROOT / "data/kibra_mint_promotion/promotion_plan.json").write_text(
        json.dumps(plan, ensure_ascii=False, indent=2),
        encoding="utf-8"
    )

    html = f"""<!doctype html>
<html>
<head>
<meta charset="utf-8">
<title>KIBRA Promotion</title>
</head>
<body>
<h1>KIBRA Native Coin</h1>

<p><b>KIBRA</b> is a native coin of the CYBRA proof blockchain.</p>

<h2>Core idea</h2>
<ul>
<li>AI tasks are converted into mining task-blocks.</li>
<li>Pools mine blocks with AI tasks.</li>
<li>Confirmed blocks create proof and pool accounting.</li>
<li>Difficulty classes: KIBRA(2,+inf), KIBRA-D2, KIBRA-D3, KIBRA-D4.</li>
<li>Closed SHA bridge prepares sealed proof packages.</li>
</ul>

<h2>Latest chain hash</h2>
<code>{latest_hash()}</code>

<h2>Utility</h2>
<ul>
<li>AI task credits</li>
<li>Proof verification services</li>
<li>Bridge packages</li>
<li>Developer marketplace</li>
<li>Pool mining participation</li>
</ul>

<h2>Safety</h2>
<p>No fake price. No fake volume. No guaranteed profit. Real launch requires OWNER approval.</p>

<p><a href="index.html">Back to KIBRA site</a></p>
</body>
</html>
"""
    (ROOT / "website/kibra/promotion.html").write_text(html, encoding="utf-8")

    return plan

def report(submit_ai=False):
    for d in ["posts", "feeds", "proofs", "data/kibra_mint_promotion", "website/kibra"]:
        (ROOT / d).mkdir(parents=True, exist_ok=True)

    state = build_state()
    recs = build_recommendations(state)
    tasks = build_ai_tasks(recs)
    plan = create_promotion_assets(state, recs)

    if submit_ai:
        for task in tasks:
            r.lpush(AIQ, json.dumps(task, ensure_ascii=False))

    report_obj = {
        "status": "kibra_mint_promotion_report_generated",
        "time": time.time(),
        "time_iso": now_iso(),
        "submit_ai": submit_ai,
        "state": state,
        "recommendations": recs,
        "ai_tasks_created": len(tasks) if submit_ai else 0,
        "ai_tasks_prepared": len(tasks),
        "promotion_plan": "data/kibra_mint_promotion/promotion_plan.json",
        "promotion_page": "website/kibra/promotion.html",
        "latest_kibra_hash": latest_hash(),
        "redis": {
            "audit": redis_len(AUDIT),
            "recommendations": redis_len(RECS),
            "ai_queue": redis_len(AIQ),
            "parliament_queue": redis_len("cybra:parliament:queue"),
            "parliament_failed": redis_len("cybra:parliament:failed")
        },
        "proof_inputs": {
            "department": file_sha("parliament/departments/kibra_mint_repair_department/promotion_department/department.json"),
            "policy": file_sha("parliament/kibra_mint_promotion/policy.json"),
            "promotion_plan": file_sha("data/kibra_mint_promotion/promotion_plan.json"),
            "promotion_page": file_sha("website/kibra/promotion.html")
        },
        "safety": {
            "fake_price": False,
            "fake_volume": False,
            "wash_trading": False,
            "guaranteed_profit": False,
            "real_ads_payment_now": False,
            "real_sell_now": False,
            "manual_OWNER_approval_required": True
        }
    }

    report_obj["double_sha"] = dsha(json.dumps(report_obj, ensure_ascii=False, sort_keys=True))

    (ROOT / "feeds/kibra_mint_promotion_report.json").write_text(
        json.dumps(report_obj, ensure_ascii=False, indent=2),
        encoding="utf-8"
    )

    rec_md = ""
    for rec in recs:
        rec_md += f"- **{rec['level']}** / `{rec['area']}`: {rec['recommendation']} Action: `{rec['action']}`\n"

    state_md = ""
    for k, v in state.items():
        mark = "✅" if v else "❌"
        state_md += f"- {mark} `{k}`\n"

    md = f"""# KIBRA Mint Promotion Department

Status: **active**  
Parent: **KIBRA Mint Repair Department**

## Purpose

Цей відділ просуває KIBRA native coin, блоки з AI-завданнями, пули, difficulty classes, bridge proof, сайт/explorer і utility.

## State

{state_md}

## Promotion assets

- Promotion plan: `data/kibra_mint_promotion/promotion_plan.json`
- Promotion page: `website/kibra/promotion.html`
- Latest KIBRA hash: `{latest_hash()}`

## Recommendations

{rec_md}

## AI tasks

- Prepared: **{len(tasks)}**
- Submitted now: **{len(tasks) if submit_ai else 0}**

## Safety

- Fake price: **false**
- Fake volume: **false**
- Guaranteed profit: **false**
- Real ads payment now: **false**
- Real sell now: **false**
- Manual OWNER approval required: **true**

## Double SHA

`{report_obj['double_sha']}`
"""

    (ROOT / "posts/kibra_mint_promotion_report.md").write_text(md, encoding="utf-8")

    with (ROOT / "proofs/kibra_mint_promotion.sha256").open("w") as f:
        subprocess.run([
            "sha256sum",
            "parliament/departments/kibra_mint_repair_department/promotion_department/department.json",
            "parliament/kibra_mint_promotion/policy.json",
            "data/kibra_mint_promotion/promotion_plan.json",
            "website/kibra/promotion.html",
            "feeds/kibra_mint_promotion_report.json",
            "posts/kibra_mint_promotion_report.md"
        ], cwd=ROOT, stdout=f, stderr=subprocess.DEVNULL)

    r.lpush(AUDIT, json.dumps({
        "status": "kibra_mint_promotion_report_generated",
        "ai_tasks_prepared": len(tasks),
        "submit_ai": submit_ai,
        "double_sha": report_obj["double_sha"],
        "time": report_obj["time"]
    }, ensure_ascii=False))

    r.lpush(RECS, json.dumps({
        "status": "recommendations_generated",
        "recommendations": recs,
        "time": report_obj["time"],
        "double_sha": report_obj["double_sha"]
    }, ensure_ascii=False))

    print("✅ KIBRA mint promotion report generated")
    print("AI tasks prepared:", len(tasks))
    print("AI submitted:", submit_ai)
    print("Report: posts/kibra_mint_promotion_report.md")
    print("Page: website/kibra/promotion.html")
    print("Proof: proofs/kibra_mint_promotion.sha256")

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

chmod +x cybra_kibra_mint_promotion.py

cat > kibra_mint_promotion_handler.sh <<'EOF2'
#!/data/data/com.termux/files/usr/bin/bash
set -e
cd "$HOME/CYBRA"

python3 cybra_kibra_mint_promotion.py submit-ai

bash cybra_ai_blocks.sh cycle >/dev/null 2>&1 || true
bash cybra_kibra_block_ai.sh submit >/dev/null 2>&1 || true
bash cybra_kibra_difficulty.sh submit-ai >/dev/null 2>&1 || true
bash cybra_kibra_bridge.sh submit-ai >/dev/null 2>&1 || true
EOF2

chmod +x kibra_mint_promotion_handler.sh

cat > cybra_mint_promo.sh <<'EOF2'
#!/data/data/com.termux/files/usr/bin/bash
set -e
cd "$HOME/CYBRA"

case "${1:-status}" in
  report)
    python3 cybra_kibra_mint_promotion.py report
    cat posts/kibra_mint_promotion_report.md
    ;;
  submit-ai)
    python3 cybra_kibra_mint_promotion.py submit-ai
    ;;
  task)
    cybra parliament '{"topic":"KIBRA Mint Promotion Department","type":"kibra_mint_promotion_task","priority":"critical","payload":{"promote_native_kibra":true,"promote_ai_task_blocks":true,"promote_pool_mining":true,"promote_bridge_proof":true,"promote_difficulty_classes":true,"fake_price":false,"fake_volume":false,"guaranteed_profit":false,"manual_OWNER_approval_required":true}}'
    ;;
  cycle)
    python3 cybra_kibra_mint_promotion.py submit-ai
    cybra parliament '{"topic":"KIBRA Mint Promotion Department","type":"kibra_mint_promotion_task","priority":"critical","payload":{"promote_native_kibra":true,"promote_ai_task_blocks":true,"promote_pool_mining":true,"promote_bridge_proof":true,"promote_difficulty_classes":true,"manual_OWNER_approval_required":true}}'
    python3 parliament_executor_v6.py || true
    python3 cybra_kibra_mint_promotion.py report
    cat posts/kibra_mint_promotion_report.md
    ;;
  until-done)
    python3 cybra_kibra_mint_promotion.py submit-ai
    bash cybra_ai_blocks.sh until-done || true
    bash cybra_ai_until_done.sh run 300 || true
    python3 cybra_kibra_mint_promotion.py report
    ;;
  status)
    redis-cli ping
    echo "MINT_PROMOTION_AUDIT: $(redis-cli LLEN cybra:kibra:mint_promotion:audit)"
    echo "MINT_PROMOTION_RECS: $(redis-cli LLEN cybra:kibra:mint_promotion:recommendations)"
    echo "MINT_PROMOTION_AI_QUEUE: $(redis-cli LLEN cybra:ai:tasks:kibra_mint_promotion)"
    echo "PARLIAMENT_QUEUE: $(redis-cli LLEN cybra:parliament:queue)"
    echo "PARLIAMENT_FAILED: $(redis-cli LLEN cybra:parliament:failed)"
    test -f posts/kibra_mint_promotion_report.md && echo "REPORT: exists" || echo "REPORT: missing"
    test -f website/kibra/promotion.html && echo "PROMOTION_PAGE: exists" || echo "PROMOTION_PAGE: missing"
    ;;
  plan)
    cat data/kibra_mint_promotion/promotion_plan.json
    ;;
  page)
    cat website/kibra/promotion.html
    ;;
  proof)
    cat proofs/kibra_mint_promotion.sha256
    ;;
  *)
    echo "Usage:"
    echo "  bash cybra_mint_promo.sh report"
    echo "  bash cybra_mint_promo.sh submit-ai"
    echo "  bash cybra_mint_promo.sh task"
    echo "  bash cybra_mint_promo.sh cycle"
    echo "  bash cybra_mint_promo.sh until-done"
    echo "  bash cybra_mint_promo.sh status"
    echo "  bash cybra_mint_promo.sh plan"
    echo "  bash cybra_mint_promo.sh page"
    echo "  bash cybra_mint_promo.sh proof"
    ;;
esac
EOF2

chmod +x cybra_mint_promo.sh

redis-cli HSET cybra:executor:mapping kibra_mint_promotion_task kibra_mint_promotion_handler.sh >/dev/null

python3 - <<'PY'
from pathlib import Path

p = Path("parliament_executor_v6.py")
s = p.read_text()

if 'r.hget("cybra:executor:mapping", task_type)' not in s:
    old = "script_name = SCRIPT_MAP.get(task_type)"
    new = 'script_name = r.hget("cybra:executor:mapping", task_type) or SCRIPT_MAP.get(task_type)'
    if old in s:
        s = s.replace(old, new, 1)

if '"kibra_mint_promotion_task"' not in s:
    i = s.find("SCRIPT_MAP")
    j = s.find("{", i)
    if i >= 0 and j >= 0:
        s = s[:j+1] + '\n    "kibra_mint_promotion_task": "kibra_mint_promotion_handler.sh",' + s[j+1:]

p.write_text(s)
print("✅ kibra_mint_promotion_task mapping ready")
PY

rm -rf __pycache__
python3 -m py_compile cybra_kibra_mint_promotion.py
python3 -m py_compile parliament_executor_v6.py
rm -rf __pycache__

echo
echo "=== CREATE PROMOTION REPORT + AI TASKS ==="
bash cybra_mint_promo.sh submit-ai

echo
echo "=== ADD MASTER TASK TO PARLIAMENT ==="
bash cybra_mint_promo.sh task

echo
echo "=== EXECUTE ONE ROUND ==="
python3 parliament_executor_v6.py || true

echo
echo "=== STATUS ==="
bash cybra_mint_promo.sh status

echo
echo "=== PROOF CHECK ==="
sha256sum -c proofs/kibra_mint_promotion.sha256 || true

echo
echo "✅ KIBRA MINT PROMOTION DEPARTMENT INSTALLED"
