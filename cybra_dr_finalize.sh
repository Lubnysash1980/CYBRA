#!/data/data/com.termux/files/usr/bin/bash
set -Eeuo pipefail

ROOT="$HOME/CYBRA"; cd "$ROOT"

REPORT_DIR="hash_ecosystem/disaster_recovery_tests"
EVIDENCE_DIR="orders/ROBOTICS-UA-0001/evidence"
ORDER_DIR="orders/ROBOTICS-UA-0001"
GI=".gitignore"

SOURCES=(
    "$ORDER_DIR/control"
    "$ORDER_DIR/evidence"
    "$ORDER_DIR/live"
    "$ORDER_DIR/runtime_snapshot"
)

OLD_ARTIFACTS=(
    "$REPORT_DIR/AI-CYBRA-DISASTER-RECOVERY-100-001_20260917T121557Z.json"
    "$REPORT_DIR/test_20260917T121440Z.json"
    "$REPORT_DIR/test_20260919T211231Z.json"
    "$REPORT_DIR/test_20260919T211251Z.json"
    "$EVIDENCE_DIR/AI-CYBRA-DISASTER-RECOVERY-100-001_20260917T121557Z.json"
)

IGNORE_BLOCK='# CYBRA DR — superseded artifacts (added by cybra_dr_finalize.sh)
hash_ecosystem/disaster_recovery_tests/test_20260917T*.json
hash_ecosystem/disaster_recovery_tests/test_20260919T2112*.json
hash_ecosystem/disaster_recovery_tests/AI-CYBRA-DISASTER-RECOVERY-100-001_20260917T*.json
orders/ROBOTICS-UA-0001/evidence/AI-CYBRA-DISASTER-RECOVERY-100-001_20260917T*.json
orders/ROBOTICS-UA-0001/control/*.lock
orders/ROBOTICS-UA-0001/control/self_healing_state.json
'

do_check() {
    echo "============================================================"
    echo " FINALIZE CHECK"
    echo "============================================================"

    echo "--- sources present on disk ---"
    local missing=0
    for f in \
        "$ORDER_DIR/control/state.json" \
        "$ORDER_DIR/control/required_tasks.json" \
        "$ORDER_DIR/evidence/final_proof.json" \
        "$ORDER_DIR/live/controller.py" \
        "$ORDER_DIR/live/logs/execution_receipt.json"; do
        if [ -f "$f" ]; then echo "  OK   $f"; else echo "  MISS $f"; missing=1; fi
    done
    [ "$missing" -eq 0 ] || { echo "CANNOT TRACK — sources absent"; return 1; }

    echo
    echo "--- sources tracked in git? ---"
    local untracked=0
    for f in \
        "$ORDER_DIR/control/state.json" \
        "$ORDER_DIR/control/required_tasks.json" \
        "$ORDER_DIR/evidence/final_proof.json" \
        "$ORDER_DIR/live/controller.py" \
        "$ORDER_DIR/live/logs/execution_receipt.json"; do
        if git ls-files --error-unmatch "$f" >/dev/null 2>&1; then
            echo "  tracked   $f"
        else
            echo "  UNTRACKED $f"
            untracked=1
        fi
    done

    echo
    echo "--- .gitignore DR block? ---"
    if grep -q "CYBRA DR — superseded artifacts" "$GI" 2>/dev/null; then
        echo "  present"
    else
        echo "  absent (will add)"
    fi

    echo
    echo "--- old artifacts ---"
    local old_present=0
    for f in "${OLD_ARTIFACTS[@]}"; do
        if [ -f "$f" ]; then echo "  present  $f"; old_present=$((old_present+1)); fi
    done
    echo "  ($old_present on disk)"

    echo
    echo "--- untracked in DR dirs ---"
    git status --short -- "$ORDER_DIR" "$REPORT_DIR" 2>/dev/null | sed 's/^/  /'

    echo "---"
    if [ "$untracked" -eq 1 ]; then
        echo "RESULT: TRACK NEEDED"
    else
        echo "RESULT: sources already tracked"
    fi
    return 0
}

do_apply() {
    echo "============================================================"
    echo " FINALIZE APPLY"
    echo "============================================================"

    local stamp backup
    stamp="$(date -u +%Y%m%dT%H%M%SZ)"
    if [ -f "$GI" ]; then
        backup="$GI.bak_$stamp"
        cp -a "$GI" "$backup"
        echo "backup: $backup"
    fi

    if ! grep -q "CYBRA DR — superseded artifacts" "$GI" 2>/dev/null; then
        printf '\n%s\n' "$IGNORE_BLOCK" >> "$GI"
        echo ".gitignore: block appended"
    else
        echo ".gitignore: block already present"
    fi

    local d
    for d in "${SOURCES[@]}"; do
        [ -d "$d" ] && git add -- "$d" && echo "staged: $d"
    done

    git add -- "$GI"
    echo "staged: $GI"

    echo
    echo "--- staged ---"
    git diff --cached --stat

    if git diff --cached --quiet; then
        echo "NOTHING STAGED"
        return 0
    fi

    local ans="n"
    [ "${1:-}" = "--yes" ] && ans="y"
    if [ "$ans" != "y" ]; then
        read -r -p "commit? [y/N] " ans
    fi
    if [ "$ans" = "y" ] || [ "$ans" = "Y" ]; then
        git commit -m "CYBRA: track DR sources; ignore superseded DR artifacts"
        echo "COMMIT=$(git rev-parse HEAD)"
    else
        echo "staged only (no commit)"
    fi
}

case "${1:-check}" in
    check) do_check ;;
    apply) do_apply "${2:-}" ;;
    all)
        do_check || { echo "CHECK failed — abort"; exit 1; }
        echo
        do_apply "${2:-}"
        ;;
    *) echo "usage: $0 {check|apply|all} [--yes]"; exit 2 ;;
esac
