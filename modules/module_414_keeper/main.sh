#!/data/data/com.termux/files/usr/bin/bash
D="$HOME/CYBRA/modules/module_414_keeper"
B=$'\e[36m'; G=$'\e[32m'; N=$'\e[0m'
while :; do
  clear; echo "${B}═══ Resilient Keeper ═══${N}"
  python3 "$D/keeper.py" status
  echo "  Daemon: $(pgrep -f 'module_414_keeper/keeper.py loop' >/dev/null && echo "${G}● online${N}" || echo "○ offline")"
  echo
  echo "  1) Status     2) Servers    3) Test server"
  echo "  4) Лог        0) Назад"
  read -rp "  Вибір: " c
  case "$c" in
    1) python3 "$D/keeper.py" status; read -rp "Enter…" _ ;;
    2) python3 "$D/keeper.py" servers; read -rp "Enter…" _ ;;
    3) python3 "$D/keeper.py" test-server; read -rp "Enter…" _ ;;
    4) tail -40 "$HOME/CYBRA/logs/keeper.log" 2>/dev/null; read -rp "Enter…" _ ;;
    0) return ;;
  esac
done
