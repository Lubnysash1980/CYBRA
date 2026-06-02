#!/data/data/com.termux/files/usr/bin/bash
set -e
cd "$HOME/CYBRA"

mkdir -p posts feeds proofs logs/dialogue

TS="$(date -Iseconds)"

python3 - <<'PY'
import json
from pathlib import Path

feed = Path("feeds/dialogue_key_status.json")
data = json.loads(feed.read_text()) if feed.exists() else {"status": "missing"}

Path("posts/dialogue_key_runtime.md").write_text(
    "# CYBRA Dialogue Runtime\n\n"
    f"Status: {data.get('status')}\n\n"
    f"Dialogue ID: `{data.get('dialogue_id')}`\n\n"
    f"Scope: `{data.get('scope')}`\n\n"
    "Mode: legal dialogue and compliance only.\n",
    encoding="utf-8"
)
PY

sha256sum \
  feeds/dialogue_key_status.json \
  posts/dialogue_key_status.md \
  posts/dialogue_key_runtime.md \
  parliament/dialogue/dialogue_policy.json \
  > proofs/dialogue_key.sha256

echo "✅ DIALOGUE KEY HANDLER EXECUTED"
