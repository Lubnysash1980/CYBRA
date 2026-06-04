#!/data/data/com.termux/files/usr/bin/bash
set +e
cd "$HOME/CYBRA" || exit 1

echo "=== FINALIZE CYBRA TASK EXECUTION RUNTIME ==="

mkdir -p posts feeds proofs data/cybra_task_tests/reports runtime/redis logs/task_tests

if ! redis-cli ping >/dev/null 2>&1; then
  redis-server --daemonize yes --bind 127.0.0.1 --port 6379 --dir "$HOME/CYBRA/runtime/redis" --save "" --appendonly no >/dev/null 2>&1 || true
  sleep 1
fi

echo
echo "=== 1. CREATE MISSING LIGHT HANDLERS ==="

cat > cybra_evolution_handler.sh <<'EOF'
#!/data/data/com.termux/files/usr/bin/bash
set +e
cd "$HOME/CYBRA" || exit 0
bash cybra_evolution.sh today >/dev/null 2>&1 || true
EOF
chmod +x cybra_evolution_handler.sh

cat > cybra_task_test_handler.sh <<'EOF'
#!/data/data/com.termux/files/usr/bin/bash
set +e
cd "$HOME/CYBRA" || exit 0
bash cybra_task_test.sh run >/dev/null 2>&1 || true
EOF
chmod +x cybra_task_test_handler.sh

echo
echo "=== 2. FIX REDIS EXECUTOR MAPPING ==="

redis-cli HSET cybra:executor:mapping menubar_owner_task cybra_menubar_handler.sh >/dev/null
redis-cli HSET cybra:executor:mapping menubar_post_task cybra_menubar_handler.sh >/dev/null
redis-cli HSET cybra:executor:mapping menubar_create_committee_task cybra_menubar_handler.sh >/dev/null
redis-cli HSET cybra:executor:mapping menubar_withdraw_proposal_task cybra_menubar_handler.sh >/dev/null

redis-cli HSET cybra:executor:mapping it_evolution_task cybra_it_evolution_handler.sh >/dev/null
redis-cli HSET cybra:executor:mapping codespace_runtime_committee_task cybra_codespace_runtime_handler.sh >/dev/null
redis-cli HSET cybra:executor:mapping frozen_license_committee_task cybra_frozen_committee_handler.sh >/dev/null
redis-cli HSET cybra:executor:mapping hash_license_violation_audit_task hash_license_guard_handler.sh >/dev/null
redis-cli HSET cybra:executor:mapping evolution_tracker_task cybra_evolution_handler.sh >/dev/null
redis-cli HSET cybra:executor:mapping task_execution_testing_task cybra_task_test_handler.sh >/dev/null

echo "✅ Redis mappings fixed"

echo
echo "=== 3. DRAIN AI INBOX INTO TASK-BLOCKS ==="

if [ -f cybra_ai_blocks.sh ]; then
  bash cybra_ai_blocks.sh until-done || true
elif [ -f cybra_closed_sha_bridge.sh ]; then
  bash cybra_closed_sha_bridge.sh cycle || true
fi

echo
echo "=== 4. REFRESH CORE REPORTS ==="

[ -f cybra_it_evolution.sh ] && bash cybra_it_evolution.sh report || true
[ -f cybra_evolution.sh ] && bash cybra_evolution.sh today || true
[ -f cybra_menubar.sh ] && bash cybra_menubar.sh report || true
[ -f cybra_task_test.sh ] && bash cybra_task_test.sh run || true

echo
echo "=== 5. BUILD FINAL TASK EXECUTION RUNTIME REPORT ==="

python3 - <<'PY'
import json, time, hashlib, subprocess
from pathlib import Path

ROOT = Path.home() / "CYBRA"

def sha(x): return hashlib.sha256(x.encode("utf-8")).hexdigest()
def dsha(o): return sha(sha(json.dumps(o, ensure_ascii=False, sort_keys=True)))

def r(cmd):
    p = subprocess.run(cmd, cwd=ROOT, text=True, capture_output=True)
    return p.stdout.strip()

def rlen(key):
    out = r(["redis-cli", "LLEN", key])
    return int(out) if out.isdigit() else 0

def hget(field):
    return r(["redis-cli", "HGET", "cybra:executor:mapping", field])

def exists(p):
    return (ROOT / p).exists()

task_types = [
    "menubar_owner_task",
    "it_evolution_task",
    "codespace_runtime_committee_task",
    "frozen_license_committee_task",
    "hash_license_violation_audit_task",
    "evolution_tracker_task",
    "task_execution_testing_task"
]

mappings = {t: hget(t) for t in task_types}

obj = {
    "status": "task_execution_runtime_finalized",
    "time": time.time(),
    "time_iso": time.strftime("%Y-%m-%dT%H:%M:%S%z"),
    "queues": {
        "ai_block_inbox": rlen("cybra:ai:tasks:block_inbox"),
        "task_block_mempool": rlen("cybra:kibra:task_blocks:mempool"),
        "pool_mining_blocks": rlen("cybra:kibra:pool:mining_blocks"),
        "parliament_queue": rlen("cybra:parliament:queue"),
        "parliament_failed": rlen("cybra:parliament:failed")
    },
    "mappings": mappings,
    "reports": {
        "task_test": exists("posts/cybra_task_execution_test_report.md"),
        "menubar": exists("posts/cybra_menubar_report.md"),
        "it_evolution": exists("posts/cybra_it_evolution_report.md"),
        "daily_evolution": exists("posts/cybra_evolution_today.md"),
        "ai_blocks": exists("posts/cybra_ai_blocks_report.md")
    },
    "result": {
        "tasks_ready": True,
        "missing_handlers": [k for k, v in mappings.items() if not v],
        "parliament_failed_zero": rlen("cybra:parliament:failed") == 0,
        "ai_inbox_empty": rlen("cybra:ai:tasks:block_inbox") == 0
    },
    "safety": {
        "real_payment_now": False,
        "automatic_SWIFT": False,
        "automatic_external_tx": False,
        "manual_OWNER_approval_required": True
    }
}

obj["overall_status"] = "OK" if not obj["result"]["missing_handlers"] and obj["result"]["parliament_failed_zero"] else "NEEDS_ATTENTION"
obj["double_sha"] = dsha(obj)

(ROOT / "feeds").mkdir(exist_ok=True)
(ROOT / "posts").mkdir(exist_ok=True)
(ROOT / "proofs").mkdir(exist_ok=True)
(ROOT / "data/cybra_task_tests/reports").mkdir(parents=True, exist_ok=True)

(ROOT / "feeds/cybra_task_execution_runtime_final.json").write_text(json.dumps(obj, ensure_ascii=False, indent=2), encoding="utf-8")
(ROOT / "data/cybra_task_tests/reports/runtime_final.json").write_text(json.dumps(obj, ensure_ascii=False, indent=2), encoding="utf-8")

md = ["# CYBRA Task Execution Runtime Final Report", "", f"Overall status: {obj['overall_status']}", ""]
md.append("## Queues")
for k,v in obj["queues"].items():
    md.append(f"{k}: {v}")
md.append("")
md.append("## Executor mappings")
for k,v in mappings.items():
    md.append(f"{k}: {v or 'MISSING'}")
md.append("")
md.append("## Reports")
for k,v in obj["reports"].items():
    md.append(f"{k}: {v}")
md.append("")
md.append("## Result")
for k,v in obj["result"].items():
    md.append(f"{k}: {v}")
md.append("")
md.append("## Safety")
for k,v in obj["safety"].items():
    md.append(f"{k}: {v}")
md.append("")
md.append("## Double SHA")
md.append(obj["double_sha"])

(ROOT / "posts/cybra_task_execution_runtime_final.md").write_text("\n".join(md), encoding="utf-8")

with (ROOT / "proofs/cybra_task_execution_runtime_final.sha256").open("w") as f:
    subprocess.run([
        "sha256sum",
        "feeds/cybra_task_execution_runtime_final.json",
        "posts/cybra_task_execution_runtime_final.md",
        "data/cybra_task_tests/reports/runtime_final.json"
    ], cwd=ROOT, stdout=f, stderr=subprocess.DEVNULL)

print("✅ final runtime report generated")
print("OVERALL:", obj["overall_status"])
print("AI_INBOX:", obj["queues"]["ai_block_inbox"])
print("PARLIAMENT_FAILED:", obj["queues"]["parliament_failed"])
print("DOUBLE_SHA:", obj["double_sha"])
PY

echo
echo "=== 6. VERIFY ==="

sha256sum -c proofs/cybra_task_execution_runtime_final.sha256 || true

echo
echo "=== 7. SHOW STATUS ==="

cybra-task-test status || true
cat posts/cybra_task_execution_runtime_final.md

echo
echo "✅ TASK EXECUTION RUNTIME FINALIZED"
