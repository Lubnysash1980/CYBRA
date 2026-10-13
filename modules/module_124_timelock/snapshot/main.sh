#!/data/data/com.termux/files/usr/bin/bash
set -uo pipefail
D="$HOME/CYBRA/modules/module_124_timelock"
G=$'\e[32m'; Y=$'\e[33m'; R=$'\e[31m'; B=$'\e[36m'; DIM=$'\e[2m'; N=$'\e[0m'

menu(){
  while :; do
    clear
    echo "${B}═══ TimeLock (Solidity + локально) ═══${N}"
    echo
    # статус деплою
    if [ -f "$D/data/deployed.json" ]; then
      ADDR=$(python3 -c "
import json
try:
    d=json.load(open('$D/data/deployed.json'))
    for k,v in d.items(): print(v['address'])
except: pass
" 2>/dev/null | head -1)
      [ -n "$ADDR" ] && echo "  ${G}✓${N} Задеплоєно: ${ADDR:0:10}…${ADDR: -6}"
    else
      echo "  ${Y}!${N} Solidity контракт не задеплоєно (локальний JSON працює)"
    fi
    echo
    echo "  ${B}─── SOLIDITY ───${N}"
    echo "  ${G}1${N}) Компілювати TimeLock.sol"
    echo "  ${G}2${N}) Задеплоїти у BSC Testnet"
    echo "  ${G}3${N}) Задеплоїти у BSC Mainnet (попередження)"
    echo "  ${G}4${N}) Info про деплой"
    echo "  ${G}5${N}) Встановити deployer key"
    echo "  ${G}6${N}) Показати deployer адресу"
    echo
    echo "  ${B}─── ЛОКАЛЬНО (JSON) ───${N}"
    echo "  ${G}10${N}) Створити lock      ${G}11${N}) Скасувати"
    echo "  ${G}12${N}) Статус            ${G}13${N}) Список"
    echo "  ${G}14${N}) Tick"
    echo
    echo "  ${G}0${N}) Назад"
    echo
    read -rp "  Вибір: " c
    case "$c" in
      1) python3 "$D/build.py" TimeLock; read -rp "Enter…" _ ;;
      2) python3 "$D/deploy.py" deploy bsc_testnet; read -rp "Enter…" _ ;;
      3)
        read -rp "  ${R}Це MAINNET — реальні гроші. Продовжити? (yes/no):${N} " a
        [ "$a" = "yes" ] && python3 "$D/deploy.py" deploy bsc_mainnet
        read -rp "Enter…" _ ;;
      4) python3 "$D/deploy.py" info; read -rp "Enter…" _ ;;
      5) read -rsp "  Private key (0x…): " k; echo
         [ -n "$k" ] && python3 "$D/deploy.py" key "$k"
         read -rp "Enter…" _ ;;
      6) python3 "$D/deploy.py" address; read -rp "Enter…" _ ;;
      10) read -rp "CID: " cid; read -rp "Затримка (сек): " s
          python3 "$D/timelock.py" create "$cid" "$s"; read -rp "Enter…" _ ;;
      11) read -rp "CID: " cid; python3 "$D/timelock.py" cancel "$cid"; read -rp "Enter…" _ ;;
      12) read -rp "CID: " cid; python3 "$D/timelock.py" check "$cid"; read -rp "Enter…" _ ;;
      13) python3 "$D/timelock.py" list; read -rp "Enter…" _ ;;
      14) python3 "$D/timelock.py" tick; read -rp "Enter…" _ ;;
      0) return ;;
    esac
  done
}
menu
