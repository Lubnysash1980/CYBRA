#!/data/data/com.termux/files/usr/bin/bash
D="$HOME/CYBRA/modules/module_97_evo_controller"
B=$'\e[36m'; N=$'\e[0m'
while :; do
  clear
  echo "${B}═══ EVO Controller + Exoskeleton ═══${N}"
  python3 "$D/exoskeleton.py" status
  echo "  1) Заблокувати (lock)  2) Перевірити  0) Назад"
  read -rp "  Вибір: " c
  case "$c" in
    1) python3 "$D/exoskeleton.py" lock; read -rp "Enter…" _ ;;
    2) python3 "$D/exoskeleton.py" status; read -rp "Enter…" _ ;;
    0) return ;;
  esac
done
