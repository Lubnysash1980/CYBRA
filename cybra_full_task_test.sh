#!/data/data/com.termux/files/usr/bin/bash
set -e

mkdir -p posts proofs tests

redis-cli ping >/dev/null 2>&1 || redis-server --daemonize yes
bash workers/pool/worker_resilience_manager.sh || true

cat > tests/full_task_test.jsonl <<'EOF'
{"topic":"TEST 1 basic","type":"test_basic_task","payload":{"goal":"basic execution"},"priority":"normal"}
{"topic":"TEST 2 AI question","type":"ai_question_task","payload":{"question":"Скільки буде 2+2?"},"priority":"normal"}
{"topic":"TEST 3 GitHub Pages","type":"github_pages_task","payload":{"goal":"check pages root index"},"priority":"critical"}
{"topic":"TEST 4 worker resilience","type":"workers_task","payload":{"goal":"check worker autoheal"},"priority":"critical"}
{"topic":"TEST 5 token evolution","type":"native_token_evolution_task","payload":{"goal":"verify token layer"},"priority":"critical"}
EOF

while read -r T; do
  cybra parliament "$T"
done < tests/full_task_test.jsonl

sleep 15

python3 - <<'PY'
import json, subprocess, hashlib
from pathlib import Path

expected = [
    "TEST 1 basic",
    "TEST 2 AI question",
    "TEST 3 GitHub Pages",
    "TEST 4 worker resilience",
    "TEST 5 token evolution",
]

raw = subprocess.check_output("cybra results", shell=True, text=True, errors="ignore")
lines = [x for x in raw.splitlines() if x.strip().startswith("{")]

found = {}
for line in lines:
    try:
        obj = json.loads(line)
    except Exception:
        continue
    topic = obj.get("topic")
    if topic in expected and topic not in found:
        found[topic] = obj

report = {
    "expected": len(expected),
    "executed": [],
    "missing": [],
    "no_mapping": [],
    "failed": []
}

for topic in expected:
    obj = found.get(topic)
    if not obj:
        report["missing"].append(topic)
    elif obj.get("status") == "executed":
        report["executed"].append(topic)
    elif obj.get("status") == "no_executor_mapping":
        report["no_mapping"].append(topic)
    else:
        report["failed"].append({"topic": topic, "status": obj.get("status"), "obj": obj})

md = "# CYBRA Full Task Test Report\n\n"
md += f"Expected: {report['expected']}\n\n"
md += f"Executed: {len(report['executed'])}\n\n"
md += f"Missing: {len(report['missing'])}\n\n"
md += f"No mapping: {len(report['no_mapping'])}\n\n"
md += f"Failed: {len(report['failed'])}\n\n"
md += "## Executed\n" + "\n".join(f"- {x}" for x in report["executed"]) + "\n\n"
md += "## Missing\n" + "\n".join(f"- {x}" for x in report["missing"]) + "\n\n"
md += "## No mapping\n" + "\n".join(f"- {x}" for x in report["no_mapping"]) + "\n\n"

Path("posts/full_task_test_report.md").write_text(md, encoding="utf-8")
raw_report = json.dumps(report, ensure_ascii=False, indent=2)
Path("proofs/full_task_test_report.json").write_text(raw_report, encoding="utf-8")
Path("proofs/full_task_test_report.sha256").write_text(
    hashlib.sha256(raw_report.encode()).hexdigest(),
    encoding="utf-8"
)

print(md)
PY

cat posts/full_task_test_report.md
