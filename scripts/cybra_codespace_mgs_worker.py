#!/usr/bin/env python3
import json, time
from pathlib import Path

ROOT = Path.cwd()
TASKS = ROOT / "data/cybra_mgs/tasks"
REPORTS = ROOT / "data/cybra_mgs/codespace"
POSTS = ROOT / "posts"
FEEDS = ROOT / "feeds"
PROOFS = ROOT / "proofs"

for p in [TASKS, REPORTS, POSTS, FEEDS, PROOFS]:
    p.mkdir(parents=True, exist_ok=True)

processed = []
for f in sorted(TASKS.glob("*.json")):
    try:
        data = json.loads(f.read_text(encoding="utf-8"))
    except Exception:
        continue
    data["codespace_status"] = "ACCEPTED"
    data["codespace_timestamp"] = time.strftime("%Y-%m-%dT%H:%M:%S")
    out = REPORTS / (f.stem + "_result.json")
    out.write_text(json.dumps(data, ensure_ascii=False, indent=2), encoding="utf-8")
    processed.append(data.get("task_id", f.stem))

latest = {
    "timestamp": time.strftime("%Y-%m-%dT%H:%M:%S"),
    "status": "OK",
    "processed_count": len(processed),
    "processed": processed[-20:],
    "real_trading_now": False,
    "automatic_external_tx": False
}

(REPORTS / "latest_codespace_mgs_report.json").write_text(json.dumps(latest, ensure_ascii=False, indent=2), encoding="utf-8")
(FEEDS / "cybra_mgs_codespace_report.json").write_text(json.dumps(latest, ensure_ascii=False, indent=2), encoding="utf-8")
(POSTS / "cybra_mgs_codespace_report.md").write_text("# CYBRA MGS Codespace Report\n\nProcessed: " + str(len(processed)) + "\n", encoding="utf-8")
print(json.dumps(latest, ensure_ascii=False, indent=2))
