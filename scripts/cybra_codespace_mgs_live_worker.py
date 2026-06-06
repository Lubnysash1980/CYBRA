#!/usr/bin/env python3
import json, time, hashlib
from pathlib import Path

ROOT = Path.cwd()
BASE = ROOT / "data/cybra_mgs"
TASKS = BASE / "tasks"
OUT = BASE / "codespace"
POSTS = ROOT / "posts"
FEEDS = ROOT / "feeds"
PROOFS = ROOT / "proofs"

for p in [TASKS, OUT, POSTS, FEEDS, PROOFS]:
    p.mkdir(parents=True, exist_ok=True)

def now():
    return time.strftime("%Y-%m-%dT%H:%M:%S")

def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()

processed = []
for f in sorted(TASKS.glob("*.json")):
    try:
        task = json.loads(f.read_text(encoding="utf-8"))
    except Exception:
        continue

    result = {
        "task_id": task.get("task_id", f.stem),
        "timestamp": now(),
        "status": "CODESPACE_EXECUTOR_ACCEPTED",
        "executor": "MGS Codespace Worker",
        "committees": task.get("committees", []),
        "title": task.get("title"),
        "evolution_rule": task.get("evolution_rule"),
        "result": "Task accepted. Patch/report should be produced as separate evolution layer. Existing v64/module64 preserved.",
        "safety": {
            "real_trading_now": False,
            "binance_real_orders": False,
            "bybit_real_orders": False,
            "automatic_external_tx": False
        }
    }

    out = OUT / f"{result['task_id']}_result.json"
    out.write_text(json.dumps(result, ensure_ascii=False, indent=2), encoding="utf-8")
    processed.append(result)

latest = {
    "timestamp": now(),
    "status": "CODESPACE_WORKER_OK",
    "processed_count": len(processed),
    "processed": processed[-50:],
    "safety": {
        "real_trading_now": False,
        "automatic_external_tx": False
    }
}

j = OUT / "latest_mgs_codespace_worker.json"
feed = FEEDS / "cybra_mgs_codespace_worker.json"
post = POSTS / "cybra_mgs_codespace_worker.md"
proof = PROOFS / "cybra_mgs_codespace_worker.sha256"

j.write_text(json.dumps(latest, ensure_ascii=False, indent=2), encoding="utf-8")
feed.write_text(json.dumps(latest, ensure_ascii=False, indent=2), encoding="utf-8")

lines = ["# CYBRA MGS Codespace Worker", "", f"Timestamp: {latest['timestamp']}", "", f"Processed: {len(processed)}", ""]
for r in processed[-20:]:
    lines.append(f"- `{r['task_id']}` — {r['title']} — {r['status']}")
lines += ["", "## Safety", "real_trading_now: false", "automatic_external_tx: false"]
post.write_text("\n".join(lines) + "\n", encoding="utf-8")

proof.write_text(
    f"{sha(j)}  data/cybra_mgs/codespace/latest_mgs_codespace_worker.json\n"
    f"{sha(feed)}  feeds/cybra_mgs_codespace_worker.json\n"
    f"{sha(post)}  posts/cybra_mgs_codespace_worker.md\n",
    encoding="utf-8"
)

print(json.dumps(latest, ensure_ascii=False, indent=2))
