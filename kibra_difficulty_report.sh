#!/data/data/com.termux/files/usr/bin/bash
set -e
cd "$HOME/CYBRA"

echo "=== KIBRA DIFFICULTY REPORT ==="

python3 - <<'PY'
import json
from pathlib import Path

p = Path("blockchain/kibra_chain/difficulty_stream.jsonl")

items = []
for line in p.read_text().splitlines():
    if line.strip():
        items.append(json.loads(line))

diffs = [x.get("difficulty", 0) for x in items]
shares = [x.get("shares_count", 0) for x in items]

print("BLOCKS:", len(items))
print("MIN_DIFFICULTY:", min(diffs) if diffs else None)
print("MAX_DIFFICULTY_REACHED:", max(diffs) if diffs else None)
print("CURRENT_DIFFICULTY:", diffs[-1] if diffs else None)
print("TOTAL_SHARES:", sum(shares))

print()
print("WHY CURRENT IS LOW:")
print("Difficulty rises when blocks are too fast.")
print("Difficulty falls when blocks take too long.")
print("Your chain reached difficulty 4, then actual block intervals became much longer than target 30 sec, so difficulty dropped to 2.")

print()
print("LAST_BLOCKS:")
for x in items[-10:]:
    print(
        "index=", x.get("index"),
        "difficulty=", x.get("difficulty"),
        "actual_interval=", x.get("actual_interval_sec"),
        "pow_ok=", x.get("pow_ok"),
        "shares=", x.get("shares_count"),
    )
PY
