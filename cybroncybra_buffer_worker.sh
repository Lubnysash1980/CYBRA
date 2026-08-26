#!/data/data/com.termux/files/usr/bin/bash

set -u
set -o pipefail

ROOT="$HOME/CYBRA"
BUFFER="$ROOT/runtime/buffer"
RUNNING="$BUFFER/running"
COMPLETED="$BUFFER/completed"
FAILED="$BUFFER/failed"
TMP="$ROOT/runtime/worker_tmp/buffer_worker"

mkdir -p "$RUNNING" "$COMPLETED" "$FAILED" "$TMP"

TASK_RUN="$(find "$RUNNING" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | sort | head -n 1)"

if [ -z "${TASK_RUN:-}" ]; then
    echo "[WORKER] NO RUNNING TASK"
    exit 2
fi

TASK_ID="$(basename "$TASK_RUN")"
START="$(date -u +%Y%m%dT%H%M%SZ)"
VENV="$TMP/$TASK_ID-$START/venv"
WORK="$TMP/$TASK_ID-$START/work"

mkdir -p "$WORK"

echo "================================================"
echo " CYBRONCYBRA — BUFFER WORKER"
echo "================================================"
echo "TASK: $TASK_ID"
echo "WORK: $WORK"
echo "VENV: $VENV"
echo

# ------------------------------------------------
# Temporary isolated VENV
# ------------------------------------------------

python -m venv "$VENV" 2>/dev/null || {
    echo "[WORKER] VENV CREATE FAILED"
    exit 10
}

"$VENV/bin/python" - <<'PY'
import sys
print("[VENV] Python:", sys.version.split()[0])
print("[VENV] READY")
PY

# ------------------------------------------------
# Evidence
# ------------------------------------------------

EVIDENCE="$TASK_RUN/evidence"
RESULT="$TASK_RUN/result.env"

mkdir -p "$EVIDENCE"

{
    echo "TASK_ID=$TASK_ID"
    echo "START=$START"
    echo "VENV=$VENV"
    echo "WORK=$WORK"

    if git -C "$ROOT" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
        echo "GIT_REPOSITORY=TRUE"
        echo "GIT_HEAD=$(git -C "$ROOT" rev-parse HEAD)"
        echo "GIT_REMOTE=$(git -C "$ROOT" remote get-url origin 2>/dev/null || true)"
    else
        echo "GIT_REPOSITORY=FALSE"
    fi
} > "$EVIDENCE/local.env"

sha256sum "$EVIDENCE/local.env" > "$EVIDENCE/local.env.sha256"

# ------------------------------------------------
# Worker result
# ------------------------------------------------

cat > "$RESULT" <<EOF_RESULT
TASK_ID=$TASK_ID
STATUS=PENDING
COMPLETION=0
GIT=FALSE
TERMUX=TRUE
TEMP_SERVER_VENV=TRUE
WORKER=TRUE
EXECUTOR=FALSE
HASH=TRUE
EVIDENCE=TRUE
EVOLUTION=FALSE
FINAL=FALSE
EOF_RESULT

echo
echo "[WORKER] LOCAL WORKER COMPLETED"
echo "[WORKER] EXECUTOR=FALSE"
echo "[WORKER] EVOLUTION=FALSE"
echo "[WORKER] FINAL=FALSE"
echo
echo "[WORKER] External execution evidence still required."
