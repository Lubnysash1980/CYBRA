#!/data/data/com.termux/files/usr/bin/bash

set -u
set -o pipefail

ROOT="$HOME/CYBRA"
BUFFER="$ROOT/runtime/buffer"

TARGET_RUN="${2:-}"

if [ "${1:-}" != "run" ] || [ -z "$TARGET_RUN" ]; then
    echo "[EXECUTOR] Usage:"
    echo "  $0 run /absolute/or/relative/RUN"
    exit 2
fi

RUN="$(realpath "$TARGET_RUN" 2>/dev/null || true)"

if [ -z "$RUN" ] || [ ! -d "$RUN" ]; then
    echo "[EXECUTOR] ERROR: RUN does not exist"
    exit 2
fi

WORK="$RUN/executor/work"
VENV="$RUN/executor/venv"
LOG="$RUN/executor/executor.log"

mkdir -p "$WORK" "$RUN/executor" "$VENV"

exec > >(tee -a "$LOG") 2>&1

echo "================================================"
echo " CYBRONCYBRA — TARGET RUN EXECUTOR"
echo "================================================"
echo "RUN=$RUN"
echo "WORK=$WORK"
echo "VENV=$VENV"
echo

fail() {
    local reason="$1"

    mkdir -p "$RUN/executor"

    {
        echo "EXECUTION=FALSE"
        echo "VERIFY=FALSE"
        echo "WORKER_RC=1"
        echo "REASON=$reason"
        echo "FINAL=FALSE"
    } > "$RUN/executor/execution.env"

    echo "[EXECUTOR] FAIL: $reason"
    echo "[EXECUTOR] FINAL=FALSE"
    return 1
}

required_file() {
    [ -f "$RUN/$1" ] || {
        echo "[EXECUTOR] MISSING: $RUN/$1"
        return 1
    }
}

echo "=== INPUT VALIDATION ==="

for f in \
    TASK.env \
    TRIAD_CONTRACT.md \
    WORKER_INSTRUCTION.md \
    RESULT_SCHEMA \
    BINARY_BUFFER.md \
    state/WORK_REQUIRED
do
    required_file "$f" || fail "MISSING_REQUIRED_INPUT:$f" || exit $?
    echo "[OK] $f"
done

echo
echo "=== FORBIDDEN FINAL AUTHORITY CHECK ==="

if grep -RnsE '^[[:space:]]*FINAL=TRUE[[:space:]]*$' \
    "$RUN/executor" \
    "$ROOT/cybroncybra_buffer_worker.sh" \
    "$ROOT/cybroncybra_buffer_executor.sh" \
    2>/dev/null
then
    fail "FORBIDDEN_FINAL_TRUE_FOUND"
    exit 1
fi

echo "[OK] NO FINAL=TRUE"

echo
echo "=== PYTHON ==="

PY="$(command -v python || command -v python3 || true)"

[ -n "$PY" ] || {
    fail "PYTHON_NOT_FOUND"
    exit 1
}

"$PY" -m venv "$VENV" >/dev/null 2>&1 || {
    fail "VENV_CREATE_FAILED"
    exit 1
}

"$VENV/bin/python" -c 'import sys; print("[VENV] Python:", sys.version.split()[0])' || {
    fail "VENV_VERIFY_FAILED"
    exit 1
}

echo "[VENV] READY"

echo
echo "=== REAL EXECUTION ==="

cat > "$WORK/execute.py" <<'PY'
from pathlib import Path
import hashlib
import json
import sys

run = Path(sys.argv[1])

required = [
    run / "TASK.env",
    run / "TRIAD_CONTRACT.md",
    run / "WORKER_INSTRUCTION.md",
    run / "RESULT_SCHEMA",
    run / "BINARY_BUFFER.md",
    run / "state" / "WORK_REQUIRED",
]

for p in required:
    if not p.is_file():
        print("[EXECUTOR-PY] MISSING:", p)
        raise SystemExit(10)

evidence = run / "evidence"
evidence.mkdir(parents=True, exist_ok=True)

records = []

for p in required:
    data = p.read_bytes()
    digest = hashlib.sha256(data).hexdigest()
    records.append({
        "file": str(p.relative_to(run)),
        "sha256": digest,
        "bytes": len(data),
    })

out = evidence / "executor_verification.json"
out.write_text(
    json.dumps(
        {
            "status": "EXECUTION_VERIFIED",
            "required_files": len(records),
            "files": records,
        },
        indent=2,
    ) + "\n",
    encoding="utf-8",
)

print("[EXECUTOR-PY] REQUIRED FILES VERIFIED:", len(records))
print("[EXECUTOR-PY] EVIDENCE:", out)
print("[EXECUTOR-PY] EXECUTION VERIFIED")
PY

"$VENV/bin/python" "$WORK/execute.py" "$RUN"
RC=$?

echo "[EXECUTOR] WORKER_RC=$RC"

if [ "$RC" -ne 0 ]; then
    fail "EXECUTION_FAILED_RC_$RC"
    exit "$RC"
fi

echo
echo "=== HASH EVIDENCE ==="

sha256sum \
    "$RUN/evidence/executor_verification.json" \
    > "$RUN/evidence/executor_verification.sha256" || {
        fail "HASH_FAILED"
        exit 1
    }

echo "[HASH] TRUE"

echo
echo "=== EXECUTION EVIDENCE ==="

{
    echo "EXECUTION=TRUE"
    echo "VERIFY=TRUE"
    echo "WORKER_RC=0"
    echo "HASH=TRUE"
    echo "EVIDENCE=TRUE"
    echo "FINAL=FALSE"
} > "$RUN/executor/execution.env"

echo "[EXECUTOR] EXECUTION=TRUE"
echo "[EXECUTOR] VERIFY=TRUE"
echo "[EXECUTOR] HASH=TRUE"
echo "[EXECUTOR] EVIDENCE=TRUE"
echo "[EXECUTOR] FINAL=FALSE"

echo
echo "================================================"
echo " EXECUTOR COMPLETED"
echo "================================================"

exit 0
