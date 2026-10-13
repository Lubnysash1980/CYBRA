#!/data/data/com.termux/files/usr/bin/bash
D="$HOME/CYBRA/modules/module_152_doctor"
while :; do
  clear
  python3 "$D/doctor.py" "$@"
  echo "  1) Auto-fix  2) Повторно  0) Назад"
  read -rp "  Вибір: " c
  case "$c" in
    1) python3 "$D/doctor.py" --fix; read -rp "Enter…" _ ;;
    2) continue ;;
    0) return ;;
  esac
done
