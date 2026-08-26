#!/data/data/com.termux/files/usr/bin/bash

set -u
set -o pipefail

ROOT="$HOME/CYBRA"
BUFFER="$ROOT/runtime/buffer"
TRIAD="$ROOT/runtime/triad"
QUEUE="$BUFFER/queue"

TASK_DIR="$(find "$QUEUE" -maxdepth 1 -type d -name 'CYBRONCYBRA-TRIAD-*' 2>/dev/null | sort | tail -n 1)"

if [ -z "${TASK_DIR:-}" ]; then
    echo "[TRIAD] No TRIAD task found."
    exit 2
fi

TASK_ID="$(basename "$TASK_DIR")"
RUN="$TRIAD/runs/$TASK_ID"

mkdir -p \
    "$RUN/git" \
    "$RUN/termux" \
    "$RUN/temp_server_venv" \
    "$RUN/evidence" \
    "$RUN/results"

cp -a "$TASK_DIR/." "$RUN/task/"

cat > "$RUN/DISPATCH.env" <<ENV
TASK_ID=$TASK_ID
MODE=BLACK_BOX
INDEPENDENT_BUFFER=TRUE

GIT_REQUIRED=TRUE
TERMUX_REQUIRED=TRUE
TEMP_SERVER_VENV_REQUIRED=TRUE

HASH_REQUIRED=TRUE
EVIDENCE_REQUIRED=TRUE
FINAL_RULE=TRUE_ONLY_AT_100_PERCENT
FAIL_CLOSED=TRUE
ENV

# ------------------------------------------------------------
# Independent task envelopes
# ------------------------------------------------------------

cat > "$RUN/git/TASK.env" <<ENV
TASK_ID=$TASK_ID
ROLE=GIT
REQUIRED=TRUE
REQUIRED_EVIDENCE=GIT_EVIDENCE
ENV

cat > "$RUN/termux/TASK.env" <<ENV
TASK_ID=$TASK_ID
ROLE=TERMUX
REQUIRED=TRUE
REQUIRED_EVIDENCE=TERMUX_EVIDENCE
ENV

cat > "$RUN/temp_server_venv/TASK.env" <<ENV
TASK_ID=$TASK_ID
ROLE=TEMP_SERVER_VENV
REQUIRED=TRUE
REQUIRED_EVIDENCE=TEMP_SERVER_VENV_EVIDENCE
ENV

# ------------------------------------------------------------
# Result files start FALSE.
# Only the respective executor may replace its own result.
# ------------------------------------------------------------

for layer in git termux temp_server_venv; do
    cat > "$RUN/results/$layer.env" <<ENV
TASK_ID=$TASK_ID
ROLE=$layer
STATUS=PENDING
COMPLETION=0
FINAL=FALSE
EVIDENCE_HASH=
ENV
done

# ------------------------------------------------------------
# Independent final gate
# ------------------------------------------------------------

cat > "$RUN/100_GATE.sh" <<'GATE'
#!/data/data/com.termux/files/usr/bin/bash

set -u
set -o pipefail

BASE="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"

FINAL="TRUE"

verify_layer() {
    local file="$1"
    local name="$2"

    if [ ! -f "$file" ]; then
        echo "[GATE] $name: MISSING"
        FINAL="FALSE"
        return
    fi

    # shellcheck disable=SC1090
    . "$file"

    if [ "${STATUS:-PENDING}" != "COMPLETED" ] ||
       [ "${COMPLETION:-0}" != "100" ] ||
       [ -z "${EVIDENCE_HASH:-}" ]; then
        echo "[GATE] $name: NOT VERIFIED"
        FINAL="FALSE"
    else
        echo "[GATE] $name: VERIFIED"
    fi
}

verify_layer "$BASE/results/git.env" "GIT"
verify_layer "$BASE/results/termux.env" "TERMUX"
verify_layer "$BASE/results/temp_server_venv.env" "TEMP_SERVER_VENV"

echo

if [ "$FINAL" = "TRUE" ]; then
    cat > "$BASE/results/FINAL.env" <<EOF
TASK_ID=$TASK_ID
STATUS=COMPLETED
COMPLETION=100
FINAL=TRUE
