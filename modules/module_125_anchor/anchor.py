#!/usr/bin/env python3
"""On-chain anchor: публікує sha256(protocol) у BSC через TX з data.
Готує TX, чекає підпис, потім позначає як anchored."""
import json, os, sys, time, hashlib
from pathlib import Path
D = Path(__file__).resolve().parent
H = Path.home() / "CYBRA"
DATA = D / "data"; DATA.mkdir(exist_ok=True)
ANCHORS = DATA / "anchors.jsonl"

def _now(): return time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())

def prepare(cid, payload_hash, from_addr, chain_id=56):
    """Готує anchor-TX. TX = 0-value transfer сам собі з data=hash."""
    tx = {
        "cid": cid, "hash": payload_hash, "from": from_addr,
        "to": from_addr,   # anchor self
        "value": 0, "data": "0x" + payload_hash,
        "chain_id": chain_id, "at": _now(), "status": "pending",
    }
    with open(ANCHORS, "a") as f:
        f.write(json.dumps(tx, ensure_ascii=False) + "\n")
    # зберегти для 108/QR — щоб людина підписала
    out = DATA / f"{cid}_anchor_tx.json"
    out.write_text(json.dumps(tx, indent=2))
    return True, str(out)

def confirm(cid, tx_hash, net="bsc"):
    """Після того як TX реально в мережі."""
    lines = []
    updated = 0
    if ANCHORS.exists():
        for line in ANCHORS.read_text().splitlines():
            try: e = json.loads(line)
            except Exception: continue
            if e["cid"] == cid and e["status"] == "pending":
                e["status"] = "confirmed"
                e["tx_hash"] = tx_hash; e["net"] = net
                e["confirmed_at"] = _now()
                updated += 1
            lines.append(json.dumps(e, ensure_ascii=False))
    ANCHORS.write_text("\n".join(lines) + "\n" if lines else "")
    return True, f"оновлено {updated}"

def verify(cid, tx_hash=None):
    if not ANCHORS.exists(): return {"ok": False, "reason": "немає anchors"}
    for line in ANCHORS.read_text().splitlines():
        try: e = json.loads(line)
        except Exception: continue
        if e["cid"] == cid:
            if tx_hash and e.get("tx_hash") != tx_hash: continue
            return {"ok": True, **e}
    return {"ok": False, "reason": "не знайдено"}

def list_all():
    if not ANCHORS.exists(): return []
    out = []
    for line in ANCHORS.read_text().splitlines():
        try: out.append(json.loads(line))
        except Exception: pass
    return out

if __name__ == "__main__":
    cmd = sys.argv[1] if len(sys.argv) > 1 else "list"
    if cmd == "prepare":
        ok, m = prepare(sys.argv[2], sys.argv[3], sys.argv[4])
        print(("✓ " if ok else "✗ ")+m)
    elif cmd == "confirm":
        ok, m = confirm(sys.argv[2], sys.argv[3]); print(("✓ " if ok else "✗ ")+m)
    elif cmd == "verify":
        print(json.dumps(verify(sys.argv[2]), indent=2))
    elif cmd == "list":
        for e in list_all():
            print(f"  [{e['status']:10s}] {e['cid'][:26]:28s} {e.get('tx_hash','—')}")
