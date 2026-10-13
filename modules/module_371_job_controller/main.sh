#!/data/data/com.termux/files/usr/bin/bash
D="$HOME/CYBRA/modules/module_371_job_controller"
B=$'\e[36m'; G=$'\e[32m'; N=$'\e[0m'
while :; do
  clear
  echo "${B}═══ Job Controller ═══${N}"
  echo
  python3 "$D/controller.py" cycle
  echo
  echo "  Daemon: $(pgrep -f 'module_371_job_controller/controller.py daemon' >/dev/null && echo "${G}● online${N}" || echo "○ offline")"
  echo
  echo "  1) Cycle   2) Log   3) Status   0) Назад"
  read -rp "  Вибір: " c
  case "$c" in
    1) python3 "$D/controller.py" cycle; read -rp "Enter…" _ ;;
    2) python3 "$D/controller.py" log 40; read -rp "Enter…" _ ;;
    3) python3 "$D/controller.py" status; read -rp "Enter…" _ ;;
    0) return ;;
  esac
done
