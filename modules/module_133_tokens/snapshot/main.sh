#!/data/data/com.termux/files/usr/bin/bash
D="$HOME/CYBRA/modules/module_133_tokens"; CFG="$HOME/CYBRA/config/metamask.env"
[ -f "$CFG" ] && . "$CFG"; MY="${BUYER_ADDR:-0x29fA26FC5768Fe1E62160E021Fd3f88d92257A1F}"
B=$'\e[36m'; N=$'\e[0m'
while :; do
  clear; echo "${B}═══ Multi-chain Tokens ═══${N}"; echo
  echo "  1) Перевірити адресу (bsc)"
  echo "  2) Перевірити адресу (eth)"
  echo "  3) Мій гаманець"
  echo "  0) Назад"; echo
  read -rp "  Вибір: " c
  case "$c" in
    1) read -rp "Addr: " a; python3 "$D/tokens.py" "$a" bsc; read -rp "Enter…" _ ;;
    2) read -rp "Addr: " a; python3 "$D/tokens.py" "$a" eth; read -rp "Enter…" _ ;;
    3) python3 "$D/tokens.py" "$MY" bsc; read -rp "Enter…" _ ;;
    0) return ;;
  esac
done
