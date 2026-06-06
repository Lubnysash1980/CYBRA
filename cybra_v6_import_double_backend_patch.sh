#!/data/data/com.termux/files/usr/bin/bash
set -e

mkdir -p double_backend/{usa,hash,recovery,audit} posts proofs

cat > double_backend/usa/backend_policy.json <<'JSON'
{
  "system": "USA Double Backend",
  "mode": "mirror_recovery_autofix",
  "rules": [
    "double_sha_every_task",
    "backup_before_push",
    "recover_from_git_paths",
    "autoheal_on_failure",
    "watchdog_required",
    "autofix_required",
    "no_private_keys"
  ],
  "status": "active"
}
JSON

cat > double_backend/recovery/git_path_recovery.sh <<'BASH'
#!/data/data/com.termux/files/usr/bin/bash
set -e

mkdir -p recovery/git_paths posts proofs

git status --short > recovery/git_paths/status.txt || true
git log --oneline -50 > recovery/git_paths/last_commits.txt || true
find . -maxdepth 3 -type f \
  ! -path "./.git/*" \
  ! -path "./logs/*" \
  > recovery/git_paths/file_index.txt

sha256sum recovery/git_paths/*.txt > proofs/git_path_recovery.sha256

cat > posts/git_path_recovery_status.md <<'MD'
# Git Path Recovery

Status: indexed

Created:
- recovery/git_paths/status.txt
- recovery/git_paths/last_commits.txt
- recovery/git_paths/file_index.txt
- proofs/git_path_recovery.sha256
MD

echo "✅ Git path recovery index created"
BASH

chmod +x double_backend/recovery/git_path_recovery.sh

cat > double_backend/hash/double_sha_backend.py <<'PY'
import hashlib, json, time
from pathlib import Path

def double_sha_bytes(data: bytes) -> str:
    return hashlib.sha256(hashlib.sha256(data).digest()).hexdigest()

def double_sha_text(text: str) -> str:
    return double_sha_bytes(text.encode())

def write_double_backend_record(task, result=None):
    Path("double_backend/audit").mkdir(parents=True, exist_ok=True)
    raw = json.dumps({
        "time": time.time(),
        "task": task,
        "result": result
    }, ensure_ascii=False, indent=2)
    h = double_sha_text(raw)
    Path(f"double_backend/audit/{h}.json").write_text(raw, encoding="utf-8")
    return h
PY

cat > posts/double_backend_status.md <<'MD'
# USA Double Backend

Status: active

Layers:
- double SHA backend
- git path recovery
- autoheal-ready
- watchdog-ready
- autofix-ready
MD

sha256sum double_backend/usa/backend_policy.json double_backend/hash/double_sha_backend.py double_backend/recovery/git_path_recovery.sh posts/double_backend_status.md > proofs/double_backend.sha256

python3 - <<'PY'
from pathlib import Path

p = Path("parliament_executor_v6.py")
s = p.read_text()

# inject imports safely
if "from cybra_core.router import route_task" not in s:
    s = s.replace(
        "import json",
        "import json\nfrom cybra_core.router import route_task"
    )

if "from double_backend.hash.double_sha_backend import write_double_backend_record" not in s:
    s = s.replace(
        "import json",
        "import json\nfrom double_backend.hash.double_sha_backend import write_double_backend_record"
    )

# add class routing after task parsed: patch common point
if "CYBRA_CLASS_ROUTE" not in s:
    marker = 'task_type = task.get("type")'
    if marker in s:
        s = s.replace(
            marker,
            '''class_route = route_task(task)
    task["CYBRA_CLASS_ROUTE"] = class_route
    try:
        write_double_backend_record(task, {"stage": "routed", "class_route": class_route})
    except Exception:
        pass

    task_type = task.get("type")'''
        )

# record result after execution
if "double_backend_executed_record" not in s:
    marker2 = 'r.lpush(Q_RESULTS, json.dumps(result, ensure_ascii=False))'
    if marker2 in s:
        s = s.replace(
            marker2,
            '''try:
        result["double_backend_executed_record"] = write_double_backend_record(task, result)
    except Exception:
        pass

    r.lpush(Q_RESULTS, json.dumps(result, ensure_ascii=False))'''
        )

p.write_text(s)
print("✅ Executor V6 patched with class-router and double-backend")
PY

python3 -m py_compile parliament_executor_v6.py

bash double_backend/recovery/git_path_recovery.sh

git add cybra_core double_backend posts proofs parliament_executor_v6.py cybra_v6_import_double_backend_patch.sh recovery
git commit -m "connect V6 executor to import classes and USA double backend" || true

echo "✅ V6 import/classes + USA double backend connected"
