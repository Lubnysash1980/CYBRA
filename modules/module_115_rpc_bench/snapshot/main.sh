#!/data/data/com.termux/files/usr/bin/bash
set -uo pipefail
D="$HOME/CYBRA/modules/module_114_autonode"
CFG="$D/networks.json"
B=$'\e[36m'; G=$'\e[32m'; R=$'\e[31m'; Y=$'\e[33m'; N=$'\e[0m'

echo "${B}═══ RPC Benchmark ═══${N}"
echo

python3 - "$CFG" <<'PY'
import json, sys, time, urllib.request, urllib.error
cfg = json.load(open(sys.argv[1]))
G='\033[32m'; Y='\033[33m'; R='\033[31m'; N='\033[0m'

def call(url, method, params=None, timeout=8):
    body = json.dumps({"jsonrpc":"2.0","id":1,"method":method,"params":params or []}).encode()
    req = urllib.request.Request(url, data=body,
        headers={"Content-Type":"application/json"}, method="POST")
    t0 = time.time()
    with urllib.request.urlopen(req, timeout=timeout) as r:
        j = json.loads(r.read())
    return j, int((time.time()-t0)*1000)

for net, cfg_n in cfg["networks"].items():
    print(f"\n  {cfg_n['name']} (chain_id={cfg_n['chain_id']})")
    print(f"  {'endpoint':50s} {'latency':>10s}  block")
    print("  " + "-"*78)
    best = None
    for url in cfg_n["rpc_http"]:
        try:
            j, lat = call(url, "eth_blockNumber")
            blk = int(j["result"], 16)
            marker = f"{G}★{N}" if (best is None or lat < best[1]) else " "
            if best is None or lat < best[1]: best = (url, lat)
            print(f"  {marker} {url:48s} {lat:>7d} ms  {blk}")
        except Exception as e:
            print(f"    {url:48s} {R}FAIL{N}      {str(e)[:30]}")
    if best:
        print(f"  {G}→ рекомендую: {best[0]} ({best[1]}ms){N}")
PY
