#!/data/data/com.termux/files/usr/bin/bash
set -e

cd "$HOME/CYBRA"

echo "=== INSTALL CYBRA EVOLUTION DEPLOYMENT ==="

mkdir -p \
  parliament/evolution_deployment \
  posts feeds proofs logs/evolution_deployment data/evolution_deployment

redis-cli ping >/dev/null 2>&1 || redis-server --daemonize yes
sleep 1

python3 - <<'PY' >/dev/null 2>&1 || python3 -m pip install redis
import redis
PY

cat > parliament/evolution_deployment/evolution_deployment_policy.json <<'JSON'
{
  "name": "CYBRA Evolution Deployment",
  "status": "active",
  "mode": "safe_growth_orchestrator",
  "mission": "Тестувати розвиток Кіберапарламенту, знаходити слабкі місця і створювати наступні безпечні еволюційні задачі.",
  "allowed_actions": [
    "scan_system_state",
    "score_maturity",
    "create_roadmap",
    "submit_safe_development_tasks",
    "refresh_reports",
    "request_hash_proof",
    "request_finance_review",
    "request_revision",
    "request_analytics",
    "request_monetization_cycle",
    "request_kibra_chain_growth",
    "request_anchor_package"
  ],
  "blocked_actions": [
    "automatic_payment",
    "automatic_token_mint",
    "automatic_liquidity_pool_creation",
    "automatic_external_blockchain_tx",
    "private_key_use",
    "seed_phrase_use",
    "market_manipulation",
    "guaranteed_price"
  ],
  "evolution_rule": "Only develop utility, proof, safety, audit, monetization proposals, difficulty chain and owner-approved workflows."
}
JSON

cat > cybra_evolution_deployment.py <<'PY'
#!/usr/bin/env python3
import json
import time
import hashlib
import subprocess
from pathlib import Path

import redis

ROOT = Path.home() / "CYBRA"
r = redis.Redis(host="127.0.0.1", port=6379, decode_responses=True)

AUDIT_KEY = "cybra:evolution_deployment:audit"
ROADMAP_KEY = "cybra:evolution_deployment:roadmap"
TASKS_KEY = "cybra:evolution_deployment:tasks"

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

def scan_state():
    kibra = load_json("feeds/kibra_token_chain_status.json")
    monet = load_json("feeds/monetization_department_report.json")
    finance = load_json("feeds/finance_department_report.json")
    review = load_json("feeds/parliament_kibra_response_review.json")
    hash_test = load_json("feeds/hash_module_test.json")
    institution = load_json("feeds/institution_audit_report.json")
    anchor = load_json("feeds/external_anchor_package.json")

    state = {
        "time": time.time(),
        "time_iso": now_iso(),
        "git": {
            "branch": git_cmd(["git", "branch", "--show-current"]),
            "commit": git_cmd(["git", "rev-parse", "--short", "HEAD"]),
            "dirty_files": len(git_cmd(["git", "status", "--short"]).splitlines())
        },
        "redis": {
            "queue": redis_len("cybra:parliament:queue"),
            "results": redis_len("cybra:parliament:results"),
            "failed": redis_len("cybra:parliament:failed"),
            "audit": redis_len("cybra:audit"),
            "kibra_audit": redis_len("cybra:kibra_chain:audit"),
            "finance_ledger": redis_len("cybra:finance:ledger"),
            "finance_audit": redis_len("cybra:finance:audit"),
            "anchor_queue": redis_len("cybra:blockchain:anchor:queue"),
            "anchor_manual_ready": redis_len("cybra:blockchain:anchor:manual_ready"),
            "monetization_audit": redis_len("cybra:monetization:audit"),
            "monetization_proposals": redis_len("cybra:monetization:proposals"),
            "spend_proposals": redis_len("cybra:monetization:spend_proposals"),
            "evolution_approved": redis_len("cybra:evolution:approved"),
            "evolution_hold": redis_len("cybra:evolution:hold"),
            "evolution_rejected": redis_len("cybra:evolution:rejected")
        },
        "files": {
            "kibra_chain": file_exists("feeds/kibra_token_chain_status.json"),
            "monetization": file_exists("feeds/monetization_department_report.json"),
            "finance": file_exists("feeds/finance_department_report.json"),
            "hash": file_exists("feeds/hash_module_test.json"),
            "institution": file_exists("feeds/institution_audit_report.json"),
            "anchor_package": file_exists("feeds/external_anchor_package.json"),
            "parliament_review": file_exists("feeds/parliament_kibra_response_review.json")
        },
        "kibra": {
            "height": kibra.get("chain", {}).get("height"),
            "latest_hash": kibra.get("chain", {}).get("latest_hash") or latest_kibra_hash(),
            "latest_difficulty": kibra.get("chain", {}).get("latest_difficulty")
        },
        "finance": {
            "risk_items": finance.get("summary", {}).get("risk_items"),
            "records_checked": finance.get("summary", {}).get("records_checked")
        },
        "institution": {
            "missing_organs": institution.get("summary", {}).get("missing_organs"),
            "missing_mapping": institution.get("summary", {}).get("task_types_without_mapping"),
            "missing_committees": institution.get("summary", {}).get("task_types_without_committee")
        },
        "monetization": {
            "exists": bool(monet),
            "double_sha": monet.get("double_sha")
        },
        "hash": {
            "exists": bool(hash_test),
            "root_double_sha": hash_test.get("root_double_sha")
        },
        "anchor": {
            "exists": bool(anchor),
            "anchor_package_root": anchor.get("anchor_package_root")
        }
    }

    return state

def score_state(state):
    score = 0
    max_score = 100
    gaps = []
    next_tasks = []

    if state["redis"]["queue"] == 0:
        score += 10
    else:
        gaps.append("parliament_queue_not_empty")
        next_tasks.append(("executor_cleanup", "owner_orchestrator_task"))

    if state["redis"]["failed"] == 0:
        score += 10
    else:
        gaps.append("failed_tasks_exist")
        next_tasks.append(("failed_task_revision", "institution_audit_task"))

    if state["files"]["kibra_chain"] and (state["kibra"]["height"] or 0) >= 8:
        score += 15
    else:
        gaps.append("kibra_chain_needs_growth")
        next_tasks.append(("mine_next_kibra_block", "kibra_token_chain_task"))

    if state["files"]["finance"] and (state["finance"]["risk_items"] in (0, None)):
        score += 10
    else:
        gaps.append("finance_risk_needs_review")
        next_tasks.append(("finance_review", "finance_department_task"))

    if state["files"]["hash"]:
        score += 10
    else:
        gaps.append("hash_module_missing")
        next_tasks.append(("hash_module_test", "hash_module_test_task"))

    if state["files"]["anchor_package"] and state["redis"]["anchor_queue"] == 0:
        score += 10
    else:
        gaps.append("anchor_package_needs_packaging")
        next_tasks.append(("anchor_package", "owner_orchestrator_task"))

    if state["files"]["monetization"]:
        score += 15
    else:
        gaps.append("monetization_department_missing_or_not_run")
        next_tasks.append(("monetization_cycle", "monetization_department_task"))

    if state["files"]["institution"] and (state["institution"]["missing_organs"] in (0, None)):
        score += 10
    else:
        gaps.append("institution_repair_needed")
        next_tasks.append(("institution_repair", "institution_audit_task"))

    if state["redis"]["evolution_rejected"] == 0:
        score += 5
    else:
        gaps.append("evolution_rejections_exist")

    if state["redis"]["spend_proposals"] > 0:
        score += 5
    else:
        gaps.append("spendability_proposal_needed")
        next_tasks.append(("spendability_proposal", "monetization_department_task"))

    maturity = "seed"
    if score >= 80:
        maturity = "growth"
    if score >= 90:
        maturity = "advanced"
    if score >= 98:
        maturity = "self_improving"

    return {
        "score": score,
        "max_score": max_score,
        "maturity": maturity,
        "gaps": gaps,
        "next_tasks": next_tasks
    }

def make_task(topic, task_type, payload):
    return {
        "topic": topic,
        "type": task_type,
        "priority": "high",
        "payload": payload
    }

def create_next_tasks(assessment, limit=5):
    created = []
    seen = set()

    for name, task_type in assessment["next_tasks"]:
        if name in seen:
            continue
        seen.add(name)

        if name == "mine_next_kibra_block":
            task = make_task(
                "Evolution Deployment: grow KIBRA proof chain",
                "kibra_token_chain_task",
                {
                    "mode": "evolution_growth_block",
                    "real_payment_execution": False,
                    "manual_owner_approval_required": True
                }
            )
        elif name == "monetization_cycle":
            task = make_task(
                "Evolution Deployment: run KIBRA monetization cycle",
                "monetization_department_task",
                {
                    "mode": "utility_first_monetization_cycle",
                    "price_guaranteed": False,
                    "manual_owner_approval_required": True
                }
            )
        elif name == "spendability_proposal":
            task = make_task(
                "Evolution Deployment: create KIBRA spendability proposal",
                "monetization_department_task",
                {
                    "mode": "spendability_proposal",
                    "service": "KIBRA-AI-TASK",
                    "real_payment_execution": False
                }
            )
        elif name == "finance_review":
            task = make_task(
                "Evolution Deployment: finance safety review",
                "finance_department_task",
                {
                    "mode": "risk_review_no_payment",
                    "real_payment_execution": False
                }
            )
        elif name == "hash_module_test":
            task = make_task(
                "Evolution Deployment: hash proof refresh",
                "hash_module_test_task",
                {
                    "mode": "refresh_double_sha_root_proof"
                }
            )
        elif name == "institution_repair":
            task = make_task(
                "Evolution Deployment: institution repair check",
                "institution_audit_task",
                {
                    "mode": "repair_committees_departments_mapping"
                }
            )
        else:
            task = make_task(
                "Evolution Deployment: owner orchestrator cleanup",
                "owner_orchestrator_task",
                {
                    "mode": "cleanup_queue_failed_anchor_finance",
                    "real_payment_execution": False
                }
            )

        r.lpush("cybra:parliament:queue", json.dumps(task, ensure_ascii=False))
        r.lpush(TASKS_KEY, json.dumps(task, ensure_ascii=False))
        created.append(task)

        if len(created) >= limit:
            break

    return created

def write_report(state, assessment, created=None):
    created = created or []

    report = {
        "status": "evolution_deployment_report_generated",
        "time": time.time(),
        "time_iso": now_iso(),
        "state": state,
        "assessment": assessment,
        "created_tasks": created,
        "policy_sha256": file_sha("parliament/evolution_deployment/evolution_deployment_policy.json")
    }

    report["double_sha"] = dsha(json.dumps(report, ensure_ascii=False, sort_keys=True))

    Path("feeds").mkdir(exist_ok=True)
    Path("posts").mkdir(exist_ok=True)
    Path("proofs").mkdir(exist_ok=True)

    Path("feeds/evolution_deployment_report.json").write_text(
        json.dumps(report, ensure_ascii=False, indent=2),
        encoding="utf-8"
    )

    gaps_md = "\n".join(f"- `{x}`" for x in assessment["gaps"]) or "- none"
    tasks_md = "\n".join(f"- `{x[0]}` → `{x[1]}`" for x in assessment["next_tasks"]) or "- none"
    created_md = "\n".join(f"- `{x.get('type')}` — {x.get('topic')}" for x in created) or "- none"

    md = f"""# CYBRA Evolution Deployment

Status: **active**  
Mode: safe growth orchestrator

## Evolution score

- Score: **{assessment["score"]}/{assessment["max_score"]}**
- Maturity: **{assessment["maturity"]}**
- Double SHA: `{report["double_sha"]}`

## Runtime

- Queue: {state["redis"]["queue"]}
- Results: {state["redis"]["results"]}
- Failed: {state["redis"]["failed"]}
- KIBRA height: {state["kibra"]["height"]}
- KIBRA latest hash: `{state["kibra"]["latest_hash"]}`
- Finance risks: {state["finance"]["risk_items"]}
- Anchor queue: {state["redis"]["anchor_queue"]}
- Anchor manual ready: {state["redis"]["anchor_manual_ready"]}
- Monetization audit: {state["redis"]["monetization_audit"]}
- Spend proposals: {state["redis"]["spend_proposals"]}

## Gaps

{gaps_md}

## Recommended next tasks

{tasks_md}

## Created tasks this cycle

{created_md}

## Rule

Evolution Deployment may create development tasks, reports, proofs and proposals.  
It must not execute real payment, token mint, liquidity pool or external blockchain transaction automatically.
"""

    Path("posts/evolution_deployment_report.md").write_text(md, encoding="utf-8")

    with Path("proofs/evolution_deployment.sha256").open("w") as f:
        subprocess.run(
            [
                "sha256sum",
                "parliament/evolution_deployment/evolution_deployment_policy.json",
                "feeds/evolution_deployment_report.json",
                "posts/evolution_deployment_report.md"
            ],
            cwd=ROOT,
            stdout=f,
            stderr=subprocess.DEVNULL
        )

    r.lpush(AUDIT_KEY, json.dumps({
        "status": "evolution_deployment_report_generated",
        "score": assessment["score"],
        "maturity": assessment["maturity"],
        "gaps": assessment["gaps"],
        "created_tasks": len(created),
        "double_sha": report["double_sha"],
        "time": report["time"]
    }, ensure_ascii=False))

    r.lpush(ROADMAP_KEY, json.dumps({
        "status": "roadmap_generated",
        "score": assessment["score"],
        "maturity": assessment["maturity"],
        "next_tasks": assessment["next_tasks"],
        "time": report["time"]
    }, ensure_ascii=False))

    print("✅ CYBRA Evolution Deployment report generated")
    print("Score:", assessment["score"], "/", assessment["max_score"])
    print("Maturity:", assessment["maturity"])
    print("Created tasks:", len(created))
    print("Report: posts/evolution_deployment_report.md")
    print("Feed: feeds/evolution_deployment_report.json")
    print("Proof: proofs/evolution_deployment.sha256")

def report_only():
    state = scan_state()
    assessment = score_state(state)
    write_report(state, assessment, [])

def develop():
    state = scan_state()
    assessment = score_state(state)
    created = create_next_tasks(assessment, limit=5)
    write_report(state, assessment, created)

def main():
    import sys
    cmd = sys.argv[1] if len(sys.argv) > 1 else "report"

    if cmd == "report":
        report_only()
    elif cmd == "develop":
        develop()
    else:
        raise SystemExit("Usage: report|develop")

if __name__ == "__main__":
    main()
PY

chmod +x cybra_evolution_deployment.py

cat > evolution_deployment_handler.sh <<'EOF2'
#!/data/data/com.termux/files/usr/bin/bash
set -e
cd "$HOME/CYBRA"

python3 cybra_evolution_deployment.py develop

for i in $(seq 1 20); do
  python3 parliament_executor_v6.py || true
  sleep 1
  [ "$(redis-cli LLEN cybra:parliament:queue)" = "0" ] && break
done

python3 cybra_evolution_deployment.py report
EOF2

chmod +x evolution_deployment_handler.sh

cat > cybra_evolution_deploy.sh <<'EOF2'
#!/data/data/com.termux/files/usr/bin/bash
set -e
cd "$HOME/CYBRA"

CMD="${1:-status}"
shift || true

case "$CMD" in
  report)
    python3 cybra_evolution_deployment.py report
    cat posts/evolution_deployment_report.md
    ;;
  develop)
    python3 cybra_evolution_deployment.py develop
    ;;
  cycle)
    python3 cybra_evolution_deployment.py develop

    for i in $(seq 1 30); do
      echo "round=$i queue=$(redis-cli LLEN cybra:parliament:queue)"
      python3 parliament_executor_v6.py || true
      sleep 1
      [ "$(redis-cli LLEN cybra:parliament:queue)" = "0" ] && break
    done

    bash cybra_monetization.sh report >/dev/null 2>&1 || true
    bash cybra_kibra_chain.sh verify >/dev/null 2>&1 || true
    bash cybra_kibra_chain.sh report >/dev/null 2>&1 || true
    bash cybra_finance.sh report >/dev/null 2>&1 || true
    bash cybra_hash_test.sh run >/dev/null 2>&1 || true
    bash cybra_institution.sh check >/dev/null 2>&1 || true
    bash review_kibra_parliament_response.sh >/dev/null 2>&1 || true

    python3 cybra_evolution_deployment.py report
    cat posts/evolution_deployment_report.md
    ;;
  loop)
    N="${1:-3}"
    for i in $(seq 1 "$N"); do
      echo "=== EVOLUTION CYCLE $i/$N ==="
      bash cybra_evolution_deploy.sh cycle
      sleep 2
    done
    ;;
  task)
    cybra parliament '{"topic":"CYBRA Evolution Deployment Cycle","type":"evolution_deployment_task","priority":"critical","payload":{"mode":"safe_growth_orchestrator","real_payment_execution":false,"automatic_external_tx":false,"manual_owner_approval_required":true}}'
    ;;
  status)
    redis-cli ping
    echo "EVOLUTION_DEPLOYMENT_AUDIT: $(redis-cli LLEN cybra:evolution_deployment:audit)"
    echo "EVOLUTION_DEPLOYMENT_ROADMAP: $(redis-cli LLEN cybra:evolution_deployment:roadmap)"
    echo "EVOLUTION_DEPLOYMENT_TASKS: $(redis-cli LLEN cybra:evolution_deployment:tasks)"
    echo "PARLIAMENT_QUEUE: $(redis-cli LLEN cybra:parliament:queue)"
    echo "PARLIAMENT_RESULTS: $(redis-cli LLEN cybra:parliament:results)"
    echo "PARLIAMENT_FAILED: $(redis-cli LLEN cybra:parliament:failed)"
    test -f posts/evolution_deployment_report.md && echo "REPORT: exists" || echo "REPORT: missing"
    ;;
  audit)
    redis-cli LRANGE cybra:evolution_deployment:audit 0 20
    ;;
  roadmap)
    redis-cli LRANGE cybra:evolution_deployment:roadmap 0 10
    ;;
  proof)
    cat proofs/evolution_deployment.sha256
    ;;
  feed)
    cat feeds/evolution_deployment_report.json
    ;;
  *)
    echo "Usage: bash cybra_evolution_deploy.sh report|develop|cycle|loop [n]|task|status|audit|roadmap|feed|proof"
    ;;
esac
EOF2

chmod +x cybra_evolution_deploy.sh

redis-cli HSET cybra:executor:mapping evolution_deployment_task evolution_deployment_handler.sh >/dev/null

python3 - <<'PY'
from pathlib import Path

p = Path("parliament_executor_v6.py")
s = p.read_text()

if 'r.hget("cybra:executor:mapping", task_type)' not in s:
    old = "script_name = SCRIPT_MAP.get(task_type)"
    new = 'script_name = r.hget("cybra:executor:mapping", task_type) or SCRIPT_MAP.get(task_type)'
    if old in s:
        s = s.replace(old, new, 1)

if '"evolution_deployment_task"' not in s:
    i = s.find("SCRIPT_MAP")
    j = s.find("{", i)
    if i >= 0 and j >= 0:
        s = s[:j+1] + '\n    "evolution_deployment_task": "evolution_deployment_handler.sh",' + s[j+1:]

p.write_text(s)
print("✅ evolution_deployment_task mapping ready")
PY

rm -rf __pycache__
python3 -m py_compile parliament_executor_v6.py
python3 -m py_compile cybra_evolution_deployment.py
rm -rf __pycache__

echo
echo "=== 1. BASE REPORT ==="
bash cybra_evolution_deploy.sh report

echo
echo "=== 2. ONE EVOLUTION CYCLE ==="
bash cybra_evolution_deploy.sh cycle

echo
echo "=== 3. TASK THROUGH PARLIAMENT ==="
bash cybra_evolution_deploy.sh task

for i in $(seq 1 30); do
  echo "round=$i queue=$(redis-cli LLEN cybra:parliament:queue)"
  python3 parliament_executor_v6.py || true
  sleep 1
  [ "$(redis-cli LLEN cybra:parliament:queue)" = "0" ] && break
done

echo
echo "=== 4. FINAL STATUS ==="
bash cybra_evolution_deploy.sh status
cybra status || true

echo
echo "=== 5. PROOF CHECK ==="
sha256sum -c proofs/evolution_deployment.sha256

echo
echo "✅ CYBRA EVOLUTION DEPLOYMENT INSTALLED"
