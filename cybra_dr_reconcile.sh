#!/data/data/com.termux/files/usr/bin/bash
set -Eeuo pipefail

ROOT="$HOME/CYBRA"; cd "$ROOT"

REPORT_DIR="hash_ecosystem/disaster_recovery_tests"
EVIDENCE_DIR="orders/ROBOTICS-UA-0001/evidence"
GI=".gitignore"
MENU_SH="node_cybra/bin/cybra_ai_bar.sh"

do_diag() {
    echo "============================================================"
    echo " DIAG — звідки меню бере хеші"
    echo "============================================================"

    echo
    echo "--- menu lines 55-85 ---"
    sed -n '55,85p' "$MENU_SH"

    echo
    echo "--- які шляхи у змінних ---"
    grep -nE 'DNA_MANIFEST=|RECOVERY_BASELINE=' "$MENU_SH" || echo "(не знайдено)"

    echo
    echo "--- перевірка: файл-хеш vs меню-числа ---"
    M="$(grep -oP 'DNA_MANIFEST="\K[^"]+' "$MENU_SH" | head -1)"
    B="$(grep -oP 'RECOVERY_BASELINE="\K[^"]+' "$MENU_SH" | head -1)"
    [ -n "$M" ] && M="${M/#\~/$HOME}" && M="${M//\$ROOT/$ROOT}"
    [ -n "$B" ] && B="${B/#\~/$HOME}" && B="${B//\$ROOT/$ROOT}"

    echo "resolved DNA_MANIFEST    = ${M:-<не розпізнано>}"
    echo "resolved RECOVERY_BASELINE = ${B:-<не розпізнано>}"

    if [ -f "$M" ]; then
        echo "  sha256(file) = $(sha256sum "$M" | awk '{print $1}')"
    fi
    if [ -f "$B" ]; then
        echo "  sha256(file) = $(sha256sum "$B" | awk '{print $1}')"
    fi

    echo
    echo "--- наш DR-контур (для порівняння) ---"
    python3 - <<'PY'
import json
g=json.load(open("hash_ecosystem/global_runtime_state.json"))["disaster_recovery_baseline"]
print(f"our reference_sha256 = {g['reference_sha256']}")
print(f"our dna_hash_before  = {g.get('dna_hash_before','?')}")
print(f"our dna_hash_after   = {g.get('dna_hash_after','?')}")
PY

    echo
    echo "--- що змінило джерело між 211509 і HEAD ---"
    OLD="hash_ecosystem/disaster_recovery_tests/test_20260919T211509Z.json"
    if [ -f "$OLD" ]; then
        echo "  software files newer than $OLD:"
        find . -maxdepth 1 -newer "$OLD" \
          \( -name 'cybra_ai_master_orchestrator.py' \
             -o -name 'robotics_ai_execute_verify_patch.sh' \
             -o -name 'robotics_verify_now.sh' \
             -o -name 'real_executor.py' \) -type f 2>/dev/null | sed 's/^/    /' || true

        echo "  DNA files newer than $OLD:"
        find hash_ecosystem/self_recovery_dna -type f -newer "$OLD" 2>/dev/null | sed 's/^/    /' || true

        echo "  orders files newer than $OLD:"
        find orders/ROBOTICS-UA-0001 -type f -newer "$OLD" 2>/dev/null | head -10 | sed 's/^/    /' || true
    fi
}

do_tidy() {
    echo "============================================================"
    echo " TIDY — untracked DR reports"
    echo "============================================================"

    # які репорти на диску, які зареєстровані (у source_report ai_tasks)
    local keep_report
    keep_report="$(python3 - <<'PY'
import json
try:
    t=json.load(open("hash_ecosystem/ai_tasks/AI-CYBRA-DISASTER-RECOVERY-100-001.json"))
    print(t.get("source_report",""))
except Exception:
    print("")
PY
)"
    echo "registered source_report = ${keep_report:-<none>}"

    echo
    echo "--- untracked test_*.json ---"
    local to_rm=()
    while IFS= read -r f; do
        [ -n "$f" ] || continue
        if [ "$f" = "$keep_report" ]; then
            echo "  KEEP (registered)   $f"
        else
            echo "  will remove         $f"
            to_rm+=("$f")
        fi
    done < <(git ls-files --others --exclude-standard -- "$REPORT_DIR"/test_*.json)

    echo
    echo "--- untracked registry (AI-CYBRA-..._*.json) ---"
    local reg_rm=()
    while IFS= read -r f; do
        [ -n "$f" ] || continue
        echo "  will remove         $f"
        reg_rm+=("$f")
    done < <(git ls-files --others --exclude-standard -- "$REPORT_DIR"/AI-CYBRA-DISASTER-RECOVERY-100-001_*.json)

    echo
    echo "--- untracked evidence ---"
    local evi_rm=()
    while IFS= read -r f; do
        [ -n "$f" ] || continue
        echo "  will remove         $f"
        evi_rm+=("$f")
    done < <(git ls-files --others --exclude-standard -- "$EVIDENCE_DIR"/AI-CYBRA-DISASTER-RECOVERY-100-001_*.json)

    # safety: не видаляємо без підтвердження
    local total=$(( ${#to_rm[@]} + ${#reg_rm[@]} + ${#evi_rm[@]} ))
    if [ "$total" -eq 0 ]; then
        echo
        echo "NOTHING TO REMOVE"
    else
        echo
        echo "TOTAL TO REMOVE: $total"
        local ans="n"
        [ "${1:-}" = "--yes" ] && ans="y"
        [ "$ans" != "y" ] && read -r -p "remove these untracked? [y/N] " ans
        if [ "$ans" = "y" ] || [ "$ans" = "Y" ]; then
            for f in "${to_rm[@]}" "${reg_rm[@]}" "${evi_rm[@]}"; do
                rm -f "$f"; echo "removed: $f"
            done
        else
            echo "kept"
        fi
    fi

    # extend .gitignore to prevent future untracked DR dumps
    echo
    echo "--- .gitignore: DR test-run dumps ---"
    if ! grep -q "CYBRA DR — test-run dumps" "$GI" 2>/dev/null; then
        local stamp
        stamp="$(date -u +%Y%m%dT%H%M%SZ)"
        cp -a "$GI" "$GI.bak_$stamp"
        echo "backup: $GI.bak_$stamp"

        cat >> "$GI" <<'IGN'

# CYBRA DR — test-run dumps (не комітити сирі прогони)
hash_ecosystem/disaster_recovery_tests/test_2026*.json
hash_ecosystem/disaster_recovery_tests/AI-CYBRA-DISASTER-RECOVERY-100-001_2026*.json
orders/ROBOTICS-UA-0001/evidence/AI-CYBRA-DISASTER-RECOVERY-100-001_2026*.json
runtime/disaster_recovery_test/
IGN
        # негативні винятки — залишити зареєстрований (актуальний) репорт
        if [ -n "$keep_report" ]; then
            printf '!%s\n' "$keep_report" >> "$GI"
        fi
        # і зареєстрований registry/evidence
        local keep_reg keep_evi
        keep_reg="$(python3 - <<'PY'
import json, os
try:
    t=json.load(open("hash_ecosystem/ai_tasks/AI-CYBRA-DISASTER-RECOVERY-100-001.json"))
    sr=t.get("source_report","")
    if sr and os.path.exists(sr):
        base=os.path.basename(sr).replace("test_","AI-CYBRA-DISASTER-RECOVERY-100-001_")
        print("hash_ecosystem/disaster_recovery_tests/"+base)
except Exception:
    pass
PY
)"
        echo "IGNORE: DR dumps block appended"
    else
        echo "IGNORE: block already present"
    fi
}

do_verify() {
    echo
    echo "============================================================"
    echo " VERIFY"
    echo "============================================================"

    echo
    echo "--- DR dirs status ---"
    git status --short -- \
        "$REPORT_DIR" \
        "$EVIDENCE_DIR" \
        hash_ecosystem/self_recovery_dna \
        hash_ecosystem/ai_tasks/AI-CYBRA-DISASTER-RECOVERY-100-001.json \
        hash_ecosystem/global_runtime_state.json \
        "$GI"
    echo "(порожньо = чисто)"

    echo
    echo "--- .gitignore DR блоки ---"
    grep -c "CYBRA DR" "$GI" || echo "0"

    echo
    echo "--- HEAD ---"
    GIT_PAGER=cat git --no-pager log --oneline -3
}

case "${1:-all}" in
    diag)    do_diag ;;
    tidy)    do_tidy "${2:-}" ;;
    verify)  do_verify ;;
    all)
        do_diag
        echo
        do_tidy "${2:-}"
        echo
        do_verify
        ;;
    *) echo "usage: $0 {diag|tidy|verify|all} [--yes]"; exit 2 ;;
esac
