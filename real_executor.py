import redis, json, time, hashlib, subprocess, os
from pathlib import Path

BASE = Path.home() / "CYBRA"

r = redis.Redis(host="127.0.0.1", port=6379, decode_responses=True)

Q_IN = "cybra:parliament:submissions"
Q_RESULTS = "cybra:parliament:results"
Q_FAILED = "cybra:parliament:failed"
Q_AUDIT = "cybra:audit"

ALLOWED = {
    "native_token_ecosystem_task": "bash create_native_token_ecosystem.sh",
    "codespaces_token_task": "bash codespace_full_auto.sh FesrWxqM67HrjFqsCoCHsUkRocZZBgWeg4P3T4b9FD9Y 1000000 9",
    "cybra_test_pipeline_task": "bash cybra_test_pipeline.sh",
    "promind_ai_evolution_task": "echo ProMind task accepted",
    "remote_codespace_task": "echo Remote Codespaces task accepted"
}

def sha(x):
    return hashlib.sha256(x.encode()).hexdigest()

def run_task(task):
    ttype = task.get("type", "generic")
    topic = task.get("topic", "unknown")

    cmd = ALLOWED.get(ttype)

    if not cmd:
        return {
            "topic": topic,
            "type": ttype,
            "status": "processed_no_executor_mapping",
            "message": "Task saved, but no real executor mapping exists yet."
        }

    result = subprocess.run(
        cmd,
        shell=True,
        cwd=str(BASE),
        text=True,
        capture_output=True,
        timeout=600
    )

    return {
        "topic": topic,
        "type": ttype,
        "status": "executed" if result.returncode == 0 else "failed_execution",
        "command": cmd,
        "returncode": result.returncode,
        "stdout": result.stdout[-4000:],
        "stderr": result.stderr[-4000:],
        "time": time.time()
    }

print("=== CYBRA REAL EXECUTOR STARTED ===")

while True:
    raw = r.rpop(Q_IN)

    if not raw:
        time.sleep(2)
        continue

    h = sha(raw)

    try:
        task = json.loads(raw)
        result = run_task(task)
        result["hash"] = h

        r.lpush(Q_RESULTS, json.dumps(result, ensure_ascii=False))
        r.lpush(Q_AUDIT, h)

        print("✅", result["status"], ":", result["topic"])

    except Exception as e:
        fail = {
            "raw": raw,
            "hash": h,
            "error": str(e),
            "time": time.time()
        }
        r.lpush(Q_FAILED, json.dumps(fail, ensure_ascii=False))
        print("❌ FAILED:", h, e)
