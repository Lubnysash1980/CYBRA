#!/data/data/com.termux/files/usr/bin/bash
D="$HOME/CYBRA/modules/module_145_ipfs"
B=$'\e[36m'; G=$'\e[32m'; N=$'\e[0m'
while :; do
  clear; echo "${B}═══ IPFS Pinning ═══${N}"; echo
  echo "  1) Setup (Pinata JWT)"
  echo "  2) Test auth"
  echo "  3) Pin JSON (файл)"
  echo "  4) Pin останній contract/protocol"
  echo "  0) Назад"; echo
  read -rp "  Вибір: " c
  case "$c" in
    1) echo "  JWT: https://app.pinata.cloud/developers/api-keys"
       read -rp "  JWT: " j
       python3 "$D/ipfs.py" setup "$j"; read -rp "Enter…" _ ;;
    2) python3 "$D/ipfs.py" test; read -rp "Enter…" _ ;;
    3) read -rp "  Шлях до JSON: " f
       python3 "$D/ipfs.py" pin-json "$f"; read -rp "Enter…" _ ;;
    4) echo "  1) INVOICE  2) protocol  3) .sig"
       read -rp "  Вибір: " t
       case "$t" in
         1) F=$(ls -t "$HOME/CYBRA/modules/module_19_contract_tui_menu/evidence"/*.json 2>/dev/null | head -1) ;;
         2) F=$(ls -t "$HOME/CYBRA/modules/module_121_parlament/protocols"/*.html 2>/dev/null | head -1) ;;
         3) F=$(ls -t "$HOME/CYBRA/modules/module_19_contract_tui_menu/evidence"/*.sig 2>/dev/null | head -1) ;;
       esac
       [ -n "$F" ] && python3 -c "
import sys, json
sys.path.insert(0, '$D')
import ipfs
try:
    d = json.load(open('$F')) if '$F'.endswith('.json') else {'raw': open('$F').read()[:5000]}
except:
    d = {'raw': open('$F', errors='ignore').read()[:5000]}
print(json.dumps(ipfs.pin_json(d, '$F'.split('/')[-1]), indent=2))
"
       read -rp "Enter…" _ ;;
    0) return ;;
  esac
done
