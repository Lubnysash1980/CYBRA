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
