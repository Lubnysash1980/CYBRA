#!/data/data/com.termux/files/usr/bin/bash
D="$HOME/CYBRA/modules/module_141_portfolio"
G=$'\e[32m'; B=$'\e[36m'; D_=$'\e[2m'; N=$'\e[0m'
CFG="$HOME/CYBRA/config/metamask.env"; [ -f "$CFG" ] && . "$CFG"
MY="${BUYER_ADDR:-}"
# авто-додати мій гаманець при першому запуску
[ -n "$MY" ] && ! grep -q "$MY" "$D/data/wallets.json" 2>/dev/null && \
  python3 "$D/portfolio.py" add "$MY" "Main" "bsc,eth" >/dev/null 2>&1

while :; do
  clear; echo "${B}═══ Portfolio Tracker ═══${N}"; echo
  echo "  ${G}1${N}) Оновити (snapshot зараз)"
  echo "  ${G}2${N}) Список гаманців     ${G}3${N}) Додати гаманець"
  echo "  ${G}4${N}) P&L (історія)"
  echo "  ${G}0${N}) Назад"; echo
  read -rp "  Вибір: " c
  case "$c" in
    1) python3 "$D/portfolio.py" snapshot; read -rp "Enter…" _ ;;
    2) python3 "$D/portfolio.py" list; read -rp "Enter…" _ ;;
    3) read -rp "Адреса: " a; read -rp "Мітка: " l
       read -rp "Мережі [bsc,eth]: " n; n="${n:-bsc,eth}"
       python3 "$D/portfolio.py" add "$a" "$l" "$n"; read -rp "Enter…" _ ;;
    4) python3 -c "
import sys; sys.path.insert(0,'$D'); import portfolio
p = portfolio.pnl()
if not p: print('  (недостатньо історії)')
else:
    G='\033[32m'; R='\033[31m'; N='\033[0m'
    col = G if p['delta_usd']>=0 else R
    print(f\"  Від:  {p['first_ts']}  \${p['first_usd']:.2f}\")
    print(f\"  До:   {p['last_ts']}  \${p['last_usd']:.2f}\")
    print(f\"  P&L:  {col}{p['delta_usd']:+.2f} USD ({p['delta_pct']:+.1f}%){N}\")
"; read -rp "Enter…" _ ;;
    0) return ;;
  esac
done
