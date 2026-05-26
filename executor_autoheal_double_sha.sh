#!/data/data/com.termux/files/usr/bin/bash
set -e

BASE="$HOME/CYBRA"
mkdir -p "$BASE/proofs" "$BASE/posts" "$BASE/logs/executor"

echo "=== CYBRA EXECUTOR DOUBLE-SHA AUTOHEAL ==="

cat > "$BASE/parliament_executor_v4.py" <<'PY'
import redis, json, time, hashlib, subprocess
from pathlib import Path

BASE = Path.home() / "CYBRA"
LOGS = BASE / "logs" / "executor"
LOGS.mkdir(parents=True, exist_ok=True)

r = redis.Redis(host="127.0.0.1", port=6379, decode_responses=True)

Q_IN = "cybra:parliament:submissions"
Q_RESULTS = "cybra:parliament:results"
Q_FAILED = "cybra:parliament:failed"
Q_AUDIT = "cybra:audit"

ALLOWED = {
    "native_token_ecosystem_task": ["bash", "create_native_token_ecosystem.sh"],
    "pmz_historical_metadata_task": ["bash", "create_pmz_registry.sh"],
    "cybra_autofix_task": ["bash", "cybra_autofix.sh"],
    "smart_autofix_mining_pool_task": ["bash", "cybra_mining_autofix.sh"],
    "promind_ai_evolution_task": ["bash", "-lc", "mkdir -p posts && echo '# ProMind accepted' > posts/promind_status_report.md"],
    "codespaces_remote_orchestration_task": ["bash", "-lc", "mkdir -p posts && echo '# Codespaces remote orchestration accepted' > posts/codespace_remote_status.md"]
}

def double_sha(data: str) -> str:
    first = hashlib.sha256(data.encode()).digest()
    return hashlib.sha256(first).hexdigest()

def execute(task):
    ttype = task.get("type", "generic")
    topic = task.get("topic", "unknown")
    cmd = ALLOWED.get(ttype)

    if not cmd:
        return {
            "topic": topic,
            "type": ttype,
            "status": "no_executor_mapping",
            "message": "No mapping yet. AutoHeal should create mapping in next executor generation."
        }

    p = subprocess.run(cmd, cwd=str(BASE), text=True, capture_output=True, timeout=900)

    return {
        "topic": topic,
        "type": ttype,
        "status": "executed" if p.returncode == 0 else "execution_failed",
        "cmd": cmd,
        "returncode": p.returncode,
        "stdout": p.stdout[-3000:],
        "stderr": p.stderr[-3000:],
        "time": time.time()
    }

print("=== CYBRA PARLIAMENT EXECUTOR V4 DOUBLE-SHA STARTED ===")

while True:
    raw = r.rpop(Q_IN)
    if not raw:
        time.sleep(2)
        continue

    h = double_sha(raw)

    try:
        task = json.loads(raw)
        result = execute(task)
        result["double_sha"] = h

        (LOGS / f"{h}.json").write_text(json.dumps(result, ensure_ascii=False, indent=2), encoding="utf-8")

        r.lpush(Q_RESULTS, json.dumps(result, ensure_ascii=False))
        r.lpush(Q_AUDIT, h)

        print("✅", result["status"], ":", result["topic"])

    except Exception as e:
        r.lpush(Q_FAILED, json.dumps({"raw": raw, "double_sha": h, "error": str(e)}, ensure_ascii=False))
        print("❌ FAILED:", h, e)
PY

# proof hashes
sha256sum parliament_executor_v2.py 2>/dev/null || true
sha256sum parliament_executor_v3.py 2>/dev/null || true
sha256sum parliament_executor_v4.py > proofs/executor_v4_hash.txt

python3 - <<'PY'
import hashlib, json
from pathlib import Path

files = [
    "parliament_executor_v2.py",
    "parliament_executor_v3.py",
    "parliament_executor_v4.py"
]

out = {}

for f in files:
    p = Path(f)
    if p.exists():
        raw = p.read_bytes()
        first = hashlib.sha256(raw).digest()
        second = hashlib.sha256(first).hexdigest()
        out[f] = second

Path("proofs/executor_double_sha_proof.json").write_text(
    json.dumps(out, ensure_ascii=False, indent=2),
    encoding="utf-8"
)
PY

cat > posts/executor_autoheal_status.md <<'MD'
# CYBRA Executor AutoHeal Status

Double-SHA AutoHeal created executor V4.

## Added
- double_sha audit hash
- executor V4
- mining pool mapping
- PMZ mapping
- native token mapping
- autofix mapping
- executor proof hashes

## Files
- parliament_executor_v4.py
- proofs/executor_v4_hash.txt
- proofs/executor_double_sha_proof.json
MD

git add parliament_executor_v4.py proofs posts executor_autoheal_double_sha.sh 2>/dev/null || true
git commit -m "add executor double-sha autoheal v4" || true

echo "✅ Executor V4 AutoHeal ready"
echo "Run:"
echo "python3 ~/CYBRA/parliament_executor_v4.py"
