#!/data/data/com.termux/files/usr/bin/bash
set -e
cd "$HOME/CYBRA"

CMD="${1:-status}"
shift || true

case "$CMD" in
  submit)
    python3 cybra_submit_guarded.py submit "$@"
    ;;
  status)
    redis-cli ping
    echo "QUEUE: $(redis-cli LLEN cybra:parliament:queue)"
    echo "RESULTS: $(redis-cli LLEN cybra:parliament:results)"
    echo "DEDUPE_FINGERPRINTS: $(redis-cli SCARD cybra:dedupe:fingerprints)"
    echo "FINGERPRINT_RECORDS: $(redis-cli HLEN cybra:audit:fingerprints)"
    echo "STRUCTURED_AUDIT: $(redis-cli LLEN cybra:audit:structured)"
    echo "DUPLICATES_BLOCKED: $(redis-cli LLEN cybra:dedupe:duplicates)"
    test -f posts/audit_dedupe_report.md && echo "REPORT: exists" || echo "REPORT: missing"
    ;;
  duplicates)
    redis-cli LRANGE cybra:dedupe:duplicates 0 20
    ;;
  audit)
    redis-cli LRANGE cybra:audit:structured 0 20
    ;;
  fingerprints)
    redis-cli HKEYS cybra:audit:fingerprints | head -50
    ;;
  report)
    python3 - <<'PY'
import json, time, hashlib, subprocess
from pathlib import Path
from collections import Counter
import redis

r = redis.Redis(host="127.0.0.1", port=6379, decode_responses=True)
r.ping()

def load(x):
    try:
        return json.loads(x)
    except Exception:
        return {"status": "raw", "raw": x}

def dsha(text):
    h1 = hashlib.sha256(text.encode("utf-8")).hexdigest()
    return hashlib.sha256(h1.encode("utf-8")).hexdigest()

audit = [load(x) for x in r.lrange("cybra:audit:structured", 0, 499)]
dups = [load(x) for x in r.lrange("cybra:dedupe:duplicates", 0, 199)]

decisions = Counter(str(x.get("decision", "unknown")) for x in audit)
types = Counter(str(x.get("type", "unknown")) for x in audit)
topics = Counter(str(x.get("topic", "unknown")) for x in audit)

report = {
    "name": "CYBRA Audit Dedupe Report",
    "status": "generated",
    "time": time.time(),
    "summary": {
        "structured_audit": len(audit),
        "duplicates_blocked": len(dups),
        "dedupe_fingerprints": r.scard("cybra:dedupe:fingerprints"),
        "fingerprint_records": r.hlen("cybra:audit:fingerprints"),
        "queue": r.llen("cybra:parliament:queue"),
        "results": r.llen("cybra:parliament:results")
    },
    "decisions": dict(decisions),
    "types": dict(types),
    "topics_top": dict(topics.most_common(20)),
    "latest_audit": audit[:20],
    "latest_duplicates": dups[:20]
}

report["double_sha"] = dsha(json.dumps(report, ensure_ascii=False, sort_keys=True))

Path("feeds").mkdir(exist_ok=True)
Path("posts").mkdir(exist_ok=True)
Path("proofs").mkdir(exist_ok=True)

Path("feeds/audit_dedupe_report.json").write_text(json.dumps(report, ensure_ascii=False, indent=2))

def lines(d):
    if not d:
        return "- none"
    return "\n".join(f"- `{k}`: {v}" for k, v in sorted(d.items(), key=lambda x: x[1], reverse=True))

md = f"""# CYBRA Audit Dedupe Report

Status: generated  
Double SHA: `{report["double_sha"]}`

## Summary

- Structured audit: {report["summary"]["structured_audit"]}
- Duplicates blocked: {report["summary"]["duplicates_blocked"]}
- Dedupe fingerprints: {report["summary"]["dedupe_fingerprints"]}
- Fingerprint records: {report["summary"]["fingerprint_records"]}
- Queue: {report["summary"]["queue"]}
- Results: {report["summary"]["results"]}

## Decisions

{lines(report["decisions"])}

## Types

{lines(report["types"])}

## Top topics

{lines(report["topics_top"])}
"""

Path("posts/audit_dedupe_report.md").write_text(md)

with open("proofs/audit_dedupe_report.sha256", "w") as f:
    subprocess.run(
        ["sha256sum", "feeds/audit_dedupe_report.json", "posts/audit_dedupe_report.md"],
        stdout=f,
        stderr=subprocess.DEVNULL
    )

print("✅ audit/dedupe report generated")
print("Report: posts/audit_dedupe_report.md")
PY
    cat posts/audit_dedupe_report.md
    ;;
  *)
    echo "Usage:"
    echo "  bash cybra_audit_dedupe.sh submit '<json_task>' [--force]"
    echo "  bash cybra_audit_dedupe.sh status|report|audit|duplicates|fingerprints"
    ;;
esac
