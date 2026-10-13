#!/data/data/com.termux/files/usr/bin/bash
# Показує статус: AutoHeal + DualBackend + Snapshot

ROOT="$HOME/CYBRA"
M19="$ROOT/modules/module_19_contract_tui_menu"
M20="$ROOT/modules/module_20_evolution_guard"
M35="$ROOT/modules/module_35_cybra_guardian"

hr() { printf -- '────────────────────────────────────────────────────────────\n'; }
head1() {
    printf -- '\n════════════════════════════════════════════════════════════\n'
    printf -- ' %s\n' "$*"
    printf -- '════════════════════════════════════════════════════════════\n'
}

# ═══════════════════════════════════════════════════════════
# 1. AUTOHEAL
# ═══════════════════════════════════════════════════════════
head1 "1. AUTOHEAL — автовідновлення"

echo "Файл: $M19/bin/cybra_self_heal.sh"
if [ -f "$M19/bin/cybra_self_heal.sh" ]; then
    echo "  [OK] існує"
    bash -n "$M19/bin/cybra_self_heal.sh" 2>/dev/null && echo "  [OK] syntax OK"

    echo ""
    echo "Backups:"
    ls -lt "$M19/bin/"*.bak.* 2>/dev/null | head -3 | awk '{print "  "$9}'

    echo ""
    echo "Запуск self-heal:"
    source "$M19/bin/cybra_self_heal.sh"
    cybra_self_heal 2>&1 | sed 's/^/  /'
else
    echo "  [FAIL] не знайдено"
fi

# ═══════════════════════════════════════════════════════════
# 2. DUAL BACKEND
# ═══════════════════════════════════════════════════════════
head1 "2. DUAL BACKEND"

echo "Найновіший dual snapshot:"
LATEST_DB="$(ls -td "$ROOT"/hashes/*/ 2>/dev/null | head -1)"
if [ -n "$LATEST_DB" ] && [ -f "${LATEST_DB}dual_snapshot.env" ]; then
    cat "${LATEST_DB}dual_snapshot.env" | grep -E '^(BACKEND|DUAL|ULTRA|RUN|STAMP)' | sed 's/^/  /'
else
    echo "  [FAIL] немає dual snapshot"
fi

echo ""
echo "Функції в lib:"
if [ -f "$M19/bin/cybra_tui_lib.sh" ]; then
    grep -q "cybra_contract_compute_dual_hash" "$M19/bin/cybra_tui_lib.sh" && echo "  [OK] compute_dual_hash" || echo "  [FAIL] missing"
    grep -q "cybra_contract_verify_dual" "$M19/bin/cybra_tui_lib.sh" && echo "  [OK] verify_dual" || echo "  [FAIL] missing"
fi

echo ""
echo "Dual-backend для контрактів (останні 5):"
for f in $(ls -t "$M19/contracts"/*.env 2>/dev/null | head -5); do
    CID="$(basename "$f" .env)"
    A="$(grep -m1 '^BACKEND_A_HASH=' "$f" 2>/dev/null | cut -d= -f2 | cut -c1-12)"
    B="$(grep -m1 '^BACKEND_B_HASH=' "$f" 2>/dev/null | cut -d= -f2 | cut -c1-12)"
    D="$(grep -m1 '^DUAL_HASH=' "$f" 2>/dev/null | cut -d= -f2 | cut -c1-12)"
    printf "  %s\n" "$CID"
    printf "    A=%s  B=%s  DUAL=%s\n" "${A:-NONE}" "${B:-NONE}" "${D:-NONE}"
done

# ═══════════════════════════════════════════════════════════
# 3. SNAPSHOT SYSTEM
# ═══════════════════════════════════════════════════════════
head1 "3. SNAPSHOT SYSTEM"

echo "Module snapshots (final_manifest.sha256):"
TOTAL=0
SEALED=0
for d in "$ROOT/modules"/*/; do
    [ -d "$d" ] || continue
    m="$(basename "$d")"
    case "$m" in @*|.*|_disabled*|evolution|answer_engine|node_modules) continue ;; esac

    snap=""
    for s in "$d/snapshot" "$d/snapshots"; do
        [ -d "$s" ] && { snap="$s"; break; }
    done
    [ -z "$snap" ] && continue

    TOTAL=$((TOTAL+1))
    if [ -f "$snap/final_manifest.sha256" ]; then
        if (cd "$snap" && sha256sum -c final_manifest.sha256 >/dev/null 2>&1); then
            SEALED=$((SEALED+1))
            printf "  [OK]   %s\n" "$m"
        else
            printf "  [BROKEN] %s\n" "$m"
        fi
    else
        printf "  [NONE] %s\n" "$m"
    fi
done

echo ""
echo "  Sealed: $SEALED / $TOTAL"

echo ""
echo "Guardian recovery snapshots:"
if [ -f "$M35/recovery/snapshots.list" ]; then
    wc -l "$M35/recovery/snapshots.list" | awk '{print "  Total: "$1}'
    tail -3 "$M35/recovery/snapshots.list" | sed 's/^/  /'
else
    echo "  [WARN] немає recovery snapshots"
fi

echo ""
echo "Contract archives (autosave):"
if [ -d "$M35/data/contracts_archive" ]; then
    ls "$M35/data/contracts_archive"/*.tar.gz 2>/dev/null | wc -l | awk '{print "  Total: "$1}'
    ls -lt "$M35/data/contracts_archive"/*.tar.gz 2>/dev/null | head -3 | awk '{print "  "$9" ("$5")"}'
else
    echo "  [WARN] немає архіву"
fi

# ═══════════════════════════════════════════════════════════
# ФУНКЦІЇ В МЕНЮ
# ═══════════════════════════════════════════════════════════
head1 "Пункти в cybra"

MENU="$M19/bin/cybra_menu.sh"
if [ -f "$MENU" ]; then
    echo "AutoHeal:"
    grep -q "\[31\]" "$MENU" && echo "  [OK] [31] Self-heal" || echo "  [FAIL] missing"
    grep -q "\[32\]" "$MENU" && echo "  [OK] [32] Dual-backend verify" || echo "  [FAIL] missing"

    echo ""
    echo "Guardian:"
    grep -q "\[86\]" "$MENU" && echo "  [OK] [86] Snapshot зараз" || echo "  [FAIL] missing"
    grep -q "\[87\]" "$MENU" && echo "  [OK] [87] Відновити з git" || echo "  [FAIL] missing"
    grep -q "\[88\]" "$MENU" && echo "  [OK] [88] Відновити з snapshot" || echo "  [FAIL] missing"
    grep -q "\[89\]" "$MENU" && echo "  [OK] [89] AUTO-recovery" || echo "  [FAIL] missing"

    echo ""
    echo "Autosave:"
    grep -q "\[92\]" "$MENU" && echo "  [OK] [92] Зберегти контракт" || echo "  [FAIL] missing"
    grep -q "\[95\]" "$MENU" && echo "  [OK] [95] Відновити контракт" || echo "  [FAIL] missing"
fi

head1 "ГОТОВО"

echo ""
echo "Запуск команд:"
echo "  cybra_self_heal.sh <module>     — відновлення"
echo "  cybra → [31]                    — self-heal"
echo "  cybra → [32]                    — dual-backend verify"
echo "  cybra → [86]                    — snapshot зараз"
echo "  cybra → [89]                    — auto-recovery"
echo ""
