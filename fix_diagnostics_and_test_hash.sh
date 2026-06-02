#!/data/data/com.termux/files/usr/bin/bash
set -e

cd "$HOME/CYBRA"

echo "=== 1. FIX TASK DIAGNOSTICS ==="

mkdir -p posts feeds proofs logs/hash hash_storage/test

# Оновити діагностику, якщо скрипт є
if [ -f cybra_task_test_diagnostics.sh ]; then
  bash cybra_task_test_diagnostics.sh report || true
else
  echo "⚠ cybra_task_test_diagnostics.sh not found"
fi

# Фіксуємо тільки безпечні файли діагностики
git add \
  cybra_task_test_diagnostics.sh \
  posts/task_diagnostics_report.md \
  feeds/task_diagnostics_report.json \
  proofs/task_diagnostics_report.sha256 2>/dev/null || true

if git diff --cached --quiet; then
  echo "ℹ No new diagnostics changes to commit"
else
  git commit -m "add CYBRA task diagnostics report"
  git push origin main
fi

echo
echo "=== 2. INSTALL HASH MODULE TEST ==="

cat > cybra_hash_module_test.py <<'PY'
#!/usr/bin/env python3
import json
import time
import hashlib
import subprocess
from pathlib import Path

try:
    import redis
except Exception:
    redis = None

ROOT = Path.home() / "CYBRA"

def sha256_text(text: str) -> str:
    return hashlib.sha256(text.encode("utf-8")).hexdigest()

def double_sha_text(text: str) -> str:
    return sha256_text(sha256_text(text))

def sha256_file(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as f:
        for chunk in iter(lambda: f.read(1024 * 1024), b""):
            h.update(chunk)
    return h.hexdigest()

def git_cmd(cmd):
    try:
        return subprocess.check_output(cmd, cwd=ROOT, text=True, stderr=subprocess.DEVNULL).strip()
    except Exception:
        return ""

def file_exists(path):
    return (ROOT / path).exists()

def main():
    (ROOT / "logs/hash").mkdir(parents=True, exist_ok=True)
    (ROOT / "hash_storage/test").mkdir(parents=True, exist_ok=True)
    (ROOT / "posts").mkdir(exist_ok=True)
    (ROOT / "feeds").mkdir(exist_ok=True)
    (ROOT / "proofs").mkdir(exist_ok=True)

    payload = {
        "module": "CYBRA Hash Module Test",
        "status": "testing",
        "time": time.time(),
        "time_iso": time.strftime("%Y-%m-%dT%H:%M:%S%z"),
        "checks": [
            "double_sha_text",
            "manifest_hash",
            "proof_file",
            "hash_storage_write",
            "redis_audit_optional",
            "existing_hash_modules_detection"
        ],
        "git": {
            "branch": git_cmd(["git", "branch", "--show-current"]),
            "commit": git_cmd(["git", "rev-parse", "--short", "HEAD"]),
            "dirty_files": len(git_cmd(["git", "status", "--short"]).splitlines())
        }
    }

    canonical = json.dumps(payload, ensure_ascii=False, sort_keys=True)
    payload_hash = sha256_text(canonical)
    payload_double_sha = double_sha_text(canonical)

    payload["sha256"] = payload_hash
    payload["double_sha"] = payload_double_sha

    payload_file = ROOT / "logs/hash/hash_test_payload.json"
    payload_file.write_text(json.dumps(payload, ensure_ascii=False, indent=2), encoding="utf-8")

    manifest = {
        "name": "CYBRA Hash Module Test Manifest",
        "status": "generated",
        "time": time.time(),
        "payload_file": "logs/hash/hash_test_payload.json",
        "payload_sha256_file": sha256_file(payload_file),
        "payload_double_sha": payload_double_sha,
        "detected_modules": {
            "gitcybrahash_double_backend.mjs": file_exists("gitcybrahash_double_backend.mjs"),
            "hash_memory.py": file_exists("hash_memory.py"),
            "hash_daemon.mjs": file_exists("hash_daemon.mjs"),
            "cybra_sha_core_manager.sh": file_exists("cybra_sha_core_manager.sh"),
            "hash_storage/root_hash.json": file_exists("hash_storage/root_hash.json")
        }
    }

    manifest_base = json.dumps(manifest, ensure_ascii=False, sort_keys=True)
    manifest["root_double_sha"] = double_sha_text(manifest_base)

    manifest_file = ROOT / "hash_storage/test/hash_module_test_manifest.json"
    manifest_file.write_text(json.dumps(manifest, ensure_ascii=False, indent=2), encoding="utf-8")

    feed = {
        "status": "hash_module_test_generated",
        "payload_double_sha": payload_double_sha,
        "root_double_sha": manifest["root_double_sha"],
        "manifest_file": "hash_storage/test/hash_module_test_manifest.json",
        "detected_modules": manifest["detected_modules"],
        "time": time.time()
    }

    feed_file = ROOT / "feeds/hash_module_test.json"
    feed_file.write_text(json.dumps(feed, ensure_ascii=False, indent=2), encoding="utf-8")

    detected_lines = ""
    for k, v in manifest["detected_modules"].items():
        detected_lines += f"- `{k}`: {v}\n"

    md = f"""# CYBRA Hash Module Test

Status: generated

Payload SHA256:
`{payload_hash}`

Payload Double SHA:
`{payload_double_sha}`

Root Double SHA:
`{manifest["root_double_sha"]}`

Manifest:
`hash_storage/test/hash_module_test_manifest.json`

## Detected hash modules

{detected_lines}

## Result

Hash module base pipeline works if:

- payload file exists;
- manifest file exists;
- proof file verifies;
- double SHA is generated;
- root double SHA is generated.
"""

    post_file = ROOT / "posts/hash_module_test.md"
    post_file.write_text(md, encoding="utf-8")

    proof_file = ROOT / "proofs/hash_module_test.sha256"
    with proof_file.open("w") as f:
        subprocess.run(
            [
                "sha256sum",
                "logs/hash/hash_test_payload.json",
                "hash_storage/test/hash_module_test_manifest.json",
                "feeds/hash_module_test.json",
                "posts/hash_module_test.md"
            ],
            cwd=ROOT,
            stdout=f,
            stderr=subprocess.DEVNULL
        )

    redis_status = "not_available"
    if redis is not None:
        try:
            r = redis.Redis(host="127.0.0.1", port=6379, decode_responses=True)
            r.ping()
            r.lpush("cybra:hash:audit", json.dumps({
                "status": "hash_module_test_generated",
                "payload_double_sha": payload_double_sha,
                "root_double_sha": manifest["root_double_sha"],
                "time": time.time()
            }, ensure_ascii=False))
            redis_status = "audit_written"
        except Exception as e:
            redis_status = f"redis_error:{e}"

    print("✅ CYBRA hash module test generated")
    print("Payload Double SHA:", payload_double_sha)
    print("Root Double SHA:", manifest["root_double_sha"])
    print("Redis:", redis_status)
    print("Report: posts/hash_module_test.md")
    print("Feed: feeds/hash_module_test.json")
    print("Proof: proofs/hash_module_test.sha256")

if __name__ == "__main__":
    main()
PY

chmod +x cybra_hash_module_test.py

cat > hash_module_test_handler.sh <<'EOF2'
#!/data/data/com.termux/files/usr/bin/bash
set -e
cd "$HOME/CYBRA"
python3 cybra_hash_module_test.py
EOF2

chmod +x hash_module_test_handler.sh

cat > cybra_hash_test.sh <<'EOF2'
#!/data/data/com.termux/files/usr/bin/bash
set -e
cd "$HOME/CYBRA"

case "${1:-run}" in
  run)
    python3 cybra_hash_module_test.py
    ;;
  task)
    cybra parliament '{"topic":"CYBRA Hash Module Test","type":"hash_module_test_task","priority":"high","payload":{"mode":"double_sha_root_hash_proof_test"}}'
    ;;
  status)
    redis-cli ping
    echo "HASH_AUDIT: $(redis-cli LLEN cybra:hash:audit)"
    test -f posts/hash_module_test.md && echo "REPORT: exists" || echo "REPORT: missing"
    test -f feeds/hash_module_test.json && echo "FEED: exists" || echo "FEED: missing"
    test -f proofs/hash_module_test.sha256 && echo "PROOF: exists" || echo "PROOF: missing"
    ;;
  report)
    cat posts/hash_module_test.md
    ;;
  feed)
    cat feeds/hash_module_test.json
    ;;
  proof)
    cat proofs/hash_module_test.sha256
    ;;
  *)
    echo "Usage: bash cybra_hash_test.sh run|task|status|report|feed|proof"
    ;;
esac
EOF2

chmod +x cybra_hash_test.sh

redis-cli ping >/dev/null 2>&1 || redis-server --daemonize yes
redis-cli HSET cybra:executor:mapping hash_module_test_task hash_module_test_handler.sh >/dev/null

python3 - <<'PY'
from pathlib import Path

p = Path("parliament_executor_v6.py")
if not p.exists():
    raise SystemExit("parliament_executor_v6.py not found")

s = p.read_text()

if 'r.hget("cybra:executor:mapping", task_type)' not in s:
    old = "script_name = SCRIPT_MAP.get(task_type)"
    new = 'script_name = r.hget("cybra:executor:mapping", task_type) or SCRIPT_MAP.get(task_type)'
    if old in s:
        s = s.replace(old, new, 1)

if '"hash_module_test_task"' not in s:
    i = s.find("SCRIPT_MAP")
    j = s.find("{", i)
    if i >= 0 and j >= 0:
        s = s[:j+1] + '\n    "hash_module_test_task": "hash_module_test_handler.sh",' + s[j+1:]

p.write_text(s)
print("✅ hash_module_test_task mapping ready")
PY

rm -rf __pycache__
python3 -m py_compile parliament_executor_v6.py
rm -rf __pycache__

echo
echo "=== 3. RUN HASH TEST DIRECTLY ==="
bash cybra_hash_test.sh run

echo
echo "=== 4. VERIFY HASH PROOF ==="
sha256sum -c proofs/hash_module_test.sha256

echo
echo "=== 5. RUN HASH TEST VIA PARLIAMENT TASK ==="
bash cybra_hash_test.sh task
cybra worker-start || true
sleep 8

echo
echo "=== 6. STATUS ==="
bash cybra_hash_test.sh status
cybra status
cybra results | head -5

echo
echo "=== 7. HASH REPORT ==="
cat posts/hash_module_test.md

echo
echo "=== DONE ==="
echo "Now commit safe hash files with:"
echo "git add cybra_hash_module_test.py hash_module_test_handler.sh cybra_hash_test.sh parliament_executor_v6.py posts/hash_module_test.md feeds/hash_module_test.json proofs/hash_module_test.sha256 hash_storage/test/hash_module_test_manifest.json logs/hash/hash_test_payload.json"
echo "git commit -m 'add CYBRA hash module test'"
echo "git push origin main"
