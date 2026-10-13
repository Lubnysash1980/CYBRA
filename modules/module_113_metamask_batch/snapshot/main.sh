#!/data/data/com.termux/files/usr/bin/bash
set -uo pipefail
H="$HOME/CYBRA"
E="$H/modules/module_19_contract_tui_menu/evidence"
B=$'\e[36m'; G=$'\e[32m'; R=$'\e[31m'; N=$'\e[0m'
N="${1:-}"
[ -z "$N" ] && read -rp "Скільки контрактів підписати? " N
[[ "$N" =~ ^[0-9]+$ ]] || { echo "${R}✗${N} треба число"; exit 1; }
echo "${B}Пакетний режим: $N контрактів${N}"
for i in $(seq 1 "$N"); do
  echo; echo "${B}── ${i}/${N} ──${N}"
  bash "$H/modules/module_108_metamask_sign/main.sh" || { echo "${R}✗${N} провал на $i"; break; }
  sleep 2
done
echo; echo "${G}✓${N} Готово"
