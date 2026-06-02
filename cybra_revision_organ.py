#!/usr/bin/env python3
import json
import time
import hashlib
import subprocess
from pathlib import Path
from collections import Counter

import redis

r = redis.Redis(host="127.0.0.1", port=6379, decode_responses=True)

def dsha(text: str) -> str:
    h1 = hashlib.sha256(text.encode("utf-8")).hexdigest()
    return hashlib.sha256(h1.encode("utf-8")).hexdigest()

def jload(raw):
    try:
        return json.loads(raw)
    except Exception:
        return {"status": "raw_unparsed", "raw": raw}

def sh(cmd):
    try:
        return subprocess.check_output(cmd, text=True, stderr=subprocess.DEVNULL).strip()
    except Exception:
        return ""

def file_count(path):
    p = Path(path)
    if not p.exists():
        return 0
    return sum(1 for x in p.rglob("*") if x.is_file())

def main():
    r.ping()

    results_raw = r.lrange("cybra:results", 0, 299)
    results = [jload(x) for x in results_raw]

    statuses = Counter(str(x.get("status", "unknown")) for x in results)
    types = Counter(str(x.get("type", "unknown")) for x in results)
    scripts = Counter(str(x.get("script") or x.get("cmd") or "none") for x in results)

    issues = []
    executed = []
    failed = []
    no_mapping = []

    for item in results:
        status = str(item.get("status", "unknown"))
        task_type = str(item.get("type", "unknown"))
        topic = str(item.get("topic", ""))

        if status == "executed":
            executed.append(item)

            if not (item.get("double_sha") or item.get("hash")):
                issues.append({
                    "level": "warning",
                    "type": task_type,
                    "topic": topic,
                    "issue": "executed_without_double_sha"
                })

            execution = item.get("execution") or {}
            rc = execution.get("returncode", 0)

            if rc not in (0, "0", None):
                failed.append(item)
                issues.append({
                    "level": "critical",
                    "type": task_type,
                    "topic": topic,
                    "issue": f"non_zero_returncode:{rc}"
                })

        elif status == "no_executor_mapping":
            no_mapping.append(item)
            issues.append({
                "level": "important",
                "type": task_type,
                "topic": topic,
                "issue": "no_executor_mapping"
            })

        elif status in ("failed", "error"):
            failed.append(item)
            issues.append({
                "level": "critical",
                "type": task_type,
                "topic": topic,
                "issue": status
            })

    proof_files = file_count("proofs")

    if proof_files == 0:
        issues.append({
            "level": "critical",
            "type": "proofs",
            "topic": "proof archive",
            "issue": "no_proof_files"
        })

    redis_state = {
        "results": r.llen("cybra:results"),
        "audit": r.llen("cybra:audit"),
        "parliament_queue": r.llen("cybra:parliament:queue"),
        "review_incoming": r.llen("cybra:review:incoming"),
        "review_approved": r.llen("cybra:review:approved"),
        "review_hold": r.llen("cybra:review:hold"),
        "review_rejected": r.llen("cybra:review:rejected"),
        "review_audit": r.llen("cybra:review:audit"),
        "analytics_audit": r.llen("cybra:analytics:audit"),
        "revision_audit": r.llen("cybra:revision:audit")
    }

    mapping = r.hgetall("cybra:executor:mapping")

    recommendations = []

    if no_mapping:
        missing_types = sorted(set(str(x.get("type")) for x in no_mapping))
        recommendations.append({
            "level": "important",
            "message": "Є задачі без executor mapping.",
            "types": missing_types,
            "action": "bash cybra_redis_executor_mapping.sh set <type> <handler.sh>"
        })

    if failed:
        recommendations.append({
            "level": "critical",
            "message": "Є задачі з помилками виконання.",
            "action": "Перевірити cybra results, logs/parliament_v6.log та handler-и."
        })

    if redis_state["parliament_queue"] > 0:
        recommendations.append({
            "level": "warning",
            "message": "У черзі виконання залишились задачі.",
            "action": "cybra worker-start && cybra status"
        })

    if redis_state["review_hold"] > 0:
        recommendations.append({
            "level": "review",
            "message": "Є задачі на hold у review.",
            "action": "bash cybra_review.sh hold"
        })

    if not recommendations:
        recommendations.append({
            "level": "ok",
            "message": "Ревізія не знайшла критичних проблем.",
            "action": "Продовжувати моніторинг."
        })

    report = {
        "organ": "CYBRA Parliament Revision Organ",
        "status": "generated",
        "time": time.time(),
        "git": {
            "branch": sh(["git", "branch", "--show-current"]),
            "commit": sh(["git", "rev-parse", "--short", "HEAD"]),
            "dirty_files": len(sh(["git", "status", "--short"]).splitlines())
        },
        "redis": redis_state,
        "summary": {
            "checked_results": len(results),
            "executed": len(executed),
            "failed": len(failed),
            "no_executor_mapping": len(no_mapping),
            "proof_files": proof_files,
            "posts_files": file_count("posts"),
            "feeds_files": file_count("feeds"),
            "executor_mapping_count": len(mapping),
            "statuses": dict(statuses),
            "types": dict(types),
            "scripts": dict(scripts)
        },
        "issues": issues[:100],
        "latest_results": results[:20],
        "executor_mapping": mapping,
        "recommendations": recommendations
    }

    report["double_sha"] = dsha(json.dumps(report, ensure_ascii=False, sort_keys=True))

    Path("feeds").mkdir(exist_ok=True)
    Path("posts").mkdir(exist_ok=True)
    Path("proofs").mkdir(exist_ok=True)

    Path("feeds/revision_organ_report.json").write_text(
        json.dumps(report, ensure_ascii=False, indent=2)
    )

    status_lines = "\n".join(
        f"- `{k}`: {v}" for k, v in report["summary"]["statuses"].items()
    ) or "- none"

    type_lines = "\n".join(
        f"- `{k}`: {v}" for k, v in report["summary"]["types"].items()
    ) or "- none"

    issue_lines = "\n".join(
        f"- **{x.get('level')}** `{x.get('type','')}` {x.get('topic','')}: {x.get('issue')}"
        for x in report["issues"][:40]
    ) or "- Критичних проблем не знайдено"

    rec_lines = "\n".join(
        f"- **{x.get('level')}**: {x.get('message')} Action: `{x.get('action')}`"
        for x in report["recommendations"]
    )

    md = f"""# CYBRA Parliament Revision Organ

Status: generated  
Double SHA: `{report["double_sha"]}`

## Summary

- Checked results: {report["summary"]["checked_results"]}
- Executed: {report["summary"]["executed"]}
- Failed: {report["summary"]["failed"]}
- No executor mapping: {report["summary"]["no_executor_mapping"]}
- Executor mappings: {report["summary"]["executor_mapping_count"]}
- Proof files: {report["summary"]["proof_files"]}
- Posts files: {report["summary"]["posts_files"]}
- Feeds files: {report["summary"]["feeds_files"]}

## Redis state

{json.dumps(report["redis"], ensure_ascii=False, indent=2)}

## Statuses

{status_lines}

## Task types

{type_lines}

## Issues

{issue_lines}

## Recommendations

{rec_lines}
"""

    Path("posts/revision_organ_report.md").write_text(md)

    with open("proofs/revision_organ.sha256", "w") as f:
        subprocess.run(
            ["sha256sum", "feeds/revision_organ_report.json", "posts/revision_organ_report.md"],
            stdout=f,
            stderr=subprocess.DEVNULL
        )

    r.lpush("cybra:revision:audit", json.dumps({
        "status": "revision_generated",
        "time": report["time"],
        "double_sha": report["double_sha"],
        "issues": len(report["issues"]),
        "checked_results": len(results)
    }, ensure_ascii=False))

    print("✅ CYBRA revision organ report generated")
    print("Report: posts/revision_organ_report.md")
    print("Feed: feeds/revision_organ_report.json")
    print("Proof: proofs/revision_organ.sha256")

if __name__ == "__main__":
    main()
