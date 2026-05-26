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
    "promind_ai_evolution_task": ["bash", "-lc", "mkdir -p posts && echo '# ProMind accepted' > posts/promind_status_report.md"],
    "self_expanding_execution_engine_task": ["bash", "run_answer_engine.sh"]
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
