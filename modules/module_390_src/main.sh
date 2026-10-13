#!/data/data/com.termux/files/usr/bin/bash
D="$HOME/CYBRA/modules/module_390_src"
B=$'\e[36m'; G=$'\e[32m'; N=$'\e[0m'
while :; do
  clear; echo "${B}═══ Self-Recovery Controller ═══${N}"
  python3 "$D/src.py" status
  echo "  Daemon: $(pgrep -f 'module_390_src/src.py daemon' >/dev/null && echo "${G}● online${N}" || echo "○ offline")"
  echo
  echo "  ${B}─── CASCADE ───${N}"
  python3 "$D/cascade.py" status
  echo "  1) Snapshot зараз    2) Checkpoint"
  echo "  3) Цикл (test)       4) Recover з checkpoint"
  echo "  5) Cascade force     6) Remote (git URL)"
  echo "  7) Log               8) Cascade status"
  echo "  0) Назад"
  read -rp "  Вибір: " c
  case "$c" in
    1) python3 "$D/src.py" snapshot; read -rp "Enter…" _ ;;
    2) python3 "$D/src.py" checkpoint; read -rp "Enter…" _ ;;
    3) python3 "$D/src.py" cycle; read -rp "Enter…" _ ;;
    4) read -rp "  Точно recover? (yes): " a; [ "$a" = "yes" ] && python3 "$D/src.py" recover; read -rp "Enter…" _ ;;
    5) python3 "$D/cascade.py" force; read -rp "Enter…" _ ;;
    6) read -rp "  git remote URL: " u; python3 "$D/src.py" set-remote "$u"; read -rp "Enter…" _ ;;
    7) python3 "$D/src.py" log 40; read -rp "Enter…" _ ;;
    8) python3 "$D/src.py" cascade; read -rp "Enter…" _ ;;
    0) return ;;
  esac
done
