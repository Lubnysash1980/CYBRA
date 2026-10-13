#!/usr/bin/env python3
"""Баланси ERC-20/BEP-20 токенів для адрес з watch-списку."""
import json, os, sys, urllib.request
from pathlib import Path
H = Path.home() / "CYBRA"
D = Path(__file__).resolve().parent

# Популярні токени: контракт → symbol
TOKENS = {
    "bsc": {
        "0x55d398326f99059ff775485246999027b3197955": "USDT",
        "0x8ac76a51cc950d9822d68b83fe1ad97b32cd580d": "USDC",
        "0xbb4cdb9cbd36b01bd1cbaebf2de08d9173bc095c": "WBNB",
        "0x2170ed0880ac9a755fd29b2688956bd959f933f8": "ETH",
    },
    "eth": {
        "0xdac17f958d2ee523a2206206994597c13d831ec7": "USDT",
        "0xa0b86991c6218b36c1d19d4a2e9eb0ce3606eb48": "USDC",
        "0x2260fac5e5542a773aa44fbcfedf7c193bc2c599": "WBTC",
    },
}

def _rpc(url, method, params):
    data = json.dumps({"jsonrpc":"2.0","id":1,"method":method,"params":params}).encode()
    req = urllib.request.Request(url, data=data,
        headers={"Content-Type":"application/json"}, method="POST")
    return json.loads(urllib.request.urlopen(req, timeout=10).read())

def _net_cfg(net="bsc"):
    p = H / "modules/module_114_autonode/networks.json"
    try:
        cfg = json.loads(p.read_text())
        return cfg["networks"].get(net, {}).get("rpc_http", [None])[0]
    except Exception: return None

def balance_of(addr, token_contract, net="bsc"):
    url = _net_cfg(net)
    if not url: return None
    # balanceOf(address) selector = 0x70a08231
    data = "0x70a08231" + addr[2:].lower().rjust(64, "0")
    try:
        r = _rpc(url, "eth_call",
                 [{"to": token_contract, "data": data}, "latest"])
        return int(r["result"], 16)
    except Exception: return None

def check_all(addr, net="bsc"):
    out = []
    for contract, symbol in TOKENS.get(net, {}).items():
        raw = balance_of(addr, contract, net)
        if raw is None: continue
        # 18 decimals — більшість, USDT/USDC на BSC теж 18
        bal = raw / 1e18
        out.append({"symbol": symbol, "contract": contract,
                    "raw": raw, "formatted": bal})
    return out

if __name__ == "__main__":
    if len(sys.argv) < 2: print("usage: tokens.py <addr> [net]"); sys.exit(1)
    addr = sys.argv[1]; net = sys.argv[2] if len(sys.argv) > 2 else "bsc"
    G='\033[32m'; B='\033[36m'; D='\033[2m'; N='\033[0m'
    print(f"\n  {B}Токени {addr[:10]}… ({net}){N}")
    for t in check_all(addr, net):
        col = G if t["formatted"] > 0 else D
        print(f"  {col}{t['symbol']:8s} {t['formatted']:>18.6f}{N}")
