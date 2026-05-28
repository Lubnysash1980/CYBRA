#!/data/data/com.termux/files/usr/bin/bash
set -e

BASE="$HOME/CYBRA"
mkdir -p "$BASE/proofs" "$BASE/posts"

find "$BASE" \
  -path "$BASE/.git" -prune -o \
  -path "$BASE/venv" -prune -o \
  -path "$BASE/.venv" -prune -o \
  -type f -exec sha256sum {} \; > "$BASE/proofs/github_backend_sha256.txt"

python3 - <<'PY'
import hashlib, json
from pathlib import Path

base = Path.home() / "CYBRA"
items = {}
for p in base.rglob("*"):
    if ".git" in p.parts or "venv" in p.parts or ".venv" in p.parts:
        continue
    if p.is_file():
        raw = p.read_bytes()
        first = hashlib.sha256(raw).digest()
        items[str(p.relative_to(base))] = hashlib.sha256(first).hexdigest()

(base / "proofs" / "github_double_backend_proof.json").write_text(
    json.dumps(items, ensure_ascii=False, indent=2),
    encoding="utf-8"
)
PY

cat > "$BASE/posts/github_double_backend_status.md" <<'MD'
# CYBRA GitHub Double Backend

Double-SHA proof backend created for repository files.

Files:
- proofs/github_backend_sha256.txt
- proofs/github_double_backend_proof.json
MD

git add proofs posts 2>/dev/null || true
git commit -m "CYBRA GitHub double backend proof" || true

echo "✅ GitHub double backend proof created"
