#!/usr/bin/env python3
"""Lightning через LNbits API (безкоштовний self-hosted або legend.lnbits.com)."""
import json, urllib.request, urllib.parse, sys, os, time
from pathlib import Path

H = Path.home() / "CYBRA"
CFG = H / "config" / "lnbits.json"

def cfg():
    if not CFG.exists(): return {"url": "", "key": "", "enabled": False}
    try: return json.loads(CFG.read_text())
    except Exception: return {"url": "", "key": "", "enabled": False}

def save(c): CFG.write_text(json.dumps(c, indent=2))

def _req(method, path, data=None, timeout=15):
    c = cfg()
    if not c.get("enabled"):
        return {"ok": False, "reason": "не налаштовано"}
    url = c["url"].rstrip("/") + path
    headers = {"X-Api-Key": c["key"], "Content-Type": "application/json"}
    body = json.dumps(data).encode() if data else None
    try:
        req = urllib.request.Request(url, data=body, headers=headers, method=method)
        with urllib.request.urlopen(req, timeout=timeout) as r:
            return {"ok": True, "data": json.loads(r.read())}
    except urllib.error.HTTPError as e:
        return {"ok": False, "reason": f"HTTP {e.code}: {e.read()[:100]}"}
    except Exception as e:
        return {"ok": False, "reason": str(e)[:150]}

def balance():
    return _req("GET", "/api/v1/wallet")

def create_invoice(amount_sat, memo=""):
    return _req("POST", "/api/v1/payments",
                {"out": False, "amount": int(amount_sat), "memo": memo})

def pay_invoice(bolt11):
    return _req("POST", "/api/v1/payments",
                {"out": True, "bolt11": bolt11})

def check(payment_hash):
    return _req("GET", f"/api/v1/payments/{payment_hash}")

if __name__ == "__main__":
    cmd = sys.argv[1] if len(sys.argv) > 1 else "balance"
    if cmd == "balance":
        print(json.dumps(balance(), indent=2))
    elif cmd == "invoice":
        print(json.dumps(create_invoice(int(sys.argv[2]), sys.argv[3] if len(sys.argv)>3 else ""), indent=2))
    elif cmd == "check":
        print(json.dumps(check(sys.argv[2]), indent=2))
    elif cmd == "setup":
        save({"url":sys.argv[2],"key":sys.argv[3],"enabled":True})
        print("✓")
