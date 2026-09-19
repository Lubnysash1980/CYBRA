#!/data/data/com.termux/files/usr/bin/bash
set -Eeuo pipefail

ROOT="$HOME/CYBRA"; cd "$ROOT"

DNA_DIR="hash_ecosystem/self_recovery_dna"
GI=".gitignore"
FINALIZE="cybra_dr_finalize.sh"

# файли DNA, які трекаємо (всі, крім токена)
DNA_KEEP=(
    "$DNA_DIR/cybra_self_recovery_dna.sh"
    "$DNA_DIR/cybra_self_recovery_watchdog.sh"
    "$DNA_DIR/dna_manifest.json"
    "$DNA_DIR/watchdog_status.json"
)

DNA_IGNORE_BLOCK='# CYBRA DNA — local secret + runtime
hash_ecosystem/self_recovery_dna/.recovery_token
hash_ecosystem/self_recovery_dna/*.lock
'

GLOBAL_IGNORE_BLOCK='# CYBRA — global state backups
hash_ecosystem/global_runtime_state.json.bak_*
'

do_apply() {
    echo "============================================================"
    echo " CLOSE — track finalize.sh + DNA, ignore backups"
    echo "============================================================"

    local stamp
    stamp="$(date -u +%Y%m%dT%H%M%SZ)"
    [ -f "$GI" ] && cp -a "$GI" "$GI.bak_$stamp" && echo "backup: $GI.bak_$stamp"

    # 1. extend .gitignore if blocks absent
    if ! grep -q "CYBRA DNA — local secret" "$GI" 2>/dev/null; then
        printf '\n%s\n' "$DNA_IGNORE_BLOCK" >> "$GI"
        echo ".gitignore: DNA block appended"
    else
        echo ".gitignore: DNA block present"
    fi

    if ! grep -q "CYBRA — global state backups" "$GI" 2>/dev/null; then
        printf '\n%s\n' "$GLOBAL_IGNORE_BLOCK" >> "$GI"
        echo ".gitignore: global-backup block appended"
    else
        echo ".gitignore: global-backup block present"
    fi

    # 2. track finalize.sh
    if [ -f "$FINALIZE" ]; then
        git add -- "$FINALIZE"
        echo "staged: $FINALIZE"
    else
        echo "MISSING: $FINALIZE"
    fi

    # 3. track DNA (force, бо може бути під *.sh ignore)
    for f in "${DNA_KEEP[@]}"; do
        if [ -f "$f" ]; then
            git add -f -- "$f"
            echo "staged: $f"
        else
            echo "absent: $f"
        fi
    done

    # 4. stage .gitignore
    git add -- "$GI"
    echo "staged: $GI"

    echo
    echo "--- staged ---"
    GIT_PAGER=cat git --no-pager diff --cached --stat

    if git diff --cached --quiet; then
        echo "NOTHING STAGED"
        return 0
    fi

    local ans="n"
    [ "${1:-}" = "--yes" ] && ans="y"
    [ "$ans" != "y" ] && read -r -p "commit? [y/N] " ans
    if [ "$ans" = "y" ] || [ "$ans" = "Y" ]; then
        git commit -m "CYBRA: close DR loop — track finalize.sh + DNA, ignore backups"
        echo "COMMIT=$(git rev-parse HEAD)"
    else
        echo "staged only"
    fi
}

do_verify() {
    echo
    echo "============================================================"
    echo " VERIFY"
    echo "============================================================"

    echo
    echo "--- DNA файли в git ---"
    for f in "${DNA_KEEP[@]}"; do
        printf '%-80s ' "$f"
        if git ls-files --error-unmatch "$f" >/dev/null 2>&1; then echo "TRACKED"; else echo "UNTRACKED"; fi
    done

    echo
    echo "--- finalize.sh в git? ---"
    printf '%-80s ' "$FINALIZE"
    if git ls-files --error-unmatch "$FINALIZE" >/dev/null 2>&1; then echo "TRACKED"; else echo "UNTRACKED"; fi

    echo
    echo "--- .bak files заблоковані? ---"
    for f in hash_ecosystem/global_runtime_state.json.bak_*; do
        [ -e "$f" ] || continue
        printf '%-80s ' "$f"
        if git check-ignore "$f" >/dev/null 2>&1; then echo "IGNORED"; else echo "NOT IGNORED"; fi
    done

    echo
    echo "--- .recovery_token заблоковано? ---"
    local tok="$DNA_DIR/.recovery_token"
    if [ -f "$tok" ]; then
        printf '%-80s ' "$tok"
        if git check-ignore "$tok" >/dev/null 2>&1; then echo "IGNORED"; else echo "NOT IGNORED — треба!"; fi
    else
        echo "  (.recovery_token відсутній)"
    fi

    echo
    echo "--- DR dirs status ---"
    git status --short -- \
        orders/ROBOTICS-UA-0001 \
        hash_ecosystem/disaster_recovery_tests \
        hash_ecosystem/self_recovery_dna \
        hash_ecosystem/global_runtime_state.json* \
        .gitignore \
        cybra_disaster_recovery_test.sh \
        cybra_register_disaster_recovery_100.sh \
        cybra_dr_*.sh
    echo "(залишок = файли, які ми свідомо лишаємо untracked)"
}

case "${1:-apply}" in
    apply) do_apply "${2:-}" ; do_verify ;;
    verify) do_verify ;;
    *) echo "usage: $0 {apply|verify} [--yes]"; exit 2 ;;
esac
