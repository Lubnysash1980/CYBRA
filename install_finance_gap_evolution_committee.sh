#!/data/data/com.termux/files/usr/bin/bash
set -e

cd "$HOME/CYBRA"

echo "=== INSTALL FINANCE GAP EVOLUTION COMMITTEE ==="

mkdir -p \
  parliament/departments/finance_department/committees/finance_gap_evolution_committee \
  parliament/finance_gap_evolution \
  data/finance_gap_evolution \
  posts feeds proofs logs/finance_gap_evolution

redis-cli ping >/dev/null 2>&1 || redis-server --daemonize yes
sleep 1

python3 - <<'PY' >/dev/null 2>&1 || python3 -m pip install redis
import redis
PY

cat > parliament/departments/finance_department/committees/finance_gap_evolution_committee/committee.json <<'JSON'
{
  "committee_id": "finance_gap_evolution_committee",
  "name": "CYBRA Finance Gap & Evolution Proposal Committee",
  "status": "active",
  "parent_department": "finance_department",
  "mission": "Шукати, чого не вистачає фінансовому департаменту, токенам, native coin, пулу, монетизації, біржі, платежам, золоту, proof-chain; пропонувати створення відсутніх модулів і запускати безпечні evolution AI-завдання.",
  "powers": [
    "scan_missing_finance_modules",
    "scan_missing_token_modules",
    "scan_missing_monetization_modules",
    "scan_missing_exchange_modules",
    "scan_missing_native_coin_modules",
    "scan_missing_proofs",
    "scan_runtime_gaps",
    "create_recommendations",
    "create_ai_tasks",
    "request_evolution_deployment",
    "request_finance_profit_audit",
    "request_hash_proof"
  ],
  "limits": [
    "no_real_payment_execution",
    "no_automatic_token_mint",
    "no_automatic_liquidity_pool",
    "no_automatic_exchange_launch",
    "no_automatic_gold_purchase",
    "no_automatic_external_blockchain_tx",
    "manual_OWNER_approval_required",
    "no_guaranteed_profit",
    "no_market_manipulation"
  ]
}
JSON

cat > parliament/finance_gap_evolution/policy.json <<'JSON'
{
  "name": "CYBRA Finance Gap Evolution Policy",
  "status": "active",
  "mode": "detect_missing_create_ai_recommendations",
  "rule": "Якщо чогось нема або не вистачає — комітет створює рекомендацію, proof і AI-завдання для безпечної еволюції.",
  "targets": [
    "finance_department",
    "finance_infrastructure",
    "finance_token_profit_audit",
    "native_kibra",
    "kibra_chain",
    "monetization",
    "market_exchange",
    "multipayment",
    "gold_treasury",
    "external_anchor",
    "owner_approval",
    "hash_module",
    "evolution_deployment",
    "existing_tasks_activation"
  ],
  "execution": {
    "real_payment": false,
    "real_mint": false,
    "real_pool": false,
    "real_exchange": false,
    "real_gold_purchase": false,
    "real_external_tx": false,
    "ai_tasks_only": true
  }
}
JSON

cat > cybra_finance_gap_evolution.py <<'PY'
#!/usr/bin/env python3
import json
import time
import hashlib
import subprocess
from pathlib import Path

import redis

ROOT = Path.home() / "CYBRA"
r = redis.Redis(host="127.0.0.1", port=6379, decode_responses=True)

AUDIT_KEY = "cybra:finance_gap_evolution:audit"
RECS_KEY = "cybra:finance_gap_evolution:recommendations"
AI_TASKS_KEY = "cybra:finance_gap_evolution:ai_tasks"

MODULES = {
    "finance_department": {
        "files": ["parliament/departments/finance_department/department.json", "feeds/finance_department_report.json"],
        "task_type": "finance_department_task",
        "action": "bash cybra_finance.sh report",
        "importance": "critical"
    },
    "finance_infrastructure": {
        "files": ["parliament/finance/infrastructure/finance_infrastructure_policy.json", "feeds/finance_infrastructure_report.json"],
        "task_type": "finance_infrastructure_task",
        "action": "bash cybra_finance_infra.sh report",
        "importance": "critical"
    },
    "finance_token_profit_audit": {
        "files": ["parliament/departments/finance_token_profit_audit_department/department.json", "feeds/finance_token_profit_audit_report.json"],
        "task_type": "finance_token_profit_audit_task",
        "action": "bash cybra_finance_profit_audit.sh report",
        "importance": "critical"
    },
    "native_kibra": {
        "files": ["parliament/native_kibra/policy/native_kibra_policy.json", "feeds/native_kibra_ai_task_package.json", "website/kibra/index.html", "token/kibra/native/assets/kibra_token.png"],
        "task_type": "native_kibra_evolution_task",
        "action": "bash cybra_native_kibra.sh build",
        "importance": "critical"
    },
    "kibra_chain": {
        "files": ["feeds/kibra_token_chain_status.json", "blockchain/kibra_chain/latest.block.hash", "proofs/kibra_token_chain.sha256"],
        "task_type": "kibra_token_chain_task",
        "action": "bash cybra_kibra_chain.sh verify && bash cybra_kibra_chain.sh report",
        "importance": "critical"
    },
    "monetization": {
        "files": ["parliament/departments/monetization_department/department.json", "feeds/monetization_department_report.json"],
        "task_type": "monetization_department_task",
        "action": "bash cybra_monetization.sh report",
        "importance": "important"
    },
    "market_exchange": {
        "files": ["parliament/departments/exchange_department/department.json", "feeds/kibra_market_exchange_plan.json"],
        "task_type": "kibra_market_exchange_task",
        "action": "bash cybra_kibra_market.sh report",
        "importance": "important"
    },
    "external_anchor": {
        "files": ["feeds/external_anchor_package.json", "posts/external_anchor_package.md"],
        "task_type": "owner_orchestrator_task",
        "action": "bash cybra_owner_orchestrator.sh run",
        "importance": "important"
    },
    "owner_approval": {
        "files": ["cybra_owner_approval.sh"],
        "task_type": "owner_orchestrator_task",
        "action": "bash cybra_owner_approval.sh status",
        "importance": "important"
    },
    "hash_module": {
        "files": ["feeds/hash_module_test.json", "proofs/hash_module_test.sha256"],
        "task_type": "hash_module_test_task",
        "action": "bash cybra_hash_test.sh run",
        "importance": "important"
    },
    "evolution_deployment": {
        "files": ["parliament/evolution_deployment/evolution_deployment_policy.json", "feeds/evolution_deployment_report.json"],
        "task_type": "evolution_deployment_task",
        "action": "bash cybra_evolution_deploy.sh report",
        "importance": "important"
    },
    "existing_tasks_activation": {
        "files": ["parliament/existing_tasks_activation/policy.json", "feeds/existing_tasks_evolution_activation.json"],
        "task_type": "existing_tasks_activation_task",
        "action": "bash cybra_existing_tasks.sh repair",
        "importance": "important"
    }
}

def sha(x):
    return hashlib.sha256(x.encode("utf-8")).hexdigest()

def dsha(x):
    return sha(sha(x))

def now_iso():
    return time.strftime("%Y-%m-%dT%H:%M:%S%z")

def exists(path):
    return (ROOT / path).exists()

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

def scan_modules():
    rows = []
    for name, meta in MODULES.items():
        missing = [f for f in meta["files"] if not exists(f)]
        rows.append({
            "module": name,
            "importance": meta["importance"],
            "task_type": meta["task_type"],
            "action": meta["action"],
            "files": meta["files"],
            "missing": missing,
            "ok": len(missing) == 0
        })
    return rows

def runtime_gaps():
    finance = load_json("feeds/finance_department_report.json")
    kibra = load_json("feeds/kibra_token_chain_status.json")
    monet = load_json("feeds/monetization_department_report.json")
    market = load_json("feeds/kibra_market_exchange_plan.json")

    gaps = []

    if redis_len("cybra:parliament:queue") > 0:
        gaps.append({
            "area": "executor",
            "level": "warning",
            "message": "Parliament queue is not empty.",
            "task_type": "existing_tasks_activation_task",
            "action": "cybra worker-start && cybra status"
        })

    if redis_len("cybra:parliament:failed") > 0:
        gaps.append({
            "area": "failed_tasks",
            "level": "warning",
            "message": "Failed tasks exist.",
            "task_type": "existing_tasks_activation_task",
            "action": "bash cybra_existing_tasks.sh repair"
        })

    risk_items = finance.get("summary", {}).get("risk_items")
    if risk_items and risk_items > 0:
        gaps.append({
            "area": "finance_risk",
            "level": "warning",
            "message": f"Finance risk items found: {risk_items}",
            "task_type": "finance_token_profit_audit_task",
            "action": "bash cybra_finance_profit_audit.sh report"
        })

    if redis_len("cybra:blockchain:anchor:queue") > 0:
        gaps.append({
            "area": "anchor_queue",
            "level": "warning",
            "message": "External anchor queue is not packaged.",
            "task_type": "owner_orchestrator_task",
            "action": "bash fix_kibra_verify_finance_anchor.sh"
        })

    if redis_len("cybra:token_mint:proposals") == 0:
        gaps.append({
            "area": "mint_proposal",
            "level": "development",
            "message": "No token/native mint proposal records found.",
            "task_type": "finance_infrastructure_task",
            "action": "bash cybra_finance_infra.sh mint-proposal"
        })

    if redis_len("cybra:monetization:spend_proposals") == 0:
        gaps.append({
            "area": "spendability",
            "level": "development",
            "message": "No KIBRA spendability proposal found.",
            "task_type": "monetization_department_task",
            "action": "bash cybra_monetization.sh spend KIBRA-AI-TASK 0"
        })

    height = kibra.get("chain", {}).get("height")
    if height is not None and height < 10:
        gaps.append({
            "area": "kibra_chain_growth",
            "level": "development",
            "message": f"KIBRA chain height is {height}; recommend growing to 10+ proof blocks.",
            "task_type": "kibra_token_chain_task",
            "action": "bash cybra_kibra_chain.sh mine 2"
        })

    if not monet:
        gaps.append({
            "area": "monetization",
            "level": "development",
            "message": "Monetization report missing.",
            "task_type": "monetization_department_task",
            "action": "bash cybra_monetization.sh report"
        })

    if not market:
        gaps.append({
            "area": "market_exchange",
            "level": "development",
            "message": "Market/exchange plan missing.",
            "task_type": "kibra_market_exchange_task",
            "action": "bash cybra_kibra_market.sh report"
        })

    return gaps

def make_ai_task(source, area, task_type, message, action):
    return {
        "topic": f"Finance Gap Evolution: {area}",
        "type": task_type,
        "priority": "high",
        "payload": {
            "source": "finance_gap_evolution_committee",
            "area": area,
            "recommendation": message,
            "suggested_action": action,
            "real_payment_execution": False,
            "automatic_token_mint": False,
            "automatic_liquidity_pool": False,
            "automatic_exchange_launch": False,
            "automatic_gold_purchase": False,
            "automatic_external_tx": False,
            "manual_OWNER_approval_required": True,
            "no_guaranteed_profit": True,
            "evolution_required": True
        }
    }

def build_report(submit_ai=False):
    r.ping()

    for p in ["posts", "feeds", "proofs", "data/finance_gap_evolution"]:
        (ROOT / p).mkdir(parents=True, exist_ok=True)

    modules = scan_modules()
    gaps = runtime_gaps()

    recommendations = []
    ai_tasks = []

    for m in modules:
        if not m["ok"]:
            msg = f"Module `{m['module']}` is missing files: {m['missing']}. Create or repair it."
            recommendations.append({
                "level": m["importance"],
                "area": m["module"],
                "message": msg,
                "action": m["action"]
            })
            ai_tasks.append(make_ai_task("module_scan", m["module"], m["task_type"], msg, m["action"]))

    for g in gaps:
        recommendations.append({
            "level": g["level"],
            "area": g["area"],
            "message": g["message"],
            "action": g["action"]
        })
        ai_tasks.append(make_ai_task("runtime_gap", g["area"], g["task_type"], g["message"], g["action"]))

    if not recommendations:
        recommendations.append({
            "level": "ok",
            "area": "finance_evolution",
            "message": "No critical gaps found. Finance department can continue evolution cycles.",
            "action": "bash cybra_evolution_deploy.sh cycle"
        })

    if submit_ai:
        for task in ai_tasks:
            r.lpush("cybra:ai:tasks:finance_gap_evolution", json.dumps(task, ensure_ascii=False))
            r.lpush(AI_TASKS_KEY, json.dumps(task, ensure_ascii=False))

    ok_modules = len([m for m in modules if m["ok"]])
    score = int((ok_modules / max(1, len(modules))) * 100)
    score -= min(50, len(gaps) * 5)
    if score < 0:
        score = 0

    report = {
        "status": "finance_gap_evolution_report_generated",
        "submit_ai": submit_ai,
        "time": time.time(),
        "time_iso": now_iso(),
        "score": score,
        "modules_total": len(modules),
        "modules_ok": ok_modules,
        "modules_missing": len(modules) - ok_modules,
        "runtime_gaps": len(gaps),
        "modules": modules,
        "gaps": gaps,
        "recommendations": recommendations,
        "ai_tasks": ai_tasks,
        "redis": {
            "queue": redis_len("cybra:parliament:queue"),
            "results": redis_len("cybra:parliament:results"),
            "failed": redis_len("cybra:parliament:failed"),
            "ai_tasks_finance_gap": redis_len("cybra:ai:tasks:finance_gap_evolution"),
            "audit": redis_len(AUDIT_KEY)
        },
        "proof_inputs": {
            "committee": file_sha("parliament/departments/finance_department/committees/finance_gap_evolution_committee/committee.json"),
            "policy": file_sha("parliament/finance_gap_evolution/policy.json")
        },
        "git": {
            "branch": git_cmd(["git", "branch", "--show-current"]),
            "commit": git_cmd(["git", "rev-parse", "--short", "HEAD"]),
            "dirty_files": len(git_cmd(["git", "status", "--short"]).splitlines())
        }
    }

    report["double_sha"] = dsha(json.dumps(report, ensure_ascii=False, sort_keys=True))

    (ROOT / "feeds/finance_gap_evolution_report.json").write_text(
        json.dumps(report, ensure_ascii=False, indent=2),
        encoding="utf-8"
    )

    (ROOT / "data/finance_gap_evolution/ai_tasks.json").write_text(
        json.dumps(ai_tasks, ensure_ascii=False, indent=2),
        encoding="utf-8"
    )

    rec_md = ""
    for rec in recommendations:
        rec_md += f"- **{rec['level']}** / `{rec['area']}`: {rec['message']} Action: `{rec['action']}`\n"

    module_md = ""
    for m in modules:
        mark = "✅" if m["ok"] else "❌"
        module_md += f"- {mark} `{m['module']}` missing={len(m['missing'])}\n"

    tasks_md = ""
    for task in ai_tasks:
        tasks_md += f"- `{task['type']}` — {task['topic']}\n"
    if not tasks_md:
        tasks_md = "- none\n"

    md = f"""# CYBRA Finance Gap & Evolution Committee

Status: **active**  
Parent: **Finance Department**

## Score

- Score: **{score}/100**
- Modules OK: **{ok_modules}/{len(modules)}**
- Runtime gaps: **{len(gaps)}**
- AI tasks created this report: **{len(ai_tasks) if submit_ai else 0}**
- Double SHA: `{report["double_sha"]}`

## What this committee does

Якщо чогось нема, не вистачає, або потрібна еволюція — комітет створює рекомендацію і AI-завдання.

## Module scan

{module_md}

## Recommendations

{rec_md}

## AI tasks prepared

{tasks_md}

## Safety

- Real payment execution: **false**
- Automatic token mint: **false**
- Automatic pool: **false**
- Automatic exchange launch: **false**
- Manual OWNER approval required: **true**
"""

    (ROOT / "posts/finance_gap_evolution_report.md").write_text(md, encoding="utf-8")

    with (ROOT / "proofs/finance_gap_evolution.sha256").open("w") as f:
        subprocess.run(
            [
                "sha256sum",
                "parliament/departments/finance_department/committees/finance_gap_evolution_committee/committee.json",
                "parliament/finance_gap_evolution/policy.json",
                "feeds/finance_gap_evolution_report.json",
                "data/finance_gap_evolution/ai_tasks.json",
                "posts/finance_gap_evolution_report.md"
            ],
            cwd=ROOT,
            stdout=f,
            stderr=subprocess.DEVNULL
        )

    r.lpush(AUDIT_KEY, json.dumps({
        "status": "finance_gap_evolution_report_generated",
        "score": score,
        "modules_ok": ok_modules,
        "runtime_gaps": len(gaps),
        "ai_tasks": len(ai_tasks),
        "submit_ai": submit_ai,
        "double_sha": report["double_sha"],
        "time": report["time"]
    }, ensure_ascii=False))

    r.lpush(RECS_KEY, json.dumps({
        "status": "recommendations_generated",
        "recommendations": recommendations,
        "time": report["time"],
        "double_sha": report["double_sha"]
    }, ensure_ascii=False))

    print("✅ Finance Gap Evolution report generated")
    print("Score:", score, "/100")
    print("Recommendations:", len(recommendations))
    print("AI tasks prepared:", len(ai_tasks))
    print("AI submitted:", submit_ai)
    print("Report: posts/finance_gap_evolution_report.md")

def main():
    import sys
    cmd = sys.argv[1] if len(sys.argv) > 1 else "report"
    if cmd == "report":
        build_report(submit_ai=False)
    elif cmd == "submit-ai":
        build_report(submit_ai=True)
    else:
        raise SystemExit("Usage: report|submit-ai")

if __name__ == "__main__":
    main()
PY

chmod +x cybra_finance_gap_evolution.py

cat > finance_gap_evolution_handler.sh <<'EOF2'
#!/data/data/com.termux/files/usr/bin/bash
set -e
cd "$HOME/CYBRA"
python3 cybra_finance_gap_evolution.py submit-ai
EOF2

chmod +x finance_gap_evolution_handler.sh

cat > cybra_finance_gap.sh <<'EOF2'
#!/data/data/com.termux/files/usr/bin/bash
set -e
cd "$HOME/CYBRA"

case "${1:-status}" in
  report)
    python3 cybra_finance_gap_evolution.py report
    cat posts/finance_gap_evolution_report.md
    ;;
  submit-ai)
    python3 cybra_finance_gap_evolution.py submit-ai
    ;;
  task)
    cybra parliament '{"topic":"Finance Gap Evolution Committee Scan","type":"finance_gap_evolution_task","priority":"critical","payload":{"mode":"detect_missing_create_ai_recommendations","real_payment_execution":false,"automatic_token_mint":false,"automatic_pool":false,"manual_OWNER_approval_required":true}}'
    ;;
  cycle)
    python3 cybra_finance_gap_evolution.py submit-ai
    cybra parliament '{"topic":"Finance Gap Evolution Committee Scan","type":"finance_gap_evolution_task","priority":"critical","payload":{"mode":"detect_missing_create_ai_recommendations","real_payment_execution":false,"automatic_token_mint":false,"automatic_pool":false,"manual_OWNER_approval_required":true}}'

    for i in $(seq 1 30); do
      echo "round=$i queue=$(redis-cli LLEN cybra:parliament:queue)"
      python3 parliament_executor_v6.py || true
      sleep 1
      [ "$(redis-cli LLEN cybra:parliament:queue)" = "0" ] && break
    done

    python3 cybra_finance_gap_evolution.py report
    cat posts/finance_gap_evolution_report.md
    ;;
  status)
    redis-cli ping
    echo "FINANCE_GAP_AUDIT: $(redis-cli LLEN cybra:finance_gap_evolution:audit)"
    echo "FINANCE_GAP_RECOMMENDATIONS: $(redis-cli LLEN cybra:finance_gap_evolution:recommendations)"
    echo "FINANCE_GAP_AI_TASKS: $(redis-cli LLEN cybra:finance_gap_evolution:ai_tasks)"
    echo "AI_QUEUE: $(redis-cli LLEN cybra:ai:tasks:finance_gap_evolution)"
    echo "PARLIAMENT_QUEUE: $(redis-cli LLEN cybra:parliament:queue)"
    echo "PARLIAMENT_RESULTS: $(redis-cli LLEN cybra:parliament:results)"
    test -f posts/finance_gap_evolution_report.md && echo "REPORT: exists" || echo "REPORT: missing"
    ;;
  recommendations)
    redis-cli LRANGE cybra:finance_gap_evolution:recommendations 0 10
    ;;
  ai-tasks)
    cat data/finance_gap_evolution/ai_tasks.json
    ;;
  feed)
    cat feeds/finance_gap_evolution_report.json
    ;;
  proof)
    cat proofs/finance_gap_evolution.sha256
    ;;
  *)
    echo "Usage: bash cybra_finance_gap.sh report|submit-ai|task|cycle|status|recommendations|ai-tasks|feed|proof"
    ;;
esac
EOF2

chmod +x cybra_finance_gap.sh

redis-cli HSET cybra:executor:mapping finance_gap_evolution_task finance_gap_evolution_handler.sh >/dev/null

python3 - <<'PY'
from pathlib import Path

p = Path("parliament_executor_v6.py")
s = p.read_text()

if 'r.hget("cybra:executor:mapping", task_type)' not in s:
    old = "script_name = SCRIPT_MAP.get(task_type)"
    new = 'script_name = r.hget("cybra:executor:mapping", task_type) or SCRIPT_MAP.get(task_type)'
    if old in s:
        s = s.replace(old, new, 1)

if '"finance_gap_evolution_task"' not in s:
    i = s.find("SCRIPT_MAP")
    j = s.find("{", i)
    if i >= 0 and j >= 0:
        s = s[:j+1] + '\n    "finance_gap_evolution_task": "finance_gap_evolution_handler.sh",' + s[j+1:]

p.write_text(s)
print("✅ finance_gap_evolution_task mapping ready")
PY

rm -rf __pycache__
python3 -m py_compile parliament_executor_v6.py
python3 -m py_compile cybra_finance_gap_evolution.py
rm -rf __pycache__

echo
echo "=== 1. RUN REPORT ==="
bash cybra_finance_gap.sh report

echo
echo "=== 2. SUBMIT AI RECOMMENDATIONS ==="
bash cybra_finance_gap.sh submit-ai

echo
echo "=== 3. RUN THROUGH PARLIAMENT ==="
bash cybra_finance_gap.sh task

for i in $(seq 1 30); do
  echo "round=$i queue=$(redis-cli LLEN cybra:parliament:queue)"
  python3 parliament_executor_v6.py || true
  sleep 1
  [ "$(redis-cli LLEN cybra:parliament:queue)" = "0" ] && break
done

echo
echo "=== 4. FINAL STATUS ==="
bash cybra_finance_gap.sh status
cybra status || true

echo
echo "=== 5. PROOF CHECK ==="
sha256sum -c proofs/finance_gap_evolution.sha256

echo
echo "✅ FINANCE GAP EVOLUTION COMMITTEE INSTALLED"
