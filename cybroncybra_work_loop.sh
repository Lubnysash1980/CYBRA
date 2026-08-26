#!/data/data/com.termux/files/usr/bin/bash

set -u
set -o pipefail

ROOT="$HOME/CYBRA"
BUFFER="$ROOT/runtime/buffer"
QUEUE="$BUFFER/queue"
RUNNING="$BUFFER/running"
COMPLETED="$BUFFER/completed"
FAILED="$BUFFER/failed"
WORKER_TMP="$ROOT/runtime/worker_tmp"

mkdir -p "$QUEUE" "$RUNNING" "$COMPLETED" "$FAILED" "$WORKER_TMP"

TASK="$(find "$QUEUE" -mindepth 1 -maxdepth 1 -type d \
    -name 'CYBRONCYBRA-TRIAD-*' 2>/dev/null | sort | head -n 1)"

if [ -z "${TASK:-}" ]; then
    echo "[WORK] NO TASK"
    exit 2
fi

TASK_ID="$(basename "$TASK")"
RUN="$RUNNING/${TASK_ID}-$(date -u +%Y%m%dT%H%M%SZ)"

mkdir -p "$RUN/work" "$RUN/evidence" "$RUN/state"

cat > "$RUN/state/work.env" <<EOF_STATE
TASK_ID=$TASK_ID
STATE=WORKING
COMPLETION=0
FINAL=FALSE
RTU=FALSE
EOF_STATE

echo "================================================"
echo " CYBRONCYBRA — REAL WORK NODE"
echo "================================================"
echo "TASK=$TASK_ID"
echo "STATE=WORKING"
echo "MODE=CONTINUOUS"
echo "VENV=TEMPORARY"
echo

cycle=0

while true; do
    cycle=$((cycle + 1))

    echo "[WORK $cycle] CHECK"

    # Temporary isolated environment for this work cycle.
    CYCLE="$WORKER_TMP/${TASK_ID}-${cycle}-$(date -u +%s)"
    VENV="$CYCLE/venv"
    mkdir -p "$CYCLE/work"

    if ! python -m venv "$VENV" 2>/dev/null; then
        echo "[WORK $cycle] VENV FAILED"
        echo "[WORK $cycle] RECOVERY"
        continue
    fi

    echo "[WORK $cycle] VENV READY"

    # Work evidence — never declares FINAL.
    {
        echo "TASK_ID=$TASK_ID"
        echo "CYCLE=$cycle"
        echo "VENV=$VENV"
        echo "TIMESTAMP=$(date -u +%Y-%m-%dT%H:%M:%SZ)"
        echo "GIT_HEAD=$(git -C "$ROOT" rev-parse HEAD 2>/dev/null || echo UNKNOWN)"
    } > "$RUN/evidence/work-$cycle.env"

    sha256sum "$RUN/evidence/work-$cycle.env" \
        > "$RUN/evidence/work-$cycle.sha256"

    # ----------------------------------------------------
    # IMPORTANT:
    # The work loop does NOT manufacture completion.
    # A real external worker/executor must write:
    #
    #   $RUN/state/verified.env
    #
    # with:
    #   VERIFIED=TRUE
    #   COMPLETION=100
    #
    # Only then can the task leave WORKING.
    # ----------------------------------------------------

    if [ -f "$RUN/state/verified.env" ]; then
        # shellcheck disable=SC1090
        . "$RUN/state/verified.env"

        if [ "${VERIFIED:-FALSE}" = "TRUE" ] &&
           [ "${COMPLETION:-0}" = "100" ]; then

            cat > "$RUN/state/work.env" <<EOF_DONE
TASK_ID=$TASK_ID
STATE=COMPLETED_100
COMPLETION=100
FINAL=TRUE
RTU=TRUE
EOF_DONE

            mv "$RUN" "$COMPLETED/$TASK_ID"

            echo
            echo "[WORK] VERIFIED WORK COMPLETE"
            echo "[100%] TRUE"
            echo "[RTU] TRUE"
            exit 0
        fi
    fi

    echo "[WORK $cycle] NOT COMPLETE"
    echo "[WORK $cycle] CONTINUE"

    # Prevent a tight CPU-burning loop.
    sleep 2
done
