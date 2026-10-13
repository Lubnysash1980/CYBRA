#!/data/data/com.termux/files/usr/bin/bash
set -uo pipefail
CFG="$HOME/CYBRA/modules/module_114_autonode/networks.json"
B=$'\e[36m'; R=$'\e[31m'; N=$'\e[0m'
HASH="${1:-}"
[ -z "$HASH" ] && read -rp "TX hash (0x…): " HASH
[ -z "$HASH" ] && exit 1

python3 - "$CFG" "$HASH" <<'PY'
import json, sys, urllib.request
cfg = json.load(open(sys.argv[1])); h = sys.argv[2]
for net, c in cfg["networks"].items():
    for url in c["rpc_http"][:3]:
        try:
            body = json.dumps({"jsonrpc":"2.0","id":1,
                "method":"eth_getTransactionByHash","params":[h]}).encode()
            req = urllib.request.Request(url, data=body,
                headers={"Content-Type":"application/json"}, method="POST")
            r = json.loads(urllib.request.urlopen(req, timeout=8).read())
            if r.get("result"):
                tx = r["result"]
                print(f"  ✓ Знайдено у {c['name']}")
                for k in ["from","to","value","nonce","gas","gasPrice","blockNumber"]:
                    v = tx.get(k)
                    if k == "value" and v: v = f"{int(v,16)/1e18} {c['symbol']}"
                    if k == "gasPrice" and v: v = f"{int(v,16)/1e9:.2f} gwei"
                    if k == "blockNumber" and v: v = int(v, 16)
                    print(f"    {k:12s} {v}")
                sys.exit(0)
        except Exception: continue
print("  ✗ не знайдено в жодній мережі")
PY
