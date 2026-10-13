#!/data/data/com.termux/files/usr/bin/bash
set -uo pipefail
E="$HOME/CYBRA/modules/module_19_contract_tui_menu/evidence"
G=$'\e[32m'; R=$'\e[31m'; B=$'\e[36m'; N=$'\e[0m'
F="${1:-}"
if [ -z "$F" ]; then
  echo "${B}Останні підписи:${N}"
  ls -1t "$E"/*.sig 2>/dev/null | head -10 | nl -w2 -s') '
  read -rp "Номер або шлях: " c
  if [[ "$c" =~ ^[0-9]+$ ]]; then F=$(ls -1t "$E"/*.sig 2>/dev/null | sed -n "${c}p"); else F="$c"; fi
fi
[ -f "$F" ] || { echo "${R}✗${N} не знайдено: $F"; exit 1; }
echo "${B}Файл:${N} $F"
python3 - "$F" <<'PY'
import json,sys
d=json.load(open(sys.argv[1]))
print(f"  CID:     {d.get('cid')}")
print(f"  Address: {d.get('address')}")
print(f"  Sig:     {d.get('signature','')[:20]}…")
try:
    from eth_account import Account
    from eth_account.messages import encode_defunct
    r=Account.recover_message(encode_defunct(text=d["message"]),signature=d["signature"])
    if r.lower()==d["address"].lower():
        print(f"\n  \033[32m✓ ПІДПИС ВАЛІДНИЙ\033[0m\n  Підписав: {r}")
    else:
        print(f"\n  \033[31m✗ НЕВАЛІДНИЙ\033[0m\n  recovered={r}\n  declared ={d['address']}")
        sys.exit(2)
except ImportError:
    print("\n  \033[33m!\033[0m pip install eth-account"); sys.exit(3)
PY
