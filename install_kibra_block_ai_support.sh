#!/data/data/com.termux/files/usr/bin/bash
set -e

cd "$HOME/CYBRA"

echo "=== INSTALL KIBRA BLOCK AI SUPPORT ==="

mkdir -p \
  parliament/kibra_block_ai_support \
  parliament/departments/kibra_block_ai_support_department \
  data/kibra_block_ai_support/tasks \
  data/kibra_block_ai_support/outbox \
  posts feeds proofs logs/kibra_block_ai_support

redis-cli ping >/dev/null 2>&1 || redis-server --daemonize yes || true
sleep 1

cat > parliament/departments/kibra_block_ai_support_department/department.json <<'JSON'
{
  "department_id": "kibra_block_ai_support_department",
  "name": "KIBRA Block AI Support Department",
  "status": "active",
  "mission": "Відправляти підтверджені KIBRA-блоки разом з AI-завданнями для підтримки AI Parliament: verify, pool accounting, bridge package, difficulty class, repair routing, evolution.",
  "mode": "block_to_ai_task_support",
  "rules": [
    "each_confirmed_block_creates_ai_support_task",
    "block_hash_required",
    "difficulty_class_required",
    "pool_accounting_required",
    "broken_blocks_to_mint_repair_department",
    "good_blocks_to_bridge_outbox",
    "no_real_external_broadcast_without_OWNER_approval"
  ],
  "safety": [
    "no_real_payment",
    "no_external_tx",
    "no_private_keys",
    "no_seed_phrase",
    "manual_OWNER_approval_required"
  ]
}
JSON

cat > parliament/kibra_block_ai_support/policy.json <<'JSON'
{
  "name": "KIBRA Block AI Support Policy",
  "status": "active",
  "native_coin": true,
  "external_mint": false,
  "purpose": "Кожен блок KIBRA стає AI-завданням для підтримки AI Parliament.",
  "block_task_payload": [
    "block_index",
    "block_hash",
    "difficulty",
    "difficulty_class",
    "shares_count",
    "pool_tagged",
    "pow_ok",
    "ai_support_goal"
  ],
  "support_goals": [
    "verify_block",
    "confirm_pool_accounting",
    "classify_by_difficulty",
    "send_to_closed_sha_bridge_outbox",
    "route_broken_blocks_to_mint_repair",
    "support_ai_parliament_until_done"
  ],
  "execution": {
    "real_network_broadcast_now": false,
    "real_payment": false,
    "real_sell": false,
    "manual_OWNER_approval_required": true
  }
}
JSON

cat > cybra_kibra_block_ai_support.py <<'PY'
#!/usr/bin/env python3
import json
import time
import hashlib
import subprocess
from pathlib import Path

import redis

ROOT = Path.home() / "CYBRA"
r = redis.Redis(host="127.0.0.1", port=6379, decode_responses=True)

AIQ = "cybra:ai:tasks:kibra_block_ai_support"
AUDIT = "cybra:kibra:block_ai_support:audit"
OUTBOX = "cybra:kibra:block_ai_support:outbox"
SENT = "cybra:kibra:block_ai_support:sent_hashes"

def sha(x):
    return hashlib.sha256(x.encode("utf-8")).hexdigest()

def dsha(x):
    return sha(sha(x))

def now_iso():
    return time.strftime("%Y-%m-%dT%H:%M:%S%z")

def file_sha(path):
    p = ROOT / path
    if not p.exists():
        return None
    h = hashlib.sha256()
    with p.open("rb") as f:
        for c in iter(lambda: f.read(1024 * 1024), b""):
            h.update(c)
    return h.hexdigest()

def redis_len(key):
    try:
        return r.llen(key)
    except Exception:
        return 0

def latest_hash():
    p = ROOT / "blockchain/kibra_chain/latest.block.hash"
    return p.read_text().strip() if p.exists() else None

def read_difficulty_stream():
    p = ROOT / "blockchain/kibra_chain/difficulty_stream.jsonl"
    rows = {}
    if not p.exists():
        return rows

    for line in p.read_text(encoding="utf-8").splitlines():
        if not line.strip():
            continue
        try:
            x = json.loads(line)
            idx = x.get("index")
            if idx is not None:
                rows[int(idx)] = x
        except Exception:
            pass
    return rows

def block_files():
    d = ROOT / "blockchain/kibra_chain/blocks"
    if not d.exists():
        return []
    return sorted(d.glob("block_*.json"))

def difficulty_names(d):
    return {
        "exact": f"KIBRA-D{d}",
        "open_interval": f"KIBRA({d},+inf)"
    }

def parse_block_index(path, obj, fallback):
    for k in ["index", "height", "block_index"]:
        if k in obj:
            try:
                return int(obj[k])
            except Exception:
                pass

    name = path.name
    digits = ""
    for ch in name:
        if ch.isdigit():
            digits += ch
        elif digits:
            break

    try:
        return int(digits)
    except Exception:
        return fallback

def build_block_tasks():
    stream = read_difficulty_stream()
    tasks = []
    broken = []

    for fallback, f in enumerate(block_files()):
        rel = str(f.relative_to(ROOT))

        try:
            obj = json.loads(f.read_text(encoding="utf-8"))
            if not isinstance(obj, dict):
                raise ValueError("block_json_not_object")

            idx = parse_block_index(f, obj, fallback)
            s = stream.get(idx, {})

            difficulty = int(s.get("difficulty") or obj.get("difficulty") or 0)
            block_hash = (
                s.get("block_hash")
                or obj.get("block_hash")
                or obj.get("hash")
                or obj.get("double_sha")
                or obj.get("pow_hash")
                or file_sha(rel)
            )
            shares = s.get("shares_count") or obj.get("shares_count") or obj.get("shares") or 0
            if isinstance(shares, list):
                shares = len(shares)
            if not isinstance(shares, int):
                try:
                    shares = int(shares)
                except Exception:
                    shares = 0

            pow_ok = bool(s.get("pow_ok", obj.get("pow_ok", True)))

            text = json.dumps(obj, ensure_ascii=False).lower()
            pool_tagged = any(x in text for x in [
                "pool", "miner", "pool_id", "mining_pool", "pool_reward", "pool_accounting"
            ])

            names = difficulty_names(difficulty)

            block_payload = {
                "block_index": idx,
                "block_file": rel,
                "block_file_sha256": file_sha(rel),
                "block_hash": block_hash,
                "difficulty": difficulty,
                "difficulty_exact_class": names["exact"],
                "difficulty_open_interval": names["open_interval"],
                "shares_count": shares,
                "pow_ok": pow_ok,
                "pool_tagged": pool_tagged,
                "latest_kibra_hash": latest_hash()
            }

            task = {
                "topic": f"KIBRA block {idx} AI Parliament support",
                "type": "kibra_block_ai_support_task",
                "priority": "high",
                "payload": {
                    "source": "kibra_block_ai_support_department",
                    "ai_support_goal": [
                        "verify_block",
                        "confirm_pool_accounting",
                        "classify_difficulty",
                        "prepare_closed_sha_bridge_outbox",
                        "support_ai_parliament_until_done"
                    ],
                    "block": block_payload,
                    "native_coin": True,
                    "external_mint": False,
                    "real_network_broadcast_now": False,
                    "real_payment": False,
                    "real_sell": False,
                    "manual_OWNER_approval_required": True,
                    "no_private_keys": True,
                    "no_seed_phrase": True
                }
            }

            task_hash = dsha(json.dumps(task, ensure_ascii=False, sort_keys=True))
            task["payload"]["block_ai_support_hash"] = task_hash
            tasks.append(task)

        except Exception as e:
            item = {
                "file": rel,
                "error": str(e),
                "sha256": file_sha(rel),
                "time": time.time()
            }
            broken.append(item)

            repair_task = {
                "topic": f"KIBRA broken block repair: {rel}",
                "type": "kibra_price_sell_repair_task",
                "priority": "critical",
                "payload": {
                    "source": "kibra_block_ai_support_department",
                    "broken_block": item,
                    "send_to": "kibra_mint_repair_department",
                    "real_network_release": False,
                    "manual_OWNER_approval_required": True
                }
            }
            repair_task["payload"]["block_ai_support_hash"] = dsha(json.dumps(repair_task, ensure_ascii=False, sort_keys=True))
            tasks.append(repair_task)

    return tasks, broken

def submit():
    tasks, broken = build_block_tasks()

    sent = 0
    skipped = 0
    outbox_items = []

    for task in tasks:
        h = task["payload"]["block_ai_support_hash"]

        outbox_items.append({
            "hash": h,
            "topic": task.get("topic"),
            "type": task.get("type"),
            "block_index": task.get("payload", {}).get("block", {}).get("block_index"),
            "block_hash": task.get("payload", {}).get("block", {}).get("block_hash"),
            "difficulty": task.get("payload", {}).get("block", {}).get("difficulty"),
            "shares_count": task.get("payload", {}).get("block", {}).get("shares_count")
        })

        if r.sadd(SENT, h):
            r.lpush(AIQ, json.dumps(task, ensure_ascii=False))
            r.lpush(OUTBOX, json.dumps(task, ensure_ascii=False))
            sent += 1
        else:
            skipped += 1

    report(sent, skipped, tasks, broken, outbox_items)

def report(sent=0, skipped=0, tasks=None, broken=None, outbox_items=None):
    for d in ["posts", "feeds", "proofs", "data/kibra_block_ai_support/tasks", "data/kibra_block_ai_support/outbox"]:
        (ROOT / d).mkdir(parents=True, exist_ok=True)

    if tasks is None:
        tasks, broken = build_block_tasks()
        outbox_items = []

    total_blocks = len(block_files())
    pool_tagged = 0
    shares_total = 0
    difficulties = {}

    for task in tasks:
        b = task.get("payload", {}).get("block", {})
        if b:
            if b.get("pool_tagged"):
                pool_tagged += 1
            shares_total += int(b.get("shares_count", 0) or 0)
            d = str(b.get("difficulty"))
            difficulties[d] = difficulties.get(d, 0) + 1

    obj = {
        "status": "kibra_block_ai_support_report_generated",
        "time": time.time(),
        "time_iso": now_iso(),
        "latest_kibra_hash": latest_hash(),
        "total_block_files": total_blocks,
        "ai_tasks_total": len(tasks),
        "ai_tasks_sent_now": sent,
        "ai_tasks_skipped_duplicates": skipped,
        "pool_tagged_blocks": pool_tagged,
        "shares_total": shares_total,
        "difficulty_distribution": difficulties,
        "broken_blocks": broken or [],
        "redis": {
            "ai_queue": redis_len(AIQ),
            "outbox": redis_len(OUTBOX),
            "sent_hashes": r.scard(SENT),
            "parliament_queue": redis_len("cybra:parliament:queue"),
            "parliament_failed": redis_len("cybra:parliament:failed")
        },
        "safety": {
            "real_network_broadcast_now": False,
            "real_payment": False,
            "real_sell": False,
            "external_mint": False,
            "manual_OWNER_approval_required": True
        }
    }

    obj["double_sha"] = dsha(json.dumps(obj, ensure_ascii=False, sort_keys=True))

    (ROOT / "feeds/kibra_block_ai_support_report.json").write_text(
        json.dumps(obj, ensure_ascii=False, indent=2),
        encoding="utf-8"
    )

    (ROOT / "data/kibra_block_ai_support/tasks/block_ai_tasks.json").write_text(
        json.dumps(tasks, ensure_ascii=False, indent=2),
        encoding="utf-8"
    )

    (ROOT / "data/kibra_block_ai_support/outbox/block_ai_outbox.json").write_text(
        json.dumps(outbox_items or [], ensure_ascii=False, indent=2),
        encoding="utf-8"
    )

    md = f"""# KIBRA Block AI Support Report

Status: **generated**

## Result

- Total block files: **{total_blocks}**
- AI tasks total: **{len(tasks)}**
- AI tasks sent now: **{sent}**
- Skipped duplicates: **{skipped}**
- Pool-tagged blocks: **{pool_tagged}**
- Shares total: **{shares_total}**
- Latest KIBRA hash: `{latest_hash()}`

## Difficulty distribution

`{difficulties}`

## Meaning

Кожен підтверджений KIBRA-блок отримує AI-завдання для підтримки AI Parliament.

Блоки відправляються не як реальна зовнішня транзакція, а як:

- AI support task
- bridge/outbox package
- pool accounting proof
- difficulty class proof
- repair routing if broken

## Safety

- Real network broadcast now: **false**
- Real payment: **false**
- Real sell: **false**
- External mint: **false**
- Manual OWNER approval required: **true**

## Double SHA

`{obj["double_sha"]}`
"""

    (ROOT / "posts/kibra_block_ai_support_report.md").write_text(md, encoding="utf-8")

    with (ROOT / "proofs/kibra_block_ai_support.sha256").open("w") as f:
        subprocess.run([
            "sha256sum",
            "parliament/kibra_block_ai_support/policy.json",
            "parliament/departments/kibra_block_ai_support_department/department.json",
            "feeds/kibra_block_ai_support_report.json",
            "data/kibra_block_ai_support/tasks/block_ai_tasks.json",
            "data/kibra_block_ai_support/outbox/block_ai_outbox.json",
            "posts/kibra_block_ai_support_report.md"
        ], cwd=ROOT, stdout=f, stderr=subprocess.DEVNULL)

    r.lpush(AUDIT, json.dumps({
        "status": "kibra_block_ai_support_report_generated",
        "tasks_total": len(tasks),
        "sent_now": sent,
        "skipped": skipped,
        "pool_tagged_blocks": pool_tagged,
        "shares_total": shares_total,
        "double_sha": obj["double_sha"],
        "time": obj["time"]
    }, ensure_ascii=False))

    print("✅ KIBRA block AI support report generated")
    print("TOTAL_BLOCKS:", total_blocks)
    print("AI_TASKS_TOTAL:", len(tasks))
    print("AI_TASKS_SENT_NOW:", sent)
    print("POOL_TAGGED_BLOCKS:", pool_tagged)
    print("SHARES_TOTAL:", shares_total)
    print("REPORT: posts/kibra_block_ai_support_report.md")
    print("PROOF: proofs/kibra_block_ai_support.sha256")

def main():
    import sys
    cmd = sys.argv[1] if len(sys.argv) > 1 else "report"

    if cmd == "report":
        report()
    elif cmd == "submit":
        submit()
    else:
        raise SystemExit("Usage: report|submit")

if __name__ == "__main__":
    main()
PY

chmod +x cybra_kibra_block_ai_support.py

cat > kibra_block_ai_support_handler.sh <<'EOF2'
#!/data/data/com.termux/files/usr/bin/bash
set -e
cd "$HOME/CYBRA"

python3 cybra_kibra_block_ai_support.py report
bash cybra_kibra_chain.sh verify >/dev/null 2>&1 || true
bash cybra_kibra_bridge.sh submit-ai >/dev/null 2>&1 || true
EOF2

chmod +x kibra_block_ai_support_handler.sh

cat > cybra_kibra_block_ai.sh <<'EOF2'
#!/data/data/com.termux/files/usr/bin/bash
set -e
cd "$HOME/CYBRA"

case "${1:-status}" in
  report)
    python3 cybra_kibra_block_ai_support.py report
    cat posts/kibra_block_ai_support_report.md
    ;;
  submit)
    python3 cybra_kibra_block_ai_support.py submit
    ;;
  task)
    cybra parliament '{"topic":"KIBRA blocks AI Parliament support","type":"kibra_block_ai_support_task","priority":"critical","payload":{"send_blocks_with_ai_tasks":true,"support_ai_parliament":true,"real_network_broadcast_now":false,"manual_OWNER_approval_required":true}}'
    ;;
  until-done)
    python3 cybra_kibra_block_ai_support.py submit
    bash cybra_ai_until_done.sh run 500
    ;;
  status)
    redis-cli ping
    echo "BLOCK_AI_AUDIT: $(redis-cli LLEN cybra:kibra:block_ai_support:audit)"
    echo "BLOCK_AI_QUEUE: $(redis-cli LLEN cybra:ai:tasks:kibra_block_ai_support)"
    echo "BLOCK_AI_OUTBOX: $(redis-cli LLEN cybra:kibra:block_ai_support:outbox)"
    echo "SENT_HASHES: $(redis-cli SCARD cybra:kibra:block_ai_support:sent_hashes)"
    echo "PARLIAMENT_QUEUE: $(redis-cli LLEN cybra:parliament:queue)"
    echo "PARLIAMENT_FAILED: $(redis-cli LLEN cybra:parliament:failed)"
    test -f posts/kibra_block_ai_support_report.md && echo "REPORT: exists" || echo "REPORT: missing"
    ;;
  tasks)
    cat data/kibra_block_ai_support/tasks/block_ai_tasks.json
    ;;
  outbox)
    cat data/kibra_block_ai_support/outbox/block_ai_outbox.json
    ;;
  proof)
    cat proofs/kibra_block_ai_support.sha256
    ;;
  *)
    echo "Usage:"
    echo "  bash cybra_kibra_block_ai.sh report"
    echo "  bash cybra_kibra_block_ai.sh submit"
    echo "  bash cybra_kibra_block_ai.sh task"
    echo "  bash cybra_kibra_block_ai.sh until-done"
    echo "  bash cybra_kibra_block_ai.sh status"
    echo "  bash cybra_kibra_block_ai.sh tasks"
    echo "  bash cybra_kibra_block_ai.sh outbox"
    echo "  bash cybra_kibra_block_ai.sh proof"
    ;;
esac
EOF2

chmod +x cybra_kibra_block_ai.sh

redis-cli HSET cybra:executor:mapping kibra_block_ai_support_task kibra_block_ai_support_handler.sh >/dev/null

python3 - <<'PY'
from pathlib import Path

p = Path("parliament_executor_v6.py")
s = p.read_text()

if 'r.hget("cybra:executor:mapping", task_type)' not in s:
    old = "script_name = SCRIPT_MAP.get(task_type)"
    new = 'script_name = r.hget("cybra:executor:mapping", task_type) or SCRIPT_MAP.get(task_type)'
    if old in s:
        s = s.replace(old, new, 1)

if '"kibra_block_ai_support_task"' not in s:
    i = s.find("SCRIPT_MAP")
    j = s.find("{", i)
    if i >= 0 and j >= 0:
        s = s[:j+1] + '\n    "kibra_block_ai_support_task": "kibra_block_ai_support_handler.sh",' + s[j+1:]

p.write_text(s)
print("✅ kibra_block_ai_support_task mapping ready")
PY

rm -rf __pycache__
python3 -m py_compile cybra_kibra_block_ai_support.py
python3 -m py_compile parliament_executor_v6.py
rm -rf __pycache__

echo
echo "=== SEND BLOCKS AS AI TASKS ==="
bash cybra_kibra_block_ai.sh submit

echo
echo "=== ADD MASTER TASK ==="
bash cybra_kibra_block_ai.sh task

echo
echo "=== RUN UNTIL DONE ==="
bash cybra_ai_until_done.sh run 500

echo
echo "=== STATUS ==="
bash cybra_kibra_block_ai.sh status
cybra status || true

echo
echo "=== PROOF CHECK ==="
sha256sum -c proofs/kibra_block_ai_support.sha256 || true

echo
echo "✅ KIBRA BLOCK AI SUPPORT INSTALLED"
