#!/usr/bin/env python3
"""Pinata API для пінінгу файлів у IPFS."""
import json, urllib.request, sys, os, time
from pathlib import Path

H = Path.home() / "CYBRA"
CFG = H / "config" / "ipfs.json"

def cfg():
    if not CFG.exists(): return {"jwt": "", "gateway": "https://gateway.pinata.cloud", "enabled": False}
    try: return json.loads(CFG.read_text())
    except Exception: return {"jwt": "", "gateway": "", "enabled": False}

def save(c): CFG.write_text(json.dumps(c, indent=2))

def _post(path, data, content_type="application/json"):
    c = cfg()
    if not c.get("enabled"): return {"ok": False, "reason": "не налаштовано"}
    url = "https://api.pinata.cloud" + path
    body = json.dumps(data).encode() if isinstance(data, dict) else data
    req = urllib.request.Request(url, data=body, method="POST",
        headers={"Authorization": f"Bearer {c['jwt']}", "Content-Type": content_type})
    try:
        with urllib.request.urlopen(req, timeout=30) as r:
            return {"ok": True, "data": json.loads(r.read())}
    except urllib.error.HTTPError as e:
        return {"ok": False, "reason": f"HTTP {e.code}: {e.read()[:200]}"}
    except Exception as e:
        return {"ok": False, "reason": str(e)[:200]}

def pin_json(obj, name):
    c = cfg()
    r = _post("/pinning/pinJSONToIPFS", {
        "pinataContent": obj,
        "pinataMetadata": {"name": name},
    })
    if r.get("ok"):
        cid = r["data"].get("IpfsHash")
        return {"ok": True, "cid": cid,
                "gateway": f"{c.get('gateway','https://gateway.pinata.cloud')}/ipfs/{cid}"}
    return r

def test_auth():
    c = cfg()
    if not c.get("enabled"): return False, "не налаштовано"
    req = urllib.request.Request("https://api.pinata.cloud/data/testAuthentication",
        headers={"Authorization": f"Bearer {c['jwt']}"})
    try:
        with urllib.request.urlopen(req, timeout=10) as r:
            return True, r.read().decode()
    except Exception as e:
        return False, str(e)[:150]

if __name__ == "__main__":
    cmd = sys.argv[1] if len(sys.argv) > 1 else "test"
    if cmd == "test":
        ok, m = test_auth(); print(("✓ " if ok else "✗ ")+m)
    elif cmd == "setup":
        save({"jwt": sys.argv[2], "gateway": sys.argv[3] if len(sys.argv)>3 else "https://gateway.pinata.cloud", "enabled": True})
        print("✓")
    elif cmd == "pin-json":
        d = json.load(open(sys.argv[2]))
        print(json.dumps(pin_json(d, os.path.basename(sys.argv[2])), indent=2))
