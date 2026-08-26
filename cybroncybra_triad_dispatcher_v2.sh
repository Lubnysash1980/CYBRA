#!/data/data/com.termux/files/usr/bin/bash

set -u
set -o pipefail

ROOT="$HOME/CYBRA"
BUFFER="$ROOT/runtime/buffer"
QUEUE="$BUFFER/queue"
RUNNING="$BUFFER/running"
COMPLETED="$BUFFER/completed"
FAILED="$BUFFER/failed"
TMP="$ROOT/runtime/worker_tmp/triad"

mkdir -p "$QUEUE" "$RUNNING" "$COMPLETED" "$FAILED" "$TMP"

TASK="$(find "$QUEUE" -mindepth 1 -maxdepth 1 -type d \
  -name 'CYBRONCYBRA-TRIAD-*' 2>/dev/null | sort | head -n 1)"

if [ -z "${TASK:-}" ]; then
    echo "[TRIAD] NO QUEUED TASK"
    exit 2
fi

TASK_ID="$(basename "$TASK")"
RUN="$RUNNING/${TASK_ID}-$(date -u +%Y%m%dT%H%M%SZ)"

mkdir -p "$RUN"/{git,termux,temp_server,worker,executor,evolution,evidence,state}

cp -a "$TASK/." "$RUN/task/"

cat > "$RUN/state/status.env" <<STATE
TASK_ID=$TASK_ID
STATE=WORKING
GIT=FALSE
TERMUX=FALSE
TEMP_SERVER_VENV=FALSE
WORKER=FALSE
EXECUTOR=FALSE
EVOLUTION=FALSE
HASH=FALSE
EVIDENCE=FALSE
COMPLETION=0
FINAL=FALSE
RTU=FALSE
STATE

echo "================================================"
echo " CYBRONCYBRA — TRIAD WORK DISPATCHER"
echo "================================================"
echo "TASK=$TASK_ID"
echo "STATE=WORKING"
echo

# ------------------------------------------------
# GIT lane
# ------------------------------------------------

{
    echo "TASK_ID=$TASK_ID"
    echo "HEAD=$(git -C "$ROOT" rev-parse HEAD 2>/dev/null || echo UNKNOWN)"
    echo "REMOTE=$(git -C "$ROOT" remote get-url origin 2>/dev/null || echo UNKNOWN)"
    git -C "$ROOT" status --short 2>&1 || true
} > "$RUN/git/evidence.txt"

sha256sum "$RUN/git/evidence.txt" > "$RUN/git/evidence.sha256"

echo "[TRIAD] GIT WORK QUEUED"

# ------------------------------------------------
# TERMUX lane
# ------------------------------------------------

{
    echo "TASK_ID=$TASK_ID"
    echo "TERMUX_PREFIX=${PREFIX:-UNKNOWN}"
    echo "TERMUX_HOME=${HOME:-UNKNOWN}"
    echo "DATE=$(date -u +%Y-%m-%dT%H:%M:%SZ)"
} > "$RUN/termux/evidence.txt"

sha256sum "$RUN/termux/evidence.txt" > "$RUN/termux/evidence.sha256"

echo "[TRIAD] TERMUX WORK QUEUED"

# ------------------------------------------------
# TEMP SERVER / VENV lane
# ------------------------------------------------

VENV="$TMP/$TASK_ID/venv"
mkdir -p "$TMP/$TASK_ID"

if python -m venv "$VENV" 2>/dev/null; then
    "$VENV/bin/python" -c 'print("[TEMP-VENV] READY")' \
        > "$RUN/temp_server/evidence.txt" 2>&1

    echo "VENV=$VENV" >> "$RUN/temp_server/evidence.txt"
    sha256sum "$RUN/temp_server/evidence.txt" \
        > "$RUN/temp_server/evidence.sha256"

    echo "[TRIAD] TEMP VENV READY"
else
    echo "[TRIAD] TEMP VENV FAILED"
fi

# ------------------------------------------------
# WORKER / EXECUTOR / EVOLUTION
# ------------------------------------------------

cat > "$RUN/state/WORK_REQUIRED" <<EOF
TASK_ID=$TASK_ID

WORKER:
  MUST_READ=$RUN/task
  MUST_EXECUTE=TRUE

EXECUTOR:
  MUST_VERIFY_WORKER=TRUE
  MUST_EXECUTE_AUTHORIZED_WORK=TRUE

EVOLUTION:
  MUST_CHECK_FAILURES=TRUE
  MUST_FIX_WHERE_AUTHORIZED=TRUE
  MUST_REVERIFY=TRUE

FINAL:
  ONLY_100_PERCENT_VERIFIED
EOF
