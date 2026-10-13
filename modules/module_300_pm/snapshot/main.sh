#!/data/data/com.termux/files/usr/bin/bash
# module_300_pm — Process Manager
B=$'\e[36m'; G=$'\e[32m'; Y=$'\e[33m'; R=$'\e[31m'; DIM=$'\e[2m'; N=$'\e[0m'
while :; do
  clear
  echo "${B}═══ Process Manager ═══${N}"
  echo
  cybra-pm list 2>&1 | sed 's/^/  /'
  echo
  echo "  ${G}1${N}) Start all   ${G}2${N}) Stop all   ${G}3${N}) Status"
  echo "  ${G}4${N}) Restart     ${G}5${N}) Logs       ${G}0${N}) Назад"
  read -rp "  Вибір: " c
  case "$c" in
    1) cybra-pm start-all; read -rp "Enter…" _ ;;
    2) read -rp "  Впевнено? yes: " a; [ "$a" = "yes" ] && cybra-pm stop-all; read -rp "Enter…" _ ;;
    3) cybra-pm status; read -rp "Enter…" _ ;;
    4) read -rp "  Process: " p; cybra-pm restart "$p"; read -rp "Enter…" _ ;;
    5) read -rp "  Process: " p; tail -30 "$HOME/CYBRA/logs/$p.log" 2>/dev/null; read -rp "Enter…" _ ;;
    0) return ;;
  esac
done
