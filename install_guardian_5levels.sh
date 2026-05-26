#!/data/data/com.termux/files/usr/bin/bash
set -e

BASE="$HOME/CYBRA"
mkdir -p "$BASE"/{guardian,proofs,posts,backup_levels,quarantine}

cat > "$BASE/guardian/guardian_5levels.py" <<'PY'
import hashlib, json, shutil, time
from pathlib import Path

BASE = Path.home() / "CYBRA"
GUARDIAN = BASE / "guardian"
PROOFS = BASE / "proofs"
BACKUPS = BASE / "backup_levels"
QUAR = BASE / "quarantine"
POSTS = BASE / "posts"

for d in [GUARDIAN, PROOFS, BACKUPS, QUAR, POSTS]:
    d.mkdir(parents=True, exist_ok=True)

WATCH = [
    "parliament_executor_v2.py",
    "parliament_executor_v3.py",
    "parliament_executor_v4.py",
    "parliament_executor_v5.py",
    "github_double_backend.sh",
    "cybra_autofix.sh",
    "create_native_token_ecosystem.sh",
    "create_pmz_registry.sh",
    "cybra_mining_autofix.sh"
]

def double_sha_bytes(raw: bytes) -> str:
    first = hashlib.sha256(raw).digest()
    return hashlib.sha256(first).hexdigest()

def file_hash(path: Path):
    if not path.exists() or not path.is_file():
        return None
    return double_sha_bytes(path.read_bytes())

def snapshot_level(level: int):
    data = {
        "level": level,
        "time": time.time(),
        "files": {}
    }

    level_dir = BACKUPS / f"level_{level}"
    level_dir.mkdir(parents=True, exist_ok=True)

    for name in WATCH:
        p = BASE / name
        h = file_hash(p)
        data["files"][name] = h

        if p.exists() and p.is_file():
            shutil.copy2(p, level_dir / name)

    proof_file = PROOFS / f"guardian_level_{level}.json"
    proof_file.write_text(json.dumps(data, ensure_ascii=False, indent=2), encoding="utf-8")
    return data

def verify_level(level: int):
    proof_file = PROOFS / f"guardian_level_{level}.json"
    if not proof_file.exists():
        return False, "proof_missing"

    proof = json.loads(proof_file.read_text(encoding="utf-8"))

    for name, old_hash in proof.get("files", {}).items():
        if old_hash is None:
            continue
        now_hash = file_hash(BASE / name)
        if now_hash != old_hash:
            return False, f"hash_mismatch:{name}"

    return True, "ok"

def restore_level(level: int):
    level_dir = BACKUPS / f"level_{level}"
    restored = []

    if not level_dir.exists():
        return restored

    for src in level_dir.glob("*"):
        dst = BASE / src.name
        if dst.exists():
            shutil.copy2(dst, QUAR / f"{src.name}.bad.{int(time.time())}")
        shutil.copy2(src, dst)
        restored.append(src.name)

    return restored

def regenerate_level(level: int):
    return snapshot_level(level)

report = {
    "time": time.time(),
    "mode": "5_level_double_sha_guardian",
    "levels": {}
}

# level 1..5 snapshots
for level in range(1, 6):
    ok, reason = verify_level(level)

    if not ok:
        restored = []
        # higher level restores lower levels
        if level > 1:
            restored = restore_level(level - 1)

        snap = regenerate_level(level)

        report["levels"][level] = {
            "status": "repaired_or_created",
            "reason": reason,
            "restored_from_previous": restored,
            "new_snapshot": snap
        }
    else:
        report["levels"][level] = {
            "status": "ok",
            "reason": reason
        }

# final level restores all previous if needed
final_status = {}
for level in range(1, 6):
    ok, reason = verify_level(level)
    final_status[level] = {"ok": ok, "reason": reason}
    if not ok:
        restore_level(level)
        regenerate_level(level)

report["final_check"] = final_status

(PROOFS / "guardian_5levels_report.json").write_text(
    json.dumps(report, ensure_ascii=False, indent=2),
    encoding="utf-8"
)

(POSTS / "guardian_5levels_status.md").write_text(
    f"""# CYBRA Guardian 5 Levels

Status: completed

Mode:
- Double-SHA
- 5 backend levels
- restore previous levels
- quarantine damaged files
- regenerate missing proofs

Report:
- proofs/guardian_5levels_report.json
""",
    encoding="utf-8"
)

print("✅ Guardian 5 levels completed")
PY

cat > "$BASE/guardian/run_guardian_5levels.sh" <<'BASH'
#!/data/data/com.termux/files/usr/bin/bash
cd "$HOME/CYBRA" || exit 1
python3 guardian/guardian_5levels.py
git add guardian proofs posts backup_levels quarantine 2>/dev/null || true
git commit -m "guardian 5-level double-sha recovery snapshot" || true
BASH

chmod +x "$BASE/guardian/run_guardian_5levels.sh"

cat > "$BASE/posts/guardian_install_status.md" <<'MD'
# CYBRA Guardian Installed

Installed:
- guardian/guardian_5levels.py
- guardian/run_guardian_5levels.sh

Purpose:
- 5-level Double-SHA backend
- restore damaged executor/backend levels
- quarantine corrupted files
- regenerate proofs
MD

git add guardian posts install_guardian_5levels.sh 2>/dev/null || true
git commit -m "install 5-level guardian double-sha backend" || true

echo "✅ Guardian installed"
echo "Run:"
echo "  bash ~/CYBRA/guardian/run_guardian_5levels.sh"
