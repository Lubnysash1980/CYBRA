#!/data/data/com.termux/files/usr/bin/bash
D="$HOME/CYBRA/modules/module_147_reputation_v2"
B=$'\e[36m'; G=$'\e[32m'; D_=$'\e[2m'; N=$'\e[0m'
while :; do
  clear; echo "${B}═══ Reputation V2 (on-chain) ═══${N}"; echo
  echo "  ${D_}Solidity контракт + deploy через 121${N}"
  echo
  echo "  1) Компілювати Reputation.sol"
  echo "  2) Деплоїти (testnet — auto, mainnet — vote)"
  echo "  3) Info про деплой"
  echo "  0) Назад"; echo
  read -rp "  Вибір: " c
  case "$c" in
    1) python3 "$HOME/CYBRA/modules/module_121_parlament/deployer.py" auto 2>&1 | head -20; read -rp "Enter…" _ ;;
    2) python3 "$HOME/CYBRA/modules/module_121_parlament/deployer.py" auto; read -rp "Enter…" _ ;;
    3) python3 -c "
import json, os
p = os.path.expanduser('~/CYBRA/config/deployed.json')
if not os.path.exists(p): print('  (порожньо)'); exit()
d = json.load(open(p))
r = d.get('Reputation')
if not r: print('  Reputation не задеплоєно'); exit()
for k, v in r.items(): print(f'  {k}: {v}')
"
       read -rp "Enter…" _ ;;
    0) return ;;
  esac
done
