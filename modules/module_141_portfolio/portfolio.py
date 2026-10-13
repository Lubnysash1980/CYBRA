#!/usr/bin/env python3
"""Portfolio: баланси + P&L по всіх гаманцях та контрактах."""
import json, os, sys, time, urllib.request
from pathlib import Path
H = Path.home() / "CYBRA"
D = Path(__file__).resolve().parent
DATA = D / "data"; DATA.mkdir(exist_ok=True)
WALLETS = DATA / "wallets.json"
HISTORY = DATA / "history.jsonl"

# Ціни (можна оновити з CoinGecko)
PRICES = {"BNB": 600, "ETH": 3500, "USDT": 1, "USDC": 1, "MATIC": 0.7}

def _load_wallets():
    if not WALLETS.exists(): return []
    try: return json.loads(WALLETS.read_text())
    except Exception: return []

def _save_wallets(w):
    WALLETS.write_text(json.dumps(w, indent=2, ensure_ascii=False))

def _rpc(net, method, params):
    cfg = H / "modules/module_114_autonode/networks.json"
    try:
        url = json.loads(cfg.read_text())["networks"][net]["rpc_http"][0]
    except Exception: return None
    try:
        data = json.dumps({"jsonrpc":"2.0","id":1,"method":method,"params":params}).encode()
        req = urllib.request.Request(url, data=data,
            headers={"Content-Type":"application/json"}, method="POST")
        return json.loads(urllib.request.urlopen(req, timeout=10).read())
    except Exception: return None

def native_balance(addr, net="bsc"):
    r = _rpc(net, "eth_getBalance", [addr, "latest"])
    if not r or "result" not in r: return 0
    return int(r["result"], 16) / 1e18

def token_balance(addr, token, net="bsc"):
    """token — контрактна адреса."""
    data = "0x70a08231" + addr[2:].lower().rjust(64, "0")
    r = _rpc(net, "eth_call", [{"to": token, "data": data}, "latest"])
    if not r or "result" not in r: return 0
    return int(r["result"], 16) / 1e18

def add_wallet(addr, label, networks=None):
    w = _load_wallets()
    if any(x["addr"].lower() == addr.lower() for x in w):
        return False, "вже є"
    w.append({"addr": addr, "label": label,
              "networks": networks or ["bsc", "eth"]})
    _save_wallets(w); return True, "додано"

def snapshot():
    """Один знімок портфеля."""
    out = {"ts": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
           "ts_unix": int(time.time()), "wallets": [], "total_usd": 0.0}
    for w in _load_wallets():
        wu = {"addr": w["addr"], "label": w["label"], "assets": [], "usd": 0.0}
        for net in w.get("networks", ["bsc"]):
            sym = "BNB" if net == "bsc" else "ETH"
            bal = native_balance(w["addr"], net)
            if bal > 0:
                usd = bal * PRICES.get(sym, 0)
                wu["assets"].append({"sym": sym, "bal": bal, "usd": usd, "net": net})
                wu["usd"] += usd
        out["wallets"].append(wu)
        out["total_usd"] += wu["usd"]
    with open(HISTORY, "a") as f:
        f.write(json.dumps(out) + "\n")
    # ротація
    try:
        if HISTORY.stat().st_size > 500_000:
            lines = HISTORY.read_text().splitlines()
            HISTORY.write_text("\n".join(lines[-500:]) + "\n")
    except Exception: pass
    return out

def pnl():
    """P&L по історії: перше vs останнє."""
    if not HISTORY.exists(): return None
    lines = [json.loads(l) for l in HISTORY.read_text().splitlines() if l.strip()]
    if len(lines) < 2: return None
    first = lines[0]; last = lines[-1]
    return {
        "first_ts": first["ts"], "last_ts": last["ts"],
        "first_usd": first["total_usd"], "last_usd": last["total_usd"],
        "delta_usd": last["total_usd"] - first["total_usd"],
        "delta_pct": ((last["total_usd"] - first["total_usd"]) / first["total_usd"] * 100)
                     if first["total_usd"] > 0 else 0,
    }

def print_portfolio(p, pnl_=None):
    G='\033[32m'; R='\033[31m'; Y='\033[33m'; B='\033[36m'; DIM='\033[2m'; BOLD='\033[1m'; N='\033[0m'
    print(f"\n{B}{BOLD}═══ Portfolio ═══{N}  {DIM}{p['ts']}{N}")
    for w in p["wallets"]:
        print(f"\n  {BOLD}{w['label']}{N} {DIM}{w['addr'][:10]}…{N}")
        if not w["assets"]:
            print(f"    {DIM}порожньо{N}")
        for a in w["assets"]:
            print(f"    {a['sym']:6s} {a['bal']:>16.6f}  {DIM}≈ ${a['usd']:.2f}  ({a['net']}){N}")
        print(f"    {DIM}підсумок: ${w['usd']:.2f}{N}")
    print(f"\n  {BOLD}Всього: ${p['total_usd']:.2f}{N}")
    if pnl_:
        col = G if pnl_["delta_usd"] >= 0 else R
        sign = "+" if pnl_["delta_usd"] >= 0 else ""
        print(f"  P&L:    {col}{sign}${pnl_['delta_usd']:.2f} ({sign}{pnl_['delta_pct']:.1f}%){N}")
        print(f"  {DIM}від {pnl_['first_ts']} до {pnl_['last_ts']}{N}")
    print()

if __name__ == "__main__":
    cmd = sys.argv[1] if len(sys.argv) > 1 else "show"
    if cmd == "add":
        ok, m = add_wallet(sys.argv[2], sys.argv[3],
                          sys.argv[4].split(",") if len(sys.argv) > 4 else None)
        print(("✓ " if ok else "✗ ")+m)
    elif cmd == "list":
        for w in _load_wallets():
            print(f"  {w['label']:20s} {w['addr']}  {','.join(w['networks'])}")
    elif cmd == "snapshot":
        s = snapshot(); print_portfolio(s, pnl())
    elif cmd == "show":
        # останній снапшот
        if HISTORY.exists():
            last = json.loads(HISTORY.read_text().splitlines()[-1])
            print_portfolio(last, pnl())
        else:
            print("  немає даних. Додай гаманець: portfolio.py add <addr> <label>")
