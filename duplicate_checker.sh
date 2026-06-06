#!/data/data/com.termux/files/usr/bin/bash
set -e
redis-cli ping >/dev/null 2>\&1 || redis-server --daemonize yes
sleep 1

mkdir -p posts proofs

python3 - <<'PY'
import redis, json, hashlib
from collections import Counter
from pathlib import Path

r = redis.Redis(host="127.0.0.1", port=6379, decode_responses=True)

keys = {
    "submissions": "cybra:parliament:submissions",
    "results": "cybra:parliament:results",
    "failed": "cybra:parliament:failed",
    "retry": "cybra:parliament:retry",
    "audit": "cybra:audit"
}

report = {}

for name, key in keys.items():
    items = r.lrange(key, 0, -1)
    hashes = [hashlib.sha256(x.encode()).hexdigest() for x in items]
    c = Counter(hashes)

    report[name] = {
        "total": len(items),
        "unique": len(c),
        "duplicate_groups": len([x for x in c.values() if x > 1])
    }

raw = json.dumps(report, ensure_ascii=False, indent=2)

Path("proofs/duplicate_checker.json").write_text(raw, encoding="utf-8")

sha = hashlib.sha256(raw.encode()).hexdigest()

Path("proofs/duplicate_checker.sha256").write_text(
    sha,
    encoding="utf-8"
)

md = "# CYBRA Duplicate Checker\n\n"

for k, v in report.items():
    md += f"## {k}\n"
    md += f"- total: {v['total']}\n"
    md += f"- unique: {v['unique']}\n"
    md += f"- duplicate groups: {v['duplicate_groups']}\n\n"

Path("posts/duplicate_checker_status.md").write_text(
    md,
    encoding="utf-8"
)

print("OK")
print(sha)
PY

echo "✅ Duplicate checker completed"
echo "Report: posts/duplicate_checker_status.md"
echo "Proof JSON: proofs/duplicate_checker.json"
echo "Proof SHA256: proofs/duplicate_checker.sha256"
