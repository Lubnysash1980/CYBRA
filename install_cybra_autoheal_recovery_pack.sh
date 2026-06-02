#!/data/data/com.termux/files/usr/bin/bash
set -e

cd "$HOME/CYBRA"

echo "=== CYBRA AUTOHEAL RECOVERY PACK INSTALL ==="

mkdir -p recovery_packs recovery_unpack posts feeds proofs docs/recovery logs/recovery runtime

touch .gitignore
for item in \
  "recovery_packs/" \
  "recovery_unpack/" \
  "private_vault/" \
  "dump.rdb" \
  "__pycache__/" \
  "ai_network/" \
  "token/runtime/rpc.env" \
  "*.pem" \
  "*.key" \
  "*secret*" \
  "mint_secret_base58.txt"
do
  grep -qxF "$item" .gitignore || echo "$item" >> .gitignore
done

cat > cybra_autoheal_recovery_pack.sh <<'BASH'
#!/data/data/com.termux/files/usr/bin/bash
set -e

cd "$HOME/CYBRA"

CMD="${1:-status}"
shift || true

mkdir -p recovery_packs recovery_unpack posts feeds proofs docs/recovery logs/recovery runtime

case "$CMD" in
  pack)
    python3 - <<'PY'
import io
import json
import time
import tarfile
import hashlib
import subprocess
from pathlib import Path

ROOT = Path.home() / "CYBRA"
PACK_DIR = ROOT / "recovery_packs"
POSTS = ROOT / "posts"
FEEDS = ROOT / "feeds"
PROOFS = ROOT / "proofs"
DOCS = ROOT / "docs" / "recovery"

EXCLUDES = [
    ".git",
    "node_modules",
    "ai_network",
    "recovery_packs",
    "recovery_unpack",
    "private_vault",
    "__pycache__",
    "dump.rdb",
    "token/runtime/rpc.env",
    ".venv",
    "venv",
    "mint_secret_base58.txt"
]

SECRET_PATTERNS = [
    ".pem",
    ".key",
    "secret",
    "seed",
    "private"
]

def sha256_file(p: Path) -> str:
    h = hashlib.sha256()
    with p.open("rb") as f:
        for chunk in iter(lambda: f.read(1024 * 1024), b""):
            h.update(chunk)
    return h.hexdigest()

def double_sha_text(text: str) -> str:
    h1 = hashlib.sha256(text.encode("utf-8")).hexdigest()
    return hashlib.sha256(h1.encode("utf-8")).hexdigest()

def excluded(rel: Path) -> bool:
    s = rel.as_posix()
    low = s.lower()

    for ex in EXCLUDES:
        if s == ex or s.startswith(ex + "/"):
            return True

    for pat in SECRET_PATTERNS:
        if pat in low:
            return True

    return False

def git_cmd(cmd):
    try:
        return subprocess.check_output(
            cmd,
            cwd=ROOT,
            text=True,
            stderr=subprocess.DEVNULL
        ).strip()
    except Exception:
        return ""

ts = time.strftime("%Y%m%d_%H%M%S")
capsule_id = f"CYBRA_RECOVERY_{ts}"

archive = PACK_DIR / f"{capsule_id}.tar.gz"
manifest_path = Path(str(archive) + ".manifest.json")

files = []

for p in ROOT.rglob("*"):
    if not p.is_file():
        continue

    rel = p.relative_to(ROOT)

    if excluded(rel):
        continue

    files.append(rel)

files = sorted(files, key=lambda x: x.as_posix())

with tarfile.open(archive, "w:gz") as tar:
    note = (
        "CYBRA AUTOHEAL RECOVERY CAPSULE\n"
        "Archive is verified by manifest, archive SHA256 and root double SHA.\n"
        "Secrets, private_vault, ai_network, node_modules and runtime files are excluded.\n"
    ).encode("utf-8")

    info = tarfile.TarInfo("CYBRA_RECOVERY_README.txt")
    info.size = len(note)
    info.mtime = int(time.time())
    tar.addfile(info, io.BytesIO(note))

    for rel in files:
        tar.add(
            ROOT / rel,
            arcname=f"CYBRA/{rel.as_posix()}",
            recursive=False
        )

file_records = []

for rel in files:
    p = ROOT / rel
    try:
        file_records.append({
            "path": rel.as_posix(),
            "size": p.stat().st_size,
            "sha256": sha256_file(p)
        })
    except Exception as e:
        file_records.append({
            "path": rel.as_posix(),
            "error": str(e)
        })

archive_sha = sha256_file(archive)

manifest = {
    "capsule_id": capsule_id,
    "status": "packed",
    "time": time.time(),
    "archive": str(archive),
    "archive_name": archive.name,
    "manifest_name": manifest_path.name,
    "archive_sha256": archive_sha,
    "mode": "autoheal_recovery_capsule",
    "root_hash_meaning": "root_double_sha256 verifies manifest + archive hash; the hash is proof, not the data itself",
    "git": {
        "branch": git_cmd(["git", "branch", "--show-current"]),
        "commit": git_cmd(["git", "rev-parse", "--short", "HEAD"]),
        "dirty_files": len(git_cmd(["git", "status", "--short"]).splitlines())
    },
    "excluded": EXCLUDES,
    "secret_patterns_excluded": SECRET_PATTERNS,
    "files_count": len(file_records),
    "files": file_records
}

root_base = json.dumps(manifest, ensure_ascii=False, sort_keys=True)
manifest["root_double_sha256"] = double_sha_text(root_base)

manifest_path.write_text(
    json.dumps(manifest, ensure_ascii=False, indent=2),
    encoding="utf-8"
)

(PACK_DIR / "latest.root.hash").write_text(
    manifest["root_double_sha256"] + "\n",
    encoding="utf-8"
)

(PACK_DIR / "latest.archive.sha256").write_text(
    f"{archive_sha}  {archive.name}\n",
    encoding="utf-8"
)

(FEEDS / "autoheal_recovery_latest.json").write_text(
    json.dumps(manifest, ensure_ascii=False, indent=2),
    encoding="utf-8"
)

(POSTS / "autoheal_recovery_status.md").write_text(f"""# CYBRA AutoHeal Recovery Capsule

Status: packed

Capsule ID:
`{capsule_id}`

Archive:
`{archive}`

Manifest:
`{manifest_path}`

Archive SHA256:
`{archive_sha}`

Root Double SHA:
`{manifest["root_double_sha256"]}`

Files packed:
{len(file_records)}

## Meaning

Архів `.tar.gz` містить файли CYBRA.

Root Double SHA — це контрольна печатка.  
Сам hash не містить файли.  
Для відновлення потрібні архів і manifest.

## Restore commands

Verify:

    bash cybra_autoheal_recovery_pack.sh verify {archive}

Unpack:

    bash cybra_autoheal_recovery_pack.sh unpack {archive}

## Excluded from capsule

- private_vault
- dump.rdb
- ai_network
- node_modules
- recovery_packs
- recovery_unpack
- token/runtime/rpc.env
- secrets / keys
""", encoding="utf-8")

(DOCS / "index.html").write_text(f"""<!doctype html>
<html>
<head>
<meta charset="utf-8">
<title>CYBRA Recovery Capsule</title>
</head>
<body>
<h1>CYBRA AutoHeal Recovery Capsule</h1>
<p>Status: packed</p>
<p>Capsule ID: <code>{capsule_id}</code></p>
<p>Archive SHA256: <code>{archive_sha}</code></p>
<p>Root Double SHA: <code>{manifest["root_double_sha256"]}</code></p>
<p>Files packed: {len(file_records)}</p>
<p>This page stores recovery proof, not private secrets.</p>
</body>
</html>
""", encoding="utf-8")

with (PROOFS / "autoheal_recovery.sha256").open("w") as f:
    subprocess.run(
        [
            "sha256sum",
            str(manifest_path.relative_to(ROOT)),
            "feeds/autoheal_recovery_latest.json",
            "posts/autoheal_recovery_status.md",
            "docs/recovery/index.html"
        ],
        cwd=ROOT,
        stdout=f,
        stderr=subprocess.DEVNULL
    )

print("✅ CYBRA recovery capsule packed")
print("Archive:", archive)
print("Manifest:", manifest_path)
print("Root Double SHA:", manifest["root_double_sha256"])
print("Archive SHA256:", archive_sha)
PY
    ;;

  verify)
    ARCHIVE="${1:-}"

    if [ -z "$ARCHIVE" ]; then
      echo "Usage: bash cybra_autoheal_recovery_pack.sh verify <archive.tar.gz>"
      exit 1
    fi

    python3 - "$ARCHIVE" <<'PY'
import sys
import json
import hashlib
from pathlib import Path

archive = Path(sys.argv[1]).expanduser()
manifest = Path(str(archive) + ".manifest.json")

def sha256_file(p: Path) -> str:
    h = hashlib.sha256()
    with p.open("rb") as f:
        for chunk in iter(lambda: f.read(1024 * 1024), b""):
            h.update(chunk)
    return h.hexdigest()

if not archive.exists():
    raise SystemExit(f"❌ archive not found: {archive}")

archive_sha = sha256_file(archive)

print("Archive:", archive)
print("Archive SHA256:", archive_sha)

if manifest.exists():
    data = json.loads(manifest.read_text())
    expected = data.get("archive_sha256")
    root = data.get("root_double_sha256")

    print("Expected SHA256:", expected)
    print("Root Double SHA:", root)

    if expected == archive_sha:
        print("✅ VERIFY OK")
    else:
        print("❌ VERIFY FAILED")
        raise SystemExit(1)
else:
    print("⚠ manifest not found, archive hash only verified")
PY
    ;;

  unpack)
    ARCHIVE="${1:-}"

    if [ -z "$ARCHIVE" ]; then
      echo "Usage: bash cybra_autoheal_recovery_pack.sh unpack <archive.tar.gz>"
      exit 1
    fi

    python3 - "$ARCHIVE" <<'PY'
import sys
import time
import tarfile
from pathlib import Path

archive = Path(sys.argv[1]).expanduser()
root = Path.home() / "CYBRA"
dest = root / "recovery_unpack" / f"restore_{time.strftime('%Y%m%d_%H%M%S')}"

if not archive.exists():
    raise SystemExit(f"❌ archive not found: {archive}")

dest.mkdir(parents=True, exist_ok=True)

def safe_extract(tar, path: Path):
    base = path.resolve()

    for member in tar.getmembers():
        target = (path / member.name).resolve()

        if not str(target).startswith(str(base)):
            print("SKIP unsafe path:", member.name)
            continue

        tar.extract(member, path)

with tarfile.open(archive, "r:gz") as tar:
    safe_extract(tar, dest)

print("✅ unpacked to:", dest)
print("To inspect:")
print("ls -lah", dest)
PY
    ;;

  latest)
    cat recovery_packs/latest.root.hash 2>/dev/null || echo "no latest root hash"
    ;;

  web)
    cat docs/recovery/index.html
    ;;

  serve)
    PORT="${1:-8787}"
    echo "Serving CYBRA recovery web on http://127.0.0.1:$PORT/"
    echo "Open: http://127.0.0.1:$PORT/docs/recovery/"
    python3 -m http.server "$PORT" --directory "$HOME/CYBRA"
    ;;

  auto)
    INTERVAL="${1:-1800}"
    echo "=== CYBRA RECOVERY AUTO PACK LOOP STARTED interval=$INTERVAL ==="

    while true; do
      bash "$HOME/CYBRA/cybra_autoheal_recovery_pack.sh" pack >> "$HOME/CYBRA/logs/recovery/auto_pack.log" 2>&1 || true
      sleep "$INTERVAL"
    done
    ;;

  start-auto)
    INTERVAL="${1:-1800}"
    pkill -f "cybra_autoheal_recovery_pack.sh auto" 2>/dev/null || true
    nohup bash "$HOME/CYBRA/cybra_autoheal_recovery_pack.sh" auto "$INTERVAL" > "$HOME/CYBRA/logs/recovery/auto_loop.log" 2>&1 &
    echo $! > runtime/recovery_auto.pid
    echo "✅ recovery auto pack started"
    ;;

  stop-auto)
    pkill -f "cybra_autoheal_recovery_pack.sh auto" 2>/dev/null || true
    rm -f runtime/recovery_auto.pid
    echo "✅ recovery auto pack stopped"
    ;;

  status)
    echo "=== CYBRA AUTOHEAL RECOVERY STATUS ==="

    echo "Latest root hash:"
    cat recovery_packs/latest.root.hash 2>/dev/null || echo "missing"

    echo
    echo "Latest archive sha:"
    cat recovery_packs/latest.archive.sha256 2>/dev/null || echo "missing"

    echo
    echo "Archives:"
    ls -lh recovery_packs/*.tar.gz 2>/dev/null | tail -5 || true

    echo
    pgrep -af "cybra_autoheal_recovery_pack.sh auto" || echo "AUTO_LOOP: not running"

    test -f posts/autoheal_recovery_status.md && echo "REPORT: exists" || echo "REPORT: missing"
    test -f docs/recovery/index.html && echo "WEB_INDEX: exists" || echo "WEB_INDEX: missing"
    ;;

  *)
    echo "Usage:"
    echo "  bash cybra_autoheal_recovery_pack.sh pack"
    echo "  bash cybra_autoheal_recovery_pack.sh verify <archive.tar.gz>"
    echo "  bash cybra_autoheal_recovery_pack.sh unpack <archive.tar.gz>"
    echo "  bash cybra_autoheal_recovery_pack.sh latest"
    echo "  bash cybra_autoheal_recovery_pack.sh web"
    echo "  bash cybra_autoheal_recovery_pack.sh serve [port]"
    echo "  bash cybra_autoheal_recovery_pack.sh start-auto [seconds]"
    echo "  bash cybra_autoheal_recovery_pack.sh stop-auto"
    echo "  bash cybra_autoheal_recovery_pack.sh status"
    ;;
esac
BASH

chmod +x cybra_autoheal_recovery_pack.sh

cat > cybra_recovery_watchdog.sh <<'WATCHDOG'
#!/data/data/com.termux/files/usr/bin/bash
set -e

cd "$HOME/CYBRA"

mkdir -p logs/recovery runtime

INTERVAL="${1:-1800}"

while true; do
  if ! pgrep -f "cybra_autoheal_recovery_pack.sh auto" >/dev/null; then
    echo "$(date -Iseconds) restarting recovery auto pack" >> logs/recovery/watchdog.log
    nohup bash "$HOME/CYBRA/cybra_autoheal_recovery_pack.sh" auto "$INTERVAL" > logs/recovery/auto_loop.log 2>&1 &
    echo $! > runtime/recovery_auto.pid
  fi

  sleep 60
done
WATCHDOG

chmod +x cybra_recovery_watchdog.sh

cat > cybra_recovery.sh <<'CLI'
#!/data/data/com.termux/files/usr/bin/bash
set -e

cd "$HOME/CYBRA"

CMD="${1:-status}"
ARG="${2:-}"

case "$CMD" in
  pack)
    bash cybra_autoheal_recovery_pack.sh pack
    ;;
  verify)
    bash cybra_autoheal_recovery_pack.sh verify "$ARG"
    ;;
  unpack)
    bash cybra_autoheal_recovery_pack.sh unpack "$ARG"
    ;;
  auto)
    bash cybra_autoheal_recovery_pack.sh start-auto "${ARG:-1800}"
    ;;
  stop)
    bash cybra_autoheal_recovery_pack.sh stop-auto
    ;;
  watchdog)
    pkill -f cybra_recovery_watchdog.sh 2>/dev/null || true
    nohup bash cybra_recovery_watchdog.sh "${ARG:-1800}" > logs/recovery/watchdog_loop.log 2>&1 &
    echo "✅ recovery watchdog started"
    ;;
  serve)
    bash cybra_autoheal_recovery_pack.sh serve "${ARG:-8787}"
    ;;
  status)
    bash cybra_autoheal_recovery_pack.sh status
    ;;
  report)
    cat posts/autoheal_recovery_status.md
    ;;
  web)
    cat docs/recovery/index.html
    ;;
  *)
    echo "Usage: bash cybra_recovery.sh pack|verify|unpack|auto|stop|watchdog|serve|status|report|web"
    ;;
esac
CLI

chmod +x cybra_recovery.sh

bash cybra_autoheal_recovery_pack.sh pack

sha256sum \
  install_cybra_autoheal_recovery_pack.sh \
  cybra_autoheal_recovery_pack.sh \
  cybra_recovery_watchdog.sh \
  cybra_recovery.sh \
  feeds/autoheal_recovery_latest.json \
  posts/autoheal_recovery_status.md \
  docs/recovery/index.html \
  > proofs/autoheal_recovery_install.sha256

echo
echo "=== RECOVERY STATUS ==="
bash cybra_recovery.sh status

echo
echo "=== AUTOHEAL RECOVERY INSTALL DONE ==="
echo "Start auto pack:"
echo "bash cybra_recovery.sh auto 1800"
echo
echo "Start watchdog:"
echo "bash cybra_recovery.sh watchdog 1800"
echo
echo "Serve web recovery:"
echo "bash cybra_recovery.sh serve 8787"
