#!/usr/bin/env python3
import json
import time
import hashlib
import subprocess
from pathlib import Path
from collections import Counter, defaultdict

import redis

ROOT = Path.home() / "CYBRA"
r = redis.Redis(host="127.0.0.1", port=6379, decode_responses=True)

SCAN_KEYS = [
    "cybra:parliament:queue",
    "cybra:parliament:results",
    "cybra:parliament:failed",
    "cybra:review:approved",
    "cybra:review:hold",
    "cybra:review:rejected",
    "cybra:evolution:approved",
    "cybra:evolution:hold",
    "cybra:evolution:rejected",
    "cybra:evolution_deployment:tasks"
]

SAFE_FALLBACK_BY_TYPE = {
    "air_alert_task": "air_alert_handler.sh",
    "analytics_committee_task": "analytics_committee_handler.sh",
    "revision_organ_task": "revision_organ_handler.sh",
    "evolution_guard_task": "evolution_guard_handler.sh",
    "closed_evolution_selfseal_task": "closed_evolution_selfseal_handler.sh",
    "biometric_succession_task": "biometric_succession_handler.sh",
    "audit_dedupe_test_task": "audit_dedupe_test_handler.sh",
    "hash_module_test_task": "hash_module_test_handler.sh",
    "institution_audit_task": "institution_audit_handler.sh",
    "finance_department_task": "finance_department_handler.sh",
    "owner_orchestrator_task": "owner_orchestrator_handler.sh",
    "token_pool_ai_task": "token_pool_ai_handler.sh",
    "kibra_token_chain_task": "kibra_token_chain_handler.sh",
    "monetization_department_task": "monetization_department_handler.sh",
    "evolution_deployment_task": "evolution_deployment_handler.sh",
    "cybra_autofix_task": "cybra_autofix.sh",
    "smart_autofix_mining_pool_task": "cybra_mining_autofix.sh",
    "pmz_historical_metadata_task": "create_pmz_registry.sh",
    "native_token_ecosystem_task": "create_native_token_ecosystem.sh",
    "evo_committee_task": "evo_committee_handler.sh",
    "committee_creation_task": "evo_committee_handler.sh",
    "self_expanding_execution_engine_task": "evo_committee_handler.sh",
    "executor_autoheal_task": "evo_committee_handler.sh",
    "codespaces_keepalive_task": "evo_committee_handler.sh",
    "github_double_backend_task": "evo_committee_handler.sh",
    "queue_fix": "evo_committee_handler.sh",
    "ai_task": "evo_committee_handler.sh",
    "test": "evo_committee_handler.sh"
}

AUDIT_KEY = "cybra:existing_tasks_activation:audit"

def sha(x):
    return hashlib.sha256(x.encode("utf-8")).hexdigest()

def dsha(x):
    return sha(sha(x))

def now_iso():
    return time.strftime("%Y-%m-%dT%H:%M:%S%z")

def slug(x):
    s = str(x or "unknown").lower()
    out = []
    for ch in s:
        if ch.isalnum() or ch in "_-":
            out.append(ch)
        else:
            out.append("_")
    return "".join(out).strip("_")[:80] or "unknown"

def git_cmd(cmd):
    try:
        return subprocess.check_output(cmd, cwd=ROOT, text=True, stderr=subprocess.DEVNULL).strip()
    except Exception:
        return ""

def load_json(raw, source):
    try:
        obj = json.loads(raw)
        if isinstance(obj, dict):
            obj["_source_key"] = source
            return obj
    except Exception:
        pass
    return {"type": "unknown_raw", "status": "raw_unparsed", "raw": raw, "_source_key": source}

def scan_records():
    records = []
    for key in SCAN_KEYS:
        try:
            for raw in r.lrange(key, 0, 1000):
                records.append(load_json(raw, key))
        except Exception:
            pass
    return records

def handler_exists(handler):
    if not handler:
        return False
    if isinstance(handler, list):
        return True
    h = str(handler)
    if h.startswith("[") or h.startswith("{"):
        return True
    if h.endswith(".sh") or h.endswith(".py") or h.endswith(".mjs") or h.endswith(".js"):
        return (ROOT / h).exists()
    return True

def choose_fallback(task_type):
    h = SAFE_FALLBACK_BY_TYPE.get(task_type)
    if h and (ROOT / h).exists():
        return h

    if (ROOT / "evo_committee_handler.sh").exists():
        return "evo_committee_handler.sh"

    return "generic_existing_task_handler.sh"

def create_committee(task_type, topics):
    base = ROOT / "parliament" / "committees" / f"{slug(task_type)}_committee"
    base.mkdir(parents=True, exist_ok=True)

    obj = {
        "committee_id": f"{slug(task_type)}_committee",
        "status": "active",
        "task_type": task_type,
        "purpose": "Support existing tasks under Evolution Deployment: mapping, handler validation, audit, proof, safe fallback.",
        "topics_seen": sorted(list(set(str(x) for x in topics if x)))[:30],
        "rules": [
            "no_automatic_payment",
            "no_automatic_token_mint",
            "no_external_blockchain_tx_without_owner",
            "audit_required",
            "proof_required",
            "evolution_deployment_compatible"
        ],
        "time_iso": now_iso()
    }
    obj["double_sha"] = dsha(json.dumps(obj, ensure_ascii=False, sort_keys=True))

    (base / "committee.json").write_text(json.dumps(obj, ensure_ascii=False, indent=2), encoding="utf-8")
    (base / "README.md").write_text(
        f"# {obj['committee_id']}\n\n"
        f"Task type: `{task_type}`\n\n"
        "Status: active\n\n"
        f"Double SHA: `{obj['double_sha']}`\n",
        encoding="utf-8"
    )

def validate_handler(handler):
    if not handler:
        return {"ok": False, "reason": "missing"}

    h = str(handler)

    if h.startswith("[") or h.startswith("{"):
        return {"ok": True, "reason": "legacy_command_mapping"}

    path = ROOT / h

    if not path.exists():
        return {"ok": False, "reason": "file_missing"}

    try:
        if h.endswith(".sh"):
            subprocess.check_output(["bash", "-n", h], cwd=ROOT, text=True, stderr=subprocess.STDOUT)
            return {"ok": True, "reason": "bash_syntax_ok"}
        if h.endswith(".py"):
            subprocess.check_output(["python3", "-m", "py_compile", h], cwd=ROOT, text=True, stderr=subprocess.STDOUT)
            return {"ok": True, "reason": "python_compile_ok"}
        return {"ok": True, "reason": "exists"}
    except subprocess.CalledProcessError as e:
        return {"ok": False, "reason": e.output[-500:]}

def archive_fixed_failures():
    failed_key = "cybra:parliament:failed"
    archive_key = "cybra:parliament:failed:archive"
    archived = 0

    for raw in r.lrange(failed_key, 0, -1):
        try:
            obj = json.loads(raw)
        except Exception:
            continue

        t = obj.get("type")
        status = obj.get("status")
        text = json.dumps(obj, ensure_ascii=False).lower()
        reason = None

        current_mapping = r.hget("cybra:executor:mapping", t or "")

        if status == "no_executor_mapping" and current_mapping:
            reason = f"old_no_mapping_fixed_now:{current_mapping}"

        if t == "kibra_token_chain_task" and "hash mismatch" in text:
            verify = ROOT / "feeds/kibra_chain_verify.json"
            if verify.exists():
                try:
                    v = json.loads(verify.read_text())
                    if v.get("status") == "verified":
                        reason = "old_kibra_verify_failure_fixed_now"
                except Exception:
                    pass

        if reason:
            r.lpush(archive_key, json.dumps({
                "archived_status": "fixed_or_superseded",
                "archive_reason": reason,
                "archived_at": time.time(),
                "original": obj
            }, ensure_ascii=False))
            r.lrem(failed_key, 1, raw)
            archived += 1

    return archived

def repair():
    r.ping()

    records = scan_records()
    mapping = r.hgetall("cybra:executor:mapping")

    topics = defaultdict(list)
    counts = Counter()

    for rec in records:
        t = rec.get("type")
        if t is None:
            t = "None"
        t = str(t)
        counts[t] += 1
        topics[t].append(rec.get("topic"))

    fixed_mapping = []
    created_committees = []

    for task_type in sorted(counts.keys()):
        if task_type in ("None", "unknown", "unknown_raw", ""):
            continue

        current = mapping.get(task_type)
        if not current or not handler_exists(current):
            fallback = choose_fallback(task_type)
            r.hset("cybra:executor:mapping", task_type, fallback)
            fixed_mapping.append({
                "task_type": task_type,
                "old_mapping": current,
                "new_mapping": fallback
            })

        create_committee(task_type, topics[task_type])
        created_committees.append(task_type)

    archived = archive_fixed_failures()

    report_obj = build_report(mode="repair")
    report_obj["repair"] = {
        "fixed_mapping": fixed_mapping,
        "created_or_checked_committees": created_committees,
        "archived_failed_records": archived
    }

    write_report(report_obj)

    print("✅ existing tasks repair completed")
    print("Fixed mappings:", len(fixed_mapping))
    print("Committees checked:", len(created_committees))
    print("Archived failed:", archived)

def build_report(mode="report"):
    records = scan_records()
    mapping = r.hgetall("cybra:executor:mapping")

    counts = Counter()
    statuses = Counter()
    sources = Counter()
    support = []

    for rec in records:
        t = rec.get("type")
        if t is None:
            t = "None"
        t = str(t)
        counts[t] += 1
        statuses[str(rec.get("status", "unknown"))] += 1
        sources[str(rec.get("_source_key", "unknown"))] += 1

    for task_type in sorted(counts.keys()):
        current = mapping.get(task_type)
        exists = handler_exists(current)
        committee = ROOT / "parliament" / "committees" / f"{slug(task_type)}_committee"
        validation = validate_handler(current) if current else {"ok": False, "reason": "missing_mapping"}

        support.append({
            "task_type": task_type,
            "count": counts[task_type],
            "mapping": current,
            "handler_exists": exists,
            "handler_validation": validation,
            "committee_exists": committee.exists()
        })

    missing_mapping = [x for x in support if x["task_type"] not in ("None", "unknown_raw") and not x["mapping"]]
    missing_handler = [x for x in support if x["mapping"] and not x["handler_exists"]]
    failed_validation = [x for x in support if x["mapping"] and not x["handler_validation"]["ok"]]
    missing_committee = [x for x in support if x["task_type"] not in ("None", "unknown_raw") and not x["committee_exists"]]

    score = 100
    score -= len(missing_mapping) * 5
    score -= len(missing_handler) * 5
    score -= len(failed_validation) * 3
    score -= len(missing_committee) * 2
    if score < 0:
        score = 0

    report = {
        "status": "existing_tasks_evolution_activation_report",
        "mode": mode,
        "time": time.time(),
        "time_iso": now_iso(),
        "score": score,
        "git": {
            "branch": git_cmd(["git", "branch", "--show-current"]),
            "commit": git_cmd(["git", "rev-parse", "--short", "HEAD"]),
            "dirty_files": len(git_cmd(["git", "status", "--short"]).splitlines())
        },
        "redis": {
            "queue": r.llen("cybra:parliament:queue"),
            "results": r.llen("cybra:parliament:results"),
            "failed": r.llen("cybra:parliament:failed"),
            "failed_archive": r.llen("cybra:parliament:failed:archive"),
            "mapping_count": r.hlen("cybra:executor:mapping")
        },
        "summary": {
            "records_checked": len(records),
            "task_types": len(counts),
            "missing_mapping": len(missing_mapping),
            "missing_handler": len(missing_handler),
            "failed_validation": len(failed_validation),
            "missing_committee": len(missing_committee)
        },
        "statuses": dict(statuses),
        "sources": dict(sources),
        "task_types": dict(counts),
        "support_matrix": support,
        "missing_mapping": missing_mapping,
        "missing_handler": missing_handler,
        "failed_validation": failed_validation,
        "missing_committee": missing_committee,
        "recommendations": []
    }

    if not missing_mapping and not missing_handler and not failed_validation and not missing_committee:
        report["recommendations"].append({
            "level": "ok",
            "message": "All existing task types have mapping, handlers and committees under Evolution Deployment.",
            "action": "Continue evolution cycles."
        })
    else:
        report["recommendations"].append({
            "level": "repair",
            "message": "Some existing tasks still need mapping/handler/committee repair.",
            "action": "Run: bash cybra_existing_tasks.sh repair"
        })

    report["double_sha"] = dsha(json.dumps(report, ensure_ascii=False, sort_keys=True))
    return report

def write_report(report):
    Path("feeds").mkdir(exist_ok=True)
    Path("posts").mkdir(exist_ok=True)
    Path("proofs").mkdir(exist_ok=True)

    Path("feeds/existing_tasks_evolution_activation.json").write_text(
        json.dumps(report, ensure_ascii=False, indent=2),
        encoding="utf-8"
    )

    support_md = ""
    for x in report["support_matrix"]:
        support_md += (
            f"- `{x['task_type']}` count={x['count']} "
            f"mapping=`{x['mapping']}` handler_exists={x['handler_exists']} "
            f"validation={x['handler_validation']['ok']} committee={x['committee_exists']}\n"
        )

    rec_md = ""
    for x in report["recommendations"]:
        rec_md += f"- **{x['level']}**: {x['message']} Action: `{x['action']}`\n"

    md = f"""# CYBRA Existing Tasks Evolution Activation

Status: generated  
Mode: {report["mode"]}  
Score: **{report["score"]}/100**  
Double SHA: `{report["double_sha"]}`

## Redis

- Queue: {report["redis"]["queue"]}
- Results: {report["redis"]["results"]}
- Failed: {report["redis"]["failed"]}
- Failed archive: {report["redis"]["failed_archive"]}
- Mapping count: {report["redis"]["mapping_count"]}

## Summary

- Records checked: {report["summary"]["records_checked"]}
- Task types: {report["summary"]["task_types"]}
- Missing mapping: {report["summary"]["missing_mapping"]}
- Missing handler: {report["summary"]["missing_handler"]}
- Failed validation: {report["summary"]["failed_validation"]}
- Missing committee: {report["summary"]["missing_committee"]}

## Support matrix

{support_md}

## Recommendations

{rec_md}
"""

    Path("posts/existing_tasks_evolution_activation.md").write_text(md, encoding="utf-8")

    with Path("proofs/existing_tasks_evolution_activation.sha256").open("w") as f:
        subprocess.run(
            [
                "sha256sum",
                "parliament/existing_tasks_activation/policy.json",
                "feeds/existing_tasks_evolution_activation.json",
                "posts/existing_tasks_evolution_activation.md"
            ],
            cwd=ROOT,
            stdout=f,
            stderr=subprocess.DEVNULL
        )

    r.lpush(AUDIT_KEY, json.dumps({
        "status": "existing_tasks_activation_report_generated",
        "mode": report["mode"],
        "score": report["score"],
        "summary": report["summary"],
        "double_sha": report["double_sha"],
        "time": report["time"]
    }, ensure_ascii=False))

def report():
    write_report(build_report(mode="report"))
    print("✅ existing tasks activation report generated")
    print("Report: posts/existing_tasks_evolution_activation.md")
    print("Feed: feeds/existing_tasks_evolution_activation.json")
    print("Proof: proofs/existing_tasks_evolution_activation.sha256")

def submit_test_task():
    task = {
        "topic": "CYBRA Existing Tasks Evolution Activation",
        "type": "existing_tasks_activation_task",
        "priority": "critical",
        "payload": {
            "mode": "validate_all_existing_tasks",
            "real_payment_execution": False,
            "automatic_token_mint": False,
            "automatic_external_tx": False,
            "manual_owner_approval_required": True
        }
    }
    r.lpush("cybra:parliament:queue", json.dumps(task, ensure_ascii=False))
    print("✅ existing_tasks_activation_task submitted")

def main():
    import sys
    cmd = sys.argv[1] if len(sys.argv) > 1 else "report"

    if cmd == "repair":
        repair()
    elif cmd == "report":
        report()
    elif cmd == "task":
        submit_test_task()
    else:
        raise SystemExit("Usage: report|repair|task")

if __name__ == "__main__":
    main()
