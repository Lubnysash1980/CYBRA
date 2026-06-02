#!/data/data/com.termux/files/usr/bin/bash
set -e

cd "$HOME/CYBRA"

echo "=== INSTALL FINANCE TOKEN PROFIT AUDIT DEPARTMENT ==="

mkdir -p \
  parliament/departments/finance_token_profit_audit_department \
  parliament/finance_profit_audit \
  data/finance_profit_audit \
  posts feeds proofs logs/finance_profit_audit

redis-cli ping >/dev/null 2>&1 || redis-server --daemonize yes
sleep 1

python3 - <<'PY' >/dev/null 2>&1 || python3 -m pip install redis
import redis
PY

cat > parliament/departments/finance_token_profit_audit_department/department.json <<'JSON'
{
  "department_id": "finance_token_profit_audit_department",
  "name": "CYBRA Finance Token Profit Audit Department",
  "status": "active",
  "mission": "Перевіряти фінансовий департамент щодо створення токенів / native coin, пулів, мультиплатежів, золотої казни, монетизації та оптимізації прибутковості через безпечні AI-рекомендації.",
  "checks": [
    "token_mint_readiness",
    "native_coin_readiness",
    "pool_model_readiness",
    "liquidity_plan_quality",
    "monetization_utility",
    "multipayment_risks",
    "gold_treasury_model",
    "exchange_readiness",
    "profit_optimization_proposals",
    "manual_OWNER_approval_gate"
  ],
  "limits": [
    "no_guaranteed_profit",
    "no_fake_price",
    "no_market_manipulation",
    "no_automatic_payment",
    "no_automatic_token_mint",
    "no_automatic_liquidity_pool",
    "no_automatic_gold_purchase",
    "no_automatic_external_tx",
    "manual_OWNER_approval_required",
    "legal_tax_aml_review_required"
  ]
}
JSON

cat > parliament/finance_profit_audit/policy.json <<'JSON'
{
  "name": "CYBRA Finance Token Profit Audit Policy",
  "status": "active",
  "mode": "audit_recommendation_only",
  "purpose": "AI Parliament перевіряє фінансовий департамент і створює план оптимізації прибутковості KIBRA без автоматичного виконання фінансових дій.",
  "profit_optimization_principles": {
    "profit_not_guaranteed": true,
    "utility_first": true,
    "real_demand_required": true,
    "liquidity_required": true,
    "slippage_control_required": true,
    "treasury_risk_control_required": true,
    "manual_owner_approval_required": true
  },
  "optimization_targets": [
    "increase_utility",
    "increase_service_catalog",
    "reduce_operational_risk",
    "prepare_liquidity_depth_model",
    "prepare_sell_without_crash_model",
    "prepare_market_price_engine",
    "prepare_exchange_sandbox",
    "prepare_gold_treasury_proof",
    "prepare_multipayment_provider_review"
  ]
}
JSON

cat > cybra_finance_token_profit_audit.py <<'PY'
#!/usr/bin/env python3
import json
import time
import hashlib
import subprocess
from pathlib import Path

import redis

ROOT = Path.home() / "CYBRA"
r = redis.Redis(host="127.0.0.1", port=6379, decode_responses=True)

AUDIT_KEY = "cybra:finance_profit_audit:audit"
RECS_KEY = "cybra:finance_profit_audit:recommendations"
AI_TASKS_KEY = "cybra:finance_profit_audit:ai_tasks"

def sha(x):
    return hashlib.sha256(x.encode("utf-8")).hexdigest()

def dsha(x):
    return sha(sha(x))

def now_iso():
    return time.strftime("%Y-%m-%dT%H:%M:%S%z")

def load_json(path):
    p = ROOT / path
    if not p.exists():
        return {}
    try:
        return json.loads(p.read_text(encoding="utf-8"))
    except Exception:
        return {}

def file_sha(path):
    p = ROOT / path
    if not p.exists():
        return None
    h = hashlib.sha256()
    with p.open("rb") as f:
        for c in iter(lambda: f.read(1024 * 1024), b""):
            h.update(c)
    return h.hexdigest()

def redis_len(key):
    try:
        return r.llen(key)
    except Exception:
        return 0

def git_cmd(cmd):
    try:
        return subprocess.check_output(cmd, cwd=ROOT, text=True, stderr=subprocess.DEVNULL).strip()
    except Exception:
        return ""

def latest_kibra_hash():
    p = ROOT / "blockchain/kibra_chain/latest.block.hash"
    return p.read_text().strip() if p.exists() else None

def score_bool(value, points):
    return points if value else 0

def build_recommendations(state):
    recs = []

    if not state["modules"]["finance_infrastructure"]:
        recs.append({
            "level": "critical",
            "area": "finance_infrastructure",
            "recommendation": "Запустити finance infrastructure для token mint / multipayment / gold treasury proposal.",
            "action": "bash cybra_finance_infra.sh report"
        })

    if not state["modules"]["monetization"]:
        recs.append({
            "level": "critical",
            "area": "monetization",
            "recommendation": "Запустити monetization department, бо без utility токен не має реальної основи для ціни.",
            "action": "bash cybra_monetization.sh report"
        })

    if not state["modules"]["market_exchange"]:
        recs.append({
            "level": "important",
            "area": "exchange",
            "recommendation": "Створити market/exchange readiness: price engine, buyers, volume, sell-without-crash.",
            "action": "bash cybra_kibra_market.sh report"
        })

    if not state["modules"]["native_kibra"]:
        recs.append({
            "level": "important",
            "area": "native_coin",
            "recommendation": "Закріпити KIBRA як native coin package: PNG, сайт, explorer, AI task.",
            "action": "bash cybra_native_kibra.sh build"
        })

    if state["runtime"]["finance_risk_items"] and state["runtime"]["finance_risk_items"] > 0:
        recs.append({
            "level": "warning",
            "area": "finance_risk",
            "recommendation": "Є фінансові risk items. Перед будь-яким реальним платежем потрібна ручна перевірка.",
            "action": "bash cybra_finance.sh report"
        })

    if state["runtime"]["anchor_queue"] > 0:
        recs.append({
            "level": "warning",
            "area": "anchor",
            "recommendation": "Anchor queue треба пакувати в manual anchor package, не виконуючи on-chain автоматично.",
            "action": "bash fix_kibra_verify_finance_anchor.sh"
        })

    if state["runtime"]["failed"] > 0:
        recs.append({
            "level": "warning",
            "area": "executor",
            "recommendation": "Є failed tasks. Архівувати старі або виправити handler-и.",
            "action": "bash cybra_existing_tasks.sh repair"
        })

    recs.append({
        "level": "growth",
        "area": "profit_optimization",
        "recommendation": "Підвищувати прибутковість не через штучну ціну, а через utility: AI credits, proof services, anchor packages, developer support, marketplace.",
        "action": "Створити utility pricing table і demand plan."
    })

    recs.append({
        "level": "growth",
        "area": "liquidity",
        "recommendation": "Підготувати liquidity depth model: стартова ліквідність, slippage, sell limits, staged sells, без fake volume.",
        "action": "AI Parliament task: liquidity_depth_model"
    })

    recs.append({
        "level": "growth",
        "area": "native_emission",
        "recommendation": "Для native KIBRA потрібна emission policy: block reward, supply tracking, halving або adaptive reward.",
        "action": "AI Parliament task: native_emission_policy"
    })

    recs.append({
        "level": "growth",
        "area": "gold_treasury",
        "recommendation": "Gold/XAU має бути treasury accounting proposal, не обіцянка забезпечення без audited reserve.",
        "action": "AI Parliament task: gold_reserve_proof_model"
    })

    return recs

def build_ai_tasks(recs):
    tasks = []

    for i, rec in enumerate(recs, 1):
        area = rec["area"]

        task_type = "monetization_department_task"
        if area in ("finance_infrastructure", "finance_risk", "gold_treasury"):
            task_type = "finance_infrastructure_task"
        elif area in ("exchange", "liquidity"):
            task_type = "kibra_market_exchange_task"
        elif area in ("native_coin", "native_emission"):
            task_type = "native_kibra_evolution_task"
        elif area in ("executor",):
            task_type = "existing_tasks_activation_task"
        elif area in ("anchor",):
            task_type = "owner_orchestrator_task"

        tasks.append({
            "topic": f"Finance Profit Audit Recommendation {i}: {area}",
            "type": task_type,
            "priority": "high",
            "payload": {
                "source": "finance_token_profit_audit_department",
                "area": area,
                "recommendation": rec["recommendation"],
                "action": rec["action"],
                "real_payment_execution": False,
                "automatic_token_mint": False,
                "automatic_liquidity_pool": False,
                "automatic_external_tx": False,
                "manual_OWNER_approval_required": True,
                "no_guaranteed_profit": True,
                "no_market_manipulation": True
            }
        })

    return tasks

def report(submit_ai=False):
    r.ping()

    for p in ["posts", "feeds", "proofs", "logs/finance_profit_audit", "data/finance_profit_audit"]:
        (ROOT / p).mkdir(parents=True, exist_ok=True)

    finance = load_json("feeds/finance_department_report.json")
    finance_infra = load_json("feeds/finance_infrastructure_report.json")
    monet = load_json("feeds/monetization_department_report.json")
    market = load_json("feeds/kibra_market_exchange_plan.json")
    native = load_json("feeds/native_kibra_ai_task_package.json")
    kibra = load_json("feeds/kibra_token_chain_status.json")
    anchor = load_json("feeds/external_anchor_package.json")

    state = {
        "status": "finance_token_profit_audit_generated",
        "time": time.time(),
        "time_iso": now_iso(),
        "latest_kibra_hash": latest_kibra_hash(),
        "modules": {
            "finance_department": bool(finance),
            "finance_infrastructure": bool(finance_infra),
            "monetization": bool(monet),
            "market_exchange": bool(market),
            "native_kibra": bool(native),
            "kibra_chain": bool(kibra),
            "external_anchor_package": bool(anchor)
        },
        "runtime": {
            "queue": redis_len("cybra:parliament:queue"),
            "results": redis_len("cybra:parliament:results"),
            "failed": redis_len("cybra:parliament:failed"),
            "finance_ledger": redis_len("cybra:finance:ledger"),
            "finance_audit": redis_len("cybra:finance:audit"),
            "finance_risk_items": finance.get("summary", {}).get("risk_items", 0) if finance else None,
            "mint_proposals": redis_len("cybra:token_mint:proposals"),
            "payment_proposals": redis_len("cybra:payment:settlement:proposals"),
            "gold_proposals": redis_len("cybra:treasury:gold:proposals"),
            "monetization_proposals": redis_len("cybra:monetization:proposals"),
            "anchor_queue": redis_len("cybra:blockchain:anchor:queue"),
            "anchor_manual_ready": redis_len("cybra:blockchain:anchor:manual_ready")
        },
        "kibra": {
            "height": kibra.get("chain", {}).get("height") if kibra else None,
            "latest_difficulty": kibra.get("chain", {}).get("latest_difficulty") if kibra else None,
            "token": kibra.get("token", {}) if kibra else {}
        },
        "proof_inputs": {
            "department": file_sha("parliament/departments/finance_token_profit_audit_department/department.json"),
            "policy": file_sha("parliament/finance_profit_audit/policy.json"),
            "finance_report": file_sha("proofs/finance_department.sha256"),
            "finance_infrastructure": file_sha("proofs/finance_infrastructure.sha256"),
            "monetization": file_sha("proofs/monetization_department.sha256"),
            "market_exchange": file_sha("proofs/kibra_market_exchange_plan.sha256"),
            "native_kibra": file_sha("proofs/native_kibra_ai_task_package.sha256"),
            "kibra_chain": file_sha("proofs/kibra_token_chain.sha256")
        },
        "git": {
            "branch": git_cmd(["git", "branch", "--show-current"]),
            "commit": git_cmd(["git", "rev-parse", "--short", "HEAD"]),
            "dirty_files": len(git_cmd(["git", "status", "--short"]).splitlines())
        }
    }

    score = 0
    score += score_bool(state["modules"]["finance_department"], 10)
    score += score_bool(state["modules"]["finance_infrastructure"], 15)
    score += score_bool(state["modules"]["monetization"], 15)
    score += score_bool(state["modules"]["market_exchange"], 15)
    score += score_bool(state["modules"]["native_kibra"], 15)
    score += score_bool(state["modules"]["kibra_chain"], 10)
    score += score_bool(state["modules"]["external_anchor_package"], 10)
    score += 10 if state["runtime"]["finance_risk_items"] in (0, None) else 0

    recs = build_recommendations(state)
    ai_tasks = build_ai_tasks(recs)

    report_obj = {
        "status": "finance_token_profit_audit_report_generated",
        "time": time.time(),
        "time_iso": now_iso(),
        "score": score,
        "max_score": 100,
        "state": state,
        "recommendations": recs,
        "ai_tasks": ai_tasks,
        "submit_ai": submit_ai,
        "profit_notice": "No guaranteed profit. This module creates optimization recommendations only."
    }

    report_obj["double_sha"] = dsha(json.dumps(report_obj, ensure_ascii=False, sort_keys=True))

    (ROOT / "feeds/finance_token_profit_audit_report.json").write_text(
        json.dumps(report_obj, ensure_ascii=False, indent=2),
        encoding="utf-8"
    )

    (ROOT / "data/finance_profit_audit/ai_tasks.json").write_text(
        json.dumps(ai_tasks, ensure_ascii=False, indent=2),
        encoding="utf-8"
    )

    if submit_ai:
        for task in ai_tasks:
            r.lpush("cybra:ai:tasks:finance_profit_audit", json.dumps(task, ensure_ascii=False))
            r.lpush(AI_TASKS_KEY, json.dumps(task, ensure_ascii=False))

    r.lpush(AUDIT_KEY, json.dumps({
        "status": "finance_token_profit_audit_report_generated",
        "score": score,
        "recommendations": len(recs),
        "ai_tasks": len(ai_tasks),
        "submit_ai": submit_ai,
        "double_sha": report_obj["double_sha"],
        "time": report_obj["time"]
    }, ensure_ascii=False))

    r.lpush(RECS_KEY, json.dumps({
        "status": "recommendations_generated",
        "recommendations": recs,
        "time": report_obj["time"],
        "double_sha": report_obj["double_sha"]
    }, ensure_ascii=False))

    rec_md = ""
    for rec in recs:
        rec_md += f"- **{rec['level']}** / `{rec['area']}`: {rec['recommendation']} Action: `{rec['action']}`\n"

    tasks_md = ""
    for task in ai_tasks:
        tasks_md += f"- `{task['type']}` — {task['topic']}\n"

    md = f"""# CYBRA Finance Token Profit Audit Department

Status: **active**  
Mode: audit + recommendation + AI tasks

## Score

- Finance/token/profit readiness score: **{score}/100**
- Profit guarantee: **false**
- Real payment execution: **false**
- Automatic token mint: **false**
- Automatic liquidity pool: **false**
- Manual OWNER approval required: **true**

## What is checked

- Finance Department
- Finance Infrastructure
- Token mint / native coin readiness
- Pool / liquidity readiness
- Monetization Department
- Market / exchange plan
- Gold/XAU treasury proposal
- Multipayment proposal
- External anchor package
- KIBRA chain proof

## Runtime

- Queue: {state["runtime"]["queue"]}
- Results: {state["runtime"]["results"]}
- Failed: {state["runtime"]["failed"]}
- Finance risk items: {state["runtime"]["finance_risk_items"]}
- Mint proposals: {state["runtime"]["mint_proposals"]}
- Payment proposals: {state["runtime"]["payment_proposals"]}
- Gold proposals: {state["runtime"]["gold_proposals"]}
- Monetization proposals: {state["runtime"]["monetization_proposals"]}
- Anchor queue: {state["runtime"]["anchor_queue"]}
- Anchor manual ready: {state["runtime"]["anchor_manual_ready"]}

## Recommendations

{rec_md}

## AI tasks prepared

{tasks_md}

## Proof

Double SHA:

`{report_obj["double_sha"]}`
"""

    (ROOT / "posts/finance_token_profit_audit_report.md").write_text(md, encoding="utf-8")

    with (ROOT / "proofs/finance_token_profit_audit.sha256").open("w") as f:
        subprocess.run(
            [
                "sha256sum",
                "parliament/departments/finance_token_profit_audit_department/department.json",
                "parliament/finance_profit_audit/policy.json",
                "feeds/finance_token_profit_audit_report.json",
                "data/finance_profit_audit/ai_tasks.json",
                "posts/finance_token_profit_audit_report.md"
            ],
            cwd=ROOT,
            stdout=f,
            stderr=subprocess.DEVNULL
        )

    print("✅ finance token profit audit report generated")
    print("Score:", score, "/ 100")
    print("Recommendations:", len(recs))
    print("AI tasks:", len(ai_tasks))
    print("Submit AI:", submit_ai)
    print("Report: posts/finance_token_profit_audit_report.md")
    print("Feed: feeds/finance_token_profit_audit_report.json")
    print("Proof: proofs/finance_token_profit_audit.sha256")

def main():
    import sys
    cmd = sys.argv[1] if len(sys.argv) > 1 else "report"

    if cmd == "report":
        report(submit_ai=False)
    elif cmd == "submit-ai":
        report(submit_ai=True)
    else:
        raise SystemExit("Usage: report|submit-ai")

if __name__ == "__main__":
    main()
PY

chmod +x cybra_finance_token_profit_audit.py

cat > finance_token_profit_audit_handler.sh <<'EOF2'
#!/data/data/com.termux/files/usr/bin/bash
set -e
cd "$HOME/CYBRA"

python3 cybra_finance_token_profit_audit.py submit-ai

bash cybra_finance.sh report >/dev/null 2>&1 || true
bash cybra_finance_infra.sh report >/dev/null 2>&1 || true
bash cybra_monetization.sh report >/dev/null 2>&1 || true
bash cybra_kibra_market.sh report >/dev/null 2>&1 || true
bash cybra_hash_test.sh run >/dev/null 2>&1 || true
EOF2

chmod +x finance_token_profit_audit_handler.sh

cat > cybra_finance_profit_audit.sh <<'EOF2'
#!/data/data/com.termux/files/usr/bin/bash
set -e
cd "$HOME/CYBRA"

case "${1:-status}" in
  report)
    python3 cybra_finance_token_profit_audit.py report
    cat posts/finance_token_profit_audit_report.md
    ;;
  submit-ai)
    python3 cybra_finance_token_profit_audit.py submit-ai
    ;;
  task)
    cybra parliament '{"topic":"CYBRA Finance Token Profit Audit","type":"finance_token_profit_audit_task","priority":"critical","payload":{"mode":"audit_finance_token_creation_profit_optimization","real_payment_execution":false,"automatic_token_mint":false,"automatic_liquidity_pool":false,"no_guaranteed_profit":true,"manual_OWNER_approval_required":true}}'
    ;;
  cycle)
    python3 cybra_finance_token_profit_audit.py submit-ai
    cybra parliament '{"topic":"CYBRA Finance Token Profit Audit","type":"finance_token_profit_audit_task","priority":"critical","payload":{"mode":"audit_finance_token_creation_profit_optimization","real_payment_execution":false,"automatic_token_mint":false,"automatic_liquidity_pool":false,"no_guaranteed_profit":true,"manual_OWNER_approval_required":true}}'

    for i in $(seq 1 30); do
      echo "round=$i queue=$(redis-cli LLEN cybra:parliament:queue)"
      python3 parliament_executor_v6.py || true
      sleep 1
      [ "$(redis-cli LLEN cybra:parliament:queue)" = "0" ] && break
    done

    python3 cybra_finance_token_profit_audit.py report
    cat posts/finance_token_profit_audit_report.md
    ;;
  status)
    redis-cli ping
    echo "FINANCE_PROFIT_AUDIT: $(redis-cli LLEN cybra:finance_profit_audit:audit)"
    echo "FINANCE_PROFIT_RECOMMENDATIONS: $(redis-cli LLEN cybra:finance_profit_audit:recommendations)"
    echo "FINANCE_PROFIT_AI_TASKS: $(redis-cli LLEN cybra:finance_profit_audit:ai_tasks)"
    echo "AI_QUEUE: $(redis-cli LLEN cybra:ai:tasks:finance_profit_audit)"
    echo "PARLIAMENT_QUEUE: $(redis-cli LLEN cybra:parliament:queue)"
    echo "PARLIAMENT_RESULTS: $(redis-cli LLEN cybra:parliament:results)"
    test -f posts/finance_token_profit_audit_report.md && echo "REPORT: exists" || echo "REPORT: missing"
    ;;
  recommendations)
    redis-cli LRANGE cybra:finance_profit_audit:recommendations 0 10
    ;;
  ai-tasks)
    cat data/finance_profit_audit/ai_tasks.json
    ;;
  feed)
    cat feeds/finance_token_profit_audit_report.json
    ;;
  proof)
    cat proofs/finance_token_profit_audit.sha256
    ;;
  *)
    echo "Usage: bash cybra_finance_profit_audit.sh report|submit-ai|task|cycle|status|recommendations|ai-tasks|feed|proof"
    ;;
esac
EOF2

chmod +x cybra_finance_profit_audit.sh

redis-cli HSET cybra:executor:mapping finance_token_profit_audit_task finance_token_profit_audit_handler.sh >/dev/null

python3 - <<'PY'
from pathlib import Path

p = Path("parliament_executor_v6.py")
s = p.read_text()

if 'r.hget("cybra:executor:mapping", task_type)' not in s:
    old = "script_name = SCRIPT_MAP.get(task_type)"
    new = 'script_name = r.hget("cybra:executor:mapping", task_type) or SCRIPT_MAP.get(task_type)'
    if old in s:
        s = s.replace(old, new, 1)

if '"finance_token_profit_audit_task"' not in s:
    i = s.find("SCRIPT_MAP")
    j = s.find("{", i)
    if i >= 0 and j >= 0:
        s = s[:j+1] + '\n    "finance_token_profit_audit_task": "finance_token_profit_audit_handler.sh",' + s[j+1:]

p.write_text(s)
print("✅ finance_token_profit_audit_task mapping ready")
PY

rm -rf __pycache__
python3 -m py_compile parliament_executor_v6.py
python3 -m py_compile cybra_finance_token_profit_audit.py
rm -rf __pycache__

echo
echo "=== 1. RUN REPORT ==="
bash cybra_finance_profit_audit.sh report

echo
echo "=== 2. SUBMIT AI TASKS ==="
bash cybra_finance_profit_audit.sh submit-ai

echo
echo "=== 3. RUN THROUGH AI PARLIAMENT ==="
bash cybra_finance_profit_audit.sh task

for i in $(seq 1 30); do
  echo "round=$i queue=$(redis-cli LLEN cybra:parliament:queue)"
  python3 parliament_executor_v6.py || true
  sleep 1
  [ "$(redis-cli LLEN cybra:parliament:queue)" = "0" ] && break
done

echo
echo "=== 4. STATUS ==="
bash cybra_finance_profit_audit.sh status
cybra status || true

echo
echo "=== 5. PROOF CHECK ==="
sha256sum -c proofs/finance_token_profit_audit.sha256

echo
echo "✅ FINANCE TOKEN PROFIT AUDIT DEPARTMENT INSTALLED"
