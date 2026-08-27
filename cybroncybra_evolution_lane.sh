#!/data/data/com.termux/files/usr/bin/bash
set -u
set -o pipefail

ROOT="$HOME/CYBRA"
RUN="${1:-}"

if [ -z "$RUN" ] || [ ! -d "$RUN" ]; then
    echo "[EVOLUTION][FAIL] RUN NOT FOUND"
    exit 2
fi

EVO="$RUN/evolution"
mkdir -p "$EVO"

REPORT="$EVO/evolution_verification.env"
SHA="$EVO/evolution_verification.sha256"

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

echo "=============================================="
echo " CYBRONCYBRA — EVOLUTION LANE"
echo "=============================================="
echo "RUN=$RUN"
echo

check "Git repository"     "git -C \"$ROOT\" rev-parse --is-inside-work-tree >/dev/null 2>&1"

check "Git HEAD"     "git -C \"$ROOT\" rev-parse HEAD >/dev/null 2>&1"

check "Git remote"     "git -C \"$ROOT\" remote get-url origin >/dev/null 2>&1"

check "Git evidence"     "[ -s \"$RUN/git/evidence.txt\" ]"

check "Git evidence hash"     "[ -s \"$RUN/git/evidence.sha256\" ]"

if [ -s "$RUN/git/evidence.sha256" ]; then
    check "Git evidence hash valid"         "sha256sum -c \"$RUN/git/evidence.sha256\" >/dev/null 2>&1"
fi

check "Termux evidence"     "[ -s \"$RUN/termux/evidence.txt\" ]"

check "Termux evidence hash"     "[ -s \"$RUN/termux/evidence.sha256\" ]"

if [ -s "$RUN/termux/evidence.sha256" ]; then
    check "Termux evidence hash valid"         "sha256sum -c \"$RUN/termux/evidence.sha256\" >/dev/null 2>&1"
fi

check "Temp VENV evidence"     "[ -s \"$RUN/temp_server/evidence.txt\" ]"

check "Temp VENV evidence hash"     "[ -s \"$RUN/temp_server/evidence.sha256\" ]"

if [ -s "$RUN/temp_server/evidence.sha256" ]; then
    check "Temp VENV hash valid"         "sha256sum -c \"$RUN/temp_server/evidence.sha256\" >/dev/null 2>&1"
fi

check "Worker result"     "[ -s \"$RUN/result.env\" ]"

if [ -s "$RUN/result.env" ]; then
    check "Worker TRUE"         "grep -q '^WORKER=TRUE$' \"$RUN/result.env\""
fi

check "Executor evidence"     "[ -s \"$RUN/evidence/executor_verification.json\" ]"

check "Executor evidence hash"     "[ -s \"$RUN/evidence/executor_verification.sha256\" ]"

if [ -s "$RUN/evidence/executor_verification.sha256" ]; then
    check "Executor evidence hash valid"         "sha256sum -c \"$RUN/evidence/executor_verification.sha256\" >/dev/null 2>&1"
fi

{
    echo "EVOLUTION=CYBRONCYBRA"
    echo "RUN=$RUN"
    echo "PASS=$PASS"
    echo "FAIL=$FAIL"

    if [ "$FAIL" -eq 0 ]; then
        echo "STATUS=PASS"
    else
        echo "STATUS=FAIL"
    fi
} > "$REPORT"

sha256sum "$REPORT" > "$SHA"

echo
echo "=============================================="

if [ "$FAIL" -eq 0 ]; then
    echo "[EVOLUTION] EVIDENCE VERIFIED"
    echo "PASS=$PASS"
    echo "FAIL=$FAIL"
    echo "REPORT=$REPORT"
    echo "SHA=$SHA"
    exit 0
else
    echo "[EVOLUTION] EVIDENCE VERIFICATION FAILED"
    echo "PASS=$PASS"
    echo "FAIL=$FAIL"
    echo "REPORT=$REPORT"
    echo "SHA=$SHA"
    exit 1
fi
