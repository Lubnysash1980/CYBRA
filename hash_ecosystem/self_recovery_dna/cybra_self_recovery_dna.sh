#!/data/data/com.termux/files/usr/bin/bash
set -Eeuo pipefail

ROOT="$HOME/CYBRA"
ORDER="ROBOTICS-UA-0001"
BASE="$ROOT/orders/$ORDER"
DNA="$ROOT/hash_ecosystem/self_recovery_dna"
STATE="$BASE/control"
EVIDENCE="$BASE/evidence"
SNAP="$BASE/runtime_snapshot"
RUNTIME="$ROOT/runtime"

mkdir -p "$DNA" "$STATE" "$EVIDENCE" "$SNAP" "$RUNTIME"

LOCK="$DNA/.lock"

if ! mkdir "$LOCK" 2>/dev/null; then
    echo "SELF_RECOVERY=ALREADY_RUNNING"
    exit 0
fi
trap 'rmdir "$LOCK" 2>/dev/null || true' EXIT

NOW="$(date -u +%Y%m%dT%H%M%SZ)"
ISO="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

STATUS="PASS"
CAUSE="SELF_CHECK_STARTED"

# ------------------------------------------------------------
# SAFE TOKEN CHECK
# ------------------------------------------------------------

TOKEN_FILE="$DNA/.recovery_token"

if [ ! -s "$TOKEN_FILE" ]; then
    echo "[REPAIR] recovery token missing"

    python3 - <<'PY' > "$TOKEN_FILE"
import secrets
print(secrets.token_hex(64))
PY

    chmod 600 "$TOKEN_FILE"
fi

TOKEN_SHA="$(sha256sum "$TOKEN_FILE" | awk '{print $1}')"

# ------------------------------------------------------------
# REDIS SELF-HEAL
# ------------------------------------------------------------

REDIS_STATUS="UNKNOWN"

if command -v redis-cli >/dev/null 2>&1; then
    if redis-cli -h 127.0.0.1 -p 6379 PING 2>/dev/null | grep -qx "PONG"; then
        REDIS_STATUS="PASS"
    else
        echo "[REPAIR] Redis unavailable"

        if command -v redis-server >/dev/null 2>&1; then
            redis-server \
              --bind 127.0.0.1 \
              --port 6379 \
              --daemonize yes \
              >/dev/null 2>&1 || true

            sleep 1
        fi

        if redis-cli -h 127.0.0.1 -p 6379 PING 2>/dev/null | grep -qx "PONG"; then
            REDIS_STATUS="RECOVERED"
        else
            REDIS_STATUS="FAIL"
        fi
    fi
else
    REDIS_STATUS="NOT_INSTALLED"
fi

# ------------------------------------------------------------
# CYBRA IMPORT
# ------------------------------------------------------------

CYBRA_IMPORT="FAIL"

if [ -f "$ROOT/cybra_env.sh" ]; then
    # shellcheck disable=SC1091
    source "$ROOT/cybra_env.sh"
fi

if PYTHONPATH="$ROOT/cybra_project${PYTHONPATH:+:$PYTHONPATH}" \
   python3 - <<'PY' >/dev/null 2>&1
import cybra
PY
then
    CYBRA_IMPORT="PASS"
fi

# ------------------------------------------------------------
# REQUIRED CORE FILES
# ------------------------------------------------------------

CORE_OK="PASS"

for f in \
    "$ROOT/cybra_ai_master_orchestrator.py" \
    "$ROOT/robotics_ai_execute_verify_patch.sh" \
    "$ROOT/robotics_verify_now.sh"
do
    if [ ! -f "$f" ]; then
        CORE_OK="FAIL"
    fi
done

# ------------------------------------------------------------
# BACKEND A / B DETECTION
# ------------------------------------------------------------

BACKEND_A="NOT_FOUND"
BACKEND_B="NOT_FOUND"

for f in \
    "$ROOT/app/main.py" \
    "$ROOT/CYBRA/app/main.py" \
    "$ROOT/backend.py" \
    "$ROOT/server.py"
do
    if [ -f "$f" ]; then
        BACKEND_A="$f"
        break
    fi
done

for f in \
    "$ROOT/backend_b.py" \
    "$ROOT/app/backend_b.py" \
    "$ROOT/CYBRA/app/backend_b.py" \
    "$ROOT/backend_secondary.py"
do
    if [ -f "$f" ]; then
        BACKEND_B="$f"
        break
    fi
done

# ------------------------------------------------------------
# ORACLE DETECTION
# ------------------------------------------------------------

ORACLE="NOT_FOUND"

for f in \
    "$ROOT/scripts/live/oracle_germany_live.py" \
    "$ROOT/oracle_germany_live.py"
do
    if [ -f "$f" ]; then
        ORACLE="$f"
        break
    fi
done

# ------------------------------------------------------------
# PARLIAMENT DETECTION
# ------------------------------------------------------------

PARLIAMENT="NOT_FOUND"

for f in \
    "$ROOT/parliament_executor_v6.py" \
    "$ROOT/CYBRA/core/committee.py" \
    "$ROOT/CYBRA/app/main.py"
do
    if [ -f "$f" ]; then
        PARLIAMENT="$f"
        break
    fi
done

# ------------------------------------------------------------
# WATCHDOG STATE
# ------------------------------------------------------------

cat > "$STATE/self_recovery_watchdog.json" <<JSON
{
  "timestamp": "$ISO",
  "status": "$STATUS",
  "redis": "$REDIS_STATUS",
  "cybra_import": "$CYBRA_IMPORT",
  "core_files": "$CORE_OK",
  "backend_a": "$BACKEND_A",
  "backend_b": "$BACKEND_B",
  "oracle": "$ORACLE",
  "parliament": "$PARLIAMENT",
  "recovery_token_sha256": "$TOKEN_SHA",
  "physical_manufacturing": false,
  "manufacturing_execution_enabled": false
}
JSON

# ------------------------------------------------------------
# SELF-REPAIR WHEN CORE IS BROKEN
# ------------------------------------------------------------

if [ "$REDIS_STATUS" = "FAIL" ] || [ "$CYBRA_IMPORT" = "FAIL" ] || [ "$CORE_OK" = "FAIL" ]; then

    echo "[REPAIR] invoking CYBRA repair engine"

    if [ -f "$ROOT/cybra_ai_master_orchestrator.py" ]; then
        python3 "$ROOT/cybra_ai_master_orchestrator.py" "$ORDER" \
            >/dev/null 2>&1 || true
    fi

    if [ -f "$ROOT/robotics_ai_execute_verify_patch.sh" ]; then
        bash "$ROOT/robotics_ai_execute_verify_patch.sh" \
            >/dev/null 2>&1 || true
    fi
fi

# ------------------------------------------------------------
# SOFTWARE EXECUTION RECEIPT
# ------------------------------------------------------------

RECEIPT="$BASE/live/logs/execution_receipt.json"

EXECUTION_OK="false"

if [ -f "$RECEIPT" ]; then
    if python3 - "$RECEIPT" <<'PY' >/dev/null 2>&1
import json,sys

with open(sys.argv[1]) as f:
    x=json.load(f)

ok=(
    x.get("order")=="ROBOTICS-UA-0001"
    and x.get("execution_completed") is True
    and x.get("execution_type")=="LOCAL_SOFTWARE_RUNTIME_TEST"
)

raise SystemExit(0 if ok else 1)
PY
    then
        EXECUTION_OK="true"
    fi
fi

# ------------------------------------------------------------
# DOUBLE SHA256
# ------------------------------------------------------------

DNA_HASH_INPUT="$DNA/dna_manifest.json"

SHA1="$(sha256sum "$DNA_HASH_INPUT" | awk '{print $1}')"
SHA2="$(printf '%s' "$SHA1" | sha256sum | awk '{print $1}')"

# ------------------------------------------------------------
# TIMESTAMP SNAPSHOT
# ------------------------------------------------------------

SNAPSHOT="$SNAP/self_recovery_$NOW.json"

python3 - "$SNAPSHOT" "$SHA1" "$SHA2" "$TOKEN_SHA" "$REDIS_STATUS" "$CYBRA_IMPORT" "$EXECUTION_OK" "$BACKEND_A" "$BACKEND_B" "$ORACLE" "$PARLIAMENT" <<'PY'
import json,sys,datetime,os

out,sha1,sha2,token,redis_status,cybra_import,execution_ok,backend_a,backend_b,oracle,parliament=sys.argv[1:]

data={
    "snapshot_type":"CYBRA_SELF_RECOVERY_DNA",
    "timestamp":datetime.datetime.now(datetime.timezone.utc).isoformat(),
    "task_id":"AI-CYBRA-SELF-REGENERATING-DNA-001",
    "double_sha256":{
        "sha256":sha1,
        "double_sha256":sha2
    },
    "checks":{
        "redis":redis_status,
        "cybra_import":cybra_import,
        "software_execution_receipt":execution_ok,
        "backend_a":backend_a,
        "backend_b":backend_b,
        "oracle":oracle,
        "parliament":parliament
    },
    "security":{
        "recovery_token_sha256":token,
        "token_embedded_in_snapshot":False,
        "token_web_exposed":False
    },
    "safety":{
        "physical_manufacturing_completed":False,
        "physical_equipment_attached":False,
        "manufacturing_execution_enabled":False
    }
}

with open(out,"w") as f:
    json.dump(data,f,indent=2)
    f.write("\n")
PY

# ------------------------------------------------------------
# SNAPSHOT FILE HASH
# ------------------------------------------------------------

SNAPSHOT_SHA="$(sha256sum "$SNAPSHOT" | awk '{print $1}')"

cat > "$SNAPSHOT.sha256" <<EOF2
$SNAPSHOT_SHA  $(basename "$SNAPSHOT")
EOF2

# ------------------------------------------------------------
# FINAL 100% GATE
# ------------------------------------------------------------

FINAL="PENDING"

if \
    [ "$REDIS_STATUS" = "PASS" ] || [ "$REDIS_STATUS" = "RECOVERED" ]
then
    if \
        [ "$CYBRA_IMPORT" = "PASS" ] &&
        [ "$CORE_OK" = "PASS" ] &&
        [ "$EXECUTION_OK" = "true" ] &&
        [ -f "$SNAPSHOT" ]
    then
        FINAL="TRUE_100"
    fi
fi

if [ "$FINAL" = "TRUE_100" ]; then
    CAUSE="ALL_REQUIRED_SELF_RECOVERY_CHECKS_CONFIRMED"
else
    CAUSE="SELF_RECOVERY_CHECKS_NOT_FULLY_CONFIRMED"
fi

cat > "$EVIDENCE/AI-CYBRA-SELF-REGENERATING-DNA-001_$NOW.json" <<EOF2
{
  "task_id": "AI-CYBRA-SELF-REGENERATING-DNA-001",
  "timestamp": "$ISO",
  "status": "$FINAL",
  "cause": "$CAUSE",
  "snapshot": "$SNAPSHOT",
  "snapshot_sha256": "$SNAPSHOT_SHA",
  "dna_sha256": "$SHA1",
  "dna_double_sha256": "$SHA2",
  "redis": "$REDIS_STATUS",
  "cybra_import": "$CYBRA_IMPORT",
  "software_execution_receipt": "$EXECUTION_OK",
  "backend_a": "$BACKEND_A",
  "backend_b": "$BACKEND_B",
  "oracle": "$ORACLE",
  "parliament": "$PARLIAMENT",
  "safety": {
    "physical_manufacturing_completed": false,
    "physical_equipment_attached": false,
    "manufacturing_execution_enabled": false
  },
  "rule": "TRUE_ONLY_AT_100_PERCENT_REQUIRED_CONFIRMATION"
}
EOF2

# ------------------------------------------------------------
# UPDATE LATEST POINTER
# ------------------------------------------------------------

cp "$SNAPSHOT" "$SNAP/latest_self_recovery.json"

# ------------------------------------------------------------
# GIT RECOVERY MANIFEST
# ------------------------------------------------------------

MANIFEST="$DNA/git_recovery_manifest.txt"

{
    echo "CYBRA SELF-RECOVERY DNA"
    echo "TIMESTAMP=$ISO"
    echo "TASK=AI-CYBRA-SELF-REGENERATING-DNA-001"
    echo "SNAPSHOT=$SNAPSHOT"
    echo "SNAPSHOT_SHA256=$SNAPSHOT_SHA"
    echo "DNA_SHA256=$SHA1"
    echo "DNA_DOUBLE_SHA256=$SHA2"
    echo "REDIS=$REDIS_STATUS"
    echo "CYBRA_IMPORT=$CYBRA_IMPORT"
    echo "EXECUTION=$EXECUTION_OK"
    echo "BACKEND_A=$BACKEND_A"
    echo "BACKEND_B=$BACKEND_B"
    echo "ORACLE=$ORACLE"
    echo "PARLIAMENT=$PARLIAMENT"
    echo "FINAL=$FINAL"
    echo "TOKEN_POLICY=LOCAL_ONLY_NOT_COMMITTED"
    echo "PHYSICAL_MANUFACTURING=false"
} > "$MANIFEST"

# ------------------------------------------------------------
# GIT — ONLY PUBLIC SAFE DNA/EVIDENCE
# ------------------------------------------------------------

cd "$ROOT"

git add \
    "hash_ecosystem/ai_tasks/AI-CYBRA-SELF-REGENERATING-DNA-001.json" \
    "hash_ecosystem/self_recovery_dna/dna_manifest.json" \
    "hash_ecosystem/self_recovery_dna/git_recovery_manifest.txt" \
    "hash_ecosystem/self_recovery_dna/self_recovery_watchdog.json" \
    "orders/$ORDER/evidence/AI-CYBRA-SELF-REGENERATING-DNA-001_$NOW.json" \
    "orders/$ORDER/runtime_snapshot/self_recovery_$NOW.json" \
    "orders/$ORDER/runtime_snapshot/self_recovery_$NOW.json.sha256" \
    "orders/$ORDER/runtime_snapshot/latest_self_recovery.json" \
    2>/dev/null || true

# Never stage the local secret.
git reset -- \
    "hash_ecosystem/self_recovery_dna/.recovery_token" \
    2>/dev/null || true

if ! git diff --cached --quiet; then
    git commit -m "CYBRA: activate self-regenerating DNA recovery task" \
        >/dev/null 2>&1 || true
fi

echo
echo "============================================================"
echo " CYBRA SELF-RECOVERY RESULT"
echo "============================================================"
echo "TASK=$TASK_ID"
echo "FINAL=$FINAL"
echo "CAUSE=$CAUSE"
echo "REDIS=$REDIS_STATUS"
echo "CYBRA_IMPORT=$CYBRA_IMPORT"
echo "EXECUTION=$EXECUTION_OK"
echo "BACKEND_A=$BACKEND_A"
echo "BACKEND_B=$BACKEND_B"
echo "ORACLE=$ORACLE"
echo "PARLIAMENT=$PARLIAMENT"
echo "DNA_SHA256=$SHA1"
echo "DNA_DOUBLE_SHA256=$SHA2"
echo "SNAPSHOT_SHA256=$SNAPSHOT_SHA"
echo "TOKEN_POLICY=LOCAL_ONLY"
echo "PHYSICAL_MANUFACTURING=false"
echo "============================================================"
