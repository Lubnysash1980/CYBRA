#!/data/data/com.termux/files/usr/bin/bash
D="$HOME/CYBRA/modules/module_138_arbitration"
G=$'\e[32m'; B=$'\e[36m'; N=$'\e[0m'
while :; do
  clear; echo "${B}═══ Arbitration Module ═══${N}"; echo
  echo "  ${G}1${N}) Правила           ${G}2${N}) Оцінити ситуацію"
  echo "  ${G}3${N}) Додати правило"
  echo; echo "  ${G}0${N}) Назад"; echo
  read -rp "  Вибір: " c
  case "$c" in
    1) python3 "$D/arbitration.py" rules; read -rp "Enter…" _ ;;
    2) read -rp "Deviation % [Enter=skip]: " d
       read -rp "Proof present (yes/no): " p
       read -rp "Both confirm (yes/no): " b
       CTX="{"
       [ -n "$d" ] && CTX="$CTX\"deviation_pct\":$d,"
       [ -n "$p" ] && CTX="$CTX\"proof_present\":$([ "$p" = "yes" ] && echo true || echo false),"
       [ -n "$b" ] && CTX="$CTX\"both_confirm\":$([ "$b" = "yes" ] && echo true || echo false),"
       CTX="${CTX%,}}"
       python3 "$D/arbitration.py" eval "$CTX"
       read -rp "Enter…" _ ;;
    3) read -rp "ID: " i; read -rp "Умова: " cnd; read -rp "Дія: " a
       python3 "$D/arbitration.py" add "$i" "$cnd" "$a"; read -rp "Enter…" _ ;;
    0) return ;;
  esac
done
