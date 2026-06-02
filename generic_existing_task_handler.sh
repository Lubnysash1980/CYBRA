#!/data/data/com.termux/files/usr/bin/bash
set -e
cd "$HOME/CYBRA"

mkdir -p posts feeds proofs logs/existing_tasks

python3 - <<'PY'
import json, time, hashlib, subprocess
from pathlib import Path

ROOT = Path.home() / "CYBRA"

def dsha(x):
    h1 = hashlib.sha256(x.encode("utf-8")).hexdigest()
    return hashlib.sha256(h1.encode("utf-8")).hexdigest()

obj = {
    "status": "generic_existing_task_handler_executed",
    "mode": "safe_fallback",
    "note": "Existing task reached safe fallback handler. No payment, no mint, no external tx executed.",
    "time": time.time()
}
obj["double_sha"] = dsha(json.dumps(obj, ensure_ascii=False, sort_keys=True))

Path("feeds/generic_existing_task_handler.json").write_text(json.dumps(obj, ensure_ascii=False, indent=2), encoding="utf-8")
Path("posts/generic_existing_task_handler.md").write_text(
    "# CYBRA Generic Existing Task Handler\n\n"
    "Status: executed\n\n"
    "Mode: safe fallback\n\n"
    f"Double SHA: `{obj['double_sha']}`\n",
    encoding="utf-8"
)

with Path("proofs/generic_existing_task_handler.sha256").open("w") as f:
    subprocess.run(
        ["sha256sum", "feeds/generic_existing_task_handler.json", "posts/generic_existing_task_handler.md"],
        cwd=ROOT,
        stdout=f,
        stderr=subprocess.DEVNULL
    )

print("✅ GENERIC EXISTING TASK HANDLER EXECUTED")
PY
