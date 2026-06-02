#!/data/data/com.termux/files/usr/bin/bash
set -e

cd "$HOME/CYBRA"

echo "=== INSTALL KIBRA DIFFICULTY CLASSES ==="

mkdir -p \
  parliament/kibra_difficulty_classes \
  data/kibra_difficulty_classes \
  posts feeds proofs logs/kibra_difficulty_classes

redis-cli ping >/dev/null 2>&1 || redis-server --daemonize yes || true
sleep 1

cat > parliament/kibra_difficulty_classes/policy.json <<'JSON'
{
  "name": "KIBRA Difficulty Naming Policy",
  "status": "active",
  "native_coin": true,
  "external_mint": false,
  "naming_rule": {
    "open_interval_name": "KIBRA(difficulty,+inf)",
    "exact_tier_name": "KIBRA-D<difficulty>",
    "examples": [
      "KIBRA(2,+inf)",
      "KIBRA(3,+inf)",
      "KIBRA(4,+inf)",
      "KIBRA-D2",
      "KIBRA-D3",
      "KIBRA-D4"
    ]
  },
  "meaning": {
    "KIBRA(2,+inf)": "all blocks with difficulty >= 2",
    "KIBRA(3,+inf)": "all blocks with difficulty >= 3",
    "KIBRA(4,+inf)": "all blocks with difficulty >= 4",
    "KIBRA-D2": "exact difficulty 2 block",
    "KIBRA-D3": "exact difficulty 3 block",
    "KIBRA-D4": "exact difficulty 4 block"
  },
  "safety": {
    "price_not_assigned_by_difficulty_alone": true,
    "market_price_requires_liquidity": true,
    "real_sell_execution_now": false,
    "manual_OWNER_approval_required": true
  }
}
JSON

cat > cybra_kibra_difficulty_classes.py <<'PY'
#!/usr/bin/env python3
import json
import time
import hashlib
import subprocess
from pathlib import Path
import redis

ROOT = Path.home() / "CYBRA"
r = redis.Redis(host="127.0.0.1", port=6379, decode_responses=True)

AUDIT = "cybra:kibra:difficulty_classes:audit"
AIQ = "cybra:ai:tasks:kibra_difficulty_classes"

def sha(x):
    return hashlib.sha256(x.encode("utf-8")).hexdigest()

def dsha(x):
    return sha(sha(x))

def now_iso():
    return time.strftime("%Y-%m-%dT%H:%M:%S%z")

def read_stream():
    p = ROOT / "blockchain/kibra_chain/difficulty_stream.jsonl"
    items = []
    if not p.exists():
        return items
    for line in p.read_text(encoding="utf-8").splitlines():
        if not line.strip():
            continue
        try:
            items.append(json.loads(line))
        except Exception:
            pass
    return items

def latest_hash():
    p = ROOT / "blockchain/kibra_chain/latest.block.hash"
    return p.read_text().strip() if p.exists() else None

def file_sha(path):
    p = ROOT / path
    if not p.exists():
        return None
    h = hashlib.sha256()
    with p.open("rb") as f:
        for c in iter(lambda: f.read(1024 * 1024), b""):
            h.update(c)
    return h.hexdigest()

def build_classes():
    items = read_stream()

    exact = {}
    open_intervals = {}
    block_classes = []

    difficulties = sorted(set(int(x.get("difficulty", 0)) for x in items if int(x.get("difficulty", 0)) > 0))

    for d in difficulties:
        exact[f"KIBRA-D{d}"] = []
        open_intervals[f"KIBRA({d},+inf)"] = []

    for x in items:
        idx = x.get("index")
        d = int(x.get("difficulty", 0))
        h = x.get("block_hash")
        shares = x.get("shares_count", 0)
        pow_ok = bool(x.get("pow_ok"))

        exact_name = f"KIBRA-D{d}"
        open_name = f"KIBRA({d},+inf)"

        block_info = {
            "index": idx,
            "difficulty": d,
            "exact_name": exact_name,
            "open_interval_name": open_name,
            "block_hash": h,
            "pow_ok": pow_ok,
            "shares_count": shares,
            "time_iso": x.get("time_iso")
        }

        block_classes.append(block_info)

        exact.setdefault(exact_name, []).append(block_info)

        for threshold in difficulties:
            if d >= threshold:
                open_intervals.setdefault(f"KIBRA({threshold},+inf)", []).append(block_info)

    summary_exact = {
        name: {
            "blocks": len(v),
            "shares_total": sum(int(b.get("shares_count", 0)) for b in v),
            "indexes": [b.get("index") for b in v]
        }
        for name, v in exact.items()
    }

    summary_open = {
        name: {
            "blocks": len(v),
            "shares_total": sum(int(b.get("shares_count", 0)) for b in v),
            "indexes": [b.get("index") for b in v]
        }
        for name, v in open_intervals.items()
    }

    return {
        "status": "kibra_difficulty_classes_created",
        "time": time.time(),
        "time_iso": now_iso(),
        "latest_kibra_hash": latest_hash(),
        "total_blocks": len(items),
        "difficulties_found": difficulties,
        "block_classes": block_classes,
        "exact_classes": summary_exact,
        "open_interval_classes": summary_open,
        "naming": {
            "exact": "KIBRA-D<difficulty>",
            "open_interval": "KIBRA(<difficulty>,+inf)"
        },
        "market_note": "Difficulty class confirms mining/proof grade. It does not create market price without liquidity/orderbook/buyers.",
        "safety": {
            "external_mint": False,
            "real_sell_execution_now": False,
            "manual_OWNER_approval_required": True
        }
    }

def report(submit_ai=False):
    for d in ["posts", "feeds", "proofs", "data/kibra_difficulty_classes"]:
        (ROOT / d).mkdir(parents=True, exist_ok=True)

    obj = build_classes()
    obj["submit_ai"] = submit_ai
    obj["double_sha"] = dsha(json.dumps(obj, ensure_ascii=False, sort_keys=True))

    (ROOT / "feeds/kibra_difficulty_classes_report.json").write_text(
        json.dumps(obj, ensure_ascii=False, indent=2),
        encoding="utf-8"
    )

    (ROOT / "data/kibra_difficulty_classes/classes.json").write_text(
        json.dumps({
            "block_classes": obj["block_classes"],
            "exact_classes": obj["exact_classes"],
            "open_interval_classes": obj["open_interval_classes"]
        }, ensure_ascii=False, indent=2),
        encoding="utf-8"
    )

    if submit_ai:
        task = {
            "topic": "KIBRA difficulty-based naming and monetization classes",
            "type": "kibra_difficulty_classes_task",
            "priority": "high",
            "payload": {
                "goal": "Use KIBRA difficulty classes for native coin block grade naming",
                "naming": obj["naming"],
                "difficulties_found": obj["difficulties_found"],
                "total_blocks": obj["total_blocks"],
                "price_not_assigned_by_difficulty_alone": True,
                "market_price_requires_liquidity": True,
                "manual_OWNER_approval_required": True
            }
        }
        r.lpush(AIQ, json.dumps(task, ensure_ascii=False))

    exact_md = ""
    for name, s in obj["exact_classes"].items():
        exact_md += f"- `{name}`: blocks={s['blocks']}, shares={s['shares_total']}, indexes={s['indexes']}\n"

    open_md = ""
    for name, s in obj["open_interval_classes"].items():
        open_md += f"- `{name}`: blocks={s['blocks']}, shares={s['shares_total']}, indexes={s['indexes']}\n"

    md = f"""# KIBRA Difficulty Classes

Status: **created**

## Naming

- Exact difficulty: `KIBRA-D<difficulty>`
- Open interval: `KIBRA(<difficulty>,+inf)`

## Current chain

- Total blocks: **{obj['total_blocks']}**
- Difficulties found: **{obj['difficulties_found']}**
- Latest hash: `{obj['latest_kibra_hash']}`

## Exact classes

{exact_md}

## Open interval classes

{open_md}

## Meaning

`KIBRA(2,+inf)` означає всі блоки зі складністю **2 і вище**.  
`KIBRA(3,+inf)` означає всі блоки зі складністю **3 і вище**.  
`KIBRA(4,+inf)` означає всі блоки зі складністю **4 і вище**.

## Market note

Складність дає proof-grade монети/блоку.  
Ринкова ціна все одно потребує liquidity/orderbook/buyers.

## Proof

Double SHA:

`{obj['double_sha']}`
"""

    (ROOT / "posts/kibra_difficulty_classes_report.md").write_text(md, encoding="utf-8")

    with (ROOT / "proofs/kibra_difficulty_classes.sha256").open("w") as f:
        subprocess.run([
            "sha256sum",
            "parliament/kibra_difficulty_classes/policy.json",
            "feeds/kibra_difficulty_classes_report.json",
            "data/kibra_difficulty_classes/classes.json",
            "posts/kibra_difficulty_classes_report.md"
        ], cwd=ROOT, stdout=f, stderr=subprocess.DEVNULL)

    r.lpush(AUDIT, json.dumps({
        "status": "kibra_difficulty_classes_created",
        "total_blocks": obj["total_blocks"],
        "difficulties_found": obj["difficulties_found"],
        "double_sha": obj["double_sha"],
        "time": obj["time"]
    }, ensure_ascii=False))

    print("✅ KIBRA difficulty classes report created")
    print("TOTAL_BLOCKS:", obj["total_blocks"])
    print("DIFFICULTIES_FOUND:", obj["difficulties_found"])
    print("REPORT: posts/kibra_difficulty_classes_report.md")
    print("PROOF: proofs/kibra_difficulty_classes.sha256")

def main():
    import sys
    cmd = sys.argv[1] if len(sys.argv) > 1 else "report"
    if cmd == "report":
        report(False)
    elif cmd == "submit-ai":
        report(True)
    else:
        raise SystemExit("Usage: report|submit-ai")

if __name__ == "__main__":
    main()
PY

chmod +x cybra_kibra_difficulty_classes.py

cat > kibra_difficulty_classes_handler.sh <<'EOF2'
#!/data/data/com.termux/files/usr/bin/bash
set -e
cd "$HOME/CYBRA"
python3 cybra_kibra_difficulty_classes.py submit-ai
EOF2

chmod +x kibra_difficulty_classes_handler.sh

cat > cybra_kibra_difficulty.sh <<'EOF2'
#!/data/data/com.termux/files/usr/bin/bash
set -e
cd "$HOME/CYBRA"

case "${1:-status}" in
  report)
    python3 cybra_kibra_difficulty_classes.py report
    cat posts/kibra_difficulty_classes_report.md
    ;;
  submit-ai)
    python3 cybra_kibra_difficulty_classes.py submit-ai
    ;;
  status)
    redis-cli ping
    echo "DIFFICULTY_CLASS_AUDIT: $(redis-cli LLEN cybra:kibra:difficulty_classes:audit)"
    echo "AI_QUEUE: $(redis-cli LLEN cybra:ai:tasks:kibra_difficulty_classes)"
    test -f posts/kibra_difficulty_classes_report.md && echo "REPORT: exists" || echo "REPORT: missing"
    ;;
  classes)
    cat data/kibra_difficulty_classes/classes.json
    ;;
  proof)
    cat proofs/kibra_difficulty_classes.sha256
    ;;
  *)
    echo "Usage: bash cybra_kibra_difficulty.sh report|submit-ai|status|classes|proof"
    ;;
esac
EOF2

chmod +x cybra_kibra_difficulty.sh

redis-cli HSET cybra:executor:mapping kibra_difficulty_classes_task kibra_difficulty_classes_handler.sh >/dev/null

python3 -m py_compile cybra_kibra_difficulty_classes.py

echo
echo "=== RUN DIFFICULTY CLASS REPORT ==="
bash cybra_kibra_difficulty.sh submit-ai

echo
echo "=== STATUS ==="
bash cybra_kibra_difficulty.sh status

echo
echo "=== PROOF CHECK ==="
sha256sum -c proofs/kibra_difficulty_classes.sha256

echo
echo "✅ KIBRA DIFFICULTY CLASSES INSTALLED"
