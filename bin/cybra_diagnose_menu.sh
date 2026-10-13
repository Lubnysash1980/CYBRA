#!/data/data/com.termux/files/usr/bin/bash
# Діагностика меню cybra

MENU="$HOME/CYBRA/modules/module_19_contract_tui_menu/bin/cybra_menu.sh"

if [ ! -f "$MENU" ]; then
    echo "[FAIL] cybra_menu.sh не знайдено"
    exit 1
fi

echo "═══════════════════════════════════════════════════════════"
echo " ДІАГНОСТИКА cybra_menu.sh"
echo "═══════════════════════════════════════════════════════════"
echo ""
echo "Файл: $MENU"
echo "Розмір: $(wc -l < "$MENU") рядків"
echo ""

echo "--- Синтаксис ---"
if bash -n "$MENU" 2>/dev/null; then
    echo "  [OK]"
else
    echo "  [FAIL]"
    bash -n "$MENU" 2>&1 | head -5
fi
echo ""

echo "--- Пункти які є ---"
grep -oE '\[[0-9]+\]' "$MENU" | sort -un | tr '\n' ' '
echo ""
echo ""

echo "--- Що бракує ---"
for n in 1 2 3 4 5 6 7 8 9 11 12 13 14 15 16 17 18 19 20 21 22 23 24 30 31 32 33 40 41 42 43 44 45 46 47 48 49 50 51 52 53 54 55 56 57 58 59 60 61 62 63 64 65 66 67 68 69 70 71 72 73 80 81 82 83 84 85 86 87 88 89 90 91 92 93 94 95 96 97; do
    if ! grep -q "\[$n\]" "$MENU"; then
        echo -n "  [$n] "
    fi
done
echo ""
echo ""

echo "--- Джерела ---"
grep -n "^source " "$MENU" | head -10
echo ""

echo "--- Функції ---"
echo "  action_create_contract:  $(grep -c '^action_create_contract()' "$MENU")"
echo "  action_self_heal:        $(grep -c '^action_self_heal()' "$MENU")"
echo "  action_dual_verify:      $(grep -c '^action_dual_verify()' "$MENU")"
echo "  action_gd_state:         $(grep -c '^action_gd_state()' "$MENU")"
echo "  action_as_save:          $(grep -c '^action_as_save()' "$MENU")"
echo ""

echo "--- print_menu ---"
if grep -q "^print_menu() {" "$MENU"; then
    START=$(grep -n "^print_menu() {" "$MENU" | head -1 | cut -d: -f1)
    END=$(awk -v start="$START" 'NR > start && /^\}/ {print NR; exit}' "$MENU")
    echo "  рядки $START - $END"
    echo "  рядків: $((END - START + 1))"
else
    echo "  [FAIL] не знайдено"
fi
echo ""

echo "--- main loop ---"
if grep -q "while true" "$MENU"; then
    L=$(grep -n "while true" "$MENU" | head -1 | cut -d: -f1)
    echo "  рядок $L"
else
    echo "  [FAIL] не знайдено"
fi
echo ""

echo "═══════════════════════════════════════════════════════════"
