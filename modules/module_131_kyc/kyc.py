#!/usr/bin/env python3
"""Реальна перевірка адреси проти завантажених списків."""
import json, sys, os, time
from pathlib import Path
D = Path(__file__).resolve().parent
LISTS = D / "data/lists"
CACHE = D / "data" / "checked.json"

SANCTIONS = LISTS / "crypto_addresses.json"

def _load_sanctions():
    if not SANCTIONS.exists(): return None
    try: return json.loads(SANCTIONS.read_text())
    except Exception: return None

def _cache():
    if not CACHE.exists(): return {}
    try: return json.loads(CACHE.read_text())
    except Exception: return {}
def _save_cache(d): CACHE.write_text(json.dumps(d, indent=2))

def detect_chain(addr):
    a = addr.strip()
    if a.startswith("0x") and len(a) == 42: return "ETH"
    if a.startswith("bc1") or (a[0] in "13" and 26 <= len(a) <= 35): return "BTC"
    if a.startswith("T") and len(a) == 34: return "TRX"
    if a.startswith("r") and 25 <= len(a) <= 35: return "XRP"
    if a.startswith(("L","ltc1")): return "LTC"
    if a.startswith(("q","p")) and len(a) == 42: return "BCH"
    if a.startswith(("4","8")) and len(a) == 95: return "XMR"
    return None

def check(addr):
    addr_l = addr.strip()
    if addr_l.startswith("0x"): addr_l = addr_l.lower()
    if addr_l.startswith("T"): addr_l = addr_l  # TRX case-sensitive першa
    cache = _cache()
    if addr in cache and (time.time() - cache[addr].get("at",0)) < 3600:
        return cache[addr]

    san = _load_sanctions()
    if san is None:
        return {"addr": addr, "sanctions": None,
                "error": "списки не завантажено. Запусти fetch.py"}

    chain = detect_chain(addr)
    if not chain:
        return {"addr": addr, "sanctions": False,
                "reason": "невідомий формат адреси", "chain": None}

    hits = []
    for sym in (chain, "ETH"):  # ETH покриває BSC/Polygon (EVM-сумісні)
        if sym in san:
            # регістро-незалежно для ETH, точно для решти
            if sym == "ETH":
                if addr_l.lower() in [x.lower() for x in san[sym]]:
                    hits.append(sym)
            else:
                if addr_l in san[sym]:
                    hits.append(sym)
    result = {
        "addr": addr, "chain": chain,
        "sanctions": len(hits) > 0,
        "hits": hits,
        "source_meta": san.get("_meta", {}).get("fetched_at"),
        "at": int(time.time()),
    }
    cache[addr] = result
    _save_cache(cache)
    return result

def stats():
    san = _load_sanctions()
    if not san: return {"loaded": False}
    out = {"loaded": True,
           "meta": san.get("_meta", {}),
           "by_chain": {k: len(v) for k,v in san.items() if k != "_meta"}}
    return out

if __name__ == "__main__":
    cmd = sys.argv[1] if len(sys.argv) > 1 else "check"
    if cmd == "check":
        if len(sys.argv) < 3: print("usage: kyc.py check <addr>"); sys.exit(1)
        r = check(sys.argv[2])
        G='\033[32m'; R='\033[31m'; Y='\033[33m'; B='\033[36m'; D='\033[2m'; N='\033[0m'
        if r.get("error"):
            print(f"  {R}✗{N} {r['error']}"); sys.exit(2)
        col = R if r["sanctions"] else G
        print(f"\n  {B}Addr:{N}      {r['addr']}")
        print(f"  {B}Chain:{N}     {r.get('chain') or '?'}")
        verdict = "SANCTIONED" if r["sanctions"] else "CLEAN"
        print(f"  {B}Verdict:{N}   {col}{verdict}{N}")
        if r.get("hits"):
            print(f"  {B}Hits:{N}      {', '.join(r['hits'])}")
        if r.get("source_meta"):
            print(f"  {D}list from: {r['source_meta']}{N}")
        print()
        sys.exit(1 if r["sanctions"] else 0)
    elif cmd == "stats":
        s = stats()
        if not s["loaded"]:
            print("  списки не завантажено"); sys.exit(1)
        G='\033[32m'; B='\033[36m'; D='\033[2m'; N='\033[0m'
        print(f"\n  {B}Списки санкцій{N}")
        print(f"  Оновлено: {s['meta'].get('fetched_at','—')}")
        print(f"  Джерела:")
        for name, m in s["meta"].get("sources", {}).items():
            print(f"    {G}✓{N} {name:20s} {m.get('size',0)//1024:>6} KB")
        print(f"\n  Адрес у базі:")
        for chain, n in sorted(s["by_chain"].items()):
            print(f"    {chain:6s} {n:>6}")
        print()
    elif cmd == "detect":
        print(detect_chain(sys.argv[2]))
