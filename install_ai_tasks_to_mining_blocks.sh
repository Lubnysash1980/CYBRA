#!/data/data/com.termux/files/usr/bin/bash
set -e
cd "$HOME/CYBRA"

echo "=== INSTALL AI TASKS → MINING BLOCKS → POOLS ==="

mkdir -p \
  parliament/ai_task_mining_blocks \
  parliament/departments/ai_task_block_mining_department \
  blockchain/kibra_chain/task_blocks \
  data/ai_task_blocks/mempool \
  data/ai_task_blocks/mined \
  data/ai_task_blocks/pool_queue \
  posts feeds proofs logs/ai_task_blocks

redis-cli ping >/dev/null 2>&1 || redis-server --daemonize yes || true
sleep 1

cat > parliament/departments/ai_task_block_mining_department/department.json <<'JSON'
{
  "department_id": "ai_task_block_mining_department",
  "name": "AI Task Block Mining Department",
  "status": "active",
  "mission": "Перетворювати всі незавершені AI-завдання у KIBRA task-blocks, передавати ці блоки у pool mining queue і підтверджувати їх через proof-of-work.",
  "rules": [
    "unfinished_ai_tasks_must_become_blocks",
    "do_not_send_empty_blocks",
    "each_block_must_contain_ai_tasks",
    "blocks_go_to_pool_for_mining",
    "mined_blocks_get_pow_hash",
    "confirmed_blocks_go_to_bridge_outbox",
    "broken_blocks_go_to_mint_repair_department"
  ],
  "safety": [
    "no_real_payment",
    "no_real_sell",
    "no_external_tx",
    "no_private_keys",
    "manual_OWNER_approval_required"
  ]
}
JSON

cat > parliament/ai_task_mining_blocks/policy.json <<'JSON'
{
  "name": "AI Tasks To KIBRA Mining Blocks Policy",
  "status": "active",
  "native_coin": true,
  "external_mint": false,
  "core_rule": "AI-завдання не відправляються просто так. Спочатку вони упаковуються у блоки, а блоки передаються у пули для майнингу.",
  "flow": [
    "scan_unfinished_ai_tasks",
    "create_task_block_mempool",
    "mine_task_block_with_pool",
    "confirm_pow",
    "send_confirmed_block_to_pool_accounting",
    "send_confirmed_block_to_bridge_outbox",
    "send_ai_support_task_after_mining"
  ],
  "execution": {
    "real_network_broadcast_now": false,
    "real_payment": false,
    "real_sell": false,
    "manual_OWNER_approval_required": true
  }
}
JSON

cat > cybra_ai_tasks_to_blocks.py <<'PY'
#!/usr/bin/env python3
import json
import time
import hashlib
import subprocess
from pathlib import Path
import redis

ROOT = Path.home() / "CYBRA"
r = redis.Redis(host="127.0.0.1", port=6379, decode_responses=True)

MEMPOOL = "cybra:kibra:task_blocks:mempool"
MINED = "cybra:kibra:task_blocks:mined"
POOL_QUEUE = "cybra:kibra:pool:mining_blocks"
AUDIT = "cybra:kibra:task_blocks:audit"
SENT = "cybra:kibra:task_blocks:seen_task_hashes"

AI_PREFIX = "cybra:ai:tasks:"
PARLIAMENT_QUEUE = "cybra:parliament:queue"

def sha(x):
    return hashlib.sha256(x.encode("utf-8")).hexdigest()

def dsha(x):
    return sha(sha(x))

def now_iso():
    return time.strftime("%Y-%m-%dT%H:%M:%S%z")

def latest_hash():
    p = ROOT / "blockchain/kibra_chain/latest.block.hash"
    return p.read_text().strip() if p.exists() else "GENESIS_TASK_BLOCK"

def redis_len(k):
    try:
        return r.llen(k)
    except Exception:
        return 0

def ai_keys():
    keys = sorted(r.keys(AI_PREFIX + "*"))
    return [k for k in keys if k not in (PARLIAMENT_QUEUE,)]

def canonical_task(raw, source):
    try:
        obj = json.loads(raw)
        if not isinstance(obj, dict):
            obj = {"topic": "raw_ai_task", "type": "generic_ai_safe_task", "payload": {"raw": raw}}
    except Exception:
        obj = {"topic": "raw_ai_task", "type": "generic_ai_safe_task", "payload": {"raw": raw}}

    obj.setdefault("topic", "unfinished_ai_task")
    obj.setdefault("type", "generic_ai_safe_task")
    obj.setdefault("priority", "high")
    obj.setdefault("payload", {})

    if not isinstance(obj["payload"], dict):
        obj["payload"] = {"original_payload": obj["payload"]}

    obj["payload"].update({
        "source_queue": source,
        "converted_to_kibra_task_block": True,
        "not_sent_directly": True,
        "must_be_mined_by_pool": True,
        "real_payment": False,
        "real_sell": False,
        "external_tx": False,
        "manual_OWNER_approval_required": True
    })

    h = dsha(json.dumps(obj, ensure_ascii=False, sort_keys=True))
    obj["task_hash"] = h
    return obj

def collect_unfinished(limit=100):
    collected = []
    sources = ai_keys()

    for key in sources:
        for raw in r.lrange(key, 0, limit - 1):
            task = canonical_task(raw, key)
            h = task["task_hash"]

            if r.sadd(SENT, h):
                collected.append(task)
                r.lpush(MEMPOOL, json.dumps(task, ensure_ascii=False))

            if len(collected) >= limit:
                break

        if len(collected) >= limit:
            break

    return collected

def mine_one_block(tasks, difficulty=2, pool_id="KIBRA-AI-POOL"):
    prev = latest_hash()
    index = int(time.time())

    base = {
        "type": "KIBRA_AI_TASK_BLOCK",
        "index": index,
        "time": time.time(),
        "time_iso": now_iso(),
        "previous_hash": prev,
        "pool_id": pool_id,
        "difficulty": difficulty,
        "difficulty_prefix": "0" * difficulty,
        "task_count": len(tasks),
        "tasks": tasks,
        "native_coin": "KIBRA",
        "external_mint": False,
        "pool_mining": True,
        "not_sent_directly": True,
        "real_payment": False,
        "real_sell": False,
        "external_tx": False,
        "manual_OWNER_approval_required": True
    }

    nonce = 0
    prefix = "0" * difficulty
    shares = []

    while True:
        candidate = dict(base)
        candidate["nonce"] = nonce
        raw = json.dumps(candidate, ensure_ascii=False, sort_keys=True)
        h = dsha(raw)

        if h.startswith(prefix):
            candidate["block_hash"] = h
            candidate["pow_ok"] = True
            candidate["shares_count"] = len(shares)
            candidate["pool_tagged"] = True
            candidate["pool_reward_accounting"] = {
                "ready": True,
                "real_payout_now": False,
                "reward_type": "native_kibra_task_block_accounting"
            }
            return candidate

        if h.startswith("0"):
            shares.append({"nonce": nonce, "hash": h})

        nonce += 1

def mine_from_mempool(max_tasks=10, difficulty=2):
    tasks = []

    while len(tasks) < max_tasks and redis_len(MEMPOOL) > 0:
        raw = r.rpop(MEMPOOL)
        if not raw:
            break
        try:
            tasks.append(json.loads(raw))
        except Exception:
            pass

    if not tasks:
        return None

    block = mine_one_block(tasks, difficulty=difficulty)

    block_id = "task_block_" + block["block_hash"][:16]
    block_path = ROOT / "blockchain/kibra_chain/task_blocks" / f"{block_id}.json"
    mined_path = ROOT / "data/ai_task_blocks/mined" / f"{block_id}.json"
    pool_path = ROOT / "data/ai_task_blocks/pool_queue" / f"{block_id}.json"

    for p in [block_path, mined_path, pool_path]:
        p.parent.mkdir(parents=True, exist_ok=True)
        p.write_text(json.dumps(block, ensure_ascii=False, indent=2), encoding="utf-8")

    r.lpush(MINED, json.dumps(block, ensure_ascii=False))
    r.lpush(POOL_QUEUE, json.dumps(block, ensure_ascii=False))

    # тільки після майнингу блоку створюємо AI-support task
    support_task = {
        "topic": f"KIBRA mined AI task block support {block_id}",
        "type": "kibra_block_ai_support_task",
        "priority": "high",
        "payload": {
            "source": "ai_task_block_mining_department",
            "mined_task_block": block_id,
            "block_hash": block["block_hash"],
            "task_count": block["task_count"],
            "pool_id": block["pool_id"],
            "difficulty": block["difficulty"],
            "shares_count": block["shares_count"],
            "support_ai_parliament": True,
            "block_was_mined_before_sending": True,
            "real_payment": False,
            "real_sell": False,
            "manual_OWNER_approval_required": True
        }
    }
    r.lpush("cybra:ai:tasks:kibra_block_ai_support", json.dumps(support_task, ensure_ascii=False))

    return block

def report(collected=0, mined=None):
    for d in ["posts", "feeds", "proofs"]:
        (ROOT / d).mkdir(parents=True, exist_ok=True)

    obj = {
        "status": "ai_tasks_to_mining_blocks_report",
        "time": time.time(),
        "time_iso": now_iso(),
        "collected_now": collected,
        "mined_block": mined,
        "redis": {
            "mempool": redis_len(MEMPOOL),
            "mined": redis_len(MINED),
            "pool_queue": redis_len(POOL_QUEUE),
            "audit": redis_len(AUDIT),
            "ai_block_support_queue": redis_len("cybra:ai:tasks:kibra_block_ai_support")
        },
        "rule": "AI tasks are not sent directly. They are converted to mined KIBRA task-blocks and then provided to pools.",
        "safety": {
            "real_payment": False,
            "real_sell": False,
            "external_tx": False,
            "manual_OWNER_approval_required": True
        }
    }

    obj["double_sha"] = dsha(json.dumps(obj, ensure_ascii=False, sort_keys=True))

    (ROOT / "feeds/ai_tasks_to_mining_blocks_report.json").write_text(
        json.dumps(obj, ensure_ascii=False, indent=2),
        encoding="utf-8"
    )

    md = f"""# AI Tasks → KIBRA Mining Blocks

Status: **active**

## Rule

AI-завдання не відправляються просто так.  
Спочатку вони упаковуються у KIBRA task-blocks.  
Потім блоки передаються у pool mining queue.  
Після майнингу створюється AI-support task для парламенту.

## Current

- Collected now: **{collected}**
- Mempool: **{obj['redis']['mempool']}**
- Mined blocks: **{obj['redis']['mined']}**
- Pool mining queue: **{obj['redis']['pool_queue']}**
- AI block support queue: **{obj['redis']['ai_block_support_queue']}**

## Last mined block

`{mined.get('block_hash') if mined else None}`

## Safety

- Real payment: **false**
- Real sell: **false**
- External transaction: **false**
- Manual OWNER approval required: **true**

## Double SHA

`{obj['double_sha']}`
"""

    (ROOT / "posts/ai_tasks_to_mining_blocks_report.md").write_text(md, encoding="utf-8")

    with (ROOT / "proofs/ai_tasks_to_mining_blocks.sha256").open("w") as f:
        subprocess.run([
            "sha256sum",
            "feeds/ai_tasks_to_mining_blocks_report.json",
            "posts/ai_tasks_to_mining_blocks_report.md",
            "parliament/ai_task_mining_blocks/policy.json",
            "parliament/departments/ai_task_block_mining_department/department.json"
        ], cwd=ROOT, stdout=f, stderr=subprocess.DEVNULL)

    r.lpush(AUDIT, json.dumps({
        "status": "reported",
        "collected": collected,
        "mined": bool(mined),
        "double_sha": obj["double_sha"],
        "time": obj["time"]
    }, ensure_ascii=False))

    print("✅ AI tasks to mining blocks report generated")
    print("COLLECTED_NOW:", collected)
    print("MEMPOOL:", redis_len(MEMPOOL))
    print("MINED:", redis_len(MINED))
    print("POOL_QUEUE:", redis_len(POOL_QUEUE))
    if mined:
        print("MINED_BLOCK_HASH:", mined["block_hash"])

def cycle():
    collected_tasks = collect_unfinished(limit=100)
    mined = None

    if redis_len(MEMPOOL) > 0:
        mined = mine_from_mempool(max_tasks=10, difficulty=2)

    report(collected=len(collected_tasks), mined=mined)

def main():
    import sys
    cmd = sys.argv[1] if len(sys.argv) > 1 else "status"

    if cmd == "collect":
        c = collect_unfinished(limit=100)
        report(collected=len(c), mined=None)
    elif cmd == "mine":
        b = mine_from_mempool(max_tasks=10, difficulty=2)
        report(collected=0, mined=b)
    elif cmd == "cycle":
        cycle()
    elif cmd == "report":
        report()
    elif cmd == "status":
        print("MEMPOOL:", redis_len(MEMPOOL))
        print("MINED:", redis_len(MINED))
        print("POOL_QUEUE:", redis_len(POOL_QUEUE))
        print("AI_BLOCK_SUPPORT_QUEUE:", redis_len("cybra:ai:tasks:kibra_block_ai_support"))
    else:
        raise SystemExit("Usage: collect|mine|cycle|report|status")

if __name__ == "__main__":
    main()
PY

chmod +x cybra_ai_tasks_to_blocks.py

cat > ai_tasks_to_blocks_handler.sh <<'EOF2'
#!/data/data/com.termux/files/usr/bin/bash
set -e
cd "$HOME/CYBRA"

python3 cybra_ai_tasks_to_blocks.py cycle
EOF2

chmod +x ai_tasks_to_blocks_handler.sh

cat > cybra_ai_blocks.sh <<'EOF2'
#!/data/data/com.termux/files/usr/bin/bash
set -e
cd "$HOME/CYBRA"

case "${1:-status}" in
  collect)
    python3 cybra_ai_tasks_to_blocks.py collect
    ;;
  mine)
    python3 cybra_ai_tasks_to_blocks.py mine
    ;;
  cycle)
    python3 cybra_ai_tasks_to_blocks.py cycle
    ;;
  task)
    cybra parliament '{"topic":"AI tasks to KIBRA mining blocks","type":"ai_tasks_to_blocks_task","priority":"critical","payload":{"unfinished_ai_tasks_to_blocks":true,"blocks_to_pool_mining":true,"do_not_send_blocks_directly":true,"manual_OWNER_approval_required":true}}'
    ;;
  until-done)
    for i in $(seq 1 50); do
      echo "AI-BLOCK-CYCLE $i"
      python3 cybra_ai_tasks_to_blocks.py cycle
      bash cybra_ai_until_done.sh run 50 || true
      [ "$(redis-cli LLEN cybra:kibra:task_blocks:mempool)" = "0" ] && break
      sleep 1
    done
    ;;
  status)
    python3 cybra_ai_tasks_to_blocks.py status
    echo "PARLIAMENT_QUEUE: $(redis-cli LLEN cybra:parliament:queue)"
    echo "PARLIAMENT_FAILED: $(redis-cli LLEN cybra:parliament:failed)"
    test -f posts/ai_tasks_to_mining_blocks_report.md && echo "REPORT: exists" || echo "REPORT: missing"
    ;;
  report)
    cat posts/ai_tasks_to_mining_blocks_report.md
    ;;
  proof)
    cat proofs/ai_tasks_to_mining_blocks.sha256
    ;;
  *)
    echo "Usage: bash cybra_ai_blocks.sh collect|mine|cycle|task|until-done|status|report|proof"
    ;;
esac
EOF2

chmod +x cybra_ai_blocks.sh

redis-cli HSET cybra:executor:mapping ai_tasks_to_blocks_task ai_tasks_to_blocks_handler.sh >/dev/null

python3 - <<'PY'
from pathlib import Path

p = Path("parliament_executor_v6.py")
s = p.read_text()

if 'r.hget("cybra:executor:mapping", task_type)' not in s:
    old = "script_name = SCRIPT_MAP.get(task_type)"
    new = 'script_name = r.hget("cybra:executor:mapping", task_type) or SCRIPT_MAP.get(task_type)'
    if old in s:
        s = s.replace(old, new, 1)

if '"ai_tasks_to_blocks_task"' not in s:
    i = s.find("SCRIPT_MAP")
    j = s.find("{", i)
    if i >= 0 and j >= 0:
        s = s[:j+1] + '\n    "ai_tasks_to_blocks_task": "ai_tasks_to_blocks_handler.sh",' + s[j+1:]

p.write_text(s)
print("✅ ai_tasks_to_blocks_task mapping ready")
PY

rm -rf __pycache__
python3 -m py_compile cybra_ai_tasks_to_blocks.py
python3 -m py_compile parliament_executor_v6.py
rm -rf __pycache__

echo
echo "=== RUN FIRST CYCLE ==="
bash cybra_ai_blocks.sh cycle

echo
echo "=== ADD MASTER TASK TO PARLIAMENT ==="
bash cybra_ai_blocks.sh task

echo
echo "=== STATUS ==="
bash cybra_ai_blocks.sh status

echo
echo "=== PROOF CHECK ==="
sha256sum -c proofs/ai_tasks_to_mining_blocks.sha256 || true

echo
echo "✅ AI TASKS TO MINING BLOCKS INSTALLED"
