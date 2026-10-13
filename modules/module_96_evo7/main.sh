#!/data/data/com.termux/files/usr/bin/bash
D="$HOME/CYBRA/modules/module_96_evo7"
B=$'\e[36m'; N=$'\e[0m'
while :; do
  clear
  echo "${B}═══ EVO7 — LevelController ═══${N}"
  python3 "$D/level_controller.py" status
  echo "  1) Спробувати підвищити рівень  0) Назад"
  read -rp "  Вибір: " c
  case "$c" in
    1) python3 "$D/level_controller.py" advance; read -rp "Enter…" _ ;;
    0) return ;;
  esac
done
