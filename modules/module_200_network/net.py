#!/usr/bin/env python3
"""Менеджер мереж: переключення mainnet/testnet з пам'яттю опцій."""
import json, os, sys, time
from pathlib import Path

H = Path.home() / "CYBRA"
CFG = H / "config" / "networks.json"

def _load():
    try: return json.loads(CFG.read_text())
    except Exception: return {"current": "bsc_mainnet", "networks": {}}

def _save(d):
    tmp = str(CFG)+".tmp"
    Path(tmp).write_text(json.dumps(d, indent=2, ensure_ascii=False))
    os.replace(tmp, CFG)

def current():
    d = _load()
    name = d.get("current", "bsc_mainnet")
    net = d["networks"].get(name, {})
    return {"name": name, **net}

def set_current(name):
    d = _load()
    if name not in d["networks"]:
        return False, f"невідома мережа: {name}. Доступні: {','.join(d['networks'].keys())}"
    d["current"] = name
    d["_last_switch"] = time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())
    _save(d)
    return True, f"current → {name}"

def list_all():
    d = _load()
    return [(k, v) for k, v in d["networks"].items()]

def rpc():
    c = current()
    eps = c.get("rpc_http", [])
    return eps[0] if eps else None

def chain_id():
    return current().get("chain_id")

def explorer():
    return current().get("explorer")

def explorer_tx(h):
    e = explorer()
    return f"{e}/tx/{h}" if e else None

def explorer_addr(a):
    e = explorer()
    return f"{e}/address/{a}" if e else None

def is_paid():
    return bool(current().get("is_paid"))

def faucet():
    return current().get("faucet")

def symbol():
    return current().get("symbol", "?") if False else current().get("symbol")

if __name__ == "__main__":
    cmd = sys.argv[1] if len(sys.argv) > 1 else "show"
    if cmd == "show":
        c = current()
        G='\033[32m'; Y='\033[33m'; B='\033[36m'; D='\033[2m'; N='\033[0m'
        col = Y if c.get("type")=="testnet" else G
        print(f"\n  {B}Поточна мережа{N}: {col}{c.get('name')}{N}")
        print(f"  {'─'*50}")
        print(f"  chain_id:  {c.get('chain_id')}")
        print(f"  symbol:    {c.get('symbol')}")
        print(f"  type:      {c.get('type')}")
        print(f"  rpc:       {c.get('rpc_http',['—'])[0]}")
        print(f"  explorer:  {c.get('explorer')}")
        if c.get('faucet'):
            print(f"  faucet:    {c.get('faucet')}")
        print()
    elif cmd == "set":
        ok, m = set_current(sys.argv[2]); print(("✓ " if ok else "✗ ")+m)
    elif cmd == "list":
        G='\033[32m'; Y='\033[33m'; B='\033[36m'; D='\033[2m'; N='\033[0m'
        cur = _load().get("current")
        for k, v in list_all():
            mark = f"{G}▶{N}" if k == cur else " "
            col = Y if v.get("type")=="testnet" else G
            print(f"  {mark} {k:22s} {col}{v.get('name','?'):22s}{N} "
                  f"chain_id={v.get('chain_id'):>6}  {v.get('type')}")
    elif cmd == "chain-id":
        print(chain_id())
    elif cmd == "rpc":
        print(rpc())
    elif cmd == "explorer":
        print(explorer())
