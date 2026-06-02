#!/data/data/com.termux/files/usr/bin/bash
set -e
cd "$HOME/CYBRA"

mkdir -p parliament/review posts feeds proofs logs/review

redis-cli ping >/dev/null 2>&1 || redis-server --daemonize yes
sleep 1

# 1. Орган Кіберпарламенту
cat > parliament/review/cybra_review_committee.json <<'JSON'
{
  "name": "CYBRA Parliament Review Organ",
  "version": "1.0",
  "status": "active",
  "queues": {
    "incoming": "cybra:review:incoming",
    "approved": "cybra:review:approved",
    "hold": "cybra:review:hold",
    "rejected": "cybra:review:rejected",
    "audit": "cybra:review:audit",
    "execution": "cybra:parliament:queue"
  },
  "organs": [
    {
      "name": "Secretariat",
      "role": "register incoming tasks"
    },
    {
      "name": "Security Review",
      "role": "block dangerous, illegal, money-transfer, violence, account-freeze tasks"
    },
    {
      "name": "Technical Validator",
      "role": "check JSON, task type, executor mapping"
    },
    {
      "name": "Execution Council",
      "role": "approve safe mapped tasks into execution queue"
    },
    {
      "name": "Audit Chamber",
      "role": "write Redis audit, posts, feeds, double SHA proofs"
    }
  ],
  "policy": {
    "no_private_keys": true,
    "no_unauthorized_access": true,
    "no_forced_money_transfer": true,
    "no_illegal_freeze_or_arrest_actions": true,
    "official_source_required_for_alerts": true
  }
}
JSON

# 2. Worker перевірки
cat > cybra_task_review_worker.py <<'PY'
#!/usr/bin/env python3
import json
import time
import hashlib
import subprocess
from pathlib import Path

import redis

INCOMING = "cybra:review:incoming"
APPROVED = "cybra:review:approved"
HOLD = "cybra:review:hold"
REJECTED = "cybra:review:rejected"
AUDIT = "cybra:review:audit"
EXECUTION = "cybra:parliament:queue"
MAPPING = "cybra:executor:mapping"

BLOCK_WORDS = [
    "вкрасти", "украсть", "steal",
    "зламати", "взломать", "hack account",
    "перевести кошти", "переведи деньги", "send money",
    "арештувати", "арестовать",
    "заморозити рахунки", "заморозить счета",
    "заблокувати рахунки", "заблокировать счета",
    "kill", "убить", "ліквідувати",
    "підробити", "подделать",
    "private key", "seed phrase"
]

def dsha(text: str) -> str:
    one = hashlib.sha256(text.encode("utf-8")).hexdigest()
    return hashlib.sha256(one.encode("utf-8")).hexdigest()

def load_static_map():
    try:
        import ast
        s = Path("parliament_executor_v6.py").read_text()
        tree = ast.parse(s)
        for node in tree.body:
            if isinstance(node, ast.Assign):
                for target in node.targets:
                    if getattr(target, "id", None) == "SCRIPT_MAP":
                        return ast.literal_eval(node.value)
    except Exception:
        return {}
    return {}

def write_status(event):
    Path("feeds").mkdir(exist_ok=True)
    Path("posts").mkdir(exist_ok=True)
    Path("proofs").mkdir(exist_ok=True)

    Path("feeds/review_status.json").write_text(
        json.dumps(event, ensure_ascii=False, indent=2)
    )

    Path("posts/review_committee_status.md").write_text(
        "# CYBRA Parliament Review Organ\n\n"
        f"Status: {event.get('status')}\n\n"
        f"Topic: {event.get('topic')}\n\n"
        f"Type: {event.get('type')}\n\n"
        f"Decision: {event.get('decision')}\n\n"
        f"Reason: {event.get('reason')}\n\n"
        f"Time: {event.get('time')}\n"
    )

    subprocess.run(
        ["sha256sum", "feeds/review_status.json", "posts/review_committee_status.md"],
        stdout=open("proofs/review_committee.sha256", "w"),
        stderr=subprocess.DEVNULL
    )

def review_task(r, raw):
    now = time.time()
    event = {
        "status": "reviewed",
        "time": now,
        "raw_double_sha": dsha(raw)
    }

    try:
        task = json.loads(raw)
        if not isinstance(task, dict):
            raise ValueError("task is not JSON object")
    except Exception as e:
        event.update({
            "decision": "rejected",
            "reason": f"invalid_json: {e}",
            "topic": None,
            "type": None
        })
        r.lpush(REJECTED, json.dumps(event, ensure_ascii=False))
        r.lpush(AUDIT, json.dumps(event, ensure_ascii=False))
        write_status(event)
        return

    topic = str(task.get("topic", ""))
    task_type = str(task.get("type", ""))
    raw_lower = raw.lower()

    event.update({
        "topic": topic,
        "type": task_type
    })

    for word in BLOCK_WORDS:
        if word.lower() in raw_lower:
            event.update({
                "decision": "rejected",
                "reason": f"blocked_policy_word: {word}"
            })
            r.lpush(REJECTED, json.dumps(event, ensure_ascii=False))
            r.lpush(AUDIT, json.dumps(event, ensure_ascii=False))
            write_status(event)
            return

    if not topic or not task_type:
        event.update({
            "decision": "hold",
            "reason": "missing topic or type"
        })
        r.lpush(HOLD, raw)
        r.lpush(AUDIT, json.dumps(event, ensure_ascii=False))
        write_status(event)
        return

    redis_script = r.hget(MAPPING, task_type)
    static_map = load_static_map()
    static_script = static_map.get(task_type)
    script = redis_script or static_script

    if not script:
        event.update({
            "decision": "hold",
            "reason": "no_executor_mapping"
        })
        r.lpush(HOLD, raw)
        r.lpush(AUDIT, json.dumps(event, ensure_ascii=False))
        write_status(event)
        return

    task["_review"] = {
        "approved": True,
        "approved_by": "CYBRA Parliament Review Organ",
        "time": now,
        "script": script,
        "double_sha": event["raw_double_sha"]
    }

    approved_raw = json.dumps(task, ensure_ascii=False)

    r.lpush(APPROVED, approved_raw)
    r.lpush(EXECUTION, approved_raw)

    event.update({
        "decision": "approved",
        "reason": "safe_and_mapped",
        "script": script
    })

    r.lpush(AUDIT, json.dumps(event, ensure_ascii=False))
    write_status(event)

def main():
    print("=== CYBRA REVIEW WORKER STARTED ===", flush=True)
    r = redis.Redis(host="127.0.0.1", port=6379, decode_responses=True)

    while True:
        item = r.brpop(INCOMING, timeout=5)
        if not item:
            continue
        _, raw = item
        try:
            review_task(r, raw)
        except Exception as e:
            err = {
                "status": "review_worker_error",
                "error": str(e),
                "time": time.time()
            }
            r.lpush(AUDIT, json.dumps(err, ensure_ascii=False))
            write_status(err)

if __name__ == "__main__":
    main()
PY

chmod +x cybra_task_review_worker.py

# 3. Start/stop/status
cat > cybra_review_start.sh <<'EOF2'
#!/data/data/com.termux/files/usr/bin/bash
cd "$HOME/CYBRA"
mkdir -p logs/review
redis-cli ping >/dev/null 2>&1 || redis-server --daemonize yes
pkill -f cybra_task_review_worker.py 2>/dev/null || true
nohup python3 cybra_task_review_worker.py > logs/review/review_worker.log 2>&1 &
sleep 1
echo "✅ CYBRA review worker started"
EOF2

cat > cybra_review_stop.sh <<'EOF2'
#!/data/data/com.termux/files/usr/bin/bash
pkill -f cybra_task_review_worker.py 2>/dev/null || true
echo "✅ CYBRA review worker stopped"
EOF2

cat > cybra_review_status.sh <<'EOF2'
#!/data/data/com.termux/files/usr/bin/bash
redis-cli ping
echo "REVIEW_INCOMING: $(redis-cli LLEN cybra:review:incoming)"
echo "REVIEW_APPROVED: $(redis-cli LLEN cybra:review:approved)"
echo "REVIEW_HOLD: $(redis-cli LLEN cybra:review:hold)"
echo "REVIEW_REJECTED: $(redis-cli LLEN cybra:review:rejected)"
echo "REVIEW_AUDIT: $(redis-cli LLEN cybra:review:audit)"
echo "EXECUTION_QUEUE: $(redis-cli LLEN cybra:parliament:queue)"
pgrep -af cybra_task_review_worker.py || echo "NO_REVIEW_WORKER"
EOF2

chmod +x cybra_review_start.sh cybra_review_stop.sh cybra_review_status.sh

# 4. CLI для Review Parliament
cat > cybra_review.sh <<'EOF2'
#!/data/data/com.termux/files/usr/bin/bash
set -e
cd "$HOME/CYBRA"

CMD="${1:-status}"
shift || true

case "$CMD" in
  submit)
    redis-cli LPUSH cybra:review:incoming "$1"
    echo "✅ Submitted to CYBRA review queue"
    ;;
  start)
    bash cybra_review_start.sh
    ;;
  stop)
    bash cybra_review_stop.sh
    ;;
  status)
    bash cybra_review_status.sh
    ;;
  approved)
    redis-cli LRANGE cybra:review:approved 0 20
    ;;
  hold)
    redis-cli LRANGE cybra:review:hold 0 20
    ;;
  rejected)
    redis-cli LRANGE cybra:review:rejected 0 20
    ;;
  audit)
    redis-cli LRANGE cybra:review:audit 0 20
    ;;
  organ)
    cat parliament/review/cybra_review_committee.json
    ;;
  *)
    echo "Usage:"
    echo "  bash cybra_review.sh submit '<json_task>'"
    echo "  bash cybra_review.sh start|stop|status"
    echo "  bash cybra_review.sh approved|hold|rejected|audit|organ"
    ;;
esac
EOF2

chmod +x cybra_review.sh

# 5. Додати Redis mapping, якщо скрипт уже є
if [ -f cybra_redis_executor_mapping.sh ]; then
  bash cybra_redis_executor_mapping.sh load || true
else
  redis-cli HSET cybra:executor:mapping air_alert_task air_alert_handler.sh >/dev/null
  redis-cli HSET cybra:executor:mapping cybra_autofix_task cybra_autofix.sh >/dev/null
fi

# 6. Статус і proof
cat > posts/review_committee_status.md <<'MD'
# CYBRA Parliament Review Organ

Status: installed

Flow:

`cybra:review:incoming` → review organ → `cybra:parliament:queue`

Only safe and mapped tasks are approved for execution.
MD

cat > feeds/review_status.json <<'JSON'
{
  "status": "installed",
  "incoming_queue": "cybra:review:incoming",
  "execution_queue": "cybra:parliament:queue",
  "organ": "CYBRA Parliament Review Organ"
}
JSON

sha256sum parliament/review/cybra_review_committee.json cybra_task_review_worker.py posts/review_committee_status.md feeds/review_status.json > proofs/review_committee.sha256

# 7. Запуск
bash cybra_review_start.sh

echo "✅ CYBRA Parliament Review Queue + Organ installed"
echo "Use: bash cybra_review.sh submit '<json_task>'"
echo "Use: bash cybra_review.sh status"
