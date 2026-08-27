#!/data/data/com.termux/files/usr/bin/bash

set -u
set -o pipefail

ROOT="$HOME/CYBRA"
BUFFER="$ROOT/runtime/buffer"
RUNNING="$BUFFER/running"

TASK_RUN="${1:-}"

if [ -z "$TASK_RUN" ]; then
    TASK_RUN="$(find "$RUNNING" -mindepth 1 -maxdepth 1 -type d \
        -name 'CYBRONCYBRA-TRIAD-*' 2>/dev/null | sort | head -n 1)"
fi

if [ -z "${TASK_RUN:-}" ] || [ ! -d "$TASK_RUN" ]; then
    echo "[VERIFIER][FAIL] RUN NOT FOUND"
    exit 2
fi

TASK_ID="$(basename "$TASK_RUN")"
VERIFIED="$TASK_RUN/state/verified.env"
REPORT="$TASK_RUN/evidence/strict_verification.env"
REPORT_SHA="$TASK_RUN/evidence/strict_verification.sha256"

mkdir -p "$TASK_RUN/state" "$TASK_RUN/evidence"

PASS=0
FAIL=0

check() {
    local name="$1"
    local condition="$2"

    if eval "$condition"; then
        echo "[PASS] $name"
        PASS=$((PASS + 1))
    else
        echo "[FAIL] $name"
        FAIL=$((FAIL + 1))
    fi
}

echo "================================================"
echo " CYBRONCYBRA — STRICT FAIL-CLOSED VERIFIER"
echo "================================================"
echo "TASK_ID=$TASK_ID"
echo "RUN=$TASK_RUN"
echo

# ------------------------------------------------
# 1. GIT
# ------------------------------------------------

check "GIT repository" \
    "git -C \"$ROOT\" rev-parse --is-inside-work-tree >/dev/null 2>&1"

check "GIT HEAD" \
    "git -C \"$ROOT\" rev-parse HEAD >/dev/null 2>&1"

check "GIT remote" \
    "git -C \"$ROOT\" remote get-url origin >/dev/null 2>&1"

check "GIT clean working tree" \
    "[ -z \"\$(git -C \"$ROOT\" status --short)\" ]"

# ------------------------------------------------
# 2. TERMUX
# ------------------------------------------------

check "TERMUX prefix" \
    "[ -n \"${PREFIX:-}\" ] && [ -d \"$PREFIX\" ]"

check "TERMUX home" \
    "[ -n \"${HOME:-}\" ] && [ -d \"$HOME\" ]"

# ------------------------------------------------
# 3. TEMP SERVER VENV
# ------------------------------------------------

VENV_EVIDENCE="$TASK_RUN/temp_server/evidence.txt"

check "TEMP VENV evidence" \
    "[ -s \"$VENV_EVIDENCE\" ]"

if [ -s "$VENV_EVIDENCE" ]; then
    check "TEMP VENV READY" \
        "grep -q '\[TEMP-VENV\] READY' \"$VENV_EVIDENCE\""
else
    echo "[FAIL] TEMP VENV READY"
    FAIL=$((FAIL + 1))
fi

# ------------------------------------------------
# 4. WORKER
# ------------------------------------------------

WORKER_EVIDENCE="$TASK_RUN/evidence/local.env"

check "WORKER evidence" \
    "[ -s \"$WORKER_EVIDENCE\" ]"

check "WORKER result" \
    "[ -s \"$TASK_RUN/result.env\" ]"

if [ -s "$TASK_RUN/result.env" ]; then
    check "WORKER=TRUE" \
        "grep -q '^WORKER=TRUE$' \"$TASK_RUN/result.env\""
else
    echo "[FAIL] WORKER=TRUE"
    FAIL=$((FAIL + 1))
fi

# ------------------------------------------------
# 5. EXECUTOR
# ------------------------------------------------

EXECUTOR_JSON="$TASK_RUN/evidence/executor_verification.json"
EXECUTOR_SHA="$TASK_RUN/evidence/executor_verification.sha256"

check "EXECUTOR evidence" \
    "[ -s \"$EXECUTOR_JSON\" ]"

check "EXECUTOR hash file" \
    "[ -s \"$EXECUTOR_SHA\" ]"

if [ -s "$EXECUTOR_SHA" ]; then
    check "EXECUTOR hash valid" \
        "sha256sum -c \"$EXECUTOR_SHA\" >/dev/null 2>&1"
else
    echo "[FAIL] EXECUTOR hash valid"
    FAIL=$((FAIL + 1))
fi

# ------------------------------------------------
# 6. EVOLUTION
# ------------------------------------------------

EVOLUTION_EVIDENCE="$TASK_RUN/evolution"

check "EVOLUTION directory" \
    "[ -d \"$EVOLUTION_EVIDENCE\" ]"

if [ -d "$EVOLUTION_EVIDENCE" ]; then
    if find "$EVOLUTION_EVIDENCE" -type f -size +0c \
        2>/dev/null | grep -q .; then
        echo "[PASS] EVOLUTION evidence present"
        PASS=$((PASS + 1))
    else
        echo "[FAIL] EVOLUTION evidence present"
        FAIL=$((FAIL + 1))
    fi
fi

# ------------------------------------------------
# 7. HASH
# ------------------------------------------------

check "Input hashes" \
    "[ -s \"$TASK_RUN/evidence/input_hashes.sha256\" ]"

check "Git evidence hash" \
    "[ -s \"$TASK_RUN/git/evidence.sha256\" ]"

check "Termux evidence hash" \
    "[ -s \"$TASK_RUN/termux/evidence.sha256\" ]"

check "Temp VENV evidence hash" \
    "[ -s \"$TASK_RUN/temp_server/evidence.sha256\" ]"

# ------------------------------------------------
# 8. EVIDENCE
# ------------------------------------------------

check "Git evidence" \
    "[ -s \"$TASK_RUN/git/evidence.txt\" ]"

check "Termux evidence" \
    "[ -s \"$TASK_RUN/termux/evidence.txt\" ]"

check "Temp VENV evidence" \
    "[ -s \"$TASK_RUN/temp_server/evidence.txt\" ]"

# ------------------------------------------------
# ABSOLUTE FINAL GUARD
# ------------------------------------------------

if grep -RnsE '^[[:space:]]*FINAL=TRUE[[:space:]]*$' \
    "$TASK_RUN" 2>/dev/null | grep -v 'verified.env'; then
    echo "[FAIL] UNAUTHORIZED FINAL=TRUE FOUND"
    FAIL=$((FAIL + 1))
fi

# ------------------------------------------------
# RESULT
# ------------------------------------------------

if [ "$FAIL" -ne 0 ]; then

    rm -f "$VERIFIED"

    cat > "$REPORT" <<EOF_REPORT
TASK_ID=$TASK_ID
VERIFIED=FALSE
COMPLETION=0
PASS=$PASS
FAIL=$FAIL
FINAL=FALSE
REASON=REQUIRED_LANE_NOT_VERIFIED
EOF_REPORT

    sha256sum "$REPORT" > "$REPORT_SHA"

    echo
    echo "================================================"
    echo "[STRICT VERIFIER] FAILED CLOSED"
    echo "PASS=$PASS"
    echo "FAIL=$FAIL"
    echo "VERIFIED=FALSE"
    echo "COMPLETION=0"
    echo "FINAL=FALSE"
    echo "================================================"

    exit 1
fi

# ------------------------------------------------
# ONLY HERE CAN verified.env EXIST
# ------------------------------------------------

cat > "$VERIFIED" <<EOF_VERIFIED
TASK_ID=$TASK_ID
VERIFIED=TRUE
COMPLETION=100
GIT=TRUE
TERMUX=TRUE
TEMP_SERVER_VENV=TRUE
WORKER=TRUE
EXECUTOR=TRUE
EVOLUTION=TRUE
HASH=TRUE
EVIDENCE=TRUE
FINAL=TRUE
VERIFIED_AT=$(date -u +%Y-%m-%dT%H:%M:%SZ)
EOF_VERIFIED

cat > "$REPORT" <<EOF_REPORT
TASK_ID=$TASK_ID
VERIFIED=TRUE
COMPLETION=100
PASS=$PASS
FAIL=0
GIT=TRUE
TERMUX=TRUE
TEMP_SERVER_VENV=TRUE
WORKER=TRUE
EXECUTOR=TRUE
EVOLUTION=TRUE
HASH=TRUE
EVIDENCE=TRUE
FINAL=TRUE
EOF_REPORT

sha256sum "$REPORT" > "$REPORT_SHA"

echo
echo "================================================"
echo "[STRICT VERIFIER] 100% VERIFIED"
echo "PASS=$PASS"
echo "FAIL=0"
echo "VERIFIED=TRUE"
echo "COMPLETION=100"
echo "FINAL=TRUE"
echo "================================================"

exit 0
