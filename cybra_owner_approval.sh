#!/data/data/com.termux/files/usr/bin/bash
set -e
cd "$HOME/CYBRA"

mkdir -p posts feeds proofs logs/owner_approval

ACTION="${1:-status}"
TARGET="${2:-general}"
NOTE="${3:-manual owner decision}"

case "$ACTION" in
  approve|reject|hold)
    python3 - <<PY
import json, time, hashlib, subprocess
from pathlib import Path
import redis

ROOT = Path.home() / "CYBRA"
r = redis.Redis(host="127.0.0.1", port=6379, decode_responses=True)

action = "$ACTION"
target = "$TARGET"
note = "$NOTE"

def dsha(x):
    h1 = hashlib.sha256(x.encode("utf-8")).hexdigest()
    return hashlib.sha256(h1.encode("utf-8")).hexdigest()

record = {
    "status": "manual_owner_approval_recorded",
    "owner_role": "MAIN_ORCHESTRATOR",
    "decision": action,
    "target": target,
    "note": note,
    "real_execution_done": False,
    "meaning": "This records OWNER decision only. It does not execute payment, mint, pool, gold conversion or external blockchain tx.",
    "time": time.time(),
    "time_iso": time.strftime("%Y-%m-%dT%H:%M:%S%z")
}

record["double_sha"] = dsha(json.dumps(record, ensure_ascii=False, sort_keys=True))

Path("feeds/owner_manual_approval_latest.json").write_text(json.dumps(record, ensure_ascii=False, indent=2), encoding="utf-8")

Path("posts/owner_manual_approval_latest.md").write_text(
    "# CYBRA Manual OWNER Approval\\n\\n"
    f"Decision: **{action}**\\n\\n"
    f"Target: `{target}`\\n\\n"
    f"Owner role: **MAIN_ORCHESTRATOR**\\n\\n"
    f"Real execution done: **false**\\n\\n"
    f"Note: {note}\\n\\n"
    f"Double SHA: `{record['double_sha']}`\\n",
    encoding="utf-8"
)

with Path("proofs/owner_manual_approval_latest.sha256").open("w") as f:
    subprocess.run(
        ["sha256sum", "feeds/owner_manual_approval_latest.json", "posts/owner_manual_approval_latest.md"],
        cwd=ROOT,
        stdout=f,
        stderr=subprocess.DEVNULL
    )

r.lpush("cybra:owner:manual_approvals", json.dumps(record, ensure_ascii=False))

print("✅ OWNER manual approval recorded")
print("Decision:", action)
print("Target:", target)
print("Real execution done: false")
print("Proof: proofs/owner_manual_approval_latest.sha256")
PY
    ;;

  status)
    redis-cli ping
    echo "OWNER_APPROVALS: $(redis-cli LLEN cybra:owner:manual_approvals)"
    test -f posts/owner_manual_approval_latest.md && cat posts/owner_manual_approval_latest.md || echo "No approval yet"
    ;;

  list)
    redis-cli LRANGE cybra:owner:manual_approvals 0 20
    ;;

  *)
    echo "Usage:"
    echo "  bash cybra_owner_approval.sh approve <target> <note>"
    echo "  bash cybra_owner_approval.sh reject <target> <note>"
    echo "  bash cybra_owner_approval.sh hold <target> <note>"
    echo "  bash cybra_owner_approval.sh status"
    echo "  bash cybra_owner_approval.sh list"
    ;;
esac
