#!/data/data/com.termux/files/usr/bin/bash
set -uo pipefail
CFG="$HOME/CYBRA/modules/module_114_autonode/networks.json"
B=$'\e[36m'; G=$'\e[32m'; Y=$'\e[33m'; R=$'\e[31m'; N=$'\e[0m'

echo "${B}═══ Gas Monitor ═══${N}"
echo

python3 - "$CFG" <<'PY'
import json, sys, time, urllib.request
cfg = json.load(open(sys.argv[1]))
G='\033[32m'; Y='\033[33m'; R='\033[31m'; N='\033[0m'

def call(url, method, params=None):
    body = json.dumps({"jsonrpc":"2.0","id":1,"method":method,"params":params or []}).encode()
    req = urllib.request.Request(url, data=body,
        headers={"Content-Type":"application/json"}, method="POST")
    with urllib.request.urlopen(req, timeout=8) as r:
        return json.loads(r.read())

for net, c in cfg["networks"].items():
    print(f"  {c['name']} ({c['symbol']})")
    try:
        url = c["rpc_http"][0]
        r = call(url, "eth_gasPrice")
        gwei = int(r["result"], 16) / 1e9
        # рівні швидкості
        slow = gwei * 0.9
        fast = gwei * 1.3
        color = G if gwei < 5 else (Y if gwei < 20 else R)
        print(f"    base:  {color}{gwei:.2f} gwei{N}")
        print(f"    slow:  {slow:.2f} gwei  (~slow confirm)")
        print(f"    fast:  {fast:.2f} gwei  (~instant)")
        # вартість простих операцій
        for name, gas in [("transfer", 21000), ("approve", 46000), ("swap", 180000)]:
            cost_native = gas * gwei * 1e-9
            print(f"    {name:10s}  {cost_native:.6f} {c['symbol']}")
    except Exception as e:
        print(f"    {R}FAIL{N} {e}")
    print()
PY
