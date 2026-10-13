#!/usr/bin/env python3
"""Моніторить BSC на події зв'язані з парламентом.
Працює через RPC log-filters. Легка — тільки перевірка TX які нам цікаві."""
import json, os, sys, time
from pathlib import Path

H = Path.home() / "CYBRA"
PRL = H / "modules/module_121_parlament"
STATE = H / "modules/module_114_autonode/parlament_seen.json"
sys.path.insert(0, str(PRL))

NET_CFG = H / "modules/module_114_autonode/networks.json"

def _load_net(net="bsc"):
    try:
        cfg = json.load(open(NET_CFG))
        return cfg["networks"][net]["rpc_http"][0]
    except Exception:
        return None

def _rpc(url, method, params):
    import urllib.request
    data = json.dumps({"jsonrpc":"2.0","id":1,"method":method,"params":params}).encode()
    req = urllib.request.Request(url, data=data,
        headers={"Content-Type":"application/json"}, method="POST")
    return json.loads(urllib.request.urlopen(req, timeout=10).read())

def check_anchors():
    """Перевіряє чи є TX для anchor-хешів з 121."""
    try:
        import parliament as P
    except ImportError:
        return []
    out = []
    seen = {}
    if STATE.exists():
        try: seen = json.loads(STATE.read_text())
        except Exception: pass
    url = _load_net("bsc")
    if not url: return out

    for p in P.proposals(status="approved"):
        pid = p["pid"]
        if pid in seen: continue
        # TX hash може бути в payload або audit
        tx = (p.get("payload") or {}).get("tx_hash")
        if not tx: continue
        try:
            r = _rpc(url, "eth_getTransactionReceipt", [tx])
            if r.get("result") and r["result"].get("status") == "0x1":
                # позначити як executed on-chain
                P.audit("on_chain_confirmed",
                        {"pid": pid, "tx": tx, "net": "bsc"})
                seen[pid] = tx
                out.append({"pid": pid, "tx": tx, "status": "confirmed"})
        except Exception: pass
    STATE.write_text(json.dumps(seen, indent=2))
    return out

if __name__ == "__main__":
    r = check_anchors()
    print(json.dumps(r, indent=2, ensure_ascii=False))
