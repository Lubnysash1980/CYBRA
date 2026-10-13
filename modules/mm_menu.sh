#!/data/data/com.termux/files/usr/bin/bash
H="$HOME/CYBRA"; REG="$H/modules/.registry"
B=$'\e[36m'; G=$'\e[32m'; R=$'\e[31m'; D=$'\e[2m'; N=$'\e[0m'
while :; do
  clear
  echo "${B}═══ CYBRA · MetaMask (пункти 108+) ═══${N}"
  echo
  while IFS='|' read -r id name entry desc; do
    [ -z "$id" ] && continue
    printf "  ${G}%s${N}  %-22s ${D}%s${N}\n" "$id" "$name" "$desc"
  done < "$REG"
  echo
  echo "  0   Назад"
  echo
  read -rp "Вибір: " c
  [ "$c" = "0" ] && break
  entry=$(grep "^$c|" "$REG" | cut -d'|' -f3)
  [ -z "$entry" ] && { echo "${R}нема пункту $c${N}"; sleep 1; continue; }
  bash "$H/modules/$entry"
  echo; read -rp "Enter…" _
done
