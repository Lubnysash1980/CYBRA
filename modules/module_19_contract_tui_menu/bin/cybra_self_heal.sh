#!/data/data/com.termux/files/usr/bin/bash
# CYBRA SELF-HEAL — автовідновлення пошкоджених файлів

set -u

ROOT="$HOME/CYBRA"
MOD="$ROOT/modules/module_19_contract_tui_menu"
BACKUP="$MOD/backups"
SNAPSHOT="$MOD/snapshot"

mkdir -p "$BACKUP" "$SNAPSHOT"

HEALED=0

heal_file() {
    local name="$1"
    local live="$MOD/bin/$name"
    local snap="$SNAPSHOT/$name"
    local bak="$BACKUP/$name"

    if [ -f "$live" ] && bash -n "$live" 2>/dev/null; then
        # Живий файл OK — оновлюємо backup
        cp "$live" "$bak" 2>/dev/null || true
        return 0
    fi

    # Спроба відновити
    printf '  [HEAL] %s — пошкоджено, відновлюю...\n' "$name"

    if [ -f "$snap" ] && bash -n "$snap" 2>/dev/null; then
        cp "$snap" "$live"
        printf '    → відновлено з snapshot\n'
        HEALED=$((HEALED+1))
        return 0
    fi

    if [ -f "$bak" ] && bash -n "$bak" 2>/dev/null; then
        cp "$bak" "$live"
        printf '    → відновлено з backup\n'
        HEALED=$((HEALED+1))
        return 0
    fi

    printf '    → %s[FAIL]%s немає валідної копії\n' $'\033[31m' $'\033[0m'
    return 1
}

cybra_self_heal() {
    printf '=== CYBRA SELF-HEAL ===\n'

    for f in cybra_tui_lib.sh cybra_menu.sh; do
        heal_file "$f"
    done

    # Решта файлів
    for f in "$MOD"/bin/*.sh; do
        [ -f "$f" ] || continue
        local name="$(basename "$f")"
        [ "$name" = "cybra_tui_lib.sh" ] || [ "$name" = "cybra_menu.sh" ] && continue

        # Просто перевіряємо синтаксис
        if ! bash -n "$f" 2>/dev/null; then
            printf '  [WARN] %s — syntax error\n' "$name"
        fi
    done

    printf -- '----------------\n'
    if [ "$HEALED" -eq 0 ]; then
        printf '  ✓ Все OK\n'
    else
        printf '  Healed: %s\n' "$HEALED"
    fi
}

if [ "${BASH_SOURCE[0]}" = "$0" ]; then
    cybra_self_heal
fi
