import json
import time
import hashlib
import subprocess
import sys
from pathlib import Path

import redis

BASE = Path.home() / "CYBRA"
sys.path.insert(0, str(BASE))

Q_IN = "cybra:parliament:submissions"
Q_RESULTS = "cybra:parliament:results"
Q_FAILED = "cybra:parliament:failed"
Q_RETRY = "cybra:parliament:retry"
Q_AUDIT = "cybra:audit"

MAX_RETRIES = 3

SCRIPT_MAP = {
    "native_token_ecosystem_task": "create_native_token_ecosystem.sh",
    "pmz_historical_metadata_task": "create_pmz_registry.sh",
    "cybra_autofix_task": "cybra_autofix.sh",
    "smart_autofix_mining_pool_task": "cybra_mining_autofix.sh",
    "executor_autoheal_task": "executor_autoheal_double_sha.sh",
    "github_double_backend_task": "github_double_backend.sh",
    "codespaces_keepalive_task": "codespace_keepalive_task.sh",
    "self_expanding_execution_engine_task": "run_answer_engine.sh",
    "executor_autoheal_task": "executor_autoheal_double_sha.sh",
    "github_double_backend_task": "github_double_backend.sh",
    "codespaces_keepalive_task": "codespace_keepalive_task.sh"
}

def double_sha(data: str) -> str:
    first = hashlib.sha256(data.encode()).digest()
    return hashlib.sha256(first).hexdigest()

def run_script(script_name: str):
    script = BASE / script_name
    if not script.exists():
        return {
            "ok": False,
            "error": f"script_not_found: {script_name}"
        }

    result = subprocess.run(
        ["bash", str(script)],
        cwd=str(BASE),
        text=True,
        capture_output=True,
        timeout=1200
    )

    return {
        "ok": result.returncode == 0,
        "returncode": result.returncode,
        "stdout": result.stdout[-4000:],
        "stderr": result.stderr[-4000:]
    }

def handle_task(raw: str):
    task_hash = double_sha(raw)
    task = json.loads(raw)

    task_type = task.get("type", "generic")
    topic = task.get("topic", "unknown")
    retries = int(task.get("_retries", 0))

    script_name = SCRIPT_MAP.get(task_type)

    if not script_name:
        return {
            "topic": topic,
            "type": task_type,
            "status": "no_executor_mapping",
            "double_sha": task_hash,
            "message": "No script mapping yet"
        }

    execution = run_script(script_name)

    status = "executed" if execution.get("ok") else "execution_failed"

    return {
        "topic": topic,
        "type": task_type,
        "status": status,
        "script": script_name,
        "double_sha": task_hash,
        "retries": retries,
        "execution": execution,
        "time": time.time()
    }

def main():
    r = redis.Redis(host="127.0.0.1", port=6379, decode_responses=True)

    logs = BASE / "logs" / "executor_v6"
    logs.mkdir(parents=True, exist_ok=True)

    print("=== CYBRA PARLIAMENT EXECUTOR V6 CLEAN STARTED ===")

    while True:
        raw = r.rpop(Q_RETRY) or r.rpop(Q_IN)

        if not raw:
            time.sleep(2)
            continue

        try:
            result = handle_task(raw)
            task_hash = result["double_sha"]

            (logs / f"{task_hash}.json").write_text(
                json.dumps(result, ensure_ascii=False, indent=2),
                encoding="utf-8"
            )

            if result["status"] == "executed":
                r.lpush(Q_RESULTS, json.dumps(result, ensure_ascii=False))
                r.lpush(Q_AUDIT, task_hash)
                print("✅ executed:", result["topic"])

            elif result["status"] == "execution_failed":
                task = json.loads(raw)
                retries = int(task.get("_retries", 0))

                if retries < MAX_RETRIES:
                    task["_retries"] = retries + 1
                    r.lpush(Q_RETRY, json.dumps(task, ensure_ascii=False))
                    print("🔁 retry:", result["topic"], task["_retries"])
                else:
                    r.lpush(Q_FAILED, json.dumps(result, ensure_ascii=False))
                    print("❌ failed final:", result["topic"])

            else:
                r.lpush(Q_RESULTS, json.dumps(result, ensure_ascii=False))
                print("⚠️", result["status"], ":", result["topic"])

        except Exception as e:
            fail_hash = double_sha(raw)
            fail = {
                "raw": raw,
                "double_sha": fail_hash,
                "error": str(e),
                "time": time.time()
            }
            r.lpush(Q_FAILED, json.dumps(fail, ensure_ascii=False))
            print("❌ parse/runtime failed:", fail_hash)

if __name__ == "__main__":
    main()
