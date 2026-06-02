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
