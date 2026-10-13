#!/data/data/com.termux/files/usr/bin/bash
D="$HOME/CYBRA/modules/module_401_cascade_verify"
B=$'\e[36m'; G=$'\e[32m'; N=$'\e[0m'
while :; do
  clear; echo "${B}═══ Cascade Verifier ═══${N}"
  echo
  python3 "$D/verify.py" test
  echo "  1) Check   2) Hash   3) JSON   0) Назад"
  read -rp "  Вибір: " c
  case "$c" in
    1) python3 "$D/verify.py" check; read -rp "Enter…" _ ;;
    2) python3 "$D/verify.py" hash; read -rp "Enter…" _ ;;
    3) python3 "$D/verify.py" json | head -40; read -rp "Enter…" _ ;;
    0) return ;;
  esac
done
