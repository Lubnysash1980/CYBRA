#!/data/data/com.termux/files/usr/bin/bash

set -u
set -o pipefail

ROOT="$HOME/CYBRA"
BUFFER="$ROOT/runtime/buffer"
QUEUE="$BUFFER/queue"
RUNNING="$BUFFER/running"
RECOVERY="$BUFFER/recovery"
TMP="$ROOT/runtime/worker_tmp/triad"

mkdir -p "$QUEUE" "$RUNNING" "$RECOVERY" "$TMP"

TASK="$(find "$QUEUE" -mindepth 1 -maxdepth 1 -type d \
    -name 'CYBRONCYBRA-TRIAD-*' 2>/dev/null | sort | head -n 1)"

if [ -z "${TASK:-}" ]; then
    echo "[TRIAD] NO QUEUED TASK"
    exit 2
fi

TASK_ID="$(basename "$TASK")"

# ------------------------------------------------------------
# ONE TASK = ONE ACTIVE RUN
# ------------------------------------------------------------

ACTIVE="$(find "$RUNNING" -mindepth 1 -maxdepth 1 -type d \
    -name "${TASK_ID}-*" 2>/dev/null | sort)"

COUNT=0

while IFS= read -r OLD_RUN; do
    [ -z "$OLD_RUN" ] && continue
    COUNT=$((COUNT + 1))

    if [ "$COUNT" -eq 1 ]; then
        ACTIVE_RUN="$OLD_RUN"
    else
        OLD_NAME="$(basename "$OLD_RUN")"
        mkdir -p "$RECOVERY"
        mv "$OLD_RUN" "$RECOVERY/$OLD_NAME"
        echo "[TRIAD] DUPLICATE RUN MOVED TO RECOVERY: $OLD_NAME"
    fi
done <<< "$ACTIVE"

if [ "$COUNT" -gt 1 ]; then
    echo "[TRIAD] DUPLICATES=$((COUNT - 1))"
fi

# Existing active run is reused.
if [ "$COUNT" -ge 1 ]; then
    RUN="$ACTIVE_RUN"
    echo "[TRIAD] EXISTING ACTIVE RUN REUSED"
else
    RUN="$RUNNING/${TASK_ID}-$(date -u +%Y%m%dT%H%M%SZ)"

    mkdir -p "$RUN"/{task,git,termux,temp_server,worker,executor,evolution,evidence,state}

    # Atomic task snapshot.
    cp -a "$TASK/." "$RUN/task/"

    cat > "$RUN/state/status.env" <<STATE
TASK_ID=$TASK_ID
RUN_ID=$(basename "$RUN")
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

    echo "[TRIAD] NEW ACTIVE RUN CREATED"
fi

echo
echo "================================================"
echo " CYBRONCYBRA — TRIAD DISPATCHER V3"
echo "================================================"
echo "TASK_ID=$TASK_ID"
echo "RUN_ID=$(basename "$RUN")"
echo "STATE=WORKING"
echo

# ------------------------------------------------------------
# Work contract
# ------------------------------------------------------------

cat > "$RUN/state/WORK_REQUIRED" <<EOF
TASK_ID=$TASK_ID
RUN_ID=$(basename "$RUN")

MODE=REAL_WORK
BUFFER=INDEPENDENT
CONTINUOUS=TRUE
TEMP_VENV=PER_RUN

GIT=REQUIRED
TERMUX=REQUIRED
TEMP_SERVER_VENV=REQUIRED
WORKER=REQUIRED
EXECUTOR=REQUIRED
EVOLUTION=REQUIRED
HASH=REQUIRED
EVIDENCE=REQUIRED

FAIL_CLOSED=TRUE
FINAL_ONLY_AT_100=TRUE

WORK_LOOP:
CHECK
FIX
DO
CONFIGURE
EXECUTE
VERIFY
REPEAT_UNTIL_100
