#!/data/data/com.termux/files/usr/bin/bash
D="$HOME/CYBRA/modules/module_399_gate"
B=$'\e[36m'; G=$'\e[32m'; N=$'\e[0m'
while :; do
  clear
  python3 "$D/gate.py" status
  echo "  1) Тест дії   2) Лог   0) Назад"
  read -rp "  Вибір: " c
  case "$c" in
    1) read -rp "  Дія (git_push/contract_sign/heal/...): " a
       python3 "$D/gate.py" allow "$a"; read -rp "Enter…" _ ;;
    2) python3 "$D/gate.py" log; read -rp "Enter…" _ ;;
    0) return ;;
  esac
done
