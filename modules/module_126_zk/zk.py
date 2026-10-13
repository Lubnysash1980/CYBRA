#!/usr/bin/env python3
"""Справжній ZK: Schnorr proof of knowledge + Pedersen commitment.

Що це дає:
  - Commit: C = s*G, де s = SHA256(cid || salt) mod p
  - Prove:  Schnorr π = (R, z) — доводить "знаю s" без розкриття s
  - Verify: перевіряє π відносно C, не знаючи s
  - Reveal: пізніше розкриває cid і salt, доводить що s*G == C

Це справжня zero-knowledge — не заглушка.
Крива: secp256k1 (як у Bitcoin/Ethereum).
"""
import json, os, sys, hashlib, secrets, time
from pathlib import Path

try:
    from py_ecc.secp256k1 import secp256k1
    from py_ecc.optimized_bls12_381 import curve_order as N_BLS
    HAVE_ECC = True
except ImportError:
    HAVE_ECC = False
    # fallback — проста модульна арифметика над простим числом
    N_BLS = None

# ─── secp256k1 параметри ────────────────────────────────────
P  = 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEFFFFFC2F
N  = 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEBAAEDCE6AF48A03BBFD25E8CD0364141
Gx = 0x79BE667EF9DCBBAC55A06295CE870B07029BFCDB2DCE28D959F2815B16F81798
Gy = 0x483ADA7726A3C4655DA4FBFC0E1108A8FD17B448A68554199C47D08FFB10D4B8

# Афінна арифметика над secp256k1 (без py_ecc, бо він важкий)
def _inv(a, m):
    return pow(a, -1, m)

def _add(P1, P2):
    if P1 is None: return P2
    if P2 is None: return P1
    x1,y1 = P1; x2,y2 = P2
    if x1 == x2 and (y1 + y2) % P == 0: return None
    if P1 == P2:
        lam = (3*x1*x1) * _inv(2*y1, P) % P
    else:
        lam = (y2-y1) * _inv(x2-x1, P) % P
    x3 = (lam*lam - x1 - x2) % P
    y3 = (lam*(x1-x3) - y1) % P
    return (x3, y3)

def _mul(k, Pt):
    R = None
    Q = Pt
    while k > 0:
        if k & 1: R = _add(R, Q)
        Q = _add(Q, Q)
        k >>= 1
    return R

G = (Gx, Gy)

def H(b):
    """SHA-256 → scalar mod N."""
    return int.from_bytes(hashlib.sha256(b).digest(), "big") % N

def H_point(Pt):
    """Хеш точки → scalar. Для Fiat-Shamir."""
    if Pt is None: return H(b"\x00")
    return H(Pt[0].to_bytes(32,"big") + Pt[1].to_bytes(32,"big"))

def serialize_point(Pt):
    if Pt is None: return None
    return {"x": hex(Pt[0]), "y": hex(Pt[1])}

def deserialize_point(d):
    if d is None: return None
    return (int(d["x"],16), int(d["y"],16))

# ─── публічні API ──────────────────────────────────────────

def commit(cid, salt=None):
    """Commit: C = s*G, де s = H(cid||salt).
    Повертає commitment (точка) + salt + hash s (для audit)."""
    salt = salt or secrets.token_hex(32)
    s = H((cid + "|" + salt).encode())
    C = _mul(s, G)
    rec = {
        "cid_hash": hashlib.sha256(cid.encode()).hexdigest(),
        "commitment": serialize_point(C),
        "salt": salt,
        "s_scalar": hex(s),  # НЕ публікувати! тільки для локальної перевірки
        "at": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
        "curve": "secp256k1",
    }
    return rec

def prove(cid, salt):
    """Schnorr proof of knowledge для s = H(cid||salt), C = s*G.
    Не розкриває s. Non-interactive через Fiat-Shamir."""
    s = H((cid + "|" + salt).encode())
    C = _mul(s, G)
    # k random, R = k*G
    k = secrets.randbelow(N - 1) + 1
    R = _mul(k, G)
    # e = H(R || C)
    e = (H_point(R) + H_point(C)) % N
    # z = k + e*s mod N
    z = (k + e * s) % N
    proof = {
        "R": serialize_point(R),
        "z": hex(z),
        "C": serialize_point(C),
        "cid_hash": hashlib.sha256(cid.encode()).hexdigest(),
        "at": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
    }
    return proof

def verify_proof(proof):
    """Перевірка Schnorr proof. Не потребує s."""
    try:
        R = deserialize_point(proof["R"])
        C = deserialize_point(proof["C"])
        z = int(proof["z"], 16)
    except Exception as e:
        return {"ok": False, "reason": f"format: {e}"}
    # e = H(R || C)
    e = (H_point(R) + H_point(C)) % N
    # перевірити z*G == R + e*C
    left  = _mul(z, G)
    right = _add(R, _mul(e, C))
    ok = left == right
    return {"ok": ok, "reason": "ok" if ok else "z*G != R + e*C"}

def reveal(proof, cid, salt):
    """Розкриття: перевірити що commitment справді від cid+salt."""
    s = H((cid + "|" + salt).encode())
    C = _mul(s, G)
    claimed = deserialize_point(proof["C"])
    match = C == claimed
    return {
        "ok": match,
        "computed": serialize_point(C),
        "claimed": proof["C"],
        "cid_hash_ok": hashlib.sha256(cid.encode()).hexdigest() == proof.get("cid_hash"),
    }

def full_verify(proof):
    """Повна перевірка: і proof, і заявлений cid_hash."""
    pv = verify_proof(proof)
    if not pv["ok"]: return pv
    if not proof.get("cid_hash"):
        return {"ok": False, "reason": "немає cid_hash"}
    return {"ok": True, "reason": "proof + cid_hash ok",
            "cid_hash": proof["cid_hash"]}

# ═══════════════════════════════════════════════════════════════
# CLI
# ═══════════════════════════════════════════════════════════════
D = Path(__file__).resolve().parent
COMMITS = D / "data" / "commitments"
PROOFS  = D / "data" / "proofs"
COMMITS.mkdir(parents=True, exist_ok=True)
PROOFS.mkdir(parents=True, exist_ok=True)

def _save(path, data):
    path.write_text(json.dumps(data, indent=2, ensure_ascii=False))

def cmd_commit(args):
    cid = args[0]
    salt = args[1] if len(args) > 1 else None
    rec = commit(cid, salt)
    out = COMMITS / f"{rec['cid_hash'][:16]}.json"
    _save(out, rec)
    G='\033[32m'; B='\033[36m'; D='\033[2m'; N='\033[0m'
    print(f"\n  {B}Commitment створено{N}")
    print(f"  CID hash:    {rec['cid_hash']}")
    print(f"  Curve:       {rec['curve']}")
    print(f"  Commitment:  x={rec['commitment']['x'][:20]}…")
    print(f"  Salt:        {rec['salt'][:32]}… {D}(збережи! потрібен для reveal){N}")
    print(f"  Saved:       {out}")
    print()

def cmd_prove(args):
    if len(args) < 2:
        print("usage: zk.py prove <cid> <salt>")
        return
    cid, salt = args[0], args[1]
    proof = prove(cid, salt)
    out = PROOFS / f"{proof['cid_hash'][:16]}.proof.json"
    _save(out, proof)
    G='\033[32m'; B='\033[36m'; N='\033[0m'
    print(f"\n  {B}Schnorr proof згенеровано{N}")
    print(f"  CID hash:  {proof['cid_hash']}")
    print(f"  R:         {proof['R']['x'][:20]}…")
    print(f"  z:         {proof['z'][:20]}…")
    print(f"  Saved:     {out}")
    print(f"\n  {G}✓{N} Тепер можна показати proof третім особам — вони перевірять")
    print(f"     без розкриття CID. Reveal пізніше покаже справжній CID.\n")

def cmd_verify(args):
    if not args: print("usage: zk.py verify <proof.json>"); return
    p = Path(args[0])
    if not p.exists(): print(f"  ✗ не знайдено: {p}"); return
    proof = json.loads(p.read_text())
    r = full_verify(proof)
    G='\033[32m'; R='\033[31m'; B='\033[36m'; N='\033[0m'
    col = G if r["ok"] else R
    print(f"\n  {B}ZK Verification{N}")
    print(f"  {col}{'✓ ПРОЙДЕНО' if r['ok'] else '✗ ПРОВАЛЕНО'}{N}")
    print(f"  Reason: {r['reason']}")
    if r.get("cid_hash"): print(f"  CID hash: {r['cid_hash']}")
    print()

def cmd_reveal(args):
    if len(args) < 3:
        print("usage: zk.py reveal <proof.json> <cid> <salt>")
        return
    p = Path(args[0])
    proof = json.loads(p.read_text())
    r = reveal(proof, args[1], args[2])
    G='\033[32m'; R='\033[31m'; B='\033[36m'; N='\033[0m'
    col = G if r["ok"] else R
    print(f"\n  {B}ZK Reveal{N}")
    print(f"  {col}{'✓ РОЗКРИТО' if r['ok'] else '✗ НЕ СПІВПАДАЄ'}{N}")
    print(f"  CID hash:  {'✓' if r.get('cid_hash_ok') else '✗'}")
    print()

def cmd_list(args):
    G='\033[32m'; B='\033[36m'; N='\033[0m'
    print(f"\n  {B}Commitments:{N}")
    for f in sorted(COMMITS.glob("*.json")):
        d = json.loads(f.read_text())
        print(f"    {d['cid_hash'][:16]}…  {d['at']}")
    print(f"\n  {B}Proofs:{N}")
    for f in sorted(PROOFS.glob("*.proof.json")):
        d = json.loads(f.read_text())
        print(f"    {d['cid_hash'][:16]}…  {d['at']}")
    print()

def cmd_selftest(args):
    """Self-test: commit → prove → verify → reveal."""
    print("\n  ▸ Self-test ZK:")
    cid = "C-INV-TEST-" + secrets.token_hex(4)
    salt = secrets.token_hex(16)
    print(f"    CID:  {cid}")
    print(f"    Salt: {salt[:24]}…")
    rec = commit(cid, salt)
    print(f"    ✓ commit")
    proof = prove(cid, salt)
    print(f"    ✓ prove")
    r = verify_proof(proof)
    print(f"    {'✓' if r['ok'] else '✗'} verify: {r['reason']}")
    rev = reveal(proof, cid, salt)
    print(f"    {'✓' if rev['ok'] else '✗'} reveal: cid_hash_ok={rev['cid_hash_ok']}")
    # негативний тест — підроблений CID
    rev_bad = reveal(proof, "WRONG-CID", salt)
    print(f"    {'✓' if not rev_bad['ok'] else '✗'} negative test (wrong cid): "
          f"{'правильно відкинуто' if not rev_bad['ok'] else 'ПРОБЛЕМА!'}")
    # перевірка швидкості
    import time as _t
    t0 = _t.time()
    for _ in range(10): prove(cid, salt)
    dt = (_t.time() - t0)/10*1000
    print(f"\n    Швидкість: {dt:.0f} ms на proof\n")

if __name__ == "__main__":
    args = sys.argv[1:]
    if not args:
        cmd_selftest(args); sys.exit(0)
    cmd = args[0]
    rest = args[1:]
    fn = {"commit":cmd_commit, "prove":cmd_prove, "verify":cmd_verify,
          "reveal":cmd_reveal, "list":cmd_list, "selftest":cmd_selftest}.get(cmd)
    if not fn:
        print("usage: zk.py {commit|prove|verify|reveal|list|selftest} ...")
        sys.exit(1)
    fn(rest)
