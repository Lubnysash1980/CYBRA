#!/data/data/com.termux/files/usr/bin/bash
set -uo pipefail
D="$HOME/CYBRA/modules/module_120_ai_guardian"
G=$'\e[32m'; Y=$'\e[33m'; R=$'\e[31m'; B=$'\e[36m'; DIM=$'\e[2m'; N=$'\e[0m'

menu(){
  while :; do
    clear
    echo "${B}═══ AI Guardian · єдина система перевірки CYBRA ═══${N}"
    echo
    echo "  ${G}1${N}) Перевірити (dry-run, нічого не змінює)"
    echo "  ${G}2${N}) AutoHeal — лікує все безпечне автоматично"
    echo "  ${G}3${N}) Heal — показати пропозиції (за підтвердженням)"
    echo "  ${G}4${N}) Повна діагностика (verbose)"
    echo "  ${G}5${N}) Історія інцидентів"
    echo "  ${G}6${N}) Аналітика (що падало, що лікувалось)"
    echo "  ${G}7${N}) Останній звіт"
    echo
    echo "  ${G}0${N}) Назад"
    echo
    read -rp "  Вибір: " c
    case "$c" in
      1) python3 "$D/guardian.py" run ;;
      2) python3 "$D/guardian.py" run --auto; echo; read -rp "Enter…" _ ;;
      3) python3 "$D/guardian.py" run --heal; echo; read -rp "Enter…" _ ;;
      4) python3 "$D/guardian.py" run -v ;;
      5) python3 "$D/guardian.py" history -n 30; echo; read -rp "Enter…" _ ;;
      6) python3 "$D/guardian.py" summary; echo; read -rp "Enter…" _ ;;
      7) ls -1t "$D/backups"/report_*.json 2>/dev/null | head -1 | xargs -r cat | head -60; echo; read -rp "Enter…" _ ;;
      0) return ;;
    esac
    echo; read -rp "Enter…" _ 2>/dev/null || true
  done
}

case "${1:-menu}" in
  menu|"") menu ;;
  *) shift; python3 "$D/guardian.py" "$@" ;;
esac
