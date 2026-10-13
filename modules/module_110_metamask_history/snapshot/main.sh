#!/data/data/com.termux/files/usr/bin/bash
E="$HOME/CYBRA/modules/module_19_contract_tui_menu/evidence"
B="$HOME/CYBRA/backups"
B1=$'\e[36m'; D=$'\e[2m'; N=$'\e[0m'
echo "${B1}═══ Історія підписів ═══${N}"; echo
i=0
while read -r f; do
  [ -z "$f" ] && continue; i=$((i+1))
  printf "  %-3s %-24s %s\n" "$i" "$(basename "$f" _buyer.sig)" "$(wc -c < "$f")B"
done < <(ls -1t "$E"/*.sig 2>/dev/null)
echo; echo "  Всього: $i"; echo
echo "${B1}Бекапи:${N}"
ls -1dt "$B"/run_* 2>/dev/null | head -5 | sed 's|^|  |'
[ -L "$B/latest" ] && echo "  ${D}latest → $(readlink "$B/latest")${N}"
