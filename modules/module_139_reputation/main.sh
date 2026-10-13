#!/data/data/com.termux/files/usr/bin/bash
D="$HOME/CYBRA/modules/module_139_reputation"
G=$'\e[32m'; B=$'\e[36m'; N=$'\e[0m'
while :; do
  clear; echo "${B}═══ Reputation On-chain ═══${N}"; echo
  echo "  1) Рейтинг учасника  2) Leaderboard"
  echo "  3) Поставити оцінку  4) Підготувати anchor TX"
  echo "  0) Назад"; echo
  read -rp "  Вибір: " c
  case "$c" in
    1) read -rp "Addr: " a; python3 "$D/reputation.py" score "$a"; read -rp "Enter…" _ ;;
    2) python3 "$D/reputation.py" leaderboard; read -rp "Enter…" _ ;;
    3) read -rp "Addr: " a; read -rp "CID: " cid; read -rp "Score 1-5: " s; read -rp "Comment: " cm
       python3 "$D/reputation.py" rate "$a" "$cid" "$s" "$cm"; read -rp "Enter…" _ ;;
    4) read -rp "Addr (кого): " a; read -rp "From (хто підписує TX): " f
       python3 "$D/reputation.py" anchor "$a" "$f"; read -rp "Enter…" _ ;;
    0) return ;;
  esac
done
