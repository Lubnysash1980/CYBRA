#!/data/data/com.termux/files/usr/bin/bash
set -e
cd "$HOME/CYBRA"

echo "=== AUTO FIX FINANCE REDIS COMMITTEE ==="

mkdir -p \
  parliament/departments/finance_department/redis_committee \
  parliament/departments/cybra_finance_department/redis_committee \
  data/finance_redis_committee \
  posts feeds proofs logs/finance_redis_committee runtime/redis runtime

if ! command -v redis-server >/dev/null 2>&1; then
  pkg update -y || true
  pkg install -y redis || true
fi

python3 - <<'PY'
import sys, subprocess
try:
    import redis
except Exception:
    subprocess.check_call([sys.executable, "-m", "pip", "install", "redis"])
PY

cat > parliament/departments/finance_department/redis_committee/committee.json <<'JSON'
{
  "committee_id": "finance_redis_committee",
  "name": "Redis",
  "full_name": "Finance Department Redis Committee",
  "parent_department": "finance_department",
  "status": "active",
  "mission": "Слідкувати, щоб Redis був увімкнений для фінансового відділу, AI Parliament, KIBRA mining blocks, closed SHA bridge, liquidity, price gate і audit queues.",
  "responsibilities": [
    "redis_health_check",
    "auto_start_redis_if_down",
    "audit_redis_status",
    "protect_finance_queues",
    "protect_ai_task_block_queues",
    "protect_closed_sha_bridge_queues",
    "notify_parliament_via_AI_task"
  ],
  "critical_queues": [
    "cybra:parliament:queue",
    "cybra:parliament:results",
    "cybra:parliament:failed",
    "cybra:ai:tasks:block_inbox",
    "cybra:kibra:task_blocks:mempool",
    "cybra:kibra:pool:mining_blocks",
    "cybra:kibra:task_blocks:mined",
    "cybra:kibra:mint_finance:audit",
    "cybra:kibra:market_proof_collector:audit",
    "cybra:kibra:real_market_price_gate:audit",
    "cybra:kibra:closed_sha_pool_bridge:audit"
  ],
  "rule": "Якщо Redis вимкнений — Redis Committee запускає його автоматично і пише audit.",
  "manual_OWNER_approval_required": false
}
JSON

cp parliament/departments/finance_department/redis_committee/committee.json \
   parliament/departments/cybra_finance_department/redis_committee/committee.json 2>/dev/null || true

cat > cybra_finance_redis_committee.py <<'PY'
#!/usr/bin/env python3
import json
import time
import hashlib
import subprocess
from pathlib import Path

ROOT = Path.home() / "CYBRA"
REDIS_DIR = ROOT / "runtime/redis"
LOG_DIR = ROOT / "logs/finance_redis_committee"

AUDIT_KEY = "cybra:finance:redis_committee:audit"
EVENT_KEY = "cybra:finance:redis_committee:events"
AI_BLOCK_INBOX = "cybra:ai:tasks:block_inbox"

CRITICAL_QUEUES = [
    "cybra:parliament:queue",
    "cybra:parliament:results",
    "cybra:parliament:failed",
    "cybra:ai:tasks:block_inbox",
    "cybra:kibra:task_blocks:mempool",
    "cybra:kibra:pool:mining_blocks",
    "cybra:kibra:task_blocks:mined",
    "cybra:kibra:mint_finance:audit",
    "cybra:kibra:market_proof_collector:audit",
    "cybra:kibra:real_market_price_gate:audit",
    "cybra:kibra:closed_sha_pool_bridge:audit"
]

def sha(text):
    return hashlib.sha256(text.encode("utf-8")).hexdigest()

def dsha(text):
    return sha(sha(text))

def now_iso():
    return time.strftime("%Y-%m-%dT%H:%M:%S%z")

def run(cmd):
    try:
        p = subprocess.run(cmd, cwd=ROOT, text=True, capture_output=True)
        return p.returncode, p.stdout.strip(), p.stderr.strip()
    except Exception as e:
        return 1, "", str(e)

def redis_ping():
    code, out, err = run(["redis-cli", "-h", "127.0.0.1", "-p", "6379", "ping"])
    return code == 0 and out == "PONG"

def start_redis():
    REDIS_DIR.mkdir(parents=True, exist_ok=True)
    LOG_DIR.mkdir(parents=True, exist_ok=True)

    if redis_ping():
        return True, "already_running"

    cmd = [
        "redis-server",
        "--daemonize", "yes",
        "--dir", str(REDIS_DIR),
        "--bind", "127.0.0.1",
        "--port", "6379",
        "--save", "",
        "--appendonly", "no"
    ]

    code, out, err = run(cmd)
    time.sleep(1)

    if redis_ping():
        return True, "started"

    return False, err or out or "redis_start_failed"

def redis_client():
    import redis
    return redis.Redis(host="127.0.0.1", port=6379, decode_responses=True)

def redis_len(r, key):
    try:
        return r.llen(key)
    except Exception:
        return None

def queue_state(r):
    return {k: redis_len(r, k) for k in CRITICAL_QUEUES}

def audit(event, extra=None):
    ok, message = start_redis()
    if not ok:
        print("REDIS_START_FAILED:", message)
        return None

    r = redis_client()
    obj = {
        "status": event,
        "time": time.time(),
        "time_iso": now_iso(),
        "redis_ping": redis_ping(),
        "message": message,
        "queues": queue_state(r),
        "extra": extra or {}
    }
    obj["double_sha"] = dsha(json.dumps(obj, ensure_ascii=False, sort_keys=True))

    r.lpush(AUDIT_KEY, json.dumps(obj, ensure_ascii=False))
    r.lpush(EVENT_KEY, json.dumps(obj, ensure_ascii=False))
    return obj

def ensure():
    was_running = redis_ping()
    ok, message = start_redis()
    event = "redis_ok" if was_running else ("redis_recovered" if ok else "redis_failed")
    obj = audit(event, {"was_running_before_check": was_running})

    print("REDIS_OK:", ok)
    print("EVENT:", event)
    print("MESSAGE:", message)
    if obj:
        print("DOUBLE_SHA:", obj["double_sha"])

def submit_ai_notice(reason):
    ok, message = start_redis()
    if not ok:
        print("Cannot submit AI task: Redis not available")
        return

    r = redis_client()
    task = {
        "topic": "Finance Redis Committee health event",
        "type": "finance_redis_committee_task",
        "priority": "critical",
        "payload": {
            "source": "finance_redis_committee",
            "reason": reason,
            "redis_required": True,
            "protect_finance_queues": True,
            "protect_ai_task_blocks": True,
            "convert_to_mining_block_first": True,
            "real_payment_now": False,
            "real_sell_now": False,
            "manual_OWNER_approval_required": False
        }
    }
    r.lpush(AI_BLOCK_INBOX, json.dumps(task, ensure_ascii=False))
    print("AI_TASK_ADDED_TO_BLOCK_INBOX")

def report():
    ensure()
    r = redis_client()

    obj = {
        "status": "finance_redis_committee_report_generated",
        "time": time.time(),
        "time_iso": now_iso(),
        "redis_ok": redis_ping(),
        "audit_len": redis_len(r, AUDIT_KEY),
        "event_len": redis_len(r, EVENT_KEY),
        "queues": queue_state(r),
        "rule": "Redis Committee watches Redis and restarts it if down.",
        "protected_systems": [
            "Finance Department",
            "AI Parliament",
            "KIBRA task-block mining",
            "Closed SHA Pool Bridge",
            "Liquidity Department",
            "Market Proof Collector",
            "Real Market Price Gate"
        ]
    }
    obj["double_sha"] = dsha(json.dumps(obj, ensure_ascii=False, sort_keys=True))

    (ROOT / "feeds").mkdir(exist_ok=True)
    (ROOT / "posts").mkdir(exist_ok=True)
    (ROOT / "proofs").mkdir(exist_ok=True)
    (ROOT / "data/finance_redis_committee").mkdir(parents=True, exist_ok=True)

    (ROOT / "feeds/finance_redis_committee_report.json").write_text(
        json.dumps(obj, ensure_ascii=False, indent=2),
        encoding="utf-8"
    )

    (ROOT / "data/finance_redis_committee/latest_report.json").write_text(
        json.dumps(obj, ensure_ascii=False, indent=2),
        encoding="utf-8"
    )

    queues_json = json.dumps(obj["queues"], ensure_ascii=False, indent=2)

    md = f"""# Finance Department Redis Committee

Status: **active**

## Redis

- Redis OK: **{obj['redis_ok']}**
- Audit records: **{obj['audit_len']}**
- Event records: **{obj['event_len']}**

## Protected systems

- Finance Department
- AI Parliament
- KIBRA task-block mining
- Closed SHA Pool Bridge
- Liquidity Department
- Market Proof Collector
- Real Market Price Gate

## Critical queues

{queues_json}

## Rule

Якщо Redis вимкнений — комітет Redis запускає його автоматично.

## Double SHA

{obj['double_sha']}
"""

    (ROOT / "posts/finance_redis_committee_report.md").write_text(md, encoding="utf-8")

    with (ROOT / "proofs/finance_redis_committee.sha256").open("w") as f:
        subprocess.run([
            "sha256sum",
            "parliament/departments/finance_department/redis_committee/committee.json",
            "feeds/finance_redis_committee_report.json",
            "posts/finance_redis_committee_report.md"
        ], cwd=ROOT, stdout=f, stderr=subprocess.DEVNULL)

    print("✅ Finance Redis Committee report generated")
    print("REDIS_OK:", obj["redis_ok"])
    print("REPORT: posts/finance_redis_committee_report.md")
    print("PROOF: proofs/finance_redis_committee.sha256")

def status():
    ok, message = start_redis()
    r = redis_client()

    print("PONG" if redis_ping() else "NO_REDIS")
    print("REDIS_OK:", ok)
    print("MESSAGE:", message)
    print("FINANCE_REDIS_AUDIT:", redis_len(r, AUDIT_KEY))
    print("FINANCE_REDIS_EVENTS:", redis_len(r, EVENT_KEY))
    print("PARLIAMENT_QUEUE:", redis_len(r, "cybra:parliament:queue"))
    print("PARLIAMENT_FAILED:", redis_len(r, "cybra:parliament:failed"))
    print("BLOCK_INBOX:", redis_len(r, "cybra:ai:tasks:block_inbox"))
    print("TASK_BLOCK_MEMPOOL:", redis_len(r, "cybra:kibra:task_blocks:mempool"))
    print("POOL_MINING_BLOCKS:", redis_len(r, "cybra:kibra:pool:mining_blocks"))
    print("REAL_MARKET_PRICE_GATE_AUDIT:", redis_len(r, "cybra:kibra:real_market_price_gate:audit"))
    print("MARKET_PROOF_COLLECTOR_AUDIT:", redis_len(r, "cybra:kibra:market_proof_collector:audit"))
    print("CLOSED_SHA_BRIDGE_AUDIT:", redis_len(r, "cybra:kibra:closed_sha_pool_bridge:audit"))
    print("REPORT_EXISTS:", (ROOT / "posts/finance_redis_committee_report.md").exists())

def main():
    import sys
    cmd = sys.argv[1] if len(sys.argv) > 1 else "status"

    if cmd == "ensure":
        ensure()
    elif cmd == "status":
        status()
    elif cmd == "report":
        report()
    elif cmd == "submit-ai":
        ensure()
        submit_ai_notice("redis_health_committee_report")
    else:
        raise SystemExit("Usage: status|ensure|report|submit-ai")

if __name__ == "__main__":
    main()
PY

cat > finance_redis_committee_handler.sh <<'EOF'
#!/data/data/com.termux/files/usr/bin/bash
set -e
cd "$HOME/CYBRA"

python3 cybra_finance_redis_committee.py ensure
python3 cybra_finance_redis_committee.py report
bash cybra_closed_sha_bridge.sh cycle >/dev/null 2>&1 || true
EOF

cat > cybra_redis_committee.sh <<'EOF'
#!/data/data/com.termux/files/usr/bin/bash
set -e
cd "$HOME/CYBRA"

case "${1:-status}" in
  status)
    python3 cybra_finance_redis_committee.py status
    ;;
  ensure|start)
    python3 cybra_finance_redis_committee.py ensure
    ;;
  report)
    python3 cybra_finance_redis_committee.py report
    cat posts/finance_redis_committee_report.md
    ;;
  submit-ai)
    python3 cybra_finance_redis_committee.py submit-ai
    bash cybra_ai_block_enforcer.sh enforce 3 >/dev/null 2>&1 || true
    ;;
  task)
    python3 cybra_finance_redis_committee.py ensure
    if command -v cybra >/dev/null 2>&1; then
      cybra parliament '{"topic":"Finance Department Redis Committee","type":"finance_redis_committee_task","priority":"critical","payload":{"redis_watchdog":true,"auto_start_redis":true,"protect_finance_queues":true,"protect_ai_task_blocks":true,"manual_OWNER_approval_required":false}}' || true
    else
      redis-cli LPUSH cybra:parliament:queue '{"topic":"Finance Department Redis Committee","type":"finance_redis_committee_task","priority":"critical","payload":{"redis_watchdog":true,"auto_start_redis":true,"protect_finance_queues":true,"protect_ai_task_blocks":true,"manual_OWNER_approval_required":false}}' >/dev/null
    fi
    ;;
  cycle)
    python3 cybra_finance_redis_committee.py ensure
    python3 cybra_finance_redis_committee.py submit-ai
    bash cybra_closed_sha_bridge.sh cycle || true
    python3 parliament_executor_v6.py || true
    python3 cybra_finance_redis_committee.py report
    ;;
  watch)
    termux-wake-lock 2>/dev/null || true
    while true; do
      date
      python3 cybra_finance_redis_committee.py ensure || true
      sleep "${2:-10}"
    done
    ;;
  start-watch)
    mkdir -p logs/finance_redis_committee runtime
    nohup bash cybra_redis_committee.sh watch "${2:-10}" > logs/finance_redis_committee/watch.log 2>&1 &
    echo $! > runtime/finance_redis_committee.pid
    echo "✅ Redis Committee watchdog started"
    echo "PID: $(cat runtime/finance_redis_committee.pid)"
    echo "LOG: logs/finance_redis_committee/watch.log"
    ;;
  stop-watch)
    if [ -f runtime/finance_redis_committee.pid ]; then
      kill "$(cat runtime/finance_redis_committee.pid)" 2>/dev/null || true
      rm -f runtime/finance_redis_committee.pid
    fi
    termux-wake-unlock 2>/dev/null || true
    echo "✅ Redis Committee watchdog stopped"
    ;;
  log)
    tail -f logs/finance_redis_committee/watch.log
    ;;
  proof)
    cat proofs/finance_redis_committee.sha256
    ;;
  *)
    echo "Usage:"
    echo "  bash cybra_redis_committee.sh status"
    echo "  bash cybra_redis_committee.sh ensure"
    echo "  bash cybra_redis_committee.sh report"
    echo "  bash cybra_redis_committee.sh submit-ai"
    echo "  bash cybra_redis_committee.sh task"
    echo "  bash cybra_redis_committee.sh cycle"
    echo "  bash cybra_redis_committee.sh start-watch 10"
    echo "  bash cybra_redis_committee.sh stop-watch"
    echo "  bash cybra_redis_committee.sh log"
    ;;
esac
EOF

chmod +x cybra_finance_redis_committee.py
chmod +x cybra_redis_committee.sh
chmod +x finance_redis_committee_handler.sh

echo
echo "=== START / ENSURE REDIS ==="
python3 cybra_finance_redis_committee.py ensure

echo
echo "=== REDIS MAPPING ==="
redis-cli HSET cybra:executor:mapping finance_redis_committee_task finance_redis_committee_handler.sh >/dev/null || true

echo
echo "=== PATCH PARLIAMENT EXECUTOR ==="
python3 - <<'PY'
from pathlib import Path

p = Path("parliament_executor_v6.py")

if not p.exists():
    print("⚠ parliament_executor_v6.py not found, Redis mapping only")
    raise SystemExit(0)

s = p.read_text(encoding="utf-8")

if 'r.hget("cybra:executor:mapping", task_type)' not in s:
    old = "script_name = SCRIPT_MAP.get(task_type)"
    new = 'script_name = r.hget("cybra:executor:mapping", task_type) or SCRIPT_MAP.get(task_type)'
    if old in s:
        s = s.replace(old, new, 1)

if '"finance_redis_committee_task"' not in s:
    i = s.find("SCRIPT_MAP")
    j = s.find("{", i)
    if i >= 0 and j >= 0:
        s = s[:j+1] + '\n    "finance_redis_committee_task": "finance_redis_committee_handler.sh",' + s[j+1:]

p.write_text(s, encoding="utf-8")
print("✅ parliament executor patched")
PY

echo
echo "=== PYTHON COMPILE CHECK ==="
rm -rf __pycache__
python3 -m py_compile cybra_finance_redis_committee.py
test -f parliament_executor_v6.py && python3 -m py_compile parliament_executor_v6.py || true
rm -rf __pycache__

echo
echo "=== CREATE REPORT ==="
bash cybra_redis_committee.sh report

echo
echo "=== ADD TASK TO PARLIAMENT ==="
bash cybra_redis_committee.sh task || true
python3 parliament_executor_v6.py || true

echo
echo "=== STATUS ==="
bash cybra_redis_committee.sh status

echo
echo "=== PROOF CHECK ==="
sha256sum -c proofs/finance_redis_committee.sha256 || true

echo
echo "✅ FINANCE REDIS COMMITTEE AUTO FIX DONE"
