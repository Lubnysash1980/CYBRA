#!/data/data/com.termux/files/usr/bin/bash
D="$HOME/CYBRA/modules/module_407_intent"
B=$'\e[36m'; G=$'\e[32m'; N=$'\e[0m'
while :; do
  clear; echo "${B}═══ Intent Engine ═══${N}"
  python3 "$D/engine.py" list
  echo
  echo "  1) Розпізнати текст"
  echo "  2) ${G}Навчити${N} (text → action)"
  echo "  0) Назад"
  read -rp "  Вибір: " c
  case "$c" in
    1) read -rp "  Текст: " t; python3 "$D/engine.py" match "$t"; read -rp "Enter…" _ ;;
    2) read -rp "  Текст: " t; read -rp "  Action: " a; python3 "$D/engine.py" learn "$t" "$a"; read -rp "Enter…" _ ;;
    0) return ;;
  esac
done
