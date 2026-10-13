#!/data/data/com.termux/files/usr/bin/bash
echo "========== CYBRA STATUS =========="
echo "Owner: $(cat "$HOME/CYBRA/.owner" 2>/dev/null || echo MISSING)"
echo ""

LATEST_LOG="$(ls -t "$HOME"/CYBRA/logs/mega_hardening_*.log 2>/dev/null | head -1)"

for d in "$HOME"/CYBRA/modules/*/; do
    [ -d "$d" ] || continue
    m=$(basename "$d")
    case "$m" in @*|.*|_disabled*|evolution|answer_engine|node_modules) continue ;; esac

    # Свіжий test log з audit
    tlog="$(ls -t "$HOME"/CYBRA/audit/*_"${m}".test.log 2>/dev/null | head -1)"

    if [ -n "$tlog" ] && [ -f "$tlog" ]; then
        p=$(grep -c '\[PASS\]' "$tlog" 2>/dev/null || true)
        f=$(grep -c '\[FAIL\]' "$tlog" 2>/dev/null || true)
    else
        p=$(cat "$HOME/CYBRA/baseline/${m}.pass" 2>/dev/null || echo 0)
        f=$(cat "$HOME/CYBRA/baseline/${m}.fail" 2>/dev/null || echo 0)
    fi

    t=$(cat "$HOME/CYBRA/baseline/${m}.tree" 2>/dev/null | cut -c1-12 || echo "?")
    printf "  %-45s PASS=%-4s FAIL=%-4s TREE=%s\n" "$m" "$p" "$f" "$t"
done

echo ""
echo "Last report:"
ls -t "$HOME"/CYBRA/audit/*_final_report.env 2>/dev/null | head -1
echo ""
echo "Last hardening log:"
echo "$LATEST_LOG"
