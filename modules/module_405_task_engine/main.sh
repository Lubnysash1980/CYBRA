#!/data/data/com.termux/files/usr/bin/bash
D="$HOME/CYBRA/modules/module_405_task_engine"
B=$'\e[36m'; G=$'\e[32m'; N=$'\e[0m'
while :; do
  clear
  echo "${B}═══ Task Engine ═══${N}"
  echo
  python3 "$D/engine.py" stats 2>/dev/null | head -20
  echo
  echo "  ${B}Останні задачі:${N}"
  python3 "$D/engine.py" tasks 2>/dev/null | head -10
  echo
  echo "  1) Detect issues"
  echo "  2) ${G}Cycle (5 tasks)${N}"
  echo "  3) Cycle (20 tasks)"
  echo "  4) Tasks list"
  echo "  0) Назад"
  read -rp "  Вибір: " c
  case "$c" in
    1) python3 "$D/engine.py" detect; read -rp "Enter…" _ ;;
    2) python3 "$D/engine.py" cycle 5; read -rp "Enter…" _ ;;
    3) python3 "$D/engine.py" cycle 20; read -rp "Enter…" _ ;;
    4) python3 "$D/engine.py" tasks; read -rp "Enter…" _ ;;
    0) return ;;
  esac
done
