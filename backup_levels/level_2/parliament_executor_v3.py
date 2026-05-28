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
    "promind_ai_evolution_task": ["bash", "-lc", "mkdir -p posts && echo '# ProMind accepted' > posts/promind_status_report.md"],
    "codespaces_remote_orchestration_task": ["bash", "-lc", "mkdir -p posts && echo '# Codespaces remote orchestration accepted' > posts/codespace_remote_status.md"]
}

def sha(x):
    return hashlib.sha256(x.encode()).hexdigest()

def execute(task):
    ttype = task.get("type", "generic")
    topic = task.get("topic", "unknown")
    cmd = ALLOWED.get(ttype)

    if not cmd:
        return {"topic": topic, "type": ttype, "status": "no_executor_mapping"}

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

print("=== CYBRA PARLIAMENT EXECUTOR V3 STARTED ===")

while True:
    raw = r.rpop(Q_IN)
    if not raw:
        time.sleep(2)
        continue

    h = sha(raw)

    try:
        task = json.loads(raw)
        result = execute(task)
        result["hash"] = h
        (LOGS / f"{h}.json").write_text(json.dumps(result, ensure_ascii=False, indent=2), encoding="utf-8")
        r.lpush(Q_RESULTS, json.dumps(result, ensure_ascii=False))
        r.lpush(Q_AUDIT, h)
        print("✅", result["status"], ":", result["topic"])
    except Exception as e:
        r.lpush(Q_FAILED, json.dumps({"raw": raw, "hash": h, "error": str(e)}, ensure_ascii=False))
        print("❌ FAILED:", h, e)
