#!/data/data/com.termux/files/usr/bin/bash
D="$HOME/CYBRA/modules/module_102_binmix_daemon"
B=$'\e[36m'; N=$'\e[0m'
while :; do
  clear
  echo "${B}═══ BinaryMixer ═══${N}"
  python3 "$D/binmix.py" status
  echo "  1) Змішати (mix now)  0) Назад"
  read -rp "  Вибір: " c
  case "$c" in
    1) python3 "$D/binmix.py" mix; read -rp "Enter…" _ ;;
    0) return ;;
  esac
done
