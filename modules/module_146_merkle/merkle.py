#!/usr/bin/env python3
"""Merkle tree для batch-якорів. N hash → 1 root → 1 TX у BSC."""
import hashlib, json, sys, os, time
from pathlib import Path

D = Path(__file__).resolve().parent
TREES = D / "data" / "trees.jsonl"

def _h(data):
    if isinstance(data, str): data = data.encode()
    return hashlib.sha256(data).hexdigest()

def build(items):
    """items — list of str/bytes. Повертає tree + proofs."""
    leaves = [_h(x) for x in items]
    if not leaves: return None
    level = leaves[:]
    tree = [level[:]]
    while len(level) > 1:
        nxt = []
        for i in range(0, len(level), 2):
            a = level[i]
            b = level[i+1] if i+1 < len(level) else a
            nxt.append(_h(a + b))
        tree.append(nxt); level = nxt
    root = level[0]

    def proof(idx):
        p = []
        for lvl in tree[:-1]:
            if idx % 2: p.append(("L", lvl[idx-1]))
            else: p.append(("R", lvl[idx+1] if idx+1 < len(lvl) else lvl[idx]))
            idx //= 2
        return p

    return {"root": root, "leaves": leaves, "tree": tree,
            "proofs": [proof(i) for i in range(len(leaves))],
            "size": len(leaves), "at": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())}

def verify(root, leaf_data, proof):
    cur = _h(leaf_data)
    for side, sib in proof:
        if side == "L": cur = _h(sib + cur)
        else: cur = _h(cur + sib)
    return cur == root

def save(tree):
    with open(TREES, "a") as f:
        f.write(json.dumps(tree) + "\n")

def batch_contracts(cids):
    """Групує N CID у одну root."""
    items = cids
    t = build(items)
    save(t)
    return t

if __name__ == "__main__":
    cmd = sys.argv[1] if len(sys.argv) > 1 else "list"
    if cmd == "build":
        items = sys.argv[2:]
        t = build(items)
        print(json.dumps({k:v for k,v in t.items() if k != "tree"}, indent=2))
    elif cmd == "batch-cids":
        cids = json.loads(sys.argv[2])
        t = batch_contracts(cids)
        print(f"  root: {t['root']}")
        print(f"  size: {t['size']}")
        print(f"  TX:   send 0 value to self with data=0x{t['root']}")
    elif cmd == "verify":
        root = sys.argv[2]; leaf = sys.argv[3]; proof = json.loads(sys.argv[4])
        print(verify(root, leaf, proof))
    elif cmd == "list":
        if not TREES.exists(): print("  (порожньо)"); exit()
        for line in TREES.read_text().splitlines()[-10:]:
            t = json.loads(line)
            print(f"  {t['at']}  root={t['root'][:16]}…  size={t['size']}")
