#!/data/data/com.termux/files/usr/bin/bash
D="$HOME/CYBRA/modules/module_144_lightning"
B=$'\e[36m'; G=$'\e[32m'; N=$'\e[0m'
while :; do
  clear; echo "${B}═══ Bitcoin Lightning ═══${N}"; echo
  echo "  1) Setup (URL + API key)"
  echo "  2) Баланс"
  echo "  3) Створити invoice (sats)"
  echo "  4) Перевірити payment"
  echo "  0) Назад"; echo
  read -rp "  Вибір: " c
  case "$c" in
    1) echo "  Реєстрація: https://legend.lnbits.com"
       read -rp "  URL [https://legend.lnbits.com]: " u; u="${u:-https://legend.lnbits.com}"
       read -rp "  Invoice/Admin key: " k
       python3 "$D/ln.py" setup "$u" "$k"; read -rp "Enter…" _ ;;
    2) python3 "$D/ln.py" balance; read -rp "Enter…" _ ;;
    3) read -rp "  Сума (sats): " a; read -rp "  Memo: " m
       python3 "$D/ln.py" invoice "$a" "$m"; read -rp "Enter…" _ ;;
    4) read -rp "  Payment hash: " h; python3 "$D/ln.py" check "$h"; read -rp "Enter…" _ ;;
    0) return ;;
  esac
done
