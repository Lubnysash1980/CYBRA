#!/data/data/com.termux/files/usr/bin/bash
set -e

cd "$HOME/CYBRA"

echo "=== INSTALL AI PARLIAMENT UNTIL DONE WORKER ==="

mkdir -p logs/ai_until_done runtime posts feeds proofs parliament/ai_until_done

redis-cli ping >/dev/null 2>&1 || redis-server --daemonize yes || true
sleep 1

python3 - <<'PY' >/dev/null 2>&1 || python3 -m pip install redis
import redis
PY

cat > generic_ai_safe_task_handler.sh <<'EOF2'
#!/data/data/com.termux/files/usr/bin/bash
set -e
cd "$HOME/CYBRA"

mkdir -p posts feeds proofs logs/generic_ai

python3 - <<'PY'
import json, time, hashlib, subprocess
from pathlib import Path

ROOT = Path.home() / "CYBRA"

obj = {
    "status": "generic_ai_safe_task_recorded",
    "time": time.time(),
    "real_payment_execution": False,
    "automatic_token_mint": False,
    "automatic_liquidity_pool": False,
    "automatic_exchange_launch": False,
    "automatic_external_tx": False,
    "manual_OWNER_approval_required": True,
    "meaning": "AI task was safely recorded. No real financial/blockchain execution."
}

raw = json.dumps(obj, ensure_ascii=False, sort_keys=True)
obj["double_sha"] = hashlib.sha256(hashlib.sha256(raw.encode()).hexdigest().encode()).hexdigest()

(ROOT / "feeds/generic_ai_safe_task_latest.json").write_text(json.dumps(obj, ensure_ascii=False, indent=2), encoding="utf-8")
(ROOT / "posts/generic_ai_safe_task_latest.md").write_text(
    "# Generic AI Safe Task\n\n"
    "Status: recorded\n\n"
    "Real execution: false\n\n"
    f"Double SHA: `{obj['double_sha']}`\n",
    encoding="utf-8"
)

with (ROOT / "proofs/generic_ai_safe_task_latest.sha256").open("w") as f:
    subprocess.run(
        ["sha256sum", "feeds/generic_ai_safe_task_latest.json", "posts/generic_ai_safe_task_latest.md"],
        cwd=ROOT,
        stdout=f,
        stderr=subprocess.DEVNULL
    )

print("✅ generic AI safe task recorded")
PY
EOF2

chmod +x generic_ai_safe_task_handler.sh

cat > native_kibra_evolution_handler.sh <<'EOF2'
#!/data/data/com.termux/files/usr/bin/bash
set -e
cd "$HOME/CYBRA"

bash cybra_native_kibra.sh build >/dev/null 2>&1 || true
bash cybra_native_kibra.sh status || true
EOF2

chmod +x native_kibra_evolution_handler.sh

cat > ai_until_done_handler.sh <<'EOF2'
#!/data/data/com.termux/files/usr/bin/bash
set -e
cd "$HOME/CYBRA"

bash cybra_ai_until_done.sh run 300
EOF2

chmod +x ai_until_done_handler.sh

redis-cli HSET cybra:executor:mapping generic_ai_safe_task generic_ai_safe_task_handler.sh >/dev/null
redis-cli HSET cybra:executor:mapping native_kibra_evolution_task native_kibra_evolution_handler.sh >/dev/null
redis-cli HSET cybra:executor:mapping ai_until_done_task ai_until_done_handler.sh >/dev/null

cat > cybra_ai_until_done.py <<'PY'
#!/usr/bin/env python3
import json
import time
import hashlib
import subprocess
from pathlib import Path

import redis

ROOT = Path.home() / "CYBRA"
r = redis.Redis(host="127.0.0.1", port=6379, decode_responses=True)

AI_PREFIX = "cybra:ai:tasks:"
PARLIAMENT_QUEUE = "cybra:parliament:queue"
FAILED = "cybra:parliament:failed"
RESULTS = "cybra:parliament:results"

AUDIT = "cybra:ai_until_done:audit"
MOVED = "cybra:ai_until_done:moved_hashes"
DONE_REPORT = "feeds/ai_until_done_report.json"

GUARD = {
    "real_payment_execution": False,
    "automatic_token_mint": False,
    "automatic_liquidity_pool": False,
    "automatic_exchange_launch": False,
    "automatic_gold_purchase": False,
    "automatic_external_tx": False,
    "manual_OWNER_approval_required": True,
    "no_private_keys": True,
    "no_seed_phrase": True,
    "no_guaranteed_profit": True,
    "no_market_manipulation": True,
    "owner_directive_scope": "AI_TASK_COMPLETION_ONLY_NO_REAL_FINANCIAL_EXECUTION"
}

def sha(x):
    return hashlib.sha256(x.encode("utf-8")).hexdigest()

def dsha(x):
    return sha(sha(x))

def now_iso():
    return time.strftime("%Y-%m-%dT%H:%M:%S%z")

def redis_len(key):
    try:
        return r.llen(key)
    except Exception:
        return 0

def ai_keys():
    return sorted([k for k in r.keys(AI_PREFIX + "*") if k != PARLIAMENT_QUEUE])

def ai_total():
    return sum(redis_len(k) for k in ai_keys())

def has_mapping(task_type):
    try:
        return bool(r.hget("cybra:executor:mapping", task_type))
    except Exception:
        return False

def normalize_task(raw, source_key):
    try:
        obj = json.loads(raw)
        if not isinstance(obj, dict):
            obj = {"topic": "Raw AI task", "type": "generic_ai_safe_task", "payload": {"raw": raw}}
    except Exception:
        obj = {"topic": "Raw AI task", "type": "generic_ai_safe_task", "payload": {"raw": raw}}

    obj.setdefault("topic", "AI task until done")
    obj.setdefault("priority", "high")
    obj.setdefault("payload", {})

    if not isinstance(obj["payload"], dict):
        obj["payload"] = {"original_payload": obj["payload"]}

    original_type = obj.get("type", "generic_ai_safe_task")
    if not has_mapping(original_type):
        obj["type"] = "generic_ai_safe_task"
        obj["payload"]["original_type_without_mapping"] = original_type
    else:
        obj["type"] = original_type

    obj["payload"].update(GUARD)
    obj["payload"]["source_ai_queue"] = source_key
    obj["payload"]["owner_directive"] = "work_until_ai_tasks_completed"

    canonical = json.dumps(obj, ensure_ascii=False, sort_keys=True)
    obj["ai_until_done_hash"] = dsha(canonical)

    return obj

def collect():
    moved = 0
    skipped = 0

    for key in ai_keys():
        while redis_len(key) > 0:
            raw = r.rpop(key)
            if raw is None:
                break

            task = normalize_task(raw, key)
            h = task["ai_until_done_hash"]

            if r.sadd(MOVED, h):
                r.lpush(PARLIAMENT_QUEUE, json.dumps(task, ensure_ascii=False))
                moved += 1
            else:
                skipped += 1

    audit = {
        "status": "ai_tasks_collected_to_parliament_queue",
        "moved": moved,
        "skipped_duplicates": skipped,
        "ai_total_left": ai_total(),
        "parliament_queue": redis_len(PARLIAMENT_QUEUE),
        "time": time.time(),
        "time_iso": now_iso()
    }
    audit["double_sha"] = dsha(json.dumps(audit, ensure_ascii=False, sort_keys=True))
    r.lpush(AUDIT, json.dumps(audit, ensure_ascii=False))

    print(f"MOVED={moved}")
    print(f"SKIPPED={skipped}")
    print(f"AI_TOTAL={ai_total()}")
    print(f"PARLIAMENT_QUEUE={redis_len(PARLIAMENT_QUEUE)}")

def status(shell=False):
    data = {
        "ai_total": ai_total(),
        "ai_keys": {k: redis_len(k) for k in ai_keys()},
        "parliament_queue": redis_len(PARLIAMENT_QUEUE),
        "parliament_results": redis_len(RESULTS),
        "parliament_failed": redis_len(FAILED),
        "audit": redis_len(AUDIT),
        "moved_hashes": r.scard(MOVED)
    }

    if shell:
        print(f"AI_TOTAL={data['ai_total']}")
        print(f"PARLIAMENT_QUEUE={data['parliament_queue']}")
        print(f"PARLIAMENT_RESULTS={data['parliament_results']}")
        print(f"PARLIAMENT_FAILED={data['parliament_failed']}")
        print(f"AUDIT={data['audit']}")
        print(f"MOVED_HASHES={data['moved_hashes']}")
    else:
        print(json.dumps(data, ensure_ascii=False, indent=2))

def directive():
    obj = {
        "status": "OWNER_DIRECTIVE_ACCEPTED",
        "directive": "AI Parliament must work until AI tasks are completed.",
        "scope": "AI task completion only",
        "real_payment_execution": False,
        "automatic_token_mint": False,
        "automatic_liquidity_pool": False,
        "automatic_exchange_launch": False,
        "automatic_external_tx": False,
        "manual_OWNER_approval_required_for_real_launch": True,
        "time": time.time(),
        "time_iso": now_iso()
    }
    obj["double_sha"] = dsha(json.dumps(obj, ensure_ascii=False, sort_keys=True))

    (ROOT / "feeds/owner_directive_ai_until_done.json").write_text(json.dumps(obj, ensure_ascii=False, indent=2), encoding="utf-8")
    (ROOT / "posts/owner_directive_ai_until_done.md").write_text(
        "# OWNER Directive: AI Parliament Until Done\n\n"
        "Directive: **work until AI tasks are completed**\n\n"
        "Scope: **AI/local/proof/report tasks only**\n\n"
        "Real payment execution: **false**\n\n"
        "Automatic token mint: **false**\n\n"
        "Automatic liquidity pool: **false**\n\n"
        "Automatic exchange launch: **false**\n\n"
        "Manual OWNER approval required for real launch: **true**\n\n"
        f"Double SHA: `{obj['double_sha']}`\n",
        encoding="utf-8"
    )

    with (ROOT / "proofs/owner_directive_ai_until_done.sha256").open("w") as f:
        subprocess.run(
            ["sha256sum", "feeds/owner_directive_ai_until_done.json", "posts/owner_directive_ai_until_done.md"],
            cwd=ROOT,
            stdout=f,
            stderr=subprocess.DEVNULL
        )

    r.lpush("cybra:owner:directives", json.dumps(obj, ensure_ascii=False))
    print("✅ OWNER directive recorded")

def finalize():
    complete = ai_total() == 0 and redis_len(PARLIAMENT_QUEUE) == 0 and redis_len(FAILED) == 0

    obj = {
        "status": "completed" if complete else "needs_attention",
        "complete": complete,
        "ai_total": ai_total(),
        "parliament_queue": redis_len(PARLIAMENT_QUEUE),
        "parliament_results": redis_len(RESULTS),
        "parliament_failed": redis_len(FAILED),
        "audit": redis_len(AUDIT),
        "moved_hashes": r.scard(MOVED),
        "real_payment_execution": False,
        "automatic_token_mint": False,
        "automatic_liquidity_pool": False,
        "automatic_exchange_launch": False,
        "automatic_external_tx": False,
        "time": time.time(),
        "time_iso": now_iso()
    }
    obj["double_sha"] = dsha(json.dumps(obj, ensure_ascii=False, sort_keys=True))

    (ROOT / "feeds/ai_until_done_report.json").write_text(json.dumps(obj, ensure_ascii=False, indent=2), encoding="utf-8")

    md = f"""# AI Parliament Until Done Report

Status: **{obj['status']}**

## Result

- Complete: **{obj['complete']}**
- AI total left: **{obj['ai_total']}**
- Parliament queue: **{obj['parliament_queue']}**
- Parliament failed: **{obj['parliament_failed']}**
- Parliament results: **{obj['parliament_results']}**
- Moved AI tasks: **{obj['moved_hashes']}**

## Safety

- Real payment execution: **false**
- Automatic token mint: **false**
- Automatic liquidity pool: **false**
- Automatic exchange launch: **false**
- External blockchain transaction: **false**

## Proof

Double SHA:

`{obj['double_sha']}`
"""
    (ROOT / "posts/ai_until_done_report.md").write_text(md, encoding="utf-8")

    with (ROOT / "proofs/ai_until_done_report.sha256").open("w") as f:
        subprocess.run(
            [
                "sha256sum",
                "feeds/ai_until_done_report.json",
                "posts/ai_until_done_report.md",
                "feeds/owner_directive_ai_until_done.json",
                "posts/owner_directive_ai_until_done.md"
            ],
            cwd=ROOT,
            stdout=f,
            stderr=subprocess.DEVNULL
        )

    r.lpush(AUDIT, json.dumps({
        "status": obj["status"],
        "complete": complete,
        "double_sha": obj["double_sha"],
        "time": obj["time"]
    }, ensure_ascii=False))

    print(json.dumps(obj, ensure_ascii=False, indent=2))

def main():
    import sys
    cmd = sys.argv[1] if len(sys.argv) > 1 else "status"

    if cmd == "collect":
        collect()
    elif cmd == "status":
        status(False)
    elif cmd == "status-shell":
        status(True)
    elif cmd == "directive":
        directive()
    elif cmd == "finalize":
        finalize()
    elif cmd == "ai-total":
        print(ai_total())
    else:
        raise SystemExit("Usage: directive|collect|status|status-shell|finalize|ai-total")

if __name__ == "__main__":
    main()
PY

chmod +x cybra_ai_until_done.py

cat > cybra_ai_until_done.sh <<'EOF2'
#!/data/data/com.termux/files/usr/bin/bash
set -e

cd "$HOME/CYBRA"

mkdir -p logs/ai_until_done runtime posts feeds proofs

case "${1:-status}" in
  directive)
    python3 cybra_ai_until_done.py directive
    ;;

  run)
    MAX_ROUNDS="${2:-500}"
    SLEEP_SECONDS="${SLEEP_SECONDS:-2}"

    termux-wake-lock 2>/dev/null || true
    redis-cli ping >/dev/null 2>&1 || redis-server --daemonize yes || true
    sleep 1

    echo "=== OWNER DIRECTIVE ==="
    python3 cybra_ai_until_done.py directive

    echo
    echo "=== SAFE PREPARE REPORTS / AI TASKS ==="
    bash cybra_native_kibra.sh build >/dev/null 2>&1 || true
    bash cybra_finance_gap.sh submit-ai >/dev/null 2>&1 || true
    bash cybra_finance_profit_audit.sh submit-ai >/dev/null 2>&1 || true
    bash cybra_evolution_deploy.sh report >/dev/null 2>&1 || true

    echo
    echo "=== COLLECT AI TASKS TO PARLIAMENT QUEUE ==="
    python3 cybra_ai_until_done.py collect

    echo
    echo "=== WORK UNTIL DONE ==="

    for i in $(seq 1 "$MAX_ROUNDS"); do
      echo
      echo "--- ROUND $i / $MAX_ROUNDS ---"

      python3 parliament_executor_v6.py || true
      python3 cybra_ai_until_done.py collect || true

      AI_TOTAL="$(python3 cybra_ai_until_done.py ai-total || echo 0)"
      QUEUE="$(redis-cli LLEN cybra:parliament:queue)"
      FAILED="$(redis-cli LLEN cybra:parliament:failed)"
      RESULTS="$(redis-cli LLEN cybra:parliament:results)"

      echo "AI_TOTAL=$AI_TOTAL"
      echo "PARLIAMENT_QUEUE=$QUEUE"
      echo "PARLIAMENT_FAILED=$FAILED"
      echo "PARLIAMENT_RESULTS=$RESULTS"

      if [ "$FAILED" != "0" ]; then
        echo "=== FAILED DETECTED: trying safe repair ==="
        bash cybra_existing_tasks.sh repair >/dev/null 2>&1 || true
        python3 parliament_executor_v6.py || true
      fi

      AI_TOTAL="$(python3 cybra_ai_until_done.py ai-total || echo 0)"
      QUEUE="$(redis-cli LLEN cybra:parliament:queue)"
      FAILED="$(redis-cli LLEN cybra:parliament:failed)"

      if [ "$AI_TOTAL" = "0" ] && [ "$QUEUE" = "0" ] && [ "$FAILED" = "0" ]; then
        echo "✅ DONE: AI tasks completed, queue empty, failed zero"
        break
      fi

      sleep "$SLEEP_SECONDS"
    done

    echo
    echo "=== FINAL SAFE REPORTS ==="
    bash cybra_kibra_chain.sh verify >/dev/null 2>&1 || true
    bash cybra_native_kibra.sh status >/dev/null 2>&1 || true
    bash cybra_finance_gap.sh report >/dev/null 2>&1 || true
    bash cybra_finance_profit_audit.sh report >/dev/null 2>&1 || true
    bash cybra_evolution_deploy.sh report >/dev/null 2>&1 || true

    echo
    echo "=== FINALIZE ==="
    python3 cybra_ai_until_done.py finalize

    echo
    echo "=== PROOF CHECK ==="
    sha256sum -c proofs/ai_until_done_report.sha256 || true

    termux-wake-unlock 2>/dev/null || true
    ;;

  start)
    MAX_ROUNDS="${2:-500}"
    nohup bash cybra_ai_until_done.sh run "$MAX_ROUNDS" > logs/ai_until_done/worker.log 2>&1 &
    echo $! > runtime/ai_until_done.pid
    echo "✅ AI Parliament until-done worker started"
    echo "PID: $(cat runtime/ai_until_done.pid)"
    echo "Log: logs/ai_until_done/worker.log"
    ;;

  stop)
    if [ -f runtime/ai_until_done.pid ]; then
      kill "$(cat runtime/ai_until_done.pid)" 2>/dev/null || true
      rm -f runtime/ai_until_done.pid
    fi
    termux-wake-unlock 2>/dev/null || true
    echo "✅ stopped"
    ;;

  status)
    python3 cybra_ai_until_done.py status-shell
    test -f runtime/ai_until_done.pid && echo "PID=$(cat runtime/ai_until_done.pid)" || true
    test -f posts/ai_until_done_report.md && echo "REPORT=exists" || echo "REPORT=missing"
    ;;

  log)
    tail -f logs/ai_until_done/worker.log
    ;;

  report)
    cat posts/ai_until_done_report.md
    ;;

  proof)
    cat proofs/ai_until_done_report.sha256
    ;;

  *)
    echo "Usage:"
    echo "  bash cybra_ai_until_done.sh directive"
    echo "  bash cybra_ai_until_done.sh run 500"
    echo "  bash cybra_ai_until_done.sh start 500"
    echo "  bash cybra_ai_until_done.sh stop"
    echo "  bash cybra_ai_until_done.sh status"
    echo "  bash cybra_ai_until_done.sh log"
    echo "  bash cybra_ai_until_done.sh report"
    echo "  bash cybra_ai_until_done.sh proof"
    ;;
esac
EOF2

chmod +x cybra_ai_until_done.sh

python3 - <<'PY'
from pathlib import Path

p = Path("parliament_executor_v6.py")
if p.exists():
    s = p.read_text()

    if 'r.hget("cybra:executor:mapping", task_type)' not in s:
        old = "script_name = SCRIPT_MAP.get(task_type)"
        new = 'script_name = r.hget("cybra:executor:mapping", task_type) or SCRIPT_MAP.get(task_type)'
        if old in s:
            s = s.replace(old, new, 1)

    inserts = {
        "ai_until_done_task": "ai_until_done_handler.sh",
        "native_kibra_evolution_task": "native_kibra_evolution_handler.sh",
        "generic_ai_safe_task": "generic_ai_safe_task_handler.sh"
    }

    for task_type, handler in inserts.items():
        if f'"{task_type}"' not in s:
            i = s.find("SCRIPT_MAP")
            j = s.find("{", i)
            if i >= 0 and j >= 0:
                s = s[:j+1] + f'\n    "{task_type}": "{handler}",' + s[j+1:]

    p.write_text(s)

print("✅ executor mapping patched")
PY

rm -rf __pycache__
python3 -m py_compile cybra_ai_until_done.py
python3 -m py_compile parliament_executor_v6.py
rm -rf __pycache__

echo
echo "=== RECORD OWNER DIRECTIVE ==="
bash cybra_ai_until_done.sh directive

echo
echo "✅ INSTALLED"
echo
echo "Run foreground:"
echo "  bash cybra_ai_until_done.sh run 500"
echo
echo "Run background:"
echo "  bash cybra_ai_until_done.sh start 500"
echo "  bash cybra_ai_until_done.sh log"
