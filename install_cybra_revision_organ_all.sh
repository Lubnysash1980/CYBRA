#!/data/data/com.termux/files/usr/bin/bash
set -e

cd "$HOME/CYBRA"

echo "=== CYBRA REVISION ORGAN INSTALL START ==="

mkdir -p parliament/revision posts feeds proofs logs/revision

redis-cli ping >/dev/null 2>&1 || redis-server --daemonize yes
sleep 1
redis-cli ping >/dev/null

python3 - <<'PY' >/dev/null 2>&1 || python3 -m pip install redis
import redis
PY

cat > parliament/revision/cybra_revision_organ.json <<'JSON'
{
  "name": "CYBRA Parliament Revision Organ",
  "version": "1.0",
  "status": "active",
  "mission": "Перевіряти задачі Кіберапарламенту, роботу над ними, результати, audit, mapping, помилки та proof-файли.",
  "redis_keys": {
    "results": "cybra:results",
    "audit": "cybra:audit",
    "review_audit": "cybra:review:audit",
    "analytics_audit": "cybra:analytics:audit",
    "executor_mapping": "cybra:executor:mapping",
    "revision_audit": "cybra:revision:audit"
  },
  "checks": [
    "executed tasks",
    "failed tasks",
    "no executor mapping",
    "missing script",
    "missing double_sha/hash",
    "review hold/rejected",
    "queue backlog",
    "proof files"
  ],
  "policy": {
    "revision_only": true,
    "no_private_keys": true,
    "no_secret_dump": true,
    "no_illegal_actions": true
  }
}
JSON

cat > cybra_revision_organ.py <<'PY'
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
PY

chmod +x cybra_revision_organ.py

cat > revision_organ_handler.sh <<'EOF2'
#!/data/data/com.termux/files/usr/bin/bash
set -e
cd "$HOME/CYBRA"
python3 cybra_revision_organ.py
EOF2

chmod +x revision_organ_handler.sh

cat > cybra_revision.sh <<'EOF2'
#!/data/data/com.termux/files/usr/bin/bash
set -e
cd "$HOME/CYBRA"

CMD="${1:-status}"

case "$CMD" in
  collect)
    python3 cybra_revision_organ.py
    ;;
  task)
    cybra parliament '{"topic":"CYBRA Parliament Revision Organ","type":"revision_organ_task","priority":"high","payload":{"mode":"task_and_work_revision"}}'
    ;;
  status)
    redis-cli ping
    echo "RESULTS: $(redis-cli LLEN cybra:results)"
    echo "AUDIT: $(redis-cli LLEN cybra:audit)"
    echo "REVISION_AUDIT: $(redis-cli LLEN cybra:revision:audit)"
    echo "PARLIAMENT_QUEUE: $(redis-cli LLEN cybra:parliament:queue)"
    echo "REVIEW_HOLD: $(redis-cli LLEN cybra:review:hold)"
    test -f posts/revision_organ_report.md && echo "REPORT: exists" || echo "REPORT: missing"
    ;;
  report)
    cat posts/revision_organ_report.md
    ;;
  feed)
    cat feeds/revision_organ_report.json
    ;;
  proof)
    cat proofs/revision_organ.sha256
    ;;
  audit)
    redis-cli LRANGE cybra:revision:audit 0 20
    ;;
  organ)
    cat parliament/revision/cybra_revision_organ.json
    ;;
  *)
    echo "Usage: bash cybra_revision.sh collect|task|status|report|feed|proof|audit|organ"
    ;;
esac
EOF2

chmod +x cybra_revision.sh

redis-cli HSET cybra:executor:mapping revision_organ_task revision_organ_handler.sh >/dev/null

python3 - <<'PY'
from pathlib import Path

p = Path("parliament_executor_v6.py")
s = p.read_text()

if 'r.hget("cybra:executor:mapping", task_type)' not in s:
    old = "script_name = SCRIPT_MAP.get(task_type)"
    new = 'script_name = r.hget("cybra:executor:mapping", task_type) or SCRIPT_MAP.get(task_type)'
    if old in s:
        s = s.replace(old, new, 1)
        print("✅ executor patched for Redis mapping")
    else:
        print("⚠ Redis mapping patch skipped: old script_name line not found")
else:
    print("✅ executor already uses Redis mapping")

if '"revision_organ_task"' not in s:
    i = s.find("SCRIPT_MAP")
    if i < 0:
        raise SystemExit("SCRIPT_MAP not found")
    j = s.find("{", i)
    if j < 0:
        raise SystemExit("SCRIPT_MAP brace not found")
    s = s[:j+1] + '\n    "revision_organ_task": "revision_organ_handler.sh",' + s[j+1:]
    print("✅ revision_organ_task static mapping inserted")
else:
    print("✅ revision_organ_task static mapping already exists")

p.write_text(s)
PY

rm -rf __pycache__
python3 -m py_compile parliament_executor_v6.py
rm -rf __pycache__

bash cybra_revision.sh collect

sha256sum \
  parliament/revision/cybra_revision_organ.json \
  cybra_revision_organ.py \
  revision_organ_handler.sh \
  cybra_revision.sh \
  feeds/revision_organ_report.json \
  posts/revision_organ_report.md \
  > proofs/revision_organ_install.sha256

echo
echo "=== DIRECT REVISION STATUS ==="
bash cybra_revision.sh status

echo
echo "=== DIRECT REPORT PREVIEW ==="
head -80 posts/revision_organ_report.md

echo
echo "=== PARLIAMENT TASK TEST ==="
cybra worker-start || true
bash cybra_revision.sh task

sleep 5

cybra status
cybra results | head -5
bash cybra_revision.sh status

echo
echo "=== CYBRA REVISION ORGAN INSTALL DONE ==="
echo "Commit manually:"
echo "git add cybra_revision_organ.py revision_organ_handler.sh cybra_revision.sh parliament/revision/cybra_revision_organ.json parliament_executor_v6.py posts/revision_organ_report.md feeds/revision_organ_report.json proofs/revision_organ.sha256 proofs/revision_organ_install.sha256"
echo "git commit -m 'add CYBRA parliament revision organ'"
echo "git push origin main"
