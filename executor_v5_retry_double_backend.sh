#!/data/data/com.termux/files/usr/bin/bash
set -e

BASE="$HOME/CYBRA"
mkdir -p "$BASE"/{proofs,posts,logs/executor,remote_queue,remote_results,remote_logs}

cat > "$BASE/parliament_executor_v5.py" <<'PY'
import redis, json, time, hashlib, subprocess
from pathlib import Path

BASE = Path.home() / "CYBRA"
LOGS = BASE / "logs" / "executor"
LOGS.mkdir(parents=True, exist_ok=True)

r = redis.Redis(host="127.0.0.1", port=6379, decode_responses=True)

Q_IN="cybra:parliament:submissions"
Q_RESULTS="cybra:parliament:results"
Q_FAILED="cybra:parliament:failed"
Q_RETRY="cybra:parliament:retry"
Q_AUDIT="cybra:audit"

MAX_RETRIES=3

ALLOWED = {
    "native_token_ecosystem_task": ["bash", "create_native_token_ecosystem.sh"],
    "pmz_historical_metadata_task": ["bash", "create_pmz_registry.sh"],
    "cybra_autofix_task": ["bash", "cybra_autofix.sh"],
    "smart_autofix_mining_pool_task": ["bash", "cybra_mining_autofix.sh"],
    "executor_autoheal_task": ["bash", "executor_autoheal_double_sha.sh"],
    "github_double_backend_task": ["bash", "github_double_backend.sh"],
    "codespaces_keepalive_task": ["bash", "codespace_keepalive_task.sh"],
    "promind_ai_evolution_task": ["bash", "-lc", "mkdir -p posts && echo '# ProMind accepted' > posts/promind_status_report.md"]
}

def dsha(data: str) -> str:
    first = hashlib.sha256(data.encode()).digest()
    return hashlib.sha256(first).hexdigest()

def execute(task):
    ttype = task.get("type", "generic")
    topic = task.get("topic", "unknown")
    cmd = ALLOWED.get(ttype)

    if not cmd:
        return {"topic": topic, "type": ttype, "status": "no_executor_mapping"}

    p = subprocess.run(cmd, cwd=str(BASE), text=True, capture_output=True, timeout=1200)

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

def handle(raw):
    h = dsha(raw)
    try:
        task = json.loads(raw)
        retries = int(task.get("_retries", 0))

        result = execute(task)
        result["double_sha"] = h
        result["retries"] = retries

        (LOGS / f"{h}.json").write_text(json.dumps(result, ensure_ascii=False, indent=2), encoding="utf-8")

        if result["status"] == "executed":
            r.lpush(Q_RESULTS, json.dumps(result, ensure_ascii=False))
            r.lpush(Q_AUDIT, h)
            print("✅ executed:", result["topic"])
        else:
            if retries < MAX_RETRIES:
                task["_retries"] = retries + 1
                r.lpush(Q_RETRY, json.dumps(task, ensure_ascii=False))
                print("🔁 retry queued:", task.get("topic"), retries + 1)
            else:
                r.lpush(Q_FAILED, json.dumps(result, ensure_ascii=False))
                print("❌ failed final:", result["topic"])

    except Exception as e:
        fail = {"raw": raw, "double_sha": h, "error": str(e), "time": time.time()}
        r.lpush(Q_FAILED, json.dumps(fail, ensure_ascii=False))
        print("❌ failed parse:", h)

print("=== CYBRA PARLIAMENT EXECUTOR V5 RETRY DOUBLE BACKEND ===")

while True:
    raw = r.rpop(Q_RETRY) or r.rpop(Q_IN)
    if not raw:
        time.sleep(2)
        continue
    handle(raw)
PY

cat > "$BASE/github_double_backend.sh" <<'BASH'
#!/data/data/com.termux/files/usr/bin/bash
set -e

BASE="$HOME/CYBRA"
mkdir -p "$BASE/proofs" "$BASE/posts"

find "$BASE" \
  -path "$BASE/.git" -prune -o \
  -path "$BASE/venv" -prune -o \
  -path "$BASE/.venv" -prune -o \
  -type f -exec sha256sum {} \; > "$BASE/proofs/github_backend_sha256.txt"

python3 - <<'PY'
import hashlib, json
from pathlib import Path

base = Path.home() / "CYBRA"
items = {}
for p in base.rglob("*"):
    if ".git" in p.parts or "venv" in p.parts or ".venv" in p.parts:
        continue
    if p.is_file():
        raw = p.read_bytes()
        first = hashlib.sha256(raw).digest()
        items[str(p.relative_to(base))] = hashlib.sha256(first).hexdigest()

(base / "proofs" / "github_double_backend_proof.json").write_text(
    json.dumps(items, ensure_ascii=False, indent=2),
    encoding="utf-8"
)
PY

cat > "$BASE/posts/github_double_backend_status.md" <<'MD'
# CYBRA GitHub Double Backend

Double-SHA proof backend created for repository files.

Files:
- proofs/github_backend_sha256.txt
- proofs/github_double_backend_proof.json
MD

git add proofs posts 2>/dev/null || true
git commit -m "CYBRA GitHub double backend proof" || true

echo "✅ GitHub double backend proof created"
BASH
chmod +x "$BASE/github_double_backend.sh"

cat > "$BASE/codespace_keepalive_task.sh" <<'BASH'
#!/data/data/com.termux/files/usr/bin/bash
set -e

BASE="$HOME/CYBRA"
mkdir -p "$BASE/remote_queue"

ID="task_codespace_keepalive_$(date +%Y%m%d_%H%M%S).task"

cat > "$BASE/remote_queue/$ID" <<'TASK'
echo "=== CYBRA Codespaces keepalive ==="
date
git status
bash cybra_test_pipeline.sh 2>/dev/null || true
TASK

git add "remote_queue/$ID"
git commit -m "Codespaces keepalive task $ID" || true
git push || true

echo "✅ Codespaces keepalive task queued: $ID"
BASH
chmod +x "$BASE/codespace_keepalive_task.sh"

cat > "$BASE/posts/executor_v5_status.md" <<'MD'
# CYBRA Executor V5 Status

Added:
- retry queue
- max retries: 3
- double-sha audit
- failed queue
- GitHub double backend
- Codespaces keepalive task support
- executor logs
MD

python3 - <<'PY'
import hashlib, json
from pathlib import Path
base = Path.home() / "CYBRA"
files = ["parliament_executor_v5.py", "github_double_backend.sh", "codespace_keepalive_task.sh"]
out = {}
for f in files:
    p = base / f
    raw = p.read_bytes()
    first = hashlib.sha256(raw).digest()
    out[f] = hashlib.sha256(first).hexdigest()
(base / "proofs" / "executor_v5_double_sha.json").write_text(json.dumps(out, indent=2), encoding="utf-8")
PY

git add parliament_executor_v5.py github_double_backend.sh codespace_keepalive_task.sh posts proofs executor_v5_retry_double_backend.sh 2>/dev/null || true
git commit -m "add executor v5 retry double backend" || true

echo "✅ Executor V5 installed"
