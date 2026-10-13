#!/data/data/com.termux/files/usr/bin/bash
D="$HOME/CYBRA/modules/module_135_walletconnect"
G=$'\e[32m'; B=$'\e[36m'; D=$'\e[2m'; N=$'\e[0m'
while :; do
  clear; echo "${B}═══ WalletConnect / Deep-Links ═══${N}"; echo
  echo "  ${G}1${N}) Показати всі deep-links для URL"
  echo "  ${G}2${N}) Відкрити конкретний гаманець"
  echo "  ${G}3${N}) Відкрити останній туннель (auto)"
  echo "  ${G}0${N}) Назад"
  echo
  read -rp "  Вибір: " c
  case "$c" in
    1) read -rp "URL: " u; python3 "$D/wc.py" all "$u"; read -rp "Enter…" _ ;;
    2) read -rp "Wallet: " w; read -rp "URL: " u
       python3 "$D/wc.py" open "$w" "$u"; read -rp "Enter…" _ ;;
    3) U=$(grep -hoE 'https://[a-z0-9-]+\.trycloudflare\.com' "$HOME/CYBRA/public/sign/"tunnel_*.log 2>/dev/null | sort -u | head -1)
       [ -z "$U" ] && { echo "немає активних тунелів"; read -rp "Enter…" _; continue; }
       echo "Знайдено: $U"
       python3 "$D/wc.py" all "$U"
       read -rp "Enter…" _
       ;;
    0) return ;;
  esac
done
