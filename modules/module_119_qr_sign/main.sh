#!/data/data/com.termux/files/usr/bin/bash
D="$HOME/CYBRA/modules/module_119_qr_sign"
B=$'\e[36m'; G=$'\e[32m'; N=$'\e[0m'
while :; do
  clear; echo "${B}═══ QR Sign ═══${N}"
  python3 "$D/cli.py" levels 2>/dev/null
  echo
  echo "  1) Тест   0) Назад"
  read -rp "  Вибір: " c
  case "$c" in
    1) python3 "$D/zk.py" selftest 2>/dev/null || echo "  (треба 119 поки не готовий)"; read -rp "Enter…" _ ;;
    0) return ;;
  esac
done
